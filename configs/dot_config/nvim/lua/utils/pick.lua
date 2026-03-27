---@class picklevim.utils.pick
---@overload fun(command: string, opts?: picklevim.utils.pick.Opts): fun()
local M = setmetatable({}, {
    __call = function(m, ...)
        return m.wrap(...)
    end,
})

---@class picklevim.utils.pick.Opts: table<string, any>
---@field root? boolean Use project root as cwd
---@field cwd? string Custom working directory
---@field buf? number Buffer number for context
---@field show_untracked? boolean Show untracked files in git

---@class PicklePicker
---@field name string Picker implementation name (e.g., "snacks")
---@field open fun(command: string, opts?: picklevim.utils.pick.Opts) Open picker with command
---@field commands table<string, string> Command aliases mapping

---@type PicklePicker?
M.picker = nil

--- Register a picker implementation
--- Only one picker can be registered at a time
---@param picker PicklePicker
---@return boolean success True if registered successfully
M.register = function(picker)
    -- Prevent overriding if a different picker is already registered
    if M.picker and M.picker.name ~= picker.name then
        return false
    end

    M.picker = picker

    return true
end

--- Open the picker with the given command and options
--- Automatically resolves project root if root option is set
---@param command? string Picker command (e.g., "files", "grep", "buffers")
---@param opts? picklevim.utils.pick.Opts Picker options
M.open = function(command, opts)
    if not M.picker then
        return PickleVim.error('PickleVim.pick: picker not set')
    end

    -- Default to 'files' command if 'auto' is specified
    command = command ~= 'auto' and command or 'files'
    opts = opts or {}

    -- Deep copy to avoid mutating original opts
    opts = vim.deepcopy(opts)

    -- Validate cwd option
    if type(opts.cwd) == 'boolean' then
        PickleVim.warn('PickleVim.pick: opts.cwd should be a string or nil')
        opts.cwd = nil
    end

    -- Auto-resolve project root if cwd not specified and root not disabled
    if not opts.cwd and opts.root ~= false then
        opts.cwd = PickleVim.root({ buf = opts.buf })
    end

    -- Resolve command aliases (e.g., "files" -> picker-specific command)
    command = M.picker.commands[command] or command
    M.picker.open(command, opts)
end

--- Wrap a picker command in a function for use in keymaps
--- Creates a closure that calls pick.open with the given command and options
---@param command? string Picker command
---@param opts? picklevim.utils.pick.Opts Picker options
---@return fun() Function that opens the picker
M.wrap = function(command, opts)
    opts = opts or {}
    return function()
        PickleVim.pick.open(command, opts)
    end
end

--- Create a picker for Neovim config files
---@return fun() Function that opens file picker in config directory
M.config_files = function()
    return M.wrap('files', { cwd = vim.fn.stdpath('config') })
end

return M
