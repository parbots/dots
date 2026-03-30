return {
    {
        'catppuccin/nvim',
        priority = 1000,
        lazy = false,
        name = 'catppuccin',

        specs = {
            {
                'akinsho/bufferline.nvim',
                optional = true,
                opts = function(_, opts)
                    opts.highlights = require('catppuccin.special.bufferline').get_theme()
                end,
            },
        },

        ---@class CatppuccinOptions
        opts = {
            flavour = 'mocha',

            background = {
                light = 'latte',
                dark = 'mocha',
            },

            transparent_background = false,
            show_end_of_buffer = false,
            term_colors = false,

            dim_inactive = {
                enabled = true,
                shade = 'dark',
                percentage = 0.25,
            },

            no_italic = false,
            no_bold = false,
            no_underline = false,

            styles = {
                comments = { 'bold', 'italic' },
                conditionals = { 'italic' },
                loops = { 'italic' },
                functions = { 'italic' },
                keywords = { 'italic' },
                strings = {},
                variables = {},
                numbers = {},
                booleans = { 'italic' },
                properties = {},
                types = { 'bold', 'italic' },
                operators = {},
            },

            lsp_styles = {
                enabled = true,

                virtual_text = {
                    errors = { 'italic' },
                    hints = { 'italic' },
                    warnings = { 'italic' },
                    information = { 'italic' },
                    ok = { 'italic' },
                },

                underlines = {
                    errors = { 'undercurl' },
                    hints = { 'underline' },
                    warnings = { 'undercurl' },
                    information = { 'underline' },
                    ok = { 'underline' },
                },

                inlay_hints = {
                    background = true,
                },
            },

            default_integrations = true,
            auto_integrations = true,

            integrations = {
                blink_cmp = {
                    style = 'solid',
                },
                blink_indent = true,
                blink_pairs = true,
                cmp = true,

                dropbar = {
                    enabled = true,
                    color_mode = true,
                },
                noice = true,
                notifier = true,
                notify = true,
                which_key = true,

                flash = true,
                grug_far = true,
                mini = {
                    enabled = true,
                },
                snacks = {
                    enabled = true,
                },

                gitsigns = {
                    enabled = true,
                    transparent = true,
                },
                neogit = true,
                diffview = true,

                lsp_trouble = true,
                mason = true,

                treesitter_context = true,
                render_markdown = true,
            },
        },
    },
}
