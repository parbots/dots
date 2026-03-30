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

---@param picker PicklePicker
---@return boolean
M.register = function(picker)
    if M.picker and M.picker.name ~= picker.name then
        return false
    end

    M.picker = picker

    return true
end

---@param command? string
---@param opts? picklevim.utils.pick.Opts
M.open = function(command, opts)
    if not M.picker then
        return PickleVim.error('PickleVim.pick: picker not set')
    end

    command = command ~= 'auto' and command or 'files'
    opts = opts or {}

    opts = vim.deepcopy(opts)

    if type(opts.cwd) == 'boolean' then
        PickleVim.warn('PickleVim.pick: opts.cwd should be a string or nil')
        opts.cwd = nil
    end

    if not opts.cwd and opts.root ~= false then
        opts.cwd = PickleVim.root({ buf = opts.buf })
    end

    command = M.picker.commands[command] or command
    M.picker.open(command, opts)
end

---@param command? string
---@param opts? picklevim.utils.pick.Opts
---@return fun()
M.wrap = function(command, opts)
    opts = opts or {}
    return function()
        PickleVim.pick.open(command, opts)
    end
end

---@return fun()
M.config_files = function()
    return M.wrap('files', { cwd = vim.fn.stdpath('config') })
end

return M
