---@class picklevim.utils.lualine
local M = {}

---@param icon string
---@param status fun(): nil | 'ok' | 'error' | 'pending'
---@return table
M.status = function(icon, status)
    local colors = {
        ok = 'Special',
        error = 'DiagnosticError',
        pending = 'DiagnosticWarn',
    }

    return {
        function()
            return icon
        end,

        cond = function()
            return status() ~= nil
        end,

        color = function()
            return { fg = Snacks.util.color(colors[status()]) or colors.ok }
        end,
    }
end

---@param component any
---@param text string
---@param hl_group? string
---@return string
M.format = function(component, text, hl_group)
    text = text:gsub('%%', '%%%%')

    if not hl_group or hl_group == '' then
        return text
    end

    ---@type table<string, string>
    component.hl_cache = component.hl_cache or {}
    local lualine_hl_group = component.hl_cache[hl_group]

    if not lualine_hl_group then
        local utils = require('lualine.utils.utils')

        ---@type string[]
        local gui = vim.tbl_filter(function(x)
            return x
        end, {
            utils.extract_highlight_colors(hl_group, 'bold') and 'bold',
            utils.extract_highlight_colors(hl_group, 'italic') and 'italic',
        })

        lualine_hl_group = component:create_hl({
            fg = utils.extract_highlight_colors(hl_group, 'fg'),
            gui = #gui > 0 and table.concat(gui, ',') or nil,
        }, 'LV_' .. hl_group)

        component.hl_cache[hl_group] = lualine_hl_group
    end

    return component:format_hl(lualine_hl_group) .. text .. component:get_default_hl()
end

---@param opts? { relative: "cwd" | "root", modified_hl: string?, directory_hl: string?, filename_hl: string?, modified_sign: string?, readonly_icon: string?, length: number? }
---@return table
M.pretty_path = function(opts)
    opts = vim.tbl_extend('force', {
        relative = 'cwd',
        modified_hl = 'MatchParen',
        directory_hl = '',
        filename_hl = 'Bold',
        modified_sign = '',
        readonly_icon = ' 󰌾 ',
        length = 3,
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
            dir = M.format(self, dir .. '/', opts.directory_hl)
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

---@param opts? {cwd:false, subdirectory: true, parent: true, other: true, icon?:string}
---@return table
M.root_dir = function(opts)
    opts = vim.tbl_extend('force', {
        cwd = true,
        subdirectory = true,
        parent = true,
        other = true,
        icon = '󱉭 ',
        color = { fg = Snacks.util.color('Special') },
    }, opts or {})

    ---@return string?
    local get_name = function()
        local cwd = PickleVim.root.cwd()
        local root = PickleVim.root.get({ normalize = true })
        local name = vim.fs.basename(root)

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

---@return table
M.noice_cmd = function()
    local noice = require('noice')
    return {
        noice.api.status.command.get, ---@diagnostic disable-line: undefined-field
        cond = noice.api.status.command.has, ---@diagnostic disable-line: undefined-field
        color = { fg = Snacks.util.color('Statement') },
    }
end

---@return table
M.noice_mode = function()
    local noice = require('noice')
    return {
        noice.api.status.mode.get, ---@diagnostic disable-line: undefined-field
        cond = noice.api.status.mode.has, ---@diagnostic disable-line: undefined-field
        color = { fg = Snacks.util.color('Constant') },
    }
end

---@return table
M.lazy_status = function()
    local lazy_status = require('lazy.status')

    return {
        lazy_status.updates,
        cond = lazy_status.has_updates,
        color = { fg = Snacks.util.color('Special') },
    }
end

---@return table
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
