---@class picklevim.utils.plugin
---@field opts fun(string): any Get plugin options
local M = {}

M.lazy_file_events = { 'BufReadPost', 'BufNewFile', 'BufWritePre' }

M.setup_lazy_file = function()
    local Event = require('lazy.core.handler.event')

    Event.mappings.LazyFile = { id = 'LazyFile', event = M.lazy_file_events }
    Event.mappings['User LazyFile'] = Event.mappings.LazyFile
end

M.setup = function()
    M.setup_lazy_file()
end

---@param name string
---@return LazyPlugin?
M.get = function(name)
    return require('lazy.core.config').spec.plugins[name]
end

---@param plugin string
---@return boolean
M.has = function(plugin)
    return M.get(plugin) ~= nil
end

---@param name string
---@return table
M.opts = function(name)
    local plugin = M.get(name)

    if not plugin then
        return {}
    end

    local Plugin = require('lazy.core.plugin')
    return Plugin.values(plugin, 'opts', false)
end

return M
