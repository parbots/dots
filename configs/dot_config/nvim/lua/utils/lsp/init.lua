---@class picklevim.utils.lsp
---LSP utilities for setup, callbacks, and formatting
local M = {}

-- Import server configurations and keymaps
M.servers = require('utils.lsp.servers')
M.keymaps = require('utils.lsp.keymaps')

--- Get comma-separated list of LSP client names for current buffer
--- Used in statusline components
---@return string client_names Comma-separated client names (e.g., "lua_ls, null-ls")
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

--- Check if any LSP clients are attached to current buffer
---@return boolean has_clients True if at least one client attached
M.has_clients = function()
    local clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
    return clients and #clients > 0
end

--- Register a callback to run when LSP attaches to a buffer
--- Optionally filter by server name
---@param on_attach fun(client: vim.lsp.Client, buffer: number) Callback function
---@param name? string Optional server name to filter (e.g., "lua_ls")
---@return number autocmd_id Autocmd ID for later removal
M.on_attach = function(on_attach, name)
    return vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
            ---@type number
            local buffer = args.buf
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            -- Only call callback if client exists and name matches (or no name filter)
            if client and (not name or client.name == name) then
                return on_attach(client, buffer)
            end
        end,
    })
end

--- Cache for tracking which methods are supported by which clients/buffers
--- Structure: { method -> { client -> { buffer -> true } } }
---@type table<string, table<vim.lsp.Client, table<number, boolean>>>
M._supports_method = {}

--- Setup LSP system
--- Hooks into capability registration to trigger LspDynamicCapability event
--- Registers method checking callbacks
M.setup = function()
    -- Wrap the built-in registerCapability handler
    local register_capability = vim.lsp.handlers['client/registerCapability']
    vim.lsp.handlers['client/registerCapability'] = function(err, res, ctx)
        local ret = register_capability(err, res, ctx)
        local client = vim.lsp.get_client_by_id(ctx.client_id)

        -- Trigger LspDynamicCapability event for all attached buffers
        -- This allows plugins to respond to capability changes
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

    -- Register method checking on attach and capability changes
    M.on_attach(M._check_methods)
    M.on_dynamic_capability(M._check_methods)
end

--- Check which LSP methods a client supports for a buffer
--- Triggers LspSupportsMethod event for each supported method
--- Internal function called on attach and capability changes
---@param client vim.lsp.Client LSP client
---@param buffer number Buffer number
M._check_methods = function(client, buffer)
    -- Skip invalid buffers
    if not vim.api.nvim_buf_is_valid(buffer) then
        return
    end

    -- Skip unlisted buffers (like terminals)
    if not vim.bo[buffer].buflisted then
        return
    end

    -- Skip special buffer types
    if vim.bo[buffer].buftype == 'nofile' then
        return
    end

    -- Check all registered methods
    for method, clients in pairs(M._supports_method) do
        clients[client] = clients[client] or {}

        -- Only trigger event if not already triggered for this client/buffer/method
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

--- Register a callback for dynamic capability registration
--- Fires when LSP server dynamically adds new capabilities
---@param fn fun(client: vim.lsp.Client, buffer: number): boolean? Callback function
---@param opts? { group?: integer } Autocmd options
---@return number autocmd_id Autocmd ID
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

--- Register a callback for when a specific LSP method is supported
--- This is more granular than on_attach - only fires when the specific method is available
--- Example: on_supports_method('textDocument/inlayHint', setup_inlay_hints)
---@param method string LSP method name (e.g., "textDocument/inlayHint")
---@param fn fun(client: vim.lsp.Client, buffer: number) Callback function
---@return number autocmd_id Autocmd ID
M.on_supports_method = function(method, fn)
    -- Register method for tracking (weak table for automatic cleanup)
    M._supports_method[method] = M._supports_method[method] or setmetatable({}, { __mode = 'k' })

    return vim.api.nvim_create_autocmd('User', {
        pattern = 'LspSupportsMethod',
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            local buffer = args.data.buffer

            -- Only call if method matches
            if client and method == args.data.method then
                return fn(client, buffer)
            end
        end,
    })
end

--- Get LSP server configuration
---@param server string Server name (e.g., "lua_ls")
---@return table? config Server configuration or nil
M.get_config = function(server)
    return vim.lsp.config(server)
end

--- Check if LSP server is enabled
---@param server string Server name
---@return boolean enabled True if server is enabled
M.is_enabled = function(server)
    local server_config = M.get_config(server)
    return server_config and server_config.enabled ~= false
end

--- Create an LSP formatter for the formatting system
--- Returns a PickleFormatter that uses LSP formatting
---@param opts? PickleFormatter | { filter?: (string | vim.lsp.get_clients.Filter) }
---@return PickleFormatter formatter LSP formatter
M.formatter = function(opts)
    opts = opts or {}

    -- Convert string filter to table filter
    local filter = opts.filter or {}
    filter = type(filter) == 'string' and { name = filter } or filter

    ---@type PickleFormatter
    local ret = {
        name = 'LSP',
        primary = true, -- LSP is a primary formatter
        priority = 1,   -- Lower priority than dedicated formatters
        format = function(buf)
            return M.format(PickleVim.merge({}, filter, { bufnr = buf }))
        end,
        sources = function(buf)
            local clients = vim.lsp.get_clients(PickleVim.merge({}, filter, { bufnr = buf }))

            -- Filter to clients that support formatting
            ---@param client vim.lsp.Client
            local ret = vim.tbl_filter(function(client)
                return client:supports_method('textDocument/formatting')
                    or client:supports_method('textDocument/rangeFormatting')
            end, clients)

            -- Return client names
            ---@param client vim.lsp.Client
            return vim.tbl_map(function(client)
                return client.name
            end, ret)
        end,
    }

    return PickleVim.merge(ret, opts)
end

---@alias lsp.Client.format { timeout_ms?: number, format_options?: table } | vim.lsp.get_clients.Filter

--- Format using LSP
--- Note: In this config, LSP formatting is handled by Conform's lsp_format = 'fallback'
---@param opts? lsp.Client.format Format options
M.format = function(opts)
    vim.lsp.buf.format(opts)
end

--- Dynamic code action helper
--- Provides dot notation access to code actions (e.g., M.action.source)
--- Usage: PickleVim.lsp.action.source() executes "source.organizeImports" action
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

--- Execute an LSP workspace command
--- Optionally opens results in Trouble for better UX
---@param opts LspCommand Command options
M.execute = function(opts)
    local params = {
        command = opts.command,
        arguments = opts.arguments,
    }

    if opts.open then
        -- Open in Trouble for better visualization
        require('trouble').open({
            mode = 'lsp_command',
            params = params,
        })
    else
        -- Execute command directly
        return vim.lsp.buf_request(0, 'workspace/executeCommand', params, opts.handler)
    end
end

--- Diagnostic severity to icon mapping
--- Used in diagnostics display and virtual text
M.diagnostic_icon = {
    [vim.diagnostic.severity.ERROR] = PickleVim.icons.diagnostics.error,
    [vim.diagnostic.severity.WARN] = PickleVim.icons.diagnostics.warn,
    [vim.diagnostic.severity.HINT] = PickleVim.icons.diagnostics.hint,
    [vim.diagnostic.severity.INFO] = PickleVim.icons.diagnostics.info,
}

--- Restart all LSP clients
--- Stops clients gracefully, clears caches, and restarts them
--- Preserves buffer attachments
---@param opts? { force?: boolean } Restart options
M.restart = function(opts)
    opts = opts or {}
    local clients = vim.lsp.get_clients()

    if #clients == 0 then
        vim.notify('No LSP clients running', vim.log.levels.INFO)
        return
    end

    -- Clear the supports_method cache to allow re-checking after restart
    M._supports_method = {}

    local restarted = {}
    local servers_to_restart = {}

    -- Stop all unique clients and track their buffers
    for _, client in ipairs(clients) do
        if not vim.tbl_contains(restarted, client.name) then
            table.insert(restarted, client.name)

            -- Store server name and attached buffers for restart
            servers_to_restart[client.name] = {}
            for buf, _ in pairs(client.attached_buffers) do
                if vim.api.nvim_buf_is_valid(buf) then
                    table.insert(servers_to_restart[client.name], buf)
                end
            end

            -- Stop the client gracefully
            client.stop()
        end
    end

    -- Wait for clients to fully stop, then restart them
    vim.defer_fn(function()
        for server_name, buffers in pairs(servers_to_restart) do
            -- Re-enable the server (only once per server)
            for _, buf in ipairs(buffers) do
                if vim.api.nvim_buf_is_valid(buf) then
                    vim.lsp.enable(server_name)
                    break -- Only need to enable once, it will attach to all buffers
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
