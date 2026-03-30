---@alias picklevim.lsp.setup table<string, fun(string, vim.lsp.Config): boolean>

return {
    {
        'mason-org/mason.nvim',
        build = ':MasonUpdate',
        cmd = { 'Mason' },
        keys = {
            { '<leader>cm', '<CMD>Mason<CR>', desc = 'Mason' },
        },

        ---@class MasonSettings
        opts = {
            max_concurrent_installers = 4,

            pip = {
                upgrade_pip = true,
            },

            ui = {
                border = 'solid',

                width = 0.8,
                height = 0.8,

                icons = {
                    package_installed = '✓',
                    package_pending = '➜',
                    package_uninstalled = '✗',
                },
            },
        },
    },

    {
        'mason-org/mason-lspconfig.nvim',
        lazy = true,
        optional = true,
        dependencies = {
            'mason.nvim',
        },
        opts = {
            automatic_enable = false,

            ensure_installed = {
                'astro',
                'basedpyright',
                'cssls',
                'gopls',
                'html',
                'jsonls',
                'lua_ls',
                'marksman',
                'mdx_analyzer',
                'sqlls',
                'taplo',
                'vtsls',
                'yamlls',
            },
        },
    },

    {
        'neovim/nvim-lspconfig',
        event = { 'LazyFile' },
        dependencies = {
            'mason-org/mason-lspconfig.nvim',
            'folke/lazydev.nvim',
        },

        ---@class PluginLspOpts
        opts = {
            diagnostics = require('utils.lsp.diagnostics').config,

            inlay_hints = {
                enabled = true,
            },

            codelens = {
                enabled = true,
            },

            capabilities = {
                textDocument = {
                    semanticTokens = {
                        multilineTokenSupport = true,
                    },
                },

                workspace = {
                    fileOperations = {
                        dynamicRegistration = true,
                        willRename = true,
                        didRename = true,
                    },
                },
            },

            -- Formatting is handled by Conform.nvim with lsp_format = 'fallback'
            format = {
                formatting_options = nil,
                timeout_ms = nil,
            },

            servers = {
                astro = PickleVim.lsp.servers.astro,
                basedpyright = PickleVim.lsp.servers.basedpyright,
                cssls = PickleVim.lsp.servers.cssls,
                gopls = PickleVim.lsp.servers.gopls,
                html = PickleVim.lsp.servers.html,
                jsonls = PickleVim.lsp.servers.jsonls,
                lua_ls = PickleVim.lsp.servers.lua_ls,
                marksman = PickleVim.lsp.servers.marksman,
                mdx_analyzer = PickleVim.lsp.servers.mdx_analyzer,
                sqlls = PickleVim.lsp.servers.sqlls,
                taplo = PickleVim.lsp.servers.taplo,
                vtsls = PickleVim.lsp.servers.vtsls,
                yamlls = PickleVim.lsp.servers.yamlls,
            },

            ---@type picklevim.lsp.setup
            setup = {},
        },

        ---@param opts PluginLspOpts
        config = function(_, opts)
            PickleVim.lsp.on_attach(function(client, buffer)
                PickleVim.lsp.keymaps.on_attach(client, buffer)
            end)

            PickleVim.lsp.setup()

            PickleVim.lsp.on_dynamic_capability(PickleVim.lsp.keymaps.on_attach)

            if opts.inlay_hints.enabled then
                PickleVim.lsp.on_supports_method('textDocument/inlayHint', function(client, buffer)
                    if vim.api.nvim_buf_is_valid(buffer) and vim.bo[buffer].buftype == '' then
                        vim.lsp.inlay_hint.enable(true, { bufnr = buffer })
                    end
                end)

                -- Re-enable hints if they get disabled (e.g. after certain LSP actions)
                local timer = nil
                local function check_and_enable_hints(buffer)
                    if timer then
                        timer:stop()
                    end

                    timer = vim.defer_fn(function()
                        if not vim.api.nvim_buf_is_valid(buffer) or vim.bo[buffer].buftype ~= '' then
                            return
                        end

                        if not vim.lsp.inlay_hint.is_enabled({ bufnr = buffer }) then
                            local clients = vim.lsp.get_clients({ bufnr = buffer })
                            for _, client in ipairs(clients) do
                                if client:supports_method('textDocument/inlayHint', { bufnr = buffer }) then
                                    vim.lsp.inlay_hint.enable(true, { bufnr = buffer })
                                    break
                                end
                            end
                        end
                    end, 100)
                end

                vim.api.nvim_create_autocmd('BufEnter', {
                    group = vim.api.nvim_create_augroup('picklevim_inlay_hints_persistence', { clear = true }),
                    callback = function(args)
                        check_and_enable_hints(args.buf)
                    end,
                })
            end

            if opts.codelens.enabled and vim.lsp.codelens then
                PickleVim.lsp.on_supports_method('textDocument/codeLens', function(_, buffer)
                    vim.lsp.codelens.enable(true, { bufnr = buffer })
                end)
            end

            vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

            ---@type lsp.ClientCapabilities
            local capabilities = vim.tbl_deep_extend(
                'force',
                {},
                vim.lsp.protocol.make_client_capabilities(),
                require('blink.cmp').get_lsp_capabilities({}, false) or {},
                opts.capabilities or {}
            )

            -- Mutually exclusive server groups: if both are configured and enabled,
            -- the later entry in each group wins (e.g. vtsls is preferred over tsserver).
            local server_conflicts = {
                typescript = { 'tsserver', 'vtsls' },
            }

            local function should_skip_server(server_name)
                for _, group in pairs(server_conflicts) do
                    if vim.tbl_contains(group, server_name) then
                        for _, conflicting_name in ipairs(group) do
                            if conflicting_name ~= server_name and opts.servers[conflicting_name] and opts.servers[conflicting_name].enabled then
                                if server_name == 'tsserver' and conflicting_name == 'vtsls' then
                                    return true
                                elseif server_name == 'vtsls' and conflicting_name == 'tsserver' then
                                    return false
                                end
                            end
                        end
                    end
                end
                return false
            end

            for server_name, server_config in pairs(opts.servers) do
                if server_config.enabled then
                    if should_skip_server(server_name) then
                        vim.notify(
                            string.format('Skipping %s (conflicts with another enabled server)', server_name),
                            vim.log.levels.INFO
                        )
                        goto continue
                    end

                    ---@type picklevim.lsp.server.opts
                    local server_opts = vim.tbl_deep_extend('force', {
                        capabilities = vim.deepcopy(capabilities),
                    }, server_config.opts or {})

                    -- Custom setup: pcall the handler; if it errors, notify with troubleshooting info.
                    -- If it returns false, fall back to default vim.lsp.config + vim.lsp.enable.
                    if opts.setup[server_name] then
                        local ok, result = pcall(opts.setup[server_name], server_name, server_opts)
                        if not ok then
                            local msg = string.format(
                                'Failed to setup %s: %s\n\nTroubleshooting:\n• Check if the server is installed: :Mason\n• Verify custom setup function in lua/plugins/lsp/%s.lua\n• Try restarting LSP: <leader>cx',
                                server_name,
                                result or 'unknown error',
                                server_name
                            )
                            vim.notify(msg, vim.log.levels.ERROR)
                        elseif result == false then
                            vim.notify(
                                string.format('%s custom setup returned false, using default setup', server_name),
                                vim.log.levels.WARN
                            )
                            vim.lsp.config[server_name] = server_opts
                            vim.lsp.enable(server_name)
                        end
                    else
                        local ok, err = pcall(function()
                            vim.lsp.config[server_name] = server_opts
                            vim.lsp.enable(server_name)
                        end)
                        if not ok then
                            local msg = string.format(
                                'Failed to enable %s: %s\n\nTroubleshooting:\n• Install the server: :Mason\n• Check if binary is in PATH: !which %s\n• Verify server configuration in lua/utils/lsp/servers.lua\n• Check health: :checkhealth picklevim',
                                server_name,
                                err or 'unknown error',
                                server_name
                            )
                            vim.notify(msg, vim.log.levels.ERROR)
                        end
                    end

                    ::continue::
                end
            end

            -- Re-trigger FileType for buffers opened before LSP was ready
            vim.schedule(function()
                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == '' then
                        local ft = vim.bo[buf].filetype
                        if ft and ft ~= '' then
                            vim.api.nvim_exec_autocmds('FileType', {
                                buffer = buf,
                                modeline = false,
                            })
                        end
                    end
                end
            end)
        end,
    },
}
