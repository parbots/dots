require('config').init()

return {

    {
        'folke/lazy.nvim',
        version = '*',
        lazy = false,
    },

    {
        'nvim-lua/plenary.nvim',
        lazy = true,
    },

    {
        'nvim-tree/nvim-web-devicons',
        lazy = true,
        opts = {
            color_icons = true,
            default = true,
            strict = true,
        },
    },

    {
        'folke/snacks.nvim',
        priority = 1000,
        lazy = false,
        opts = {
            animate = { enabled = true },
            bigfile = { enabled = true },
            bufdelete = { enabled = true },
            dashboard = { enabled = true },
            debug = { enabled = true },
            dim = { enabled = true },
            explorer = { enabled = true },
            git = { enabled = true },
            gitbrowse = { enabled = true },
            image = { enabled = true },
            indent = { enabled = true },
            input = { enabled = true },
            layout = { enabled = true },
            lazygit = { enabled = true },
            notifier = { enabled = false },
            notify = { enabled = true },
            picker = { enabled = true },
            quickfile = { enabled = true },
            rename = { enabled = true },
            scope = { enabled = true },
            scratch = { enabled = true },
            scroll = { enabled = true },
            statuscolumn = { enabled = true },
            terminal = { enabled = true },
            toggle = { enabled = true },
            util = { enabled = true },
            win = { enabled = true },
            words = { enabled = true },
            zen = { enabled = true },
        },
        config = function(_, opts)
            local notify = vim.notify

            require('snacks').setup(opts)

            if PickleVim.plugin.has('noice.nvim') then
                vim.notify = notify
            end
        end,
    },
}
