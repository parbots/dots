--- Rust LSP configuration via rustaceanvim
--- Uses rustaceanvim plugin for rust-analyzer LSP integration
--- Provides enhanced Rust development experience with better LSP handling than standard lspconfig
---
--- Features:
---   - Automatic rust-analyzer setup and configuration
---   - Cargo integration with all features enabled
---   - Procedural macro expansion
---   - Inlay hints for types, parameters, and chaining
---   - Check-on-save with configurable checker (clippy/cargo check)
---   - Debug Adapter Protocol (DAP) integration
---
--- Note:
---   - rustaceanvim manages rust-analyzer directly (not through lspconfig)
---   - Configuration is stored in vim.g.rustaceanvim
---   - LSP keymaps are loaded via PickleVim.lsp.keymaps.on_attach()

return {
    {
        'mrcjkb/rustaceanvim',
        version = '^6',       -- Use v6.x (stable)
        lazy = false,         -- Load immediately for Rust files
        ft = { 'rust' },      -- Load on Rust filetype

        opts = function()
            return {
                ----------------------------------------
                -- Plugin Tools
                ----------------------------------------
                tools = {},   -- Use default rustaceanvim tools

                ----------------------------------------
                -- LSP Server Configuration
                ----------------------------------------
                server = {
                    -- Attach LSP keymaps when rust-analyzer connects
                    on_attach = function(client, bufnr)
                        -- Load standard LSP keymaps (gd, gr, K, etc.)
                        PickleVim.lsp.keymaps.on_attach(client, bufnr)
                    end,

                    -- rust-analyzer settings
                    default_settings = {
                        ['rust-analyzer'] = {
                            ----------------------------------------
                            -- Cargo Configuration
                            ----------------------------------------
                            cargo = {
                                allFeatures = true,        -- Enable all Cargo features
                                loadOutDirsFromCheck = true, -- Load OUT_DIR from cargo check
                                buildScripts = {
                                    enable = true,         -- Run build scripts (build.rs)
                                },
                            },

                            ----------------------------------------
                            -- Diagnostics
                            ----------------------------------------
                            checkOnSave = true,            -- Run cargo check on save

                            ----------------------------------------
                            -- Procedural Macros
                            ----------------------------------------
                            procMacro = {
                                enable = true,             -- Enable proc macro expansion
                                -- Ignore problematic proc macros that cause issues
                                ignored = {
                                    ['async-trait'] = { 'async_trait' },
                                    ['napi-derive'] = { 'napi' },
                                    ['async-recursion'] = { 'async_recursion' },
                                },
                            },

                            ----------------------------------------
                            -- Inlay Hints
                            ----------------------------------------
                            -- Type hints, parameter names, etc. shown inline in editor
                            inlayHints = {
                                bindingModeHints = {
                                    enable = false,        -- Don't show binding mode hints (ref, mut)
                                },
                                chainingHints = {
                                    enable = true,         -- Show type hints for method chains
                                },
                                closingBraceHints = {
                                    enable = true,         -- Show closing brace hints (for long blocks)
                                    minLines = 25,         -- Only for blocks >= 25 lines
                                },
                                closureReturnTypeHints = {
                                    enable = 'never',      -- Don't show closure return types
                                },
                                lifetimeElisionHints = {
                                    enable = 'never',      -- Don't show elided lifetimes
                                    useParameterNames = false,
                                },
                                maxLength = 25,            -- Max hint length before truncation
                                parameterHints = {
                                    enable = true,         -- Show parameter name hints
                                },
                                reborrowHints = {
                                    enable = 'never',      -- Don't show reborrow hints
                                },
                                renderColons = true,       -- Render colons in hints (: Type)
                                typeHints = {
                                    enable = true,         -- Show type hints for variables
                                    hideClosureInitialization = false, -- Show types for closures
                                    hideNamedConstructor = false,      -- Show types for constructors
                                },
                            },
                        },
                    },
                },

                ----------------------------------------
                -- Debug Adapter Protocol (DAP)
                ----------------------------------------
                dap = {},     -- Use default DAP configuration
            }
        end,

        -- Apply configuration to vim.g.rustaceanvim
        -- rustaceanvim reads config from this global variable
        config = function(_, opts)
            vim.g.rustaceanvim = vim.tbl_deep_extend('keep', vim.g.rustaceanvim or {}, opts or {})
        end,
    },
}
