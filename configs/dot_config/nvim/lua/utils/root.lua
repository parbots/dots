---@class picklevim.utils.root
---@overload fun(): string
local M = setmetatable({}, {
    __call = function(m, ...)
        return m.get(...)
    end,
})

---@class PickleRoot
---@field paths string[] Detected root paths
---@field spec PickleRootSpec Spec that detected these roots

---@alias PickleRootFn fun(buf: number): (string | string[])
---@alias PickleRootSpec string | string[] | PickleRootFn

-- Detector priority cascade: LSP workspace folders first (most project-aware),
-- then pattern matching (.git, lua) for non-LSP contexts, then cwd as fallback.
-- First spec to return a result wins; later specs are not tried.
---@type PickleRootSpec[]
M.spec = { 'lsp', { '.git', 'lua' }, 'cwd' }

M.detectors = {}

---@return string[]
M.detectors.cwd = function()
    return { vim.uv.cwd() }
end

---@param buf number
---@return string[]
M.detectors.lsp = function(buf)
    local bufpath = M.bufpath(buf)

    if not bufpath then
        return {}
    end

    ---@type string[]
    local roots = {}

    local clients = vim.lsp.get_clients({ bufnr = buf })

    clients = vim.tbl_filter(function(client)
        return not vim.tbl_contains(vim.g.root_lsp_ignore or {}, client.name)
    end, clients)

    for _, client in pairs(clients) do
        local workspace = client.config.workspace_folders
        for _, ws in pairs(workspace or {}) do
            roots[#roots + 1] = vim.uri_to_fname(ws.uri)
        end

        if client.root_dir then
            roots[#roots + 1] = client.root_dir
        end
    end

    return vim.tbl_filter(function(path)
        path = PickleVim.norm(path)
        return path and bufpath:find(path, 1, true) == 1
    end, roots)
end

---@param buf number
---@param patterns string[] | string
---@return string[]
M.detectors.pattern = function(buf, patterns)
    ---@cast patterns string[]
    patterns = type(patterns) == 'string' and { patterns } or patterns
    local path = M.bufpath(buf) or vim.uv.cwd()

    local pattern = vim.fs.find(function(name)
        for _, p in ipairs(patterns) do
            if name == p then
                return true
            end

            if p:sub(1, 1) == '*' and name:find(vim.pesc(p:sub(2)) .. '$') then
                return true
            end
        end

        return false
    end, { path = path, upward = true })[1]

    return pattern and { vim.fs.dirname(pattern) } or {}
end

---@param buf number
---@return string?
M.bufpath = function(buf)
    if not buf then
        return nil
    end
    return M.realpath(vim.api.nvim_buf_get_name(buf))
end

---@return string
M.cwd = function()
    return M.realpath(vim.uv.cwd()) or ''
end

---@param path? string
---@return string?
M.realpath = function(path)
    if path == '' or path == nil then
        return nil
    end

    path = vim.uv.fs_realpath(path) or path

    return PickleVim.norm(path)
end

---@param spec PickleRootSpec
---@return PickleRootFn
M.resolve = function(spec)
    if M.detectors[spec] then
        return M.detectors[spec]
    elseif type(spec) == 'function' then
        return spec
    end

    return function(buf)
        return M.detectors.pattern(buf, spec)
    end
end

---@param opts? { buf?: number, spec?: PickleRootSpec[], all?: boolean }
---@return PickleRoot[]
M.detect = function(opts)
    opts = opts or {}

    opts.spec = opts.spec or type(vim.g.root_spec) == 'table' and vim.g.root_spec or M.spec
    opts.buf = (opts.buf == nil or opts.buf == 0) and vim.api.nvim_get_current_buf() or opts.buf

    ---@type PickleRoot[]
    local ret = {}

    for _, spec in ipairs(opts.spec) do
        local paths = M.resolve(spec)(opts.buf)
        paths = type(paths) == 'table' and paths or (paths and { paths } or {})

        ---@type string[]
        local roots = {}

        for _, p in ipairs(paths) do
            local pp = M.realpath(p)
            if pp and not vim.tbl_contains(roots, pp) then
                roots[#roots + 1] = pp
            end
        end

        table.sort(roots, function(a, b)
            return #a > #b
        end)

        if #roots > 0 then
            ret[#ret + 1] = { spec = spec, paths = roots }

            if opts.all == false then
                break
            end
        end
    end

    return ret
end

M.info = function()
    local spec = type(vim.g.root_spec) == 'table' and vim.g.root_spec or M.spec
    local roots = M.detect({ all = true })
    local lines = {} ---@type string[]
    local first = true

    for _, root in ipairs(roots) do
        for _, path in ipairs(root.paths) do
            lines[#lines + 1] = ('- [%s] `%s` **(%s)**'):format(
                first and 'x' or ' ',
                path,
                ---@cast root { spec: string[] }
                type(root.spec) == 'table' and table.concat(root.spec, ', ') or root.spec
            )

            first = false
        end
    end

    lines[#lines + 1] = ''
    lines[#lines + 1] = '```lua'
    lines[#lines + 1] = 'vim.g.root_spec = ' .. vim.inspect(spec)
    lines[#lines + 1] = '```'

    PickleVim.info(lines, { title = 'PickleVim Roots' })
end

---@return string
M.get_default = function()
    local roots = M.detect({ all = false })
    return roots[1] and roots[1].paths[1] or vim.uv.cwd()
end

-- Per-buffer cache: stores the resolved root path for each buffer number.
-- Invalidated on LspAttach (new LSP info may change the root) and
-- DirChanged (user switched project). Avoids re-running detectors on
-- every root.get() call.
---@type table<number, string>
M.cache = {}

M.setup = function()
    vim.api.nvim_create_user_command('PickleRoot', function()
        PickleVim.root.info()
    end, { desc = 'PickleVim roots for the current buffer' })

    vim.api.nvim_create_autocmd({ 'LspAttach', 'DirChanged' }, {
        group = vim.api.nvim_create_augroup('picklevim_root_cache', { clear = true }),
        callback = function(event)
            M.cache[event.buf] = nil

            if event.event == 'DirChanged' then
                PickleVim.clear_memoize_cache()
            end
        end,
    })
end

---@param opts? {normalize?: boolean, buf?: number}
---@return string
M.get = function(opts)
    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local ret = M.cache[buf]

    if not ret then
        local roots = M.detect({ all = false, buf = buf })
        ret = roots[1] and roots[1].paths[1] or vim.uv.cwd()
        M.cache[buf] = ret
    end

    if opts and opts.normalize then
        return ret
    end

    return PickleVim.is_win() and ret:gsub('/', '\\') or ret
end

---@return string
M.git = function()
    local root = M.get()
    local git_root = vim.fs.find('.git', { path = root, upward = true })[1]
    local ret = git_root and vim.fn.fnamemodify(git_root, ':h') or root

    return ret
end

return M
