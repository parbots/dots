---@class picklevim.utils.formatting
---@overload fun(opts?: { force?: boolean })
local M = setmetatable({}, {
    __call = function(m, ...)
        return m.format(...)
    end,
})

M.list_by_ft = require('utils.formatting.formatters').by_ft
M.list = require('utils.formatting.formatters').all

---@class PickleFormatter
---@field name string Formatter name (e.g., "conform")
---@field primary? boolean If true, only one primary formatter runs per buffer
---@field format fun(bufnr: number): boolean Format function, returns true if successful
---@field sources fun(bufnr: number): string[] Get available formatter sources for buffer
---@field priority number Higher priority formatters run first

---@type PickleFormatter[]
M.formatters = {}

-- Caches vim.fn.executable() results to avoid repeated shell calls on every
-- format invocation. Cleared only on Neovim restart.
---@type table<string, boolean>
M._binary_cache = {}

---@param name string
---@return boolean
M.has_binary = function(name)
    if M._binary_cache[name] == nil then
        M._binary_cache[name] = vim.fn.executable(name) == 1
    end
    return M._binary_cache[name]
end

---@param formatter PickleFormatter
M.register = function(formatter)
    M.formatters[#M.formatters + 1] = formatter

    table.sort(M.formatters, function(a, b)
        return a.priority > b.priority
    end)
end

---@return function
M.formatexpr = function()
    if PickleVim.plugin.has('conform.nvim') then
        return require('conform').formatexpr()
    end

    return vim.lsp.formatexpr({ timeout_ms = 3000 })
end

---@param buf? number
---@return (PickleFormatter | { active: boolean, resolved: string[] })[]
M.resolve = function(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local have_primary = false

    ---@param formatter PickleFormatter
    return vim.tbl_map(function(formatter)
        local sources = formatter.sources(buf)

        local available_sources = vim.tbl_filter(function(source)
            return M.has_binary(source)
        end, sources)

        local active = #available_sources > 0 and (not formatter.primary or not have_primary)
        have_primary = have_primary or (active and formatter.primary) or false

        return setmetatable({
            active = active,
            resolved = available_sources,
        }, {
            __index = formatter,
        })
    end, M.formatters)
end

---@param buf? number
M.info = function(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local gaf = vim.g.autoformat == nil or vim.g.autoformat
    local baf = vim.b[buf].autoformat
    local enabled = M.enabled(buf)

    local lines = {
        '# autoformat status',
        ('- [%s] global **%s**'):format(gaf and 'x' or ' ', gaf and 'enabled' or 'disabled'),
        ('- [%s] buffer **%s**'):format(
            enabled and 'x' or ' ',
            baf == nil and 'inherit' or baf and 'enabled' or 'disabled'
        ),
    }

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

    PickleVim[enabled and 'info' or 'warn'](
        table.concat(lines, '\n'),
        { title = 'PickleFormat (' .. (enabled and 'enabled' or 'disabled') .. ')' }
    )
end

---@param formatter PickleFormatter
---@param buf number
M.format_msg = function(formatter, buf)
    local parts = vim.split(PickleVim.norm(vim.api.nvim_buf_get_name(buf)), '[\\/]')
    local filename = parts[#parts]

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

---@param buf? number
---@return boolean
M.enabled = function(buf)
    buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
    local gaf = vim.g.autoformat
    local baf = vim.b[buf].autoformat

    if baf ~= nil then
        return baf
    end

    return gaf == nil or gaf
end

---@param buf? number
M.toggle = function(buf)
    if buf then
        vim.b[buf].autoformat = not M.enabled(buf)
    else
        vim.g.autoformat = not (vim.g.autoformat == nil or vim.g.autoformat)
    end

    M.info(buf)
end

---@param enable? boolean
---@param buf? number
M.enable = function(enable, buf)
    if enable == nil then
        enable = true
    end

    if buf then
        buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
        vim.b[buf].autoformat = enable
    else
        vim.g.autoformat = enable
    end

    M.info(buf)
end

---@param opts? { force?: boolean, buf?: number }
M.format = function(opts)
    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()

    if not ((opts and opts.force) or M.enabled(buf)) then
        return
    end

    local done = false

    for _, formatter in ipairs(M.resolve(buf)) do
        if formatter.active then
            done = true

            PickleVim.try(function()
                local formatted = formatter.format(buf) or false

                if formatted then
                    M.format_msg(formatter, buf)
                end

                return formatted
            end, { msg = 'Formatter `' .. formatter.name .. '` failed' })
        end
    end

    if not done and opts and opts.force then
        PickleVim.warn('No formatter available', { title = 'PickleVim' })
        return false
    end
end

M.setup = function()
    vim.api.nvim_create_autocmd('BufWritePre', {
        group = vim.api.nvim_create_augroup('PickleFormat', {}),
        callback = function(event)
            M.format({ buf = event.buf })
        end,
    })

    vim.api.nvim_create_user_command('PickleFormat', function()
        M.format({ force = true })
    end, {
        desc = 'Format selection or buffer',
    })

    vim.api.nvim_create_user_command('PickleFormatInfo', function()
        M.info()
    end, { desc = 'Show info about the formatters for the current buffer', force = true })
end

return M
