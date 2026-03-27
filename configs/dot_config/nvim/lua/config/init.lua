--- Main configuration module for PickleVim
--- Handles initialization, setup, and configuration management
--- Provides centralized config with lazy loading and default options

-- Initialize global PickleVim namespace with utilities
_G.PickleVim = require('utils')

---@class PickleVimConfig: PickleVimOptions
local M = {}

-- Register config module globally
PickleVim.config = M
PickleVim.icons = require('config.icons')

---@class PickleVimOptions
---Configuration options for PickleVim
local defaults = {
    --- Colorscheme to load (string or function)
    ---@type string | fun()
    colorscheme = 'catppuccin',

    --- Control loading of default configs
    defaults = {
        autocmds = true, -- Load default autocmds
        keymaps = true,  -- Load default keymaps
    },

    --- LSP symbol kind filtering for document symbols, aerial, etc.
    --- Controls which symbol types appear in outlines and symbol pickers
    ---@type table<string, string[] | boolean>?
    kind_filter = {
        -- Default filter for most filetypes
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
        -- Disable symbol filtering for these filetypes
        markdown = false,
        help = false,
        -- Lua-specific filter
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

--- User-provided options (merged with defaults in setup())
---@type PickleVimOptions
local options

--- Clipboard setting backup for lazy loading
local lazy_clipboard

--- Load a config module (autocmds, options, or keymaps)
--- Safely loads module and triggers corresponding User event
---@param name 'autocmds' | 'options' | 'keymaps' Config module to load
M.load = function(name)
    --- Internal function to safely load a module if it exists
    ---@param mod string Module path to load
    local _load = function(mod)
        -- Check if module exists before requiring
        if require('lazy.core.cache').find(mod)[1] then
            PickleVim.try(function()
                require(mod)
            end, {
                msg = 'Failed loading ' .. mod,
            })
        end
    end

    -- Build User event pattern (e.g., "PickleVimAutocmds")
    local pattern = 'PickleVim' .. name:sub(1, 1):upper() .. name:sub(2)

    -- Load the config module
    _load('config.' .. name)

    -- Fix Lazy.nvim UI if open
    if vim.bo.filetype == 'lazy' then
        vim.cmd([[do VimResized]])
    end

    -- Trigger User event for plugins to hook into
    vim.api.nvim_exec_autocmds('User', { pattern = pattern, modeline = false })
end

--- Setup PickleVim configuration
--- Called from lazy.lua after plugin manager is initialized
--- Handles loading order: options -> autocmds -> keymaps (lazy)
---@param opts? PickleVimConfig User configuration options
M.setup = function(opts)
    -- Merge user options with defaults
    options = vim.tbl_deep_extend('force', defaults, opts or {}) or {}

    -- Determine if autocmds should be lazy-loaded
    -- Only lazy load if Neovim started without arguments
    local lazy_autocmds = vim.fn.argc(-1) == 0
    if not lazy_autocmds then
        M.load('autocmds')
    end

    -- Setup VeryLazy callback for deferred initialization
    local group = vim.api.nvim_create_augroup('picklevim_init', { clear = true })
    vim.api.nvim_create_autocmd('User', {
        group = group,
        pattern = 'VeryLazy',
        callback = function()
            -- Load autocmds if they were deferred
            if lazy_autocmds then
                M.load('autocmds')
            end

            -- Load keymaps after plugins are loaded
            M.load('keymaps')

            -- Restore clipboard setting after startup
            if lazy_clipboard ~= nil then
                vim.opt.clipboard = lazy_clipboard
            end

            -- Initialize formatting and root detection systems
            PickleVim.formatting.setup()
            PickleVim.root.setup()
        end,
    })

    -- Load colorscheme with error handling
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
            -- Fallback to catppuccin
            vim.cmd.colorscheme('catppuccin')
        end,
    })
    PickleVim.track()
end

--- Flag to prevent double initialization
M.did_init = false

--- Initialize PickleVim (called very early in startup)
--- Sets up deferred notifications, loads options, and prepares clipboard
M.init = function()
    -- Prevent double initialization
    if M.did_init then
        return
    end

    M.did_init = true

    -- Setup deferred notification system
    PickleVim.lazy_notify()

    -- Load options immediately (before plugins)
    M.load('options')

    -- Defer clipboard to avoid startup cost
    lazy_clipboard = vim.opt.clipboard
    vim.opt.clipboard = ''

    -- Setup plugin utilities (LazyFile event, etc.)
    PickleVim.plugin.setup()
end

--- Get LSP symbol kind filter for a buffer
--- Returns which symbol types should be shown in document symbols, aerial, etc.
--- Returns nil if filtering is disabled for the filetype
---@param buf? number Buffer number (default: current buffer)
---@return string[] | nil | boolean kinds Symbol kinds to show, or nil/false to disable filtering
M.get_kind_filter = function(buf)
    buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf

    local ft = vim.bo[buf].filetype

    -- If filetype has boolean false, disable filtering entirely
    if type(M.kind_filter[ft]) == 'boolean' then
        return nil
    end

    -- If filetype has specific filter, use it
    if type(M.kind_filter[ft]) == 'table' then
        return M.kind_filter[ft]
    end

    -- Fall back to default filter
    if type(M.kind_filter.default) == 'table' then
        return M.kind_filter.default
    end

    return nil
end

-- Metatable for lazy access to configuration options
-- Allows accessing config values directly (e.g., M.colorscheme)
-- Falls back to defaults if setup() hasn't been called yet
setmetatable(M, {
    __index = function(_, key)
        if options == nil then
            -- Return deep copy to prevent mutation of defaults
            return vim.deepcopy(defaults)[key]
        end

        ---@cast options PickleVimConfig
        return options[key]
    end,
})

return M
