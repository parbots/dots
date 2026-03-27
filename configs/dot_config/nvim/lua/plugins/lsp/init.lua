--- Main LSP configuration
--- Sets up nvim-lspconfig, Mason package manager, and all LSP servers
--- Coordinates LSP server installation, configuration, and attachment
---
--- Architecture:
---   1. Mason - LSP/DAP/linter package manager (auto-installs tools)
---   2. mason-lspconfig - Bridge between Mason and nvim-lspconfig
---   3. nvim-lspconfig - LSP server configuration and management
---
--- Flow:
---   1. Mason installs LSP server binaries
---   2. nvim-lspconfig loads server configurations from lua/utils/lsp/servers.lua
---   3. Custom setup functions (if defined) configure special servers (vtsls, etc.)
---   4. Servers are configured via vim.lsp.config() and enabled via vim.lsp.enable()
---   5. on_attach callback registers LSP keymaps when server connects
---
--- Features:
---   - Auto-install LSP servers via Mason
---   - Unified diagnostics configuration (virtual text, signs, underline)
---   - Inlay hints with persistence (re-enable if disabled)
---   - Codelens with auto-refresh
---   - Server conflict resolution (vtsls vs tsserver)
---   - Blink.cmp LSP completion integration
---   - File operation support (rename files updates imports)
---   - Semantic token support
---
--- Key Files:
---   - lua/utils/lsp/servers.lua - Server configurations
---   - lua/utils/lsp/keymaps.lua - LSP keymaps
---   - lua/utils/lsp/init.lua - LSP utilities (on_attach, on_supports_method, etc.)
---   - lua/plugins/lsp/typescript.lua - TypeScript-specific setup
---   - lua/plugins/lsp/rust.lua - Rust-specific setup

--- Custom setup function type
--- Returns true if setup succeeded, false to fall back to default setup
---@alias picklevim.lsp.setup table<string, fun(string, vim.lsp.Config): boolean>

return {
    ----------------------------------------
    -- Mason - LSP/DAP/Linter Package Manager
    ----------------------------------------
    {
        'mason-org/mason.nvim',
        build = ':MasonUpdate',  -- Update Mason registry on plugin update
        cmd = { 'Mason' },       -- Lazy-load on :Mason command
        keys = {
            { '<leader>cm', '<CMD>Mason<CR>', desc = 'Mason' },
        },

        ---@class MasonSettings
        opts = {
            -- Install up to 4 packages concurrently
            max_concurrent_installers = 4,

            -- Python package installer settings
            pip = {
                upgrade_pip = true,  -- Auto-upgrade pip before installing packages
            },

            -- Mason UI configuration
            ui = {
                border = 'rounded',  -- Rounded border for Mason window

                width = 0.8,         -- 80% of screen width
                height = 0.8,        -- 80% of screen height

                icons = {
                    package_installed = '✓',
                    package_pending = '➜',
                    package_uninstalled = '✗',
                },
            },
        },
    },

    ----------------------------------------
    -- mason-lspconfig - Bridge between Mason and lspconfig
    ----------------------------------------
    {
        'mason-org/mason-lspconfig.nvim',
        lazy = true,
        optional = true,
        dependencies = {
            'mason.nvim',
        },
        opts = {
            -- Don't automatically setup servers (we handle it manually in lspconfig)
            automatic_enable = false,

            -- Auto-install these LSP servers via Mason
            ensure_installed = {
                'astro',         -- Astro
                'basedpyright',  -- Python
                'cssls',         -- CSS
                'gopls',         -- Go
                'html',          -- HTML
                'jsonls',        -- JSON
                'lua_ls',        -- Lua
                'marksman',      -- Markdown
                'mdx_analyzer',  -- MDX
                'sqlls',         -- SQL
                'taplo',         -- TOML
                'vtsls',         -- TypeScript/JavaScript
                'yamlls',        -- YAML
            },
        },
    },

    ----------------------------------------
    -- nvim-lspconfig - LSP Server Configuration
    ----------------------------------------
    {
        'neovim/nvim-lspconfig',
        event = { 'LazyFile' },  -- Load when opening files
        dependencies = {
            'williamboman/mason-lspconfig.nvim',
            'folke/lazydev.nvim',  -- Lua development (Neovim API completion)
        },

        ---@class PluginLspOpts
        opts = {
            ----------------------------------------
            -- Diagnostics Configuration
            ----------------------------------------
            ---@type vim.diagnostic.Opts
            diagnostics = {
                underline = true,         -- Underline diagnostic text
                update_in_insert = false, -- Don't update diagnostics while typing

                -- Virtual text (inline error messages)
                virtual_text = {
                    spacing = 2,          -- Spacing between code and diagnostic
                    source = 'if_many',   -- Show source if multiple sources
                    prefix = function(diag, _, _)
                        -- Use icon based on severity
                        return PickleVim.lsp.diagnostic_icon[diag.severity]
                    end,
                },

                severity_sort = true,     -- Sort diagnostics by severity

                -- Sign column icons
                signs = {
                    text = {
                        [vim.diagnostic.severity.ERROR] = PickleVim.icons.diagnostics.error,
                        [vim.diagnostic.severity.WARN] = PickleVim.icons.diagnostics.warn,
                        [vim.diagnostic.severity.HINT] = PickleVim.icons.diagnostics.hint,
                        [vim.diagnostic.severity.INFO] = PickleVim.icons.diagnostics.info,
                    },
                },
            },

            ----------------------------------------
            -- Feature Toggles
            ----------------------------------------
            inlay_hints = {
                enabled = true,  -- Enable inlay hints (type annotations, parameter names, etc.)
            },

            codelens = {
                enabled = true,  -- Enable codelens (inline actions/info)
            },

            ----------------------------------------
            -- LSP Capabilities
            ----------------------------------------
            -- Additional capabilities beyond Neovim defaults
            capabilities = {
                textDocument = {
                    semanticTokens = {
                        multilineTokenSupport = true,  -- Support semantic tokens across lines
                    },
                },

                workspace = {
                    fileOperations = {
                        dynamicRegistration = true,  -- Allow servers to register file operations

                        willRename = true,            -- Notify server before file rename
                        didRename = true,             -- Notify server after file rename
                    },
                },
            },

            ----------------------------------------
            -- Formatting Configuration
            ----------------------------------------
            -- NOTE: Formatting is handled by Conform.nvim with lsp_format = 'fallback'
            -- LSP formatting is used as fallback when no formatter is available
            format = {
                formatting_options = nil,  -- Use default formatting options
                timeout_ms = nil,          -- Use default timeout
            },

            ----------------------------------------
            -- LSP Server Definitions
            ----------------------------------------
            -- Server configurations imported from lua/utils/lsp/servers.lua
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

            ----------------------------------------
            -- Custom Server Setup Functions
            ----------------------------------------
            -- Custom setup functions for servers requiring special handling
            -- Defined in separate files (e.g., lua/plugins/lsp/typescript.lua)
            ---@type picklevim.lsp.setup
            setup = {},
        },

        ----------------------------------------
        -- Configuration Function
        ----------------------------------------
        ---@param opts PluginLspOpts
        config = function(_, opts)
            -- NOTE: LSP formatting is handled by Conform via lsp_format = 'fallback'
            -- No need to register LSP as a separate formatter

            ----------------------------------------
            -- Register Global LSP Callbacks
            ----------------------------------------

            -- Attach LSP keymaps when server connects
            PickleVim.lsp.on_attach(function(client, buffer)
                PickleVim.lsp.keymaps.on_attach(client, buffer)
            end)

            -- Initialize LSP utilities
            PickleVim.lsp.setup()

            -- Register keymaps for dynamically registered capabilities
            PickleVim.lsp.on_dynamic_capability(PickleVim.lsp.keymaps.on_attach)

            ----------------------------------------
            -- Inlay Hints Setup
            ----------------------------------------
            if opts.inlay_hints.enabled then
                -- Enable inlay hints when LSP server supports it
                PickleVim.lsp.on_supports_method('textDocument/inlayHint', function(client, buffer)
                    if vim.api.nvim_buf_is_valid(buffer) and vim.bo[buffer].buftype == '' then
                        vim.lsp.inlay_hint.enable(true, { bufnr = buffer })
                    end
                end)

                -- Persistence: Re-enable hints if they get disabled
                -- This handles cases where hints disappear after certain actions
                local timer = nil
                local function check_and_enable_hints(buffer)
                    if timer then
                        timer:stop()
                    end

                    timer = vim.defer_fn(function()
                        -- Validate buffer before proceeding
                        if not vim.api.nvim_buf_is_valid(buffer) or vim.bo[buffer].buftype ~= '' then
                            return
                        end

                        -- Only re-enable if not already enabled
                        if not vim.lsp.inlay_hint.is_enabled({ bufnr = buffer }) then
                            local clients = vim.lsp.get_clients({ bufnr = buffer })
                            for _, client in ipairs(clients) do
                                if client:supports_method('textDocument/inlayHint', { bufnr = buffer }) then
                                    vim.lsp.inlay_hint.enable(true, { bufnr = buffer })
                                    break
                                end
                            end
                        end
                    end, 100) -- 100ms debounce
                end

                -- Only check on buffer enter (not every edit for performance)
                vim.api.nvim_create_autocmd('BufEnter', {
                    group = vim.api.nvim_create_augroup('picklevim_inlay_hints_persistence', { clear = true }),
                    callback = function(args)
                        check_and_enable_hints(args.buf)
                    end,
                })
            end

            ----------------------------------------
            -- Code Lens Setup
            ----------------------------------------
            if opts.codelens.enabled and vim.lsp.codelens then
                PickleVim.lsp.on_supports_method('textDocument/codeLens', function(_, buffer)
                    -- Refresh codelens immediately
                    vim.lsp.codelens.refresh()

                    -- Auto-refresh codelens on certain events
                    vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'InsertLeave' }, {
                        buffer = buffer,
                        callback = vim.lsp.codelens.refresh,
                    })
                end)
            end

            ----------------------------------------
            -- Apply Diagnostic Configuration
            ----------------------------------------
            vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

            ----------------------------------------
            -- Build LSP Client Capabilities
            ----------------------------------------
            -- Merge capabilities from multiple sources
            ---@type lsp.ClientCapabilities
            local capabilities = vim.tbl_deep_extend(
                'force',
                {},
                vim.lsp.protocol.make_client_capabilities(),  -- Neovim defaults
                require('blink.cmp').get_lsp_capabilities({}, false) or {},  -- Blink.cmp completion
                opts.capabilities or {}  -- Custom capabilities
            )

            ----------------------------------------
            -- Server Conflict Resolution
            ----------------------------------------
            -- Define groups of mutually exclusive servers
            local server_conflicts = {
                typescript = { 'tsserver', 'vtsls' },  -- vtsls is preferred over tsserver
            }

            -- Check if server should be skipped due to conflicts
            local function should_skip_server(server_name)
                for _, group in pairs(server_conflicts) do
                    if vim.tbl_contains(group, server_name) then
                        -- Check if any conflicting server is already configured
                        for _, conflicting_name in ipairs(group) do
                            if conflicting_name ~= server_name and opts.servers[conflicting_name] and opts.servers[conflicting_name].enabled then
                                -- Prefer vtsls over tsserver
                                if server_name == 'tsserver' and conflicting_name == 'vtsls' then
                                    return true
                                elseif server_name == 'vtsls' and conflicting_name == 'tsserver' then
                                    return false -- Keep vtsls, skip tsserver
                                end
                            end
                        end
                    end
                end
                return false
            end

            ----------------------------------------
            -- Configure and Enable LSP Servers
            ----------------------------------------
            for server_name, server_config in pairs(opts.servers) do
                if server_config.enabled then
                    -- Skip if conflicts with another enabled server
                    if should_skip_server(server_name) then
                        vim.notify(
                            string.format('Skipping %s (conflicts with another enabled server)', server_name),
                            vim.log.levels.INFO
                        )
                        goto continue
                    end

                    -- Build server options by merging capabilities with server config
                    ---@type picklevim.lsp.server.opts
                    local server_opts = vim.tbl_deep_extend('force', {
                        capabilities = vim.deepcopy(capabilities),
                    }, server_config.opts or {})

                    -- Use custom setup function if defined
                    if opts.setup[server_name] then
                        local ok, result = pcall(opts.setup[server_name], server_name, server_opts)
                        if not ok then
                            -- Custom setup failed
                            local msg = string.format(
                                'Failed to setup %s: %s\n\nTroubleshooting:\n• Check if the server is installed: :Mason\n• Verify custom setup function in lua/plugins/lsp/%s.lua\n• Try restarting LSP: <leader>cx',
                                server_name,
                                result or 'unknown error',
                                server_name
                            )
                            vim.notify(msg, vim.log.levels.ERROR)
                        elseif result == false then
                            -- Custom setup returned false, fall back to default
                            vim.notify(
                                string.format('%s custom setup returned false, using default setup', server_name),
                                vim.log.levels.WARN
                            )
                            vim.lsp.config[server_name] = server_opts
                            vim.lsp.enable(server_name)
                        end
                    else
                        -- Use default setup (vim.lsp.config + vim.lsp.enable)
                        local ok, err = pcall(function()
                            vim.lsp.config[server_name] = server_opts
                            vim.lsp.enable(server_name)
                        end)
                        if not ok then
                            -- Default setup failed
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

            ----------------------------------------
            -- Attach LSP to Already-Open Buffers
            ----------------------------------------
            -- Trigger LSP attachment for buffers that were opened before LSP was ready
            vim.schedule(function()
                -- Re-trigger FileType event for all valid buffers to attach LSP
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
