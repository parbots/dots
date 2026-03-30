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
local M = {}

_G.PickleVim = M

setmetatable(M, {
    __index = function(t, k)
        if LazyUtil[k] then
            return LazyUtil[k]
        end

        t[k] = require('utils.' .. k)

        return t[k]
    end,
})

---@return boolean
function M.is_win()
    return vim.uv.os_uname().sysname:find('Windows') ~= nil
end

-- Captures vim.notify calls during startup and replays them once a
-- notification plugin loads or after 500ms, whichever comes first.
M.lazy_notify = function()
    local notifs = {}

    local temp = function(...)
        table.insert(notifs, vim.F.pack_len(...))
    end

    local orig = vim.notify
    vim.notify = temp

    local timer = vim.uv.new_timer()
    local check = assert(vim.uv.new_check())

    local replay = function()
        if timer then
            timer:stop()
            timer:close()
            timer = nil
        end
        check:stop()
        check:close()

        if vim.notify == temp then
            vim.notify = orig
        end

        vim.schedule(function()
            for _, notif in ipairs(notifs) do
                vim.notify(vim.F.unpack_len(notif))
            end
        end)
    end

    check:start(function()
        if vim.notify ~= temp then
            replay()
        end
    end)

    if timer then
        timer:start(500, 0, replay)
    end
end

---@param fn fun()
M.on_very_lazy = function(fn)
    vim.api.nvim_create_autocmd('User', {
        pattern = 'VeryLazy',
        callback = function()
            fn()
        end,
    })
end

---@param name string
---@return boolean
M.is_loaded = function(name)
    local Config = require('lazy.core.config')
    return Config.plugins[name] and Config.plugins[name]._.loaded
end

---@param name string
---@param fn fun(name: string)
M.on_load = function(name, fn)
    if M.is_loaded(name) then
        fn(name)
    else
        vim.api.nvim_create_autocmd('User', {
            pattern = 'LazyLoad',
            callback = function(event)
                if event.data == name then
                    fn(name)

                    return true
                end
            end,
        })
    end
end

---@type table<(fun()), table<string, any>>
local cache = {}

---@generic T: fun()
---@param fn T
---@param key_fn? fun(...): string
---@return T
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

M.clear_memoize_cache = function()
    cache = {}
end

---@class picklevim.utils.ui
M.ui = {}

---@return string
M.ui.foldtext = function()
    return vim.api.nvim_buf_get_lines(0, vim.v.lnum - 1, vim.v.lnum, false)[1]
end

---@return string|number
M.ui.foldexpr = function()
    local buf = vim.api.nvim_get_current_buf()

    if vim.b[buf].ts_folds == nil then
        if vim.bo[buf].filetype == '' then
            return 0
        end

        if vim.bo[buf].filetype:find('dashboard') then
            vim.b[buf].ts_folds = false
        else
            vim.b[buf].ts_folds = vim.treesitter.get_parser(buf) ~= nil
        end
    end

    return vim.b[buf].ts_folds and vim.treesitter.foldexpr() or '0'
end

return M
