---@class picklevim.utils.formatting
---@overload fun(opts?: { force?: boolean })
---Formatting system with formatter registry and auto-format on save
local M = setmetatable({}, {
    __call = function(m, ...)
        return m.format(...)
    end,
})

-- Import formatter definitions
M.list_by_ft = require('utils.formatting.formatters').by_ft
M.list = require('utils.formatting.formatters').all

---@class PickleFormatter
---@field name string Formatter name (e.g., "conform")
---@field primary? boolean If true, only one primary formatter runs per buffer
---@field format fun(bufnr: number): boolean Format function, returns true if successful
---@field sources fun(bufnr: number): string[] Get available formatter sources for buffer
---@field priority number Higher priority formatters run first

--- Registered formatters (sorted by priority)
---@type PickleFormatter[]
M.formatters = {}

--- Cache for binary existence checks
--- Avoids repeated filesystem lookups for formatter binaries
---@type table<string, boolean>
M._binary_cache = {}

--- Check if a formatter binary is available in PATH
--- Results are cached for performance
---@param name string Binary name
---@return boolean available True if binary exists in PATH
M.has_binary = function(name)
    if M._binary_cache[name] == nil then
        M._binary_cache[name] = vim.fn.executable(name) == 1
    end
    return M._binary_cache[name]
end

--- Register a formatter in the global registry
--- Formatters are sorted by priority after registration
---@param formatter PickleFormatter Formatter to register
M.register = function(formatter)
    M.formatters[#M.formatters + 1] = formatter

    -- Sort by priority (highest first)
    table.sort(M.formatters, function(a, b)
        return a.priority > b.priority
    end)
end

--- Get formatexpr function for 'gq' formatting
--- Prefers Conform.nvim if available, falls back to LSP
---@return function formatexpr Format expression function
M.formatexpr = function()
    if PickleVim.plugin.has('conform.nvim') then
        return require('conform').formatexpr()
    end

    return vim.lsp.formatexpr({ timeout_ms = 3000 })
end

--- Resolve active formatters for a buffer
--- Returns formatters with their availability and resolved sources
--- Only one primary formatter can be active at a time
---@param buf? number Buffer number
---@return (PickleFormatter | { active: boolean, resolved: string[] })[] formatters
M.resolve = function(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local have_primary = false

    ---@param formatter PickleFormatter
    return vim.tbl_map(function(formatter)
        local sources = formatter.sources(buf)

        -- Filter out sources whose binaries don't exist
        local available_sources = vim.tbl_filter(function(source)
            return M.has_binary(source)
        end, sources)

        -- Formatter is active if:
        -- 1. It has available sources
        -- 2. It's not primary, OR it's primary and no other primary is active
        local active = #available_sources > 0 and (not formatter.primary or not have_primary)
        have_primary = have_primary or (active and formatter.primary) or false

        -- Return formatter with active/resolved metadata
        return setmetatable({
            active = active,
            resolved = available_sources,
        }, {
            __index = formatter,
        })
    end, M.formatters)
end

--- Display formatting information for a buffer
--- Shows autoformat status and available formatters
---@param buf? number Buffer number
M.info = function(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local gaf = vim.g.autoformat == nil or vim.g.autoformat
    local baf = vim.b[buf].autoformat
    local enabled = M.enabled(buf)

    -- Build status message
    local lines = {
        '# autoformat status',
        ('- [%s] global **%s**'):format(gaf and 'x' or ' ', gaf and 'enabled' or 'disabled'),
        ('- [%s] buffer **%s**'):format(
            enabled and 'x' or ' ',
            baf == nil and 'inherit' or baf and 'enabled' or 'disabled'
        ),
    }

    -- List available formatters
    local have = false
    for _, formatter in ipairs(M.resolve(buf)) do
        if #formatter.resolved > 0 then
            have = true
            lines[#lines + 1] = '\n# ' .. formatter.name .. (formatter.active and ' ***(active)***' or '')
            for _, line in ipairs(formatter.resolved) do
                lines[#lines + 1] = ('- [%s] **%s**'):format(formatter.active and 'x' or ' ', line)
            end
        end
    end

    if not have then
        lines[#lines + 1] = '\n***No formatters available for this buffer.***'
    end

    -- Display as info or warning based on enabled status
    PickleVim[enabled and 'info' or 'warn'](
        table.concat(lines, '\n'),
        { title = 'PickleFormat (' .. (enabled and 'enabled' or 'disabled') .. ')' }
    )
end

--- Create a notification message after formatting
---@param formatter PickleFormatter Formatter that was used
---@param buf number Buffer that was formatted
M.format_msg = function(formatter, buf)
    -- Extract filename from buffer path
    local parts = vim.split(PickleVim.norm(vim.api.nvim_buf_get_name(buf)), '[\\/]')
    local filename = parts[#parts]

    -- Build formatter list
    local formatters = '('
    local sources = formatter.sources(buf)
    for idx, name in ipairs(sources) do
        if idx ~= #sources then
            formatters = formatters .. name .. ', '
        else
            formatters = formatters .. name .. ')'
        end
    end

    vim.notify(formatters .. ': formatted ' .. filename)
end

--- Check if auto-format is enabled for a buffer
--- Checks buffer-local setting first, then falls back to global
---@param buf? number Buffer number
---@return boolean enabled True if auto-format is enabled
M.enabled = function(buf)
    buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
    local gaf = vim.g.autoformat
    local baf = vim.b[buf].autoformat

    -- Buffer-local setting takes precedence
    if baf ~= nil then
        return baf
    end

    -- Default to true if global not set
    return gaf == nil or gaf
end

--- Toggle auto-format for buffer or globally
---@param buf? number Buffer number (nil for global toggle)
M.toggle = function(buf)
    if buf then
        -- Toggle buffer-local setting
        vim.b[buf].autoformat = not M.enabled(buf)
    else
        -- Toggle global setting
        vim.g.autoformat = not (vim.g.autoformat == nil or vim.g.autoformat)
    end

    M.info(buf)
end

--- Enable or disable auto-format
---@param enable? boolean Whether to enable formatting (default: true)
---@param buf? number Buffer number (nil for global, 0 for current buffer)
M.enable = function(enable, buf)
    if enable == nil then
        enable = true
    end

    if buf then
        -- Set buffer-local
        buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
        vim.b[buf].autoformat = enable
    else
        -- Set global
        vim.g.autoformat = enable
    end

    M.info(buf)
end

--- Format a buffer using active formatters
--- Respects autoformat setting unless force is true
---@param opts? { force?: boolean, buf?: number }
M.format = function(opts)
    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()

    -- Skip if not enabled and not forced
    if not ((opts and opts.force) or M.enabled(buf)) then
        return
    end

    local done = false

    -- Run all active formatters in priority order
    for _, formatter in ipairs(M.resolve(buf)) do
        if formatter.active then
            done = true

            -- Wrap in try/catch to prevent errors from breaking the chain
            PickleVim.try(function()
                local formatted = formatter.format(buf) or false

                -- Show success notification
                if formatted then
                    M.format_msg(formatter, buf)
                end

                return formatted
            end, { msg = 'Formatter `' .. formatter.name .. '` failed' })
        end
    end

    -- Warn if forced but no formatters available
    if not done and opts and opts.force then
        PickleVim.warn('No formatter available', { title = 'PickleVim' })
        return false
    end
end

--- Setup formatting system
--- Creates autocmds and user commands
M.setup = function()
    -- Auto-format on save
    vim.api.nvim_create_autocmd('BufWritePre', {
        group = vim.api.nvim_create_augroup('PickleFormat', {}),
        callback = function(event)
            M.format({ buf = event.buf })
        end,
    })

    -- Manual format command (force format)
    vim.api.nvim_create_user_command('PickleFormat', function()
        M.format({ force = true })
    end, {
        desc = 'Format selection or buffer',
    })

    -- Show formatter info command
    vim.api.nvim_create_user_command('PickleFormatInfo', function()
        M.info()
    end, { desc = 'Show info about the formatters for the current buffer', force = true })
end

return M
