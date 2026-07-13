---@param direction string Window direction (h/j/k/l)
---@return fun(self: snacks.terminal): string | nil
local terminal_nav = function(direction)
    ---@param self snacks.terminal
    return function(self)
        return self:is_floating() and '<c-' .. direction .. '>'
            or vim.schedule(function()
                vim.cmd.wincmd(direction)
            end)
    end
end

return {
    {
        'folke/snacks.nvim',

        opts = {
            styles = {
                -- Global solid borders: 1-char padding that matches the float background
                float = { border = 'solid' },
                input = { border = 'solid' },
                -- Notifications use a line border so the per-level diagnostic colors
                -- (info/warn/error) render as a visible colored line instead of blending in
                notification = { border = 'rounded' },
                notification_history = { border = 'rounded' },
                snacks_image = {
                    relative = 'cursor',
                    border = 'solid',
                    focusable = false,
                    backdrop = false,
                    row = 1,
                    column = 1,
                },
            },

            animate = {
                enabled = true,
                duration = 20,
                easing = 'linear',
                fps = 60,
            },

            bigfile = {
                enabled = true,
                notify = true,

                size = 1.5 * 1024 * 1024,
                line_length = 10000,

                ---@param ctx { buf: number, ft: string }
                setup = function(ctx)
                    if vim.fn.exists(':NoMatchParen') ~= 0 then
                        vim.cmd([[NoMatchParen]])
                    end

                    Snacks.util.wo(0, {
                        foldmethod = 'manual',
                        statuscolumn = '',
                        conceallevel = 0,
                    })

                    vim.b.minianimate_disable = true

                    -- Re-enable syntax highlighting without other heavy features
                    vim.schedule(function()
                        if vim.api.nvim_buf_is_valid(ctx.buf) then
                            vim.bo[ctx.buf].syntax = ctx.ft
                        end
                    end)
                end,
            },

            dashboard = {
                preset = {
                    pick = function(cmd, opts)
                        return PickleVim.pick(cmd, opts)()
                    end,

                    header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],

                    ---@type snacks.dashboard.Item[]
                    keys = {
                        {
                            icon = ' ',
                            key = 'f',
                            desc = 'Find File',
                            action = ":lua Snacks.dashboard.pick('files')",
                        },
                        {
                            icon = ' ',
                            key = 'g',
                            desc = 'Find Text',
                            action = ":lua Snacks.dashboard.pick('live_grep')",
                        },
                        { icon = '󰒲 ', key = 'l', desc = 'Lazy', action = ':Lazy' },
                        { icon = ' ', key = 'm', desc = 'Mason', action = ':Mason' },
                        {
                            icon = ' ',
                            key = 'c',
                            desc = 'Config',
                            action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })",
                        },
                        { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
                    },
                },
            },

            dim = {
                enabled = true,

                scope = {
                    min_size = 5,
                    max_size = 20,
                    siblings = true,
                },

                animate = {
                    enabled = true,
                    easing = 'outQuad',
                    duration = {
                        step = 20,
                        total = 300,
                    },
                },

                ---@param buf number Buffer number
                ---@return boolean should_dim Whether to dim this buffer
                filter = function(buf)
                    return vim.g.snacks_dim ~= false
                        and vim.b[buf].snacks_dim ~= false
                        and vim.bo[buf].buftype == ''
                end,
            },

            image = {
                enabled = false,

                doc = {
                    enabled = true,
                    inline = true,
                    float = false,
                    max_width = 40,
                    max_height = 40,
                    conceal = true,
                },
            },

            -- Using kdheepak/lazygit.nvim instead
            lazygit = {
                enabled = false,
            },

            notifier = {
                enabled = true,
                timeout = 5000,

                width = {
                    min = 50,
                    max = 0.4,
                },

                height = {
                    min = 1,
                    max = 0.6,
                },

                margin = {
                    top = 0,
                    right = 1,
                    bottom = 0,
                },

                padding = true,

                sort = {
                    'level',
                    'added',
                },

                level = vim.log.levels.TRACE,

                icons = {
                    error = PickleVim.icons.diagnostics.error,
                    warn = PickleVim.icons.diagnostics.warn,
                    hint = PickleVim.icons.diagnostics.hint,
                    info = PickleVim.icons.diagnostics.info,
                    debug = '',
                    trace = '✎',
                },

                style = 'fancy',
                date_format = '%I:%M:%S %p',
                more_format = '  %d lines ',
                refresh = 50,
            },

            scroll = {
                animate = {
                    easing = 'linear',
                    duration = { step = 15, total = 225 },
                },

                animate_repeat = {
                    easing = 'linear',
                    delay = 100,
                    duration = { step = 5, total = 50 },
                },

                ---@param buf number Buffer number
                ---@return boolean should_scroll Whether to smooth scroll this buffer
                filter = function(buf)
                    return vim.g.snacks_scroll ~= false
                        and vim.b[buf].snacks_scroll ~= false
                        and vim.bo[buf].buftype ~= 'terminal'
                end,
            },

            terminal = {
                win = {
                    keys = {
                        nav_h = { '<C-h>', terminal_nav('h'), desc = 'Go to Left Window', expr = true, mode = 't' },
                        nav_j = { '<C-j>', terminal_nav('j'), desc = 'Go to Lower Window', expr = true, mode = 't' },
                        nav_k = { '<C-k>', terminal_nav('k'), desc = 'Go to Upper Window', expr = true, mode = 't' },
                        nav_l = { '<C-l>', terminal_nav('l'), desc = 'Go to Right Window', expr = true, mode = 't' },
                    },
                },
            },
        },
    },
}
