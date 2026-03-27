local LazyUtil = require('lazy.core.util')

---@class picklevim.utils: LazyUtilCore
---@field config PickleVimConfig Configuration system
---@field icons picklevim.icons Icon definitions
---@field formatting picklevim.utils.formatting Formatter registry and management
---@field lsp picklevim.utils.lsp LSP utilities and callbacks
---@field lualine picklevim.utils.lualine Lualine component helpers
---@field mini picklevim.utils.mini Mini.nvim integration helpers
---@field pick picklevim.utils.pick Picker abstraction layer
---@field plugin picklevim.utils.plugin Plugin management utilities
---@field root picklevim.utils.root Project root detection
---@field ui picklevim.utils.ui UI utilities (folding, etc.)
local M = {}

-- Export to global namespace for easy access
_G.PickleVim = M

-- Metatable for lazy-loading utility modules
-- When accessing a key that doesn't exist, try to load it from utils/
setmetatable(M, {
    __index = function(t, k)
        -- First check if LazyUtil has this utility
        if LazyUtil[k] then
            return LazyUtil[k]
        end

        -- Lazy-load from utils/ directory
        t[k] = require('utils.' .. k)

        return t[k]
    end,
})

--- Check if running on Windows
---@return boolean is_windows True if running on Windows
function M.is_win()
    return vim.uv.os_uname().sysname:find('Windows') ~= nil
end

--- Defer notifications until a proper notification handler is loaded
--- Captures all vim.notify calls during startup and replays them after 500ms
--- or when a notification plugin (like Snacks) is loaded
M.lazy_notify = function()
    local notifs = {}

    -- Temporary notify function that captures notifications
    local temp = function(...)
        table.insert(notifs, vim.F.pack_len(...))
    end

    -- Store original vim.notify
    local orig = vim.notify
    vim.notify = temp

    local timer = vim.uv.new_timer()
    local check = assert(vim.uv.new_check())

    -- Replay captured notifications
    local replay = function()
        if timer then
            timer:stop()
            timer:close()
            timer = nil
        end
        check:stop()
        check:close()

        -- Restore original notify if still using temp
        if vim.notify == temp then
            vim.notify = orig
        end

        -- Replay all captured notifications
        vim.schedule(function()
            for _, notif in ipairs(notifs) do
                vim.notify(vim.F.unpack_len(notif))
            end
        end)
    end

    -- Check if notify has been overridden by a plugin
    check:start(function()
        if vim.notify ~= temp then
            replay()
        end
    end)

    -- Fallback: replay after 500ms even if no plugin loaded
    if timer then
        timer:start(500, 0, replay)
    end
end

--- Execute a function when VeryLazy event fires
--- VeryLazy fires after startup when Neovim is idle
---@param fn fun() Function to execute
M.on_very_lazy = function(fn)
    vim.api.nvim_create_autocmd('User', {
        pattern = 'VeryLazy',
        callback = function()
            fn()
        end,
    })
end

--- Check if a plugin is loaded
---@param name string Plugin name
---@return boolean loaded True if plugin is loaded
M.is_loaded = function(name)
    local Config = require('lazy.core.config')
    return Config.plugins[name] and Config.plugins[name]._.loaded
end

--- Execute a function when a plugin is loaded
--- If plugin is already loaded, execute immediately
--- Otherwise, wait for LazyLoad event
---@param name string Plugin name
---@param fn fun(name: string) Function to execute when plugin loads
M.on_load = function(name, fn)
    if M.is_loaded(name) then
        fn(name)
    else
        vim.api.nvim_create_autocmd('User', {
            pattern = 'LazyLoad',
            callback = function(event)
                if event.data == name then
                    fn(name)

                    -- Return true to remove autocmd after first trigger
                    return true
                end
            end,
        })
    end
end

--- Cache for memoized functions
---@type table<(fun()), table<string, any>>
local cache = {}

--- Memoize a function (cache results based on arguments)
--- Useful for expensive computations that are called repeatedly
---@generic T: fun()
---@param fn T Function to memoize
---@param key_fn? fun(...): string Custom key function (defaults to vim.inspect)
---@return T memoized_fn Memoized version of the function
M.memoize = function(fn, key_fn)
    return function(...)
        local key = key_fn and key_fn(...) or vim.inspect({ ... })

        cache[fn] = cache[fn] or {}

        if cache[fn][key] == nil then
            cache[fn][key] = fn(...)
        end

        return cache[fn][key]
    end
end

--- Clear all memoized function caches
M.clear_memoize_cache = function()
    cache = {}
end

return M
