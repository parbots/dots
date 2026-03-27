--- Noice.nvim - Modern UI for messages, cmdline, and popupmenu
--- Completely replaces the default Neovim UI for messages and command line
--- Provides beautiful, customizable views for all UI interactions
---
--- Features:
---   - Popup command line with syntax highlighting
---   - Beautiful notification system (via nvim-notify)
---   - LSP progress notifications
---   - Message history and filtering
---   - LSP hover and signature documentation styling
---   - Cmdline redirect to split/popup
---   - Scrollable LSP documentation
---   - Search count in virtual text
---
--- Keybindings:
---   <leader>sn* - Noice commands
---   <leader>snl - Show last message in popup
---   <leader>snh - Show message history in split
---   <leader>sna - Show all messages in split
---   <leader>snd - Dismiss all notifications
---   <leader>snt - Open Noice message picker
---   <S-Enter> - Redirect command output to popup (in command mode)
---   <C-b> - Scroll backward in LSP hover/signature
---
--- Command Line Formats:
---   : - Vim command (icon:  )
---   / - Search down (icon:  )
---   ? - Search up (icon:  )
---   :! - Shell command (icon: $ )
---   :lua - Lua command (icon:  )
---   :help - Help command (icon: 󰋖 )
---
--- Presets:
---   - bottom_search: Search at bottom instead of top
---   - command_palette: Command line in center of screen
---   - long_message_to_split: Long messages open in split
---   - lsp_doc_border: Add borders to LSP documentation

return {
    ----------------------------------------
    -- Noice.nvim - Modern UI
    ----------------------------------------
    {
        'folke/noice.nvim',
        event = { 'VeryLazy' }, -- Load after startup
        dependencies = {
            'MunifTanjim/nui.nvim', -- UI component library
            'rcarriga/nvim-notify', -- Notification system
        },

        ----------------------------------------
        -- Keybindings
        ----------------------------------------
        keys = {
            -- Noice command group
            { '<leader>sn', '', desc = '+noice' },

            -- Redirect command output to popup (while in command mode)
            {
                '<S-Enter>',
                function()
                    require('noice').redirect(vim.fn.getcmdline())
                end,
                mode = 'c',
                desc = 'Redirect Cmdline',
            },

            -- Show last message in popup
            {
                '<leader>snl',
                function()
                    require('noice').cmd('last')
                end,
                desc = 'Noice Last Message',
            },

            -- Show message history in split
            {
                '<leader>snh',
                function()
                    require('noice').cmd('history')
                end,
                desc = 'Noice History',
            },

            -- Show all messages in split
            {
                '<leader>sna',
                function()
                    require('noice').cmd('all')
                end,
                desc = 'Noice All',
            },

            -- Dismiss all notifications
            {
                '<leader>snd',
                function()
                    require('noice').cmd('dismiss')
                end,
                desc = 'Dismiss All',
            },

            -- Open Noice message picker
            {
                '<leader>snt',
                function()
                    require('noice').cmd('pick')
                end,
                desc = 'Noice Picker',
            },

            -- Scroll backward in LSP hover/signature
            -- Note: <C-f> is commented out (conflicts with format keybinding)
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

        ----------------------------------------
        -- Configuration
        ----------------------------------------
        opts = {
            ----------------------------------------
            -- Performance
            ----------------------------------------
            throttle = 1000 / 60, -- 60 FPS throttle

            ----------------------------------------
            -- Command Line
            ----------------------------------------
            cmdline = {
                enabled = true, -- Enable cmdline UI

                view = 'cmdline_popup', -- Popup command line (not bottom line)
                opts = {},

                -- Command line format for different command types
                format = {
                    cmdline = { pattern = '^:', icon = ' ', lang = 'vim' },
                    search_down = { kind = 'search', pattern = '^/', icon = '  ', lang = 'regex' },
                    search_up = { kind = 'search', pattern = '^%?', icon = '  ', lang = 'regex' },
                    filter = { pattern = '^:%s*!', icon = '$ ', lang = 'bash' },
                    lua = { pattern = { '^:%s*lua%s+', '^:%s*lua%s*=%s*', '^:%s*=%s*' }, icon = ' ', lang = 'lua' },
                    help = { pattern = '^:%s*he?l?p?%s+', icon = '󰋖 ' },
                    input = { view = 'cmdline_input', icon = '󰥻 ' },
                },
            },

            ----------------------------------------
            -- Messages
            ----------------------------------------
            messages = {
                enabled = true, -- Enable message UI

                view = 'notify', -- Use notify for messages
                view_error = 'notify', -- Use notify for errors
                view_warn = 'notify', -- Use notify for warnings
                view_history = 'messages', -- Use messages view for history
                view_search = 'virtualtext', -- Show search count in virtual text
            },

            ----------------------------------------
            -- Popup Menu
            ----------------------------------------
            popupmenu = {
                enabled = true, -- Enable popup menu

                backend = 'nui', -- Use nui.nvim backend
            },

            ----------------------------------------
            -- Command Redirect
            ----------------------------------------
            ---@type NoiceRouteConfig
            redirect = {
                view = 'popup', -- Show redirected commands in popup
                filter = { event = 'msg_show' },
            },

            ----------------------------------------
            -- Custom Commands
            ----------------------------------------
            ---@type table<string, NoiceCommand>
            commands = {
                -- :Noice history - Show message history in split
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

                -- :Noice last - Show last message in popup
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

                -- :Noice errors - Show all errors in popup
                errors = {
                    view = 'popup',
                    opts = { enter = true, format = 'details' },
                    filter = { error = true },
                    filter_opts = { reverse = true },
                },

                -- :Noice all - Show all messages in split
                all = {
                    view = 'split',
                    opts = { enter = true, format = 'details' },
                    filter = {},
                    filter_opts = {},
                },
            },

            ----------------------------------------
            -- Notifications
            ----------------------------------------
            notify = {
                enabled = true, -- Enable notification system

                view = 'notify', -- Use notify view
            },

            ----------------------------------------
            -- LSP Integration
            ----------------------------------------
            lsp = {
                ----------------------------------------
                -- LSP Progress
                ----------------------------------------
                progress = {
                    enabled = true, -- Show LSP progress notifications

                    -- Progress message format
                    format = {
                        ' ({data.progress.percentage}%) ',
                        { '{spinner} ', hl_group = 'NoiceLspProgressSpinner' },
                        { '{data.progress.title} ', hl_group = 'NoiceLspProgressTitle' },
                        { '{data.progress.client} ', hl_group = 'NoiceLspProgressClient' },
                    },

                    -- Done message format
                    format_done = {
                        { ' ✔ ', hl_group = 'NoiceLspProgressSpinner' },
                        { '{data.progress.title} ', hl_group = 'NoiceLspProgressTitle' },
                        { '{data.progress.client} ', hl_group = 'NoiceLspProgressClient' },
                    },

                    throttle = 1000 / 60, -- 60 FPS throttle
                    view = 'mini', -- Use mini view for progress
                },

                ----------------------------------------
                -- LSP Overrides
                ----------------------------------------
                -- Override default LSP handlers for better UI
                override = {
                    ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
                    ['vim.lsp.util.stylize_markdown'] = true,
                    ['cmp.entry.get_documentation'] = true,
                },
            },

            ----------------------------------------
            -- LSP Hover
            ----------------------------------------
            hover = {
                enabled = true, -- Enable hover documentation

                silent = false, -- Show notification when hover is not available
                view = nil, -- Use default view

                opts = {},
            },

            ----------------------------------------
            -- LSP Signature
            ----------------------------------------
            signature = {
                enabled = true, -- Enable signature help

                -- Auto-open behavior
                auto_open = {
                    enabled = true, -- Auto-open signature help

                    trigger = true, -- Auto-open on trigger characters
                    luasnip = true, -- Auto-open with LuaSnip
                    throttle = 50, -- Throttle (ms)
                },

                view = nil, -- Use default view

                opts = {},
            },

            ----------------------------------------
            -- Messages
            ----------------------------------------
            message = {
                enabled = true, -- Enable message handling

                view = 'notify', -- Use notify view

                opts = {},
            },

            ----------------------------------------
            -- Documentation
            ----------------------------------------
            documentation = {
                view = 'hover', -- Use hover view for documentation

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

            ----------------------------------------
            -- Markdown Rendering
            ----------------------------------------
            markdown = {
                -- Clickable links
                hover = {
                    ['|(%S-)|'] = vim.cmd.help, -- Vim help links
                    ['%[.-%]%((%S-)%)'] = require('noice.util').open, -- Markdown links
                },

                -- Syntax highlighting
                highlights = {
                    ['|%S-|'] = '@text.reference',
                    ['@%S+'] = '@parameter',
                    ['^%s*(Parameters:)'] = '@text.title',
                    ['^%s*(Return:)'] = '@text.title',
                    ['^%s*(See also:)'] = '@text.title',
                    ['{%S-}'] = '@parameter',
                },
            },

            ----------------------------------------
            -- Health Check
            ----------------------------------------
            health = {
                checker = true, -- Enable health checker
            },

            ----------------------------------------
            -- Message Routes
            ----------------------------------------
            -- Route specific messages to specific views
            routes = {
                -- Show file info messages in mini view (less intrusive)
                {
                    filter = {
                        event = 'msg_show',
                        any = {
                            { find = '%d+L, %d+B' }, -- "100L, 1000B" (file stats)
                            { find = '; after #%d+' }, -- Undo messages
                            { find = '; before #%d+' }, -- Redo messages
                        },
                    },
                    view = 'mini',
                },

                -- Show format messages in mini view
                {
                    filter = {
                        event = 'notify',
                        any = {
                            { find = 'formatted ' }, -- Format messages
                        },
                    },
                    view = 'mini',
                },
            },

            ----------------------------------------
            -- View Configuration
            ----------------------------------------
            ---@type NoiceConfigViews
            views = {
                -- Hover view configuration
                hover = {
                    anchor = 'auto',
                    border = {
                        style = 'rounded',
                        padding = { 0, 1 },
                    },
                    position = { row = 2, col = 0 },
                },

                -- Notify view configuration
                notify = {
                    backend = { 'notify', 'snacks' }, -- Try notify, fallback to snacks
                    fallback = 'snacks',

                    format = 'notify',

                    replace = true, -- Replace old notifications
                    merge = false, -- Don't merge notifications
                },
            },

            ----------------------------------------
            -- UI Presets
            ----------------------------------------
            ---@type NoicePresets
            presets = {
                bottom_search = true, -- Search at bottom instead of top
                command_palette = true, -- Command line in center of screen
                long_message_to_split = true, -- Long messages open in split
                lsp_doc_border = true, -- Add borders to LSP documentation
            },
        },
    },
}
