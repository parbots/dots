return {
    {
        'MeanderingProgrammer/render-markdown.nvim',
        dependencies = {
            'nvim-treesitter/nvim-treesitter',
            'echasnovski/mini.icons',
        },

        ft = { 'markdown' },
        cmd = { 'RenderMarkdown' },

        opts = {
            enabled = true,
            render_modes = { 'n', 'c', 't' },

            max_file_size = 10.0,
            debounce = 100,

            preset = 'obsidian',

            completions = {
                blink = {
                    enabled = true,
                },
            },

            latex = {
                enabled = false,
            },
        },
    },
}
