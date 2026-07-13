return {
    {
        'folke/noice.nvim',
        event = { 'VeryLazy' },
        dependencies = {
            'MunifTanjim/nui.nvim',
        },

        keys = {
            { '<leader>sn', '', desc = '+noice' },

            {
                '<S-Enter>',
                function()
                    require('noice').redirect(vim.fn.getcmdline())
                end,
                mode = 'c',
                desc = 'Redirect Cmdline',
            },

            {
                '<leader>snl',
                function()
                    require('noice').cmd('last')
                end,
                desc = 'Noice Last Message',
            },

            {
                '<leader>snh',
                function()
                    require('noice').cmd('history')
                end,
                desc = 'Noice History',
            },

            {
                '<leader>sna',
                function()
                    require('noice').cmd('all')
                end,
                desc = 'Noice All',
            },

            {
                '<leader>snd',
                function()
                    require('noice').cmd('dismiss')
                end,
                desc = 'Dismiss All',
            },

            {
                '<leader>snt',
                function()
                    require('noice').cmd('pick')
                end,
                desc = 'Noice Picker',
            },

            {
                '<c-b>',
                function()
                    if not require('noice.lsp').scroll(-4) then
                        return '<c-b>'
                    end
                end,
                silent = true,
                expr = true,
                desc = 'Scroll Backward',
                mode = { 'i', 'n', 's' },
            },
        },

        opts = {
            throttle = 1000 / 60,

            cmdline = {
                enabled = true,
                view = 'cmdline_popup',
                opts = {},

                format = {
                    cmdline = { pattern = '^:', icon = ' ', lang = 'vim' },
                    search_down = { kind = 'search', pattern = '^/', icon = '  ', lang = 'regex' },
                    search_up = { kind = 'search', pattern = '^%?', icon = '  ', lang = 'regex' },
                    filter = { pattern = '^:%s*!', icon = '$ ', lang = 'bash' },
                    lua = { pattern = { '^:%s*lua%s+', '^:%s*lua%s*=%s*', '^:%s*=%s*' }, icon = ' ', lang = 'lua' },
                    help = { pattern = '^:%s*he?l?p?%s+', icon = '󰋖 ' },
                    input = { view = 'cmdline_input', icon = '󰥻 ' },
                },
            },

            messages = {
                enabled = true,
                view = 'notify',
                view_error = 'notify',
                view_warn = 'notify',
                view_history = 'messages',
                view_search = 'virtualtext',
            },

            popupmenu = {
                enabled = true,
                backend = 'nui',
            },

            ---@type NoiceRouteConfig
            redirect = {
                view = 'popup',
                filter = { event = 'msg_show' },
            },

            ---@type table<string, NoiceCommand>
            commands = {
                history = {
                    view = 'split',
                    opts = { enter = true, format = 'details' },
                    filter = {
                        any = {
                            { event = 'notify' },
                            { error = true },
                            { warning = true },
                            { event = 'msg_show', kind = { '' } },
                            { event = 'lsp', kind = 'message' },
                        },
                    },
                    filter_opts = {},
                },

                last = {
                    view = 'popup',
                    opts = { enter = true, format = 'details' },
                    filter = {
                        any = {
                            { event = 'notify' },
                            { error = true },
                            { warning = true },
                            { event = 'msg_show', kind = { '' } },
                            { event = 'lsp', kind = 'message' },
                        },
                    },
                    filter_opts = { count = 1 },
                },

                errors = {
                    view = 'popup',
                    opts = { enter = true, format = 'details' },
                    filter = { error = true },
                    filter_opts = { reverse = true },
                },

                all = {
                    view = 'split',
                    opts = { enter = true, format = 'details' },
                    filter = {},
                    filter_opts = {},
                },
            },

            notify = {
                enabled = true,
                view = 'notify',
            },

            lsp = {
                -- LSP progress is rendered by the snacks notifier (see plugins/snacks/init.lua)
                progress = {
                    enabled = false,

                    format = {
                        ' ({data.progress.percentage}%) ',
                        { '{spinner} ', hl_group = 'NoiceLspProgressSpinner' },
                        { '{data.progress.title} ', hl_group = 'NoiceLspProgressTitle' },
                        { '{data.progress.client} ', hl_group = 'NoiceLspProgressClient' },
                    },

                    format_done = {
                        { ' ✔ ', hl_group = 'NoiceLspProgressSpinner' },
                        { '{data.progress.title} ', hl_group = 'NoiceLspProgressTitle' },
                        { '{data.progress.client} ', hl_group = 'NoiceLspProgressClient' },
                    },

                    throttle = 1000 / 60,
                    view = 'mini',
                },

                override = {
                    ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
                    ['vim.lsp.util.stylize_markdown'] = true,
                    ['cmp.entry.get_documentation'] = true,
                },
            },

            hover = {
                enabled = true,
                silent = false,
                view = nil,
                opts = {},
            },

            signature = {
                enabled = true,

                auto_open = {
                    enabled = true,
                    trigger = true,
                    luasnip = true,
                    throttle = 50,
                },

                view = nil,
                opts = {},
            },

            message = {
                enabled = true,
                view = 'notify',
                opts = {},
            },

            documentation = {
                view = 'hover',

                ---@type NoiceViewOptions
                opts = {
                    lang = 'markdown',
                    replace = true,
                    render = 'plain',
                    format = { '{message}' },
                    win_options = {
                        concealcursor = 'n',
                        conceallevel = 3,
                        border = 'solid',
                    },
                },
            },

            markdown = {
                hover = {
                    ['|(%S-)|'] = vim.cmd.help,
                    ['%[.-%]%((%S-)%)'] = require('noice.util').open,
                },

                highlights = {
                    ['|%S-|'] = '@text.reference',
                    ['@%S+'] = '@parameter',
                    ['^%s*(Parameters:)'] = '@text.title',
                    ['^%s*(Return:)'] = '@text.title',
                    ['^%s*(See also:)'] = '@text.title',
                    ['{%S-}'] = '@parameter',
                },
            },

            health = {
                checker = true,
            },

            -- Route file-stat and undo/redo messages to the mini view (less intrusive).
            routes = {
                {
                    filter = {
                        event = 'msg_show',
                        any = {
                            { find = '%d+L, %d+B' },
                            { find = '; after #%d+' },
                            { find = '; before #%d+' },
                        },
                    },
                    view = 'mini',
                },

                {
                    filter = {
                        event = 'notify',
                        any = {
                            { find = 'formatted ' },
                        },
                    },
                    view = 'mini',
                },
            },

            ---@type NoiceConfigViews
            views = {
                hover = {
                    anchor = 'auto',
                    border = {
                        style = 'rounded',
                        padding = { 0, 1 },
                    },
                    position = { row = 2, col = 0 },
                },

                notify = {
                    backend = 'snacks',
                    format = 'notify',
                    replace = true,
                    merge = false,
                },
            },

            ---@type NoicePresets
            presets = {
                bottom_search = true,
                command_palette = true,
                long_message_to_split = true,
                lsp_doc_border = true,
            },
        },
    },
}
