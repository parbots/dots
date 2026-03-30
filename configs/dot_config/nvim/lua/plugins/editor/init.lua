return {
    {
        'max397574/better-escape.nvim',
        opts = {
            timeout = vim.o.timeoutlen,
            default_mappings = true,
            mappings = {
                i = {
                    j = {
                        k = '<Esc>',
                        j = '<Esc>',
                    },
                    k = {
                        j = '<Esc>',
                    },
                },
                c = {
                    j = {
                        k = '<Esc>',
                        j = '<Esc>',
                    },
                    k = {
                        j = '<Esc>',
                    },
                },
                t = {
                    j = {
                        k = '<C-\\><C-n>',
                    },
                },
                v = {
                    j = {
                        k = '<Esc>',
                    },
                },
                s = {
                    j = {
                        k = '<Esc>',
                    },
                },
            },
        },
    },

    {
        'folke/todo-comments.nvim',
        cmd = { 'TodoTrouble' },
        event = { 'LazyFile' },
        dependencies = {
            'folke/snacks.nvim',
        },
        opts = {
            keywords = {
                TODO = {
                    alt = { 'todo' },
                },
            },
        },
        keys = {
            {
                ']t',
                function()
                    require('todo-comments').jump_next()
                end,
                desc = 'Next Todo Comment',
            },
            {
                '[t',
                function()
                    require('todo-comments').jump_prev()
                end,
                desc = 'Previous Todo Comment',
            },
            { '<leader>xt', '<cmd>Trouble todo toggle<cr>', desc = 'Todo (Trouble)' },
            {
                '<leader>xT',
                '<cmd>Trouble todo toggle filter = {tag = {TODO,FIX,FIXME}}<cr>',
                desc = 'Todo/Fix/Fixme (Trouble)',
            },
        },
    },

    {
        'MagicDuck/grug-far.nvim',
        cmd = 'GrugFar',
        keys = {
            {
                '<leader>sr',
                function()
                    local grug = require('grug-far')
                    local ext = vim.bo.buftype == '' and vim.fn.expand('%:e')
                    grug.open({
                        transient = true,
                        prefills = {
                            filesFilter = ext and ext ~= '' and '*.' .. ext or nil,
                        },
                    })
                end,
                mode = { 'n', 'v' },
                desc = 'Search and Replace',
            },
        },
        opts = {
            headerMaxWidth = 80,

            normalModeSearch = true,
        },
    },

    {
        'brenoprata10/nvim-highlight-colors',
        event = { 'LazyFile' },
        opts = {
            render = 'virtual',

            virtual_symbol = '',
            virtual_symbol_prefix = '',
            virtual_symbol_suffix = ' ',
            virtual_symbol_position = 'inline', -- 'inline' | 'eol' | 'eow'

            enable_hex = true,
            enable_short_hex = true,
            enable_rgb = true,
            enable_hsl = true,
            enable_ansi = true,
            enable_hsl_without_function = true,
            enable_var_usage = true,
            enable_named_colors = true,
            enable_tailwind = true,

            exclude_filetypes = { 'lazy', 'snacks' },
        },
    },

    {
        'm4xshen/hardtime.nvim',
        dependencies = { 'MunifTanjim/nui.nvim' },
        event = 'VeryLazy',
        keys = {
            {
                '<leader>ch',
                function()
                    vim.g.hardtime_enabled = not vim.g.hardtime_enabled

                    vim.cmd(('Hardtime %s'):format(vim.g.hardtime_enabled and 'enable' or 'disable'))

                    PickleVim['info'](
                        (' **%s** '):format(vim.g.hardtime_enabled and 'Enabled' or 'Disabled'),
                        { title = 'Hardtime' }
                    )
                end,
                mode = { 'n', 'v' },
                desc = 'Toggle hardtime',
            },
        },
        opts = {},
    },

    {
        'tris203/precognition.nvim',
        event = 'VeryLazy',
        keys = {
            {
                '<leader>cp',
                function()
                    if require('precognition').toggle() then
                        PickleVim['info'](' **Enabled** ', { title = 'Precognition' })
                    else
                        PickleVim['info'](' **Disabled** ', { title = 'Precognition' })
                    end
                end,
                mode = { 'n', 'v' },
                desc = 'Toggle precognition',
            },
        },
        opts = {
            startVisible = false,
            showBlankVirtLine = false,
            highlightColor = { link = 'Comment' },
            hints = {
                Caret = { text = '^', prio = 2 },
                Dollar = { text = '$', prio = 1 },
                MatchingPair = { text = '%', prio = 5 },
                Zero = { text = '0', prio = 1 },
                w = { text = 'w', prio = 10 },
                b = { text = 'b', prio = 9 },
                e = { text = 'e', prio = 8 },
                W = { text = 'W', prio = 7 },
                B = { text = 'B', prio = 6 },
                E = { text = 'E', prio = 5 },
            },
            gutterHints = {
                G = { text = 'G', prio = 10 },
                gg = { text = 'gg', prio = 9 },
                PrevParagraph = { text = '{', prio = 8 },
                NextParagraph = { text = '}', prio = 8 },
            },
            disabled_fts = {
                'snacks_dashboard',
            },
        },
    },
}
