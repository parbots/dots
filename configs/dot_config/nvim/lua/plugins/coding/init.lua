return {
    {
        'folke/ts-comments.nvim',
        event = { 'VeryLazy' },
    },

    {
        'folke/lazydev.nvim',
        ft = { 'lua' },
        opts = function()
            return {
                runtime = vim.env.VIMRUNTIME,

                library = {
                    '${3rd}/luv/library',
                    vim.fn.stdpath('config'),
                    vim.fn.stdpath('data') .. '/lazy',
                },

                integrations = {
                    lspconfig = true,
                    cmp = false,
                },

                ---@type boolean | (fun(root: string): boolean?)
                enabled = function(_)
                    return vim.g.lazydev_enabled == nil and true or vim.g.lazydev_enabled
                end,

                sources = {
                    default = { 'lazydev' },
                    providers = {
                        lazydev = {
                            name = 'lazy',
                            kind = 'lazy',
                            module = 'lazydev.integrations.blink',

                            min_keyword_length = 1,
                            max_items = 5,
                        },
                    },
                },
            }
        end,
        config = function(_, opts)
            require('lazydev').setup(opts)
        end,
    },
}
