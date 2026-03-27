return {
    'folke/snacks.nvim',
    keys = {
        {
            '<leader>e',
            function()
                ---@diagnostic disable: missing-fields
                Snacks.explorer({ cwd = PickleVim.root() })
            end,
            desc = 'Explorer Snacks (root dir)',
        },
        {
            '<leader>E',
            function()
                Snacks.explorer()
            end,
            desc = 'Explorer Snacks (cwd)',
        },
    },
    opts = {
        explorer = {
            replace_netrw = true,
        },

        ---@type snacks.picker.Config
        picker = {
            sources = {
                explorer = {
                    finder = 'explorer',
                    sort = {
                        fields = { 'sort' },
                    },
                    supports_live = true,
                    tree = true,
                    watch = true,
                    diagnostics = true,
                    diagnostics_open = false,
                    git_status = true,
                    git_status_open = false,
                    git_untracked = true,
                    follow_file = true,
                    focus = 'list',
                    auto_close = false,
                    jump = {
                        close = false,
                    },
                    layout = {
                        preset = 'sidebar',
                    },
                    formatters = {
                        file = { filename_only = true },
                        severity = { pos = 'right' },
                    },

                    hidden = true,
                    ignored = true,

                    matcher = {
                        sort_empty = false,
                        fuzzy = true,
                    },
                },
            },
        },
    },
}
