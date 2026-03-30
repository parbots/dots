---@class picklevim.utils.lsp.keymaps
local M = {}

---@alias picklevim.lsp.keys.spec LazyKeysSpec | { has?: string | string[], cond?: fun(): boolean }
---@alias picklevim.lsp.keys LazyKeys | { has?: string | string[], cond?: fun(): boolean }

---@type picklevim.lsp.keys.spec[] | nil
M._keys = nil

---@return picklevim.lsp.keys.spec[]
M.get = function()
    if M._keys then
        return M._keys
    end

    M._keys = {
        {
            '<leader>cl',
            function()
                Snacks.picker.lsp_config()
            end,
            desc = 'Lsp Info',
        },

        { 'gd', vim.lsp.buf.definition, desc = 'Goto Definition', has = 'definition' },
        { 'gr', vim.lsp.buf.references, desc = 'References' },
        { 'gI', vim.lsp.buf.implementation, desc = 'Goto Implementation' },
        { 'gy', vim.lsp.buf.type_definition, desc = 'Goto T[y]pe Definition' },
        { 'gD', vim.lsp.buf.declaration, desc = 'Goto Declaration' },

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

        { '<leader>ca', vim.lsp.buf.code_action, desc = 'Code Action', mode = { 'n', 'v' }, has = 'codeAction' },
        { '<leader>cc', vim.lsp.codelens.run, desc = 'Run Codelens', mode = { 'n', 'v' }, has = 'codeLens' },
        {
            '<leader>cC',
            function()
                vim.lsp.codelens.enable(not vim.lsp.codelens.is_enabled(), { bufnr = 0 })
            end,
            desc = 'Toggle Codelens',
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

        {
            '<leader>cF',
            function()
                vim.notify(vim.inspect(vim.lsp.buf.list_workspace_folders()))
            end,
            desc = 'List workspace folders',
            mode = { 'n' },
        },

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

        {
            ']d',
            function()
                vim.diagnostic.jump({ count = 1 })
            end,
            desc = 'Next Diagnostic',
            mode = { 'n' },
        },
        {
            '[d',
            function()
                vim.diagnostic.jump({ count = -1 })
            end,
            desc = 'Prev Diagnostic',
            mode = { 'n' },
        },

        {
            ']e',
            function()
                vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR })
            end,
            desc = 'Next Error',
            mode = { 'n' },
        },
        {
            '[e',
            function()
                vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR })
            end,
            desc = 'Prev Error',
            mode = { 'n' },
        },

        {
            ']w',
            function()
                vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.WARN })
            end,
            desc = 'Next Warning',
            mode = { 'n' },
        },
        {
            '[w',
            function()
                vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.WARN })
            end,
            desc = 'Prev Warning',
            mode = { 'n' },
        },

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

---@param buffer number
---@param method string | string[]
---@return boolean
M.has = function(buffer, method)
    if type(method) == 'table' then
        for _, m in ipairs(method) do
            if M.has(buffer, m) then
                return true
            end
        end

        return false
    end

    method = method:find('/') and method or 'textDocument/' .. method

    local clients = vim.lsp.get_clients({ bufnr = buffer })
    for _, client in ipairs(clients) do
        if client:supports_method(method, buffer) then
            return true
        end
    end

    return false
end

---@param buffer number
---@return picklevim.lsp.keys[]
M.resolve = function(buffer)
    local Keys = require('lazy.core.handler.keys')

    if not Keys.resolve then
        return {}
    end

    ---@type picklevim.lsp.keys.spec
    local spec = vim.tbl_extend('force', {}, M.get())

    ---@type picklevim.lsp.server[]
    local servers = PickleVim.plugin.opts('nvim-lspconfig').servers
    local clients = vim.lsp.get_clients({ bufnr = buffer })
    for _, client in ipairs(clients) do
        local maps = servers[client.name] and servers[client.name].keys or {}
        vim.list_extend(spec, maps)
    end

    return Keys.resolve(spec)
end

---@param _ table
---@param buffer number
M.on_attach = function(_, buffer)
    local Keys = require('lazy.core.handler.keys')
    local keymaps = M.resolve(buffer)

    for _, keys in pairs(keymaps) do
        local has = not keys.has or M.has(buffer, keys.has)

        local cond = true
        if keys.cond == false then
            cond = false
        elseif type(keys.cond) == 'function' then
            cond = keys.cond()
        end

        if has and cond then
            local key_opts = Keys.opts(keys)
            local opts = vim.tbl_extend('force', key_opts, {
                buffer = buffer,
            })
            opts.has = nil
            opts.cond = nil
            opts.silent = opts.silent ~= false

            vim.keymap.set(keys.mode or 'n', keys.lhs, keys.rhs, opts)
        end
    end
end

return M
