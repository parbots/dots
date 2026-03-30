return {
    {
        'stevearc/oil.nvim',
        cmd = 'Oil',
        dependencies = {
            'echasnovski/mini.icons',
        },

        keys = {
            {
                '<leader>oo',
                function()
                    require('oil').open_float(nil, {
                        preview = {
                            vertical = true,
                        },
                    }, nil)
                end,
                desc = 'Open oil (float)',
            },

            {
                '<leader>fe',
                '<CMD>Oil<CR>',
                desc = 'Open oil',
            },
        },

        ---@module 'oil'
        ---@type oil.SetupOpts
        opts = {
            default_file_explorer = false,

            columns = {
                'icon',
            },

            buf_options = {
                buflisted = false,
                bufhidden = 'hide',
            },

            win_options = {
                wrap = false,
                signcolumn = 'yes',
                cursorcolumn = false,
                foldcolumn = '0',
                spell = false,
                list = false,
                conceallevel = 3,
                concealcursor = 'nvic',
            },

            delete_to_trash = false,
            skip_confirm_for_simple_edits = true,
            prompt_save_on_select_new_entry = true,
            cleanup_delay_ms = 2000,

            lsp_file_methods = {
                enabled = true,
                timeout_ms = 1000,
                autosave_changes = false,
            },

            constrain_cursor = 'editable',
            watch_for_changes = true,

            view_options = {
                show_hidden = true,
                natural_order = 'fast',
            },
        },
    },
}
