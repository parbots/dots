---@class picklevim.utils.lualine
---Lualine component helpers for custom statusline elements
local M = {}

--- Create a status component with dynamic icon and color
--- Useful for showing LSP status, formatter status, etc.
---@param icon string Icon to display (e.g., " ")
---@param status fun(): nil | 'ok' | 'error' | 'pending' Function returning current status
---@return table component Lualine component configuration
M.status = function(icon, status)
    -- Status to highlight group mapping
    local colors = {
        ok = 'Special',
        error = 'DiagnosticError',
        pending = 'DiagnosticWarn',
    }

    return {
        -- Display function
        function()
            return icon
        end,

        -- Only show if status is not nil
        cond = function()
            return status() ~= nil
        end,

        -- Dynamic color based on status
        color = function()
            return { fg = Snacks.util.color(colors[status()]) or colors.ok }
        end,
    }
end

--- Format text with a highlight group for lualine
--- Handles highlight caching and formatting with lualine's hl system
---@param component any Lualine component instance
---@param text string Text to format
---@param hl_group? string Highlight group name
---@return string formatted Formatted text with highlight codes
M.format = function(component, text, hl_group)
    -- Escape % characters for lualine
    text = text:gsub('%%', '%%%%')

    -- Return plain text if no highlight group specified
    if not hl_group or hl_group == '' then
        return text
    end

    -- Use cached highlight if available
    ---@type table<string, string>
    component.hl_cache = component.hl_cache or {}
    local lualine_hl_group = component.hl_cache[hl_group]

    if not lualine_hl_group then
        local utils = require('lualine.utils.utils')

        -- Extract gui attributes (bold, italic)
        ---@type string[]
        local gui = vim.tbl_filter(function(x)
            return x
        end, {
            utils.extract_highlight_colors(hl_group, 'bold') and 'bold',
            utils.extract_highlight_colors(hl_group, 'italic') and 'italic',
        })

        -- Create lualine highlight with extracted colors
        lualine_hl_group = component:create_hl({
            fg = utils.extract_highlight_colors(hl_group, 'fg'),
            gui = #gui > 0 and table.concat(gui, ',') or nil,
        }, 'LV_' .. hl_group) -- Prefix with LV_ for namespace

        -- Cache for future use
        component.hl_cache[hl_group] = lualine_hl_group
    end

    -- Return text wrapped with highlight codes
    return component:format_hl(lualine_hl_group) .. text .. component:get_default_hl()
end

--- Create a pretty path component for lualine
--- Shows relative path with directory/filename highlighting and modified indicator
--- Truncates long paths intelligently
---@param opts? { relative: "cwd" | "root", modified_hl: string?, directory_hl: string?, filename_hl: string?, modified_sign: string?, readonly_icon: string?, length: number? }
---@return table component Lualine component configuration
M.pretty_path = function(opts)
    -- Default options
    opts = vim.tbl_extend('force', {
        relative = 'cwd',           -- Make path relative to cwd or project root
        modified_hl = 'MatchParen', -- Highlight for modified indicator
        directory_hl = '',          -- Highlight for directory part
        filename_hl = 'Bold',       -- Highlight for filename
        modified_sign = '',        -- Icon shown when buffer is modified
        readonly_icon = ' 󰌾 ',      -- Icon shown when buffer is readonly
        length = 3,                 -- Max path parts to show (0 = unlimited)
    }, opts or {})

    local get_path = function(self)
        local path = vim.fn.expand('%:p')

        if path == '' then
            return ''
        end

        path = PickleVim.norm(path)
        local root = PickleVim.root.get({ normalize = true })
        local cwd = PickleVim.root.cwd()

        if opts.relative == 'cwd' and path:find(cwd, 1, true) == 1 then
            path = path:sub(#cwd + 2)
        elseif path:find(root, 1, true) == 1 then
            path = path:sub(#root + 2)
        end

        local parts = vim.split(path, '[\\/]')

        if opts.length == 0 then
            parts = parts
        elseif #parts > opts.length then
            parts = { parts[1], '…', unpack(parts, #parts - opts.length + 2, #parts) }
        end

        if opts.modified_hl and vim.bo.modified then
            parts[#parts] = parts[#parts] .. opts.modified_sign
            parts[#parts] = M.format(self, parts[#parts], opts.modified_hl)
        else
            parts[#parts] = M.format(self, parts[#parts], opts.filename_hl)
        end

        local dir = ''
        if #parts > 1 then
            dir = table.concat({ unpack(parts, 1, #parts - 1) }, '/')
            dir = M.format(self, dir .. sep, opts.directory_hl)
        end

        local readonly = ''
        if vim.bo.readonly then
            readonly = M.format(self, opts.readonly_icon, opts.modified_hl)
        end

        return dir .. parts[#parts] .. readonly
    end

    return {
        get_path,
        padding = { left = 1, right = 0 },
    }
end

--- Create a root directory component
--- Shows project root name with conditional display based on relationship to cwd
---@param opts? {cwd:false, subdirectory: true, parent: true, other: true, icon?:string}
---@return table component Lualine component configuration
M.root_dir = function(opts)
    opts = vim.tbl_extend('force', {
        cwd = true,             -- Show when root == cwd
        subdirectory = true,    -- Show when root is subdirectory of cwd
        parent = true,          -- Show when cwd is subdirectory of root
        other = true,           -- Show when root is elsewhere
        icon = '󱉭 ',
        color = { fg = Snacks.util.color('Special') },
    }, opts or {})

    --- Get root directory name based on relationship to cwd
    ---@return string? name Root directory name or nil
    local get_name = function()
        local cwd = PickleVim.root.cwd()
        local root = PickleVim.root.get({ normalize = true })
        local name = vim.fs.basename(root)

        -- Return name based on relationship between root and cwd
        if root == cwd then
            return opts.cwd and name
        elseif root:find(cwd, 1, true) == 1 then
            return opts.subdirectory and name
        elseif cwd:find(root, 1, true) == 1 then
            return opts.parent and name
        else
            return opts.other and name
        end
    end

    return {
        function()
            return (opts.icon and opts.icon) .. get_name()
        end,
        cond = function()
            return type(get_name()) == 'string'
        end,
        color = opts.color,
        padding = { left = 1, right = 1 },
    }
end

--- Create a Noice command component
--- Shows the current command being executed via Noice
---@return table component Lualine component configuration
M.noice_cmd = function()
    local noice = require('noice')
    return {
        noice.api.status.command.get, ---@diagnostic disable-line: undefined-field
        cond = noice.api.status.command.has, ---@diagnostic disable-line: undefined-field
        color = { fg = Snacks.util.color('Statement') },
    }
end

--- Create a Noice mode component
--- Shows the current mode via Noice
---@return table component Lualine component configuration
M.noice_mode = function()
    local noice = require('noice')
    return {
        noice.api.status.mode.get, ---@diagnostic disable-line: undefined-field
        cond = noice.api.status.mode.has, ---@diagnostic disable-line: undefined-field
        color = { fg = Snacks.util.color('Constant') },
    }
end

--- Create a Lazy.nvim update status component
--- Shows pending plugin updates
---@return table component Lualine component configuration
M.lazy_status = function()
    local lazy_status = require('lazy.status')

    return {
        lazy_status.updates,
        cond = lazy_status.has_updates,
        color = { fg = Snacks.util.color('Special') },
    }
end

--- Create an LSP status component
--- Shows names of attached LSP clients
---@return table component Lualine component configuration
M.lsp_status = function()
    return {
        function()
            local clients = vim.lsp.get_clients({ bufnr = 0 })
            if #clients == 0 then
                return ''
            end

            local names = {}
            for _, client in ipairs(clients) do
                table.insert(names, client.name)
            end

            return ' ' .. table.concat(names, ' ')
        end,
        cond = function()
            return #vim.lsp.get_clients({ bufnr = 0 }) > 0
        end,
        color = { fg = Snacks.util.color('Special') },
        padding = { left = 0, right = 1 },
    }
end

return M
