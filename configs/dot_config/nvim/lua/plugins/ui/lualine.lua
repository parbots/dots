return {
    {
        'nvim-lualine/lualine.nvim',
        event = { 'VeryLazy' },
        dependencies = {
            'folke/noice.nvim',
        },

        -- Hide statusline on startup for cleaner dashboard experience
        init = function()
            vim.g.lualine_laststatus = vim.o.laststatus

            if vim.fn.argc(-1) > 0 then
                vim.o.statusline = ' '
            else
                vim.o.laststatus = 0
            end
        end,

        opts = function()
            local lualine_require = require('lualine_require')
            lualine_require.require = require

            vim.o.laststatus = vim.g.lualine_laststatus

            local opts = {
                options = {
                    theme = 'catppuccin-mocha',

                    globalstatus = vim.o.laststatus == 3,

                    disabled_filetypes = {
                        statusline = { 'snacks_dashboard' },
                    },
                },

                sections = {
                    lualine_a = {
                        {
                            'mode',
                            padding = { left = 1, right = 1 },
                        },
                    },

                    lualine_b = {
                        {
                            'branch',
                            icon = '',
                            padding = { left = 1, right = 1 },
                        },

                        {
                            'diff',
                            symbols = {
                                added = PickleVim.icons.git.added,
                                modified = PickleVim.icons.git.modified,
                                removed = PickleVim.icons.git.removed,
                            },
                            source = function()
                                local gitsigns = vim.b.gitsigns_status_dict
                                if gitsigns then
                                    return {
                                        added = gitsigns.added,
                                        modified = gitsigns.changed,
                                        removed = gitsigns.removed,
                                    }
                                else
                                    return nil
                                end
                            end,
                        },
                    },

                    lualine_c = {
                        PickleVim.lualine.root_dir(),
                        PickleVim.lualine.pretty_path(),
                        {
                            'searchcount',
                        },
                    },

                    lualine_x = {
                        Snacks.profiler.status(),
                        PickleVim.lualine.noice_cmd(),
                        PickleVim.lualine.noice_mode(),
                        PickleVim.lualine.lazy_status(),
                    },

                    lualine_y = {
                        {
                            'diagnostics',
                            sources = {
                                'nvim_diagnostic',
                            },
                            symbols = {
                                error = PickleVim.icons.diagnostics.error,
                                warn = PickleVim.icons.diagnostics.warn,
                                info = PickleVim.icons.diagnostics.info,
                                hint = PickleVim.icons.diagnostics.hint,
                            },
                            padding = { left = 1, right = 1 },
                        },

                        PickleVim.lualine.lsp_status(),

                        {
                            'filetype',
                            icon_only = false,
                            draw_empty = false,
                            padding = { left = 1, right = 1 },
                        },
                    },

                    lualine_z = {
                        {
                            'location',
                            icon = '',
                            padding = { left = 1, right = 1 },
                        },
                    },
                },

                extensions = {
                    'lazy',
                    'man',
                    'mason',
                    'oil',
                    'trouble',
                },
            }

            return opts
        end,
    },
}
