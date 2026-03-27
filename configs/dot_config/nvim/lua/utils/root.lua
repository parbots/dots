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

--- Default root detection specification
--- Order matters: tries LSP, then patterns, then cwd
---@type PickleRootSpec[]
M.spec = { 'lsp', { '.git', 'lua' }, 'cwd' }

--- Root detection strategies
M.detectors = {}

--- Detector: Use current working directory
---@return string[] paths
M.detectors.cwd = function()
    return { vim.uv.cwd() }
end

--- Detector: Use LSP workspace folders and root directories
--- Filters out LSP servers listed in vim.g.root_lsp_ignore
---@param buf number Buffer number
---@return string[] paths LSP root paths
M.detectors.lsp = function(buf)
    local bufpath = M.bufpath(buf)

    if not bufpath then
        return {}
    end

    ---@type string[]
    local roots = {}

    -- Get LSP clients attached to buffer
    local clients = vim.lsp.get_clients({ bufnr = buf })

    -- Filter out ignored LSP servers
    clients = vim.tbl_filter(function(client)
        return not vim.tbl_contains(vim.g.root_lsp_ignore or {}, client.name)
    end, clients)

    -- Collect workspace folders and root directories from each client
    for _, client in pairs(clients) do
        local workspace = client.config.workspace_folders
        for _, ws in pairs(workspace or {}) do
            roots[#roots + 1] = vim.uri_to_fname(ws.uri)
        end

        if client.root_dir then
            roots[#roots + 1] = client.root_dir
        end
    end

    -- Only return roots that are ancestors of the buffer path
    return vim.tbl_filter(function(path)
        path = PickleVim.norm(path)
        return path and bufpath:find(path, 1, true) == 1
    end, roots)
end

--- Detector: Use file pattern matching (e.g., .git, package.json)
--- Searches upward from buffer path for matching files/directories
--- Supports wildcards with * prefix (e.g., "*.git" matches ".git")
---@param buf number Buffer number
---@param patterns string[] | string Patterns to search for
---@return string[] paths Matched root paths
M.detectors.pattern = function(buf, patterns)
    ---@cast patterns string[]
    patterns = type(patterns) == 'string' and { patterns } or patterns
    local path = M.bufpath(buf) or vim.uv.cwd()

    -- Find first matching pattern searching upward
    local pattern = vim.fs.find(function(name)
        for _, p in ipairs(patterns) do
            -- Exact match
            if name == p then
                return true
            end

            -- Wildcard match (e.g., "*.git" matches ".git")
            if p:sub(1, 1) == '*' and name:find(vim.pesc(p:sub(2)) .. '$') then
                return true
            end
        end

        return false
    end, { path = path, upward = true })[1]

    return pattern and { vim.fs.dirname(pattern) } or {}
end

--- Get normalized buffer path
---@param buf number Buffer number
---@return string? path Normalized buffer path or nil
M.bufpath = function(buf)
    if not buf then
        return nil
    end
    return M.realpath(vim.api.nvim_buf_get_name(buf))
end

--- Get normalized current working directory
---@return string cwd Normalized cwd
M.cwd = function()
    return M.realpath(vim.uv.cwd()) or ''
end

--- Resolve and normalize a path (follow symlinks)
---@param path? string Path to resolve
---@return string? normalized Normalized path or nil
M.realpath = function(path)
    if path == '' or path == nil then
        return nil
    end

    -- Resolve symlinks
    path = vim.uv.fs_realpath(path) or path

    return PickleVim.norm(path)
end

--- Resolve a root spec to a detector function
---@param spec PickleRootSpec Spec to resolve (e.g., "lsp", {"git"}, function)
---@return PickleRootFn detector Detector function
M.resolve = function(spec)
    -- Built-in detector (e.g., "lsp", "cwd")
    if M.detectors[spec] then
        return M.detectors[spec]
    -- Custom function
    elseif type(spec) == 'function' then
        return spec
    end

    -- Pattern spec (e.g., {".git", "lua"})
    return function(buf)
        return M.detectors.pattern(buf, spec)
    end
end

--- Detect project roots for a buffer using configured specs
---@param opts? { buf?: number, spec?: PickleRootSpec[], all?: boolean }
---@return PickleRoot[] roots Detected roots with their specs
M.detect = function(opts)
    opts = opts or {}

    -- Use custom spec or global spec or default spec
    opts.spec = opts.spec or type(vim.g.root_spec) == 'table' and vim.g.root_spec or M.spec
    opts.buf = (opts.buf == nil or opts.buf == 0) and vim.api.nvim_get_current_buf() or opts.buf

    ---@type PickleRoot[]
    local ret = {}

    -- Try each spec in order
    for _, spec in ipairs(opts.spec) do
        local paths = M.resolve(spec)(opts.buf)
        paths = type(paths) == 'table' and paths or (paths and { paths } or {})

        ---@type string[]
        local roots = {}

        -- Normalize and deduplicate paths
        for _, p in ipairs(paths) do
            local pp = M.realpath(p)
            if pp and not vim.tbl_contains(roots, pp) then
                roots[#roots + 1] = pp
            end
        end

        -- Sort by length (longest/most specific first)
        table.sort(roots, function(a, b)
            return #a > #b
        end)

        -- Add to results if found
        if #roots > 0 then
            ret[#ret + 1] = { spec = spec, paths = roots }

            -- Stop after first match if not detecting all
            if opts.all == false then
                break
            end
        end
    end

    return ret
end

--- Display information about detected roots in a notification
--- Shows all detected roots with their detection method
M.info = function()
    local spec = type(vim.g.root_spec) == 'table' and vim.g.root_spec or M.spec
    local roots = M.detect({ all = true })
    local lines = {} ---@type string[]
    local first = true

    -- Build list of detected roots
    for _, root in ipairs(roots) do
        for _, path in ipairs(root.paths) do
            lines[#lines + 1] = ('- [%s] `%s` **(%s)**'):format(
                first and 'x' or ' ', -- Mark first root as active
                path,
                ---@cast root { spec: string[] }
                type(root.spec) == 'table' and table.concat(root.spec, ', ') or root.spec
            )

            first = false
        end
    end

    -- Show current root spec configuration
    lines[#lines + 1] = ''
    lines[#lines + 1] = '```lua'
    lines[#lines + 1] = 'vim.g.root_spec = ' .. vim.inspect(spec)
    lines[#lines + 1] = '```'

    PickleVim.info(lines, { title = 'PickleVim Roots' })
end

--- Get the default root directory (first detected root or cwd)
--- This is uncached and always performs fresh detection
---@return string root Default root directory
M.get_default = function()
    local roots = M.detect({ all = false })
    return roots[1] and roots[1].paths[1] or vim.uv.cwd()
end

--- Cache for root detection results (per buffer)
---@type table<number, string>
M.cache = {}

--- Setup root detection system
--- Creates user command and cache invalidation autocmds
M.setup = function()
    -- Command to display root info
    vim.api.nvim_create_user_command('PickleRoot', function()
        PickleVim.root.info()
    end, { desc = 'PickleVim roots for the current buffer' })

    -- Invalidate cache when conditions change
    vim.api.nvim_create_autocmd({ 'LspAttach', 'DirChanged' }, {
        group = vim.api.nvim_create_augroup('picklevim_root_cache', { clear = true }),
        callback = function(event)
            M.cache[event.buf] = nil

            -- Clear memoize caches on directory change (project switch)
            if event.event == 'DirChanged' then
                PickleVim.clear_memoize_cache()
            end
        end,
    })
end

--- Get the root directory for a buffer (cached)
--- This is the primary root detection function used throughout the config
---@param opts? {normalize?: boolean, buf?: number}
---@return string root Root directory path
M.get = function(opts)
    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local ret = M.cache[buf]

    -- Detect and cache if not already cached
    if not ret then
        local roots = M.detect({ all = false, buf = buf })
        ret = roots[1] and roots[1].paths[1] or vim.uv.cwd()
        M.cache[buf] = ret
    end

    -- Return normalized path if requested, otherwise platform-specific
    if opts and opts.normalize then
        return ret
    end

    -- Convert to Windows path separators on Windows
    return PickleVim.is_win() and ret:gsub('/', '\\') or ret
end

--- Get the git root directory for the current buffer
--- Searches upward from the current root for .git directory
---@return string git_root Git root directory
M.git = function()
    local root = M.get()
    local git_root = vim.fs.find('.git', { path = root, upward = true })[1]
    local ret = git_root and vim.fn.fnamemodify(git_root, ':h') or root

    return ret
end

return M
