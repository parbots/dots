return {
    {
        'L3MON4D3/LuaSnip',
        lazy = true,
        version = 'v2.*',
        build = 'make install_jsregexp',

        dependencies = {
            'rafamadriz/friendly-snippets',
        },

        opts = {},

        config = function(_, opts)
            local luasnip = require('luasnip')
            luasnip.setup(opts)

            luasnip.filetype_extend('typescript', { 'javascript' })
            luasnip.filetype_extend('javascriptreact', { 'javascript', 'html' })
            luasnip.filetype_extend('typescriptreact', { 'typescript', 'html' })

            require('luasnip.loaders.from_vscode').lazy_load()

            require('luasnip.loaders.from_vscode').lazy_load({
                paths = { vim.fn.stdpath('config') .. '/snippets' },
            })
        end,
    },
}
