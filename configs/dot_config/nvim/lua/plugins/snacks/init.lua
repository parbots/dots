--- Snacks.nvim - Core snacks configuration
--- Snacks provides many utility features in one plugin
--- This file configures core snacks: animate, bigfile, dashboard, dim, terminal, notifier
---
--- Features:
---   - animate: Smooth animations for window/cursor movement (60 FPS)
---   - bigfile: Optimize performance for large files (>1.5MB)
---   - dashboard: Beautiful startup screen with ASCII art
---   - dim: Dim inactive code scopes for focus
---   - terminal: Floating terminal with window navigation
---   - notifier: Notification system (alternative to nvim-notify)
---   - scroll: Smooth scrolling animations
---
--- Dashboard Keybindings:
---   f - Find files
---   g - Live grep (find text)
---   l - Open Lazy
---   m - Open Mason
---   c - Config files
---   q - Quit
---
--- Terminal Navigation:
---   <C-h/j/k/l> - Navigate between windows (works in terminal mode)
---
--- Bigfile Threshold:
---   1.5MB or 10,000 line length

--- Helper function for terminal window navigation
---@param direction string Window direction (h/j/k/l)
---@return fun(self: snacks.terminal): string | nil
local terminal_nav = function(direction)
    ---@param self snacks.terminal
    return function(self)
        -- If floating terminal, send Ctrl+direction
        return self:is_floating() and '<c-' .. direction .. '>'
            -- Otherwise, navigate windows
            or vim.schedule(function()
                vim.cmd.wincmd(direction)
            end)
    end
end

return {
    ----------------------------------------
    -- Snacks.nvim - Core Features
    ----------------------------------------
    {
        'folke/snacks.nvim',

        ----------------------------------------
        -- Configuration
        ----------------------------------------
        opts = {
            ----------------------------------------
            -- Styles
            ----------------------------------------
            styles = {
                -- Image preview style (used by image rendering)
                snacks_image = {
                    relative = 'cursor', -- Position relative to cursor
                    border = 'rounded', -- Rounded border
                    focusable = false, -- Not focusable
                    backdrop = false, -- No backdrop
                    row = 1, -- Row offset
                    column = 1, -- Column offset
                },
            },

            ----------------------------------------
            -- Animate - Smooth Animations
            ----------------------------------------
            animate = {
                enabled = true, -- Enable animations

                duration = 20, -- Animation duration (ms)
                easing = 'linear', -- Linear easing
                fps = 60, -- 60 FPS animations
            },

            ----------------------------------------
            -- Bigfile - Large File Optimization
            ----------------------------------------
            bigfile = {
                enabled = true, -- Enable bigfile detection

                notify = true, -- Notify when bigfile detected

                -- Thresholds for bigfile detection
                size = 1.5 * 1024 * 1024, -- 1.5MB file size
                line_length = 10000, -- 10,000 character line length

                -- Setup function called for bigfiles
                ---@param ctx { buf: number, ft: string }
                setup = function(ctx)
                    -- Disable matchparen for performance
                    if vim.fn.exists(':NoMatchParen') ~= 0 then
                        vim.cmd([[NoMatchParen]])
                    end

                    -- Optimize window options for performance
                    Snacks.util.wo(0, {
                        foldmethod = 'manual', -- Manual folding (faster)
                        statuscolumn = '', -- No status column
                        conceallevel = 0, -- No concealing
                    })

                    -- Disable animations
                    vim.b.minianimate_disable = true

                    -- Re-enable syntax highlighting (without other heavy features)
                    vim.schedule(function()
                        if vim.api.nvim_buf_is_valid(ctx.buf) then
                            vim.bo[ctx.buf].syntax = ctx.ft
                        end
                    end)
                end,
            },

            ----------------------------------------
            -- Dashboard - Startup Screen
            ----------------------------------------
            dashboard = {
                preset = {
                    -- Custom pick function (uses PickleVim.pick)
                    pick = function(cmd, opts)
                        return PickleVim.pick(cmd, opts)()
                    end,

                    -- ASCII art header
                    header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],

                    -- Dashboard menu items
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

            ----------------------------------------
            -- Dim - Scope Dimming
            ----------------------------------------
            -- Dims code outside current scope for better focus
            dim = {
                enabled = true, -- Enable dimming

                -- Scope detection (Treesitter-based)
                scope = {
                    min_size = 5, -- Minimum lines to consider as scope
                    max_size = 20, -- Maximum lines to highlight

                    siblings = true, -- Include sibling nodes in scope
                },

                -- Animation for dimming
                animate = {
                    enabled = true, -- Enable animated transitions

                    easing = 'outQuad', -- Ease-out quadratic easing
                    duration = {
                        step = 20, -- Step duration (ms)
                        total = 300, -- Total animation duration (ms)
                    },
                },

                -- Filter function: when to apply dimming
                ---@param buf number Buffer number
                ---@return boolean should_dim Whether to dim this buffer
                filter = function(buf)
                    return vim.g.snacks_dim ~= false -- Global enable
                        and vim.b[buf].snacks_dim ~= false -- Buffer-local enable
                        and vim.bo[buf].buftype == '' -- Normal buffers only
                end,
            },

            ----------------------------------------
            -- Image - Image Preview (Disabled)
            ----------------------------------------
            image = {
                enabled = false, -- Disabled (experimental feature)

                -- Documentation image rendering
                doc = {
                    enabled = true, -- Would enable if image.enabled = true

                    inline = true, -- Show inline
                    float = false, -- Don't show in float

                    max_width = 40, -- Max width
                    max_height = 40, -- Max height

                    conceal = true, -- Conceal markdown image syntax
                },
            },

            ----------------------------------------
            -- LazyGit (Disabled)
            ----------------------------------------
            -- Using kdheepak/lazygit.nvim instead
            lazygit = {
                enabled = false,
            },

            ----------------------------------------
            -- Notifier - Notification System
            ----------------------------------------
            notifier = {
                enabled = true, -- Enable notifier

                timeout = 5000, -- Auto-dismiss after 5 seconds

                -- Width constraints
                width = {
                    min = 50, -- Minimum width
                    max = 0.4, -- Maximum width (40% of screen)
                },

                -- Height constraints
                height = {
                    min = 1, -- Minimum height
                    max = 0.6, -- Maximum height (60% of screen)
                },

                -- Positioning
                margin = {
                    top = 0, -- Top margin
                    right = 1, -- Right margin
                    bottom = 0, -- Bottom margin
                },

                padding = true, -- Add padding

                -- Sort order
                sort = {
                    'level', -- Sort by log level first
                    'added', -- Then by time added
                },

                level = vim.log.levels.TRACE, -- Show all log levels

                -- Icons by log level
                icons = {
                    error = PickleVim.icons.diagnostics.error,
                    warn = PickleVim.icons.diagnostics.warn,
                    hint = PickleVim.icons.diagnostics.hint,
                    info = PickleVim.icons.diagnostics.info,
                    debug = '',
                    trace = '✎',
                },

                style = 'fancy', -- Fancy style with icons and colors

                date_format = '%I:%M:%S %p', -- Time format (12-hour with AM/PM)

                more_format = '  %d lines ', -- Format for "X more lines"

                refresh = 50, -- Refresh rate (ms)
            },

            ----------------------------------------
            -- Scroll - Smooth Scrolling
            ----------------------------------------
            scroll = {
                -- Normal scroll animation
                animate = {
                    easing = 'linear', -- Linear easing
                    duration = { step = 15, total = 225 }, -- 225ms total
                },

                -- Repeat scroll animation (when holding key)
                animate_repeat = {
                    easing = 'linear', -- Linear easing
                    delay = 100, -- Delay before repeat (ms)
                    duration = { step = 5, total = 50 }, -- 50ms total (faster)
                },

                -- Filter function: when to enable smooth scrolling
                ---@param buf number Buffer number
                ---@return boolean should_scroll Whether to smooth scroll this buffer
                filter = function(buf)
                    return vim.g.snacks_scroll ~= false -- Global enable
                        and vim.b[buf].snacks_scroll ~= false -- Buffer-local enable
                        and vim.bo[buf].buftype ~= 'terminal' -- Not in terminal
                end,
            },

            ----------------------------------------
            -- Terminal - Floating Terminal
            ----------------------------------------
            terminal = {
                win = {
                    -- Terminal window keybindings
                    keys = {
                        -- Navigate to adjacent windows from terminal
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
