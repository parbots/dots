---@class picklevim.utils.lsp
local M = {}

M.servers = require('utils.lsp.servers')
M.keymaps = require('utils.lsp.keymaps')

---@return string
M.get_status = function()
    local client_info = ''

    for client_idx, client in ipairs(vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })) do
        if client_idx == 1 then
            client_info = client.name
        else
            client_info = client_info .. ', ' .. client.name
        end
    end

    return client_info
end

---@return boolean
M.has_clients = function()
    local clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
    return clients and #clients > 0
end

---@param on_attach fun(client: vim.lsp.Client, buffer: number)
---@param name? string
---@return number
M.on_attach = function(on_attach, name)
    return vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
            ---@type number
            local buffer = args.buf
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client and (not name or client.name == name) then
                return on_attach(client, buffer)
            end
        end,
    })
end

---@type table<string, table<vim.lsp.Client, table<number, boolean>>>
M._supports_method = {}

M.setup = function()
    local register_capability = vim.lsp.handlers['client/registerCapability']
    vim.lsp.handlers['client/registerCapability'] = function(err, res, ctx)
        local ret = register_capability(err, res, ctx)
        local client = vim.lsp.get_client_by_id(ctx.client_id)

        if client then
            for buffer in pairs(client.attached_buffers) do
                vim.api.nvim_exec_autocmds('User', {
                    pattern = 'LspDynamicCapability',
                    data = { client_id = client.id, buffer = buffer },
                })
            end
        end

        return ret
    end

    M.on_attach(M._check_methods)
    M.on_dynamic_capability(M._check_methods)
end

---@param client vim.lsp.Client
---@param buffer number
M._check_methods = function(client, buffer)
    if not vim.api.nvim_buf_is_valid(buffer) then
        return
    end

    if not vim.bo[buffer].buflisted then
        return
    end

    if vim.bo[buffer].buftype == 'nofile' then
        return
    end

    for method, clients in pairs(M._supports_method) do
        clients[client] = clients[client] or {}

        if not clients[client][buffer] then
            if client:supports_method(method, buffer) then
                clients[client][buffer] = true
                vim.api.nvim_exec_autocmds('User', {
                    pattern = 'LspSupportsMethod',
                    data = { client_id = client.id, buffer = buffer, method = method },
                })
            end
        end
    end
end

---@param fn fun(client: vim.lsp.Client, buffer: number): boolean?
---@param opts? { group?: integer }
---@return number
M.on_dynamic_capability = function(fn, opts)
    return vim.api.nvim_create_autocmd('User', {
        pattern = 'LspDynamicCapability',
        group = opts and opts.group or nil,
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            local buffer = args.data.buffer

            if client then
                return fn(client, buffer)
            end
        end,
    })
end

-- _supports_method uses weak-keyed tables (keyed by client object) so that
-- when an LSP client is garbage-collected, its tracking entries are automatically
-- cleaned up. _check_methods populates these tables on attach and dynamic
-- capability changes, firing LspSupportsMethod only once per client/buffer/method.
---@param method string
---@param fn fun(client: vim.lsp.Client, buffer: number)
---@return number
M.on_supports_method = function(method, fn)
    M._supports_method[method] = M._supports_method[method] or setmetatable({}, { __mode = 'k' })

    return vim.api.nvim_create_autocmd('User', {
        pattern = 'LspSupportsMethod',
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            local buffer = args.data.buffer

            if client and method == args.data.method then
                return fn(client, buffer)
            end
        end,
    })
end

---@param server string
---@return table?
M.get_config = function(server)
    return vim.lsp.config(server)
end

---@param server string
---@return boolean
M.is_enabled = function(server)
    local server_config = M.get_config(server)
    return server_config and server_config.enabled ~= false
end

---@param opts? PickleFormatter | { filter?: (string | vim.lsp.get_clients.Filter) }
---@return PickleFormatter
M.formatter = function(opts)
    opts = opts or {}

    local filter = opts.filter or {}
    filter = type(filter) == 'string' and { name = filter } or filter

    ---@type PickleFormatter
    local ret = {
        name = 'LSP',
        primary = true,
        priority = 1,
        format = function(buf)
            return M.format(PickleVim.merge({}, filter, { bufnr = buf }))
        end,
        sources = function(buf)
            local clients = vim.lsp.get_clients(PickleVim.merge({}, filter, { bufnr = buf }))

            ---@param client vim.lsp.Client
            local ret = vim.tbl_filter(function(client)
                return client:supports_method('textDocument/formatting')
                    or client:supports_method('textDocument/rangeFormatting')
            end, clients)

            ---@param client vim.lsp.Client
            return vim.tbl_map(function(client)
                return client.name
            end, ret)
        end,
    }

    return PickleVim.merge(ret, opts)
end

---@alias lsp.Client.format { timeout_ms?: number, format_options?: table } | vim.lsp.get_clients.Filter

---@param opts? lsp.Client.format
M.format = function(opts)
    vim.lsp.buf.format(opts)
end

-- Dot notation access to code actions: PickleVim.lsp.action["source.organizeImports"]()
M.action = setmetatable({}, {
    __index = function(_, action)
        return function()
            vim.lsp.buf.code_action({
                apply = true,
                context = {
                    only = { action },
                    diagnostics = {},
                },
            })
        end
    end,
})

---@class LspCommand: lsp.ExecuteCommandParams
---@field open? boolean Open results in Trouble
---@field handler? lsp.Handler Custom result handler

---@param opts LspCommand
M.execute = function(opts)
    local params = {
        command = opts.command,
        arguments = opts.arguments,
    }

    if opts.open then
        require('trouble').open({
            mode = 'lsp_command',
            params = params,
        })
    else
        return vim.lsp.buf_request(0, 'workspace/executeCommand', params, opts.handler)
    end
end

M.diagnostic_icon = {
    [vim.diagnostic.severity.ERROR] = PickleVim.icons.diagnostics.error,
    [vim.diagnostic.severity.WARN] = PickleVim.icons.diagnostics.warn,
    [vim.diagnostic.severity.HINT] = PickleVim.icons.diagnostics.hint,
    [vim.diagnostic.severity.INFO] = PickleVim.icons.diagnostics.info,
}

---@param opts? { force?: boolean }
M.restart = function(opts)
    opts = opts or {}
    local clients = vim.lsp.get_clients()

    if #clients == 0 then
        vim.notify('No LSP clients running', vim.log.levels.INFO)
        return
    end

    M._supports_method = {}

    local restarted = {}
    local servers_to_restart = {}

    for _, client in ipairs(clients) do
        if not vim.tbl_contains(restarted, client.name) then
            table.insert(restarted, client.name)

            servers_to_restart[client.name] = {}
            for buf, _ in pairs(client.attached_buffers) do
                if vim.api.nvim_buf_is_valid(buf) then
                    table.insert(servers_to_restart[client.name], buf)
                end
            end

            client.stop()
        end
    end

    vim.defer_fn(function()
        for server_name, buffers in pairs(servers_to_restart) do
            for _, buf in ipairs(buffers) do
                if vim.api.nvim_buf_is_valid(buf) then
                    vim.lsp.enable(server_name)
                    break
                end
            end
        end

        vim.notify(
            string.format('Restarted LSP clients: %s', table.concat(restarted, ', ')),
            vim.log.levels.INFO
        )
    end, 500) -- 500ms delay to allow clean shutdown
end

return M
