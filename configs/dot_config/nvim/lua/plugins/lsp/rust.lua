return {
    {
        'mrcjkb/rustaceanvim',
        version = '^6',
        lazy = false,
        ft = { 'rust' },

        opts = function()
            return {
                tools = {},

                server = {
                    on_attach = function(client, bufnr)
                        PickleVim.lsp.keymaps.on_attach(client, bufnr)
                    end,

                    default_settings = {
                        ['rust-analyzer'] = {
                            cargo = {
                                allFeatures = true,
                                loadOutDirsFromCheck = true,
                                buildScripts = {
                                    enable = true,
                                },
                            },

                            checkOnSave = true,

                            procMacro = {
                                enable = true,
                                ignored = {
                                    ['async-trait'] = { 'async_trait' },
                                    ['napi-derive'] = { 'napi' },
                                    ['async-recursion'] = { 'async_recursion' },
                                },
                            },

                            inlayHints = {
                                bindingModeHints = {
                                    enable = false,
                                },
                                chainingHints = {
                                    enable = true,
                                },
                                closingBraceHints = {
                                    enable = true,
                                    minLines = 25,
                                },
                                closureReturnTypeHints = {
                                    enable = 'never',
                                },
                                lifetimeElisionHints = {
                                    enable = 'never',
                                    useParameterNames = false,
                                },
                                maxLength = 25,
                                parameterHints = {
                                    enable = true,
                                },
                                reborrowHints = {
                                    enable = 'never',
                                },
                                renderColons = true,
                                typeHints = {
                                    enable = true,
                                    hideClosureInitialization = false,
                                    hideNamedConstructor = false,
                                },
                            },
                        },
                    },
                },

                dap = {},
            }
        end,

        -- rustaceanvim reads config from vim.g.rustaceanvim
        config = function(_, opts)
            vim.g.rustaceanvim = vim.tbl_deep_extend('keep', vim.g.rustaceanvim or {}, opts or {})
        end,
    },
}
