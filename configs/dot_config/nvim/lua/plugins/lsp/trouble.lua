return {
    'folke/trouble.nvim',
    lazy = true,
    cmd = { 'Trouble' },

    ---@class trouble.Config
    opts = {
        auto_close = false,
        auto_open = false,
        auto_preview = true,
        auto_refresh = true,
        auto_jump = false,

        focus = true,
        restore = true,
        follow = true,

        indent_guides = true,
        max_items = 200,
        multiline = true,
        pinned = false,

        warn_no_results = true,
        open_no_results = false,

        win = {},

        preview = {
            type = 'main',
            scratch = true,
        },

        throttle = {
            refresh = 20,
            update = 10,
            render = 10,
            follow = 100,

            preview = {
                ms = 100,
                debounce = true,
            },
        },

        keys = {},

        modes = {
            lsp = {
                win = { position = 'right' },
            },
        },

        icons = {
            indent = {
                top = '│ ',
                middle = '├╴',
                last = '╰╴',
                fold_open = ' ',
                fold_closed = ' ',
                ws = '  ',
            },

            kinds = PickleVim.icons.kinds,
        },

        debug = {},
    },

    keys = {
        { '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Diagnostics (Trouble)' },
        { '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = 'Buffer Diagnostics (Trouble)' },

        { '<leader>cs', '<cmd>Trouble symbols toggle<cr>', desc = 'Symbols (Trouble)' },
        { '<leader>cS', '<cmd>Trouble lsp toggle<cr>', desc = 'LSP references/definitions/... (Trouble)' },

        { '<leader>xL', '<cmd>Trouble loclist toggle<cr>', desc = 'Location List (Trouble)' },
        { '<leader>xQ', '<cmd>Trouble qflist toggle<cr>', desc = 'Quickfix List (Trouble)' },
    },
}
