--- LSP keymaps configuration
--- Defines all LSP-related key mappings with dynamic capability checking
--- Keymaps are only registered when the attached LSP server supports the feature
---
--- Architecture:
---   - Keymaps are defined as specs with optional 'has' field for capability checking
---   - Default keymaps are merged with server-specific overrides from lspconfig setup
---   - Keymaps are registered per-buffer in on_attach callback
---   - Uses Lazy.nvim's key handler for consistent keymap management

---@class picklevim.utils.lsp.keymaps
local M = {}

----------------------------------------
-- Type Definitions
----------------------------------------

--- Extended keymap spec with LSP capability checking
--- Inherits from LazyKeysSpec and adds capability/condition fields
---@alias picklevim.lsp.keys.spec LazyKeysSpec | { has?: string | string[], cond?: fun(): boolean }

--- Resolved keymap with capability checking
---@alias picklevim.lsp.keys LazyKeys | { has?: string | string[], cond?: fun(): boolean }

--- Cached keymap specifications
---@type picklevim.lsp.keys.spec[] | nil
M._keys = nil

----------------------------------------
-- Keymap Specifications
----------------------------------------

--- Get default LSP keymap specifications
--- Keymaps are only registered if:
---   1. LSP server supports the capability (via 'has' field)
---   2. Optional condition function returns true (via 'cond' field)
---@return picklevim.lsp.keys.spec[]
M.get = function()
    -- Return cached specs if available
    if M._keys then
        return M._keys
    end

    M._keys = {
        ----------------------------------------
        -- LSP Info and Configuration
        ----------------------------------------
        {
            '<leader>cl',
            function()
                Snacks.picker.lsp_config()
            end,
            desc = 'Lsp Info',
        },

        ----------------------------------------
        -- Navigation (goto commands)
        ----------------------------------------
        { 'gd', vim.lsp.buf.definition, desc = 'Goto Definition', has = 'definition' },
        { 'gr', vim.lsp.buf.references, desc = 'References' },
        { 'gI', vim.lsp.buf.implementation, desc = 'Goto Implementation' },
        { 'gy', vim.lsp.buf.type_definition, desc = 'Goto T[y]pe Definition' },
        { 'gD', vim.lsp.buf.declaration, desc = 'Goto Declaration' },

        ----------------------------------------
        -- Documentation
        ----------------------------------------
        {
            'K',
            function()
                return vim.lsp.buf.hover()
            end,
            desc = 'Hover',
        },
        {
            'gK',
            function()
                return vim.lsp.buf.signature_help()
            end,
            desc = 'Signature Help',
            has = 'signatureHelp',
        },
        {
            '<c-k>',
            function()
                return vim.lsp.buf.signature_help()
            end,
            mode = 'i',
            desc = 'Signature Help',
            has = 'signatureHelp',
        },

        ----------------------------------------
        -- Code Actions and Refactoring
        ----------------------------------------
        { '<leader>ca', vim.lsp.buf.code_action, desc = 'Code Action', mode = { 'n', 'v' }, has = 'codeAction' },
        { '<leader>cc', vim.lsp.codelens.run, desc = 'Run Codelens', mode = { 'n', 'v' }, has = 'codeLens' },
        {
            '<leader>cC',
            vim.lsp.codelens.refresh,
            desc = 'Refresh & Display Codelens',
            mode = { 'n' },
            has = 'codeLens',
        },
        {
            '<leader>cR',
            function()
                Snacks.rename.rename_file()
            end,
            desc = 'Rename File',
            mode = { 'n' },
            has = { 'workspace/didRenameFiles', 'workspace/willRenameFiles' },
        },
        { '<leader>cr', vim.lsp.buf.rename, desc = 'Rename', has = 'rename' },
        { '<leader>cA', PickleVim.lsp.action.source, desc = 'Source Action', has = 'codeAction' },

        ----------------------------------------
        -- Reference Navigation (via Snacks.words)
        ----------------------------------------
        -- Jump to next/prev word reference under cursor
        -- Requires documentHighlight capability and Snacks.words enabled
        {
            ']]',
            function()
                Snacks.words.jump(vim.v.count1)
            end,
            has = 'documentHighlight',
            desc = 'Next Reference',
            cond = function()
                return Snacks.words.is_enabled()
            end,
        },
        {
            '[[',
            function()
                Snacks.words.jump(-vim.v.count1)
            end,
            has = 'documentHighlight',
            desc = 'Prev Reference',
            cond = function()
                return Snacks.words.is_enabled()
            end,
        },
        {
            '<a-n>',
            function()
                Snacks.words.jump(vim.v.count1, true)
            end,
            has = 'documentHighlight',
            desc = 'Next Reference',
            cond = function()
                return Snacks.words.is_enabled()
            end,
        },
        {
            '<a-p>',
            function()
                Snacks.words.jump(-vim.v.count1, true)
            end,
            has = 'documentHighlight',
            desc = 'Prev Reference',
            cond = function()
                return Snacks.words.is_enabled()
            end,
        },

        ----------------------------------------
        -- Workspace Management
        ----------------------------------------
        {
            '<leader>cF',
            function()
                vim.notify(vim.inspect(vim.lsp.buf.list_workspace_folders()))
            end,
            desc = 'List workspace folders',
            mode = { 'n' },
        },

        ----------------------------------------
        -- Display Toggles
        ----------------------------------------
        {
            '<leader>uh',
            function()
                local buf = vim.api.nvim_get_current_buf()
                local current = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
                vim.lsp.inlay_hint.enable(not current, { bufnr = buf })
                vim.notify(
                    string.format('Inlay hints %s', not current and 'enabled' or 'disabled'),
                    vim.log.levels.INFO
                )
            end,
            desc = 'Toggle Inlay Hints',
            mode = { 'n' },
            has = 'textDocument/inlayHint',
        },

        ----------------------------------------
        -- Diagnostic Navigation
        ----------------------------------------
        -- Navigate all diagnostics (errors, warnings, hints, info)
        {
            ']d',
            function()
                vim.diagnostic.goto_next()
            end,
            desc = 'Next Diagnostic',
            mode = { 'n' },
        },
        {
            '[d',
            function()
                vim.diagnostic.goto_prev()
            end,
            desc = 'Prev Diagnostic',
            mode = { 'n' },
        },

        -- Navigate errors only
        {
            ']e',
            function()
                vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })
            end,
            desc = 'Next Error',
            mode = { 'n' },
        },
        {
            '[e',
            function()
                vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })
            end,
            desc = 'Prev Error',
            mode = { 'n' },
        },

        -- Navigate warnings only
        {
            ']w',
            function()
                vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.WARN })
            end,
            desc = 'Next Warning',
            mode = { 'n' },
        },
        {
            '[w',
            function()
                vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.WARN })
            end,
            desc = 'Prev Warning',
            mode = { 'n' },
        },

        -- Send diagnostics to location list
        {
            '<leader>q',
            function()
                vim.diagnostic.setloclist()
            end,
            desc = 'Diagnostics to Location List',
            mode = { 'n' },
        },
    }

    return M._keys
end

----------------------------------------
-- Capability Checking
----------------------------------------

--- Check if any attached LSP client supports a method
--- Used to determine if a keymap should be registered
---@param buffer number Buffer number
---@param method string | string[] LSP method name(s) (e.g., 'definition', 'codeAction')
---@return boolean supported True if any client supports the method
M.has = function(buffer, method)
    -- For array of methods, return true if any method is supported
    if type(method) == 'table' then
        for _, m in ipairs(method) do
            if M.has(buffer, m) then
                return true
            end
        end

        return false
    end

    -- Auto-prepend 'textDocument/' if not a full method path
    method = method:find('/') and method or 'textDocument/' .. method

    -- Check if any attached client supports the method
    local clients = vim.lsp.get_clients({ bufnr = buffer })
    for _, client in ipairs(clients) do
        if client:supports_method(method, buffer) then
            return true
        end
    end

    return false
end

----------------------------------------
-- Keymap Resolution
----------------------------------------

--- Resolve keymaps by merging defaults with server-specific overrides
--- Server-specific keymaps are defined in lspconfig server configs
---@param buffer number Buffer number
---@return picklevim.lsp.keys[] keymaps Resolved keymaps ready for registration
M.resolve = function(buffer)
    local Keys = require('lazy.core.handler.keys')

    if not Keys.resolve then
        return {}
    end

    -- Start with default keymaps
    ---@type picklevim.lsp.keys.spec
    local spec = vim.tbl_extend('force', {}, M.get())

    -- Merge in server-specific keymaps from lspconfig
    ---@type picklevim.lsp.server[]
    local servers = PickleVim.plugin.opts('nvim-lspconfig').servers
    local clients = vim.lsp.get_clients({ bufnr = buffer })
    for _, client in ipairs(clients) do
        local maps = servers[client.name] and servers[client.name].keys or {}
        vim.list_extend(spec, maps)
    end

    return Keys.resolve(spec)
end

----------------------------------------
-- Keymap Registration
----------------------------------------

--- Register LSP keymaps on buffer attach
--- Called from PickleVim.lsp.on_attach() callback
--- Filters keymaps based on:
---   1. LSP capability support (via 'has' field)
---   2. Optional condition function (via 'cond' field)
---@param _ table LSP client (unused)
---@param buffer number Buffer number to register keymaps for
M.on_attach = function(_, buffer)
    local Keys = require('lazy.core.handler.keys')
    local keymaps = M.resolve(buffer)

    for _, keys in pairs(keymaps) do
        -- Check if LSP server supports required capability
        local has = not keys.has or M.has(buffer, keys.has)

        -- Check optional condition function
        local cond = true
        if keys.cond == false then
            cond = false
        elseif type(keys.cond) == 'function' then
            cond = keys.cond()
        end

        -- Register keymap only if both checks pass
        if has and cond then
            local key_opts = Keys.opts(keys)
            local opts = vim.tbl_extend('force', key_opts, {
                buffer = buffer,
            })
            -- Clean up LSP-specific fields before registering
            opts.has = nil
            opts.cond = nil
            opts.silent = opts.silent ~= false

            vim.keymap.set(keys.mode or 'n', keys.lhs, keys.rhs, opts)
        end
    end
end

return M
