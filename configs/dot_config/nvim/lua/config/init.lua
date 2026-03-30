_G.PickleVim = require('utils')

---@class PickleVimConfig: PickleVimOptions
local M = {}

PickleVim.config = M
PickleVim.icons = require('config.icons')

---@class PickleVimOptions
local defaults = {
    ---@type string | fun()
    colorscheme = 'catppuccin',

    defaults = {
        autocmds = true,
        keymaps = true,
    },

    ---@type table<string, string[] | boolean>?
    kind_filter = {
        default = {
            'Class',
            'Constructor',
            'Enum',
            'Field',
            'Function',
            'Interface',
            'Method',
            'Module',
            'Namespace',
            'Package',
            'Property',
            'Struct',
            'Trait',
        },
        markdown = false,
        help = false,
        lua = {
            'Class',
            'Constructor',
            'Enum',
            'Field',
            'Function',
            'Interface',
            'Method',
            'Module',
            'Namespace',
            'Property',
            'Struct',
            'Trait',
        },
    },
}

---@type PickleVimOptions
local options

local lazy_clipboard

---@param name 'autocmds' | 'options' | 'keymaps'
M.load = function(name)
    ---@param mod string
    local _load = function(mod)
        if require('lazy.core.cache').find(mod)[1] then
            PickleVim.try(function()
                require(mod)
            end, {
                msg = 'Failed loading ' .. mod,
            })
        end
    end

    local pattern = 'PickleVim' .. name:sub(1, 1):upper() .. name:sub(2)

    _load('config.' .. name)

    if vim.bo.filetype == 'lazy' then
        vim.cmd([[do VimResized]])
    end

    vim.api.nvim_exec_autocmds('User', { pattern = pattern, modeline = false })
end

---@param opts? PickleVimConfig
M.setup = function(opts)
    options = vim.tbl_deep_extend('force', defaults, opts or {}) or {}

    -- Only lazy load autocmds if Neovim started without arguments
    local lazy_autocmds = vim.fn.argc(-1) == 0
    if not lazy_autocmds then
        M.load('autocmds')
    end

    local group = vim.api.nvim_create_augroup('picklevim_init', { clear = true })
    vim.api.nvim_create_autocmd('User', {
        group = group,
        pattern = 'VeryLazy',
        callback = function()
            if lazy_autocmds then
                M.load('autocmds')
            end

            M.load('keymaps')

            if lazy_clipboard ~= nil then
                vim.opt.clipboard = lazy_clipboard
            end

            PickleVim.formatting.setup()
            PickleVim.root.setup()
        end,
    })

    PickleVim.track('colorscheme')
    PickleVim.try(function()
        if type(M.colorscheme) == 'function' then
            M.colorscheme()
        else
            vim.cmd.colorscheme(M.colorscheme)
        end
    end, {
        msg = 'Could not load colorscheme',
        on_error = function(msg)
            PickleVim.error(msg)
            vim.cmd.colorscheme('catppuccin')
        end,
    })
    PickleVim.track()
end

M.did_init = false

M.init = function()
    if M.did_init then
        return
    end

    M.did_init = true

    PickleVim.lazy_notify()

    M.load('options')

    -- Defer clipboard to avoid startup cost
    lazy_clipboard = vim.opt.clipboard
    vim.opt.clipboard = ''

    PickleVim.plugin.setup()
end

---@param buf? number
---@return string[] | nil | boolean
M.get_kind_filter = function(buf)
    buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf

    local ft = vim.bo[buf].filetype

    if type(M.kind_filter[ft]) == 'boolean' then
        return nil
    end

    if type(M.kind_filter[ft]) == 'table' then
        return M.kind_filter[ft]
    end

    if type(M.kind_filter.default) == 'table' then
        return M.kind_filter.default
    end

    return nil
end

-- Allows accessing config values directly (e.g., M.colorscheme)
-- Falls back to defaults if setup() hasn't been called yet
setmetatable(M, {
    __index = function(_, key)
        if options == nil then
            return vim.deepcopy(defaults)[key]
        end

        ---@cast options PickleVimConfig
        return options[key]
    end,
})

return M
