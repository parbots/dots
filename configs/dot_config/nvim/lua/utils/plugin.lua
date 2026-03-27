---@class picklevim.utils.plugin
---@field opts fun(string): any Get plugin options
local M = {}

--- Events that trigger LazyFile for file-related plugins
--- LazyFile fires earlier than VeryLazy for better UX when opening files
M.lazy_file_events = { 'BufReadPost', 'BufNewFile', 'BufWritePre' }

--- Setup the custom LazyFile event for lazy loading file-related plugins
--- This creates a custom event that fires when files are opened, before VeryLazy
M.setup_lazy_file = function()
    local Event = require('lazy.core.handler.event')

    -- Register LazyFile as a composite event
    Event.mappings.LazyFile = { id = 'LazyFile', event = M.lazy_file_events }
    Event.mappings['User LazyFile'] = Event.mappings.LazyFile
end

--- Initialize plugin utilities
--- Currently only sets up LazyFile event
M.setup = function()
    M.setup_lazy_file()
end

--- Get a plugin spec by name
---@param name string Plugin name (e.g., "nvim-lspconfig")
---@return LazyPlugin? plugin Plugin spec or nil if not found
M.get = function(name)
    return require('lazy.core.config').spec.plugins[name]
end

--- Check if a plugin is installed
---@param plugin string Plugin name
---@return boolean installed True if plugin is installed
M.has = function(plugin)
    return M.get(plugin) ~= nil
end

--- Get the resolved options for a plugin
--- Returns empty table if plugin not found or has no options
---@param name string Plugin name
---@return table opts Plugin options
M.opts = function(name)
    local plugin = M.get(name)

    if not plugin then
        return {}
    end

    -- Use Lazy's Plugin.values to resolve opts (handles functions, etc.)
    local Plugin = require('lazy.core.plugin')
    return Plugin.values(plugin, 'opts', false)
end

return M
