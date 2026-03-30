return {
    {
        'Bekaboo/dropbar.nvim',
        event = { 'LazyFile' },

        keys = {
            {
                '<leader>;',
                mode = { 'n' },
                function()
                    require('dropbar.api').pick()
                end,
                desc = 'Pick symbol in dropbar',
            },

            {
                '[;',
                mode = { 'n' },
                function()
                    require('dropbar.api').goto_context_start()
                end,
                desc = 'Go to start of current context',
            },

            {
                '];',
                mode = { 'n' },
                function()
                    require('dropbar.api').select_next_context()
                end,
                desc = 'Select next context',
            },
        },

        opts = {
            bar = {
                update_debounce = 50,
            },

            menu = {
                preview = false,

                scrollbar = {
                    enable = true,
                    background = true,
                },
            },

            icons = {
                enable = true,

                ui = {
                    bar = {
                        separator = '  ',
                        extends = '…',
                    },

                    menu = {
                        separator = ' ',
                        indicator = '  ',
                    },
                },
            },

            sources = {
                path = {
                    ---@param sym any Symbol data
                    ---@return any modified Modified symbol with [+] indicator
                    modified = function(sym)
                        return sym:merge({
                            name = sym.name .. ' [+]',
                            icon = ' ',
                            name_hl = 'DiffAdded',
                            icon_hl = 'DiffAdded',
                        })
                    end,
                },
            },
        },
    },
}
