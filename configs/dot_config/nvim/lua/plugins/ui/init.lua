--- UI utility plugins
--- Core dependencies for UI components and notifications
---
--- Plugins:
---   - mini.icons: Icon provider (mocks nvim-web-devicons)
---   - nui.nvim: UI component library (used by Noice)
---   - nvim-notify: Notification system with animations
---
--- mini.icons:
---   Provides icons for LSP kinds, file types, etc.
---   Mocks nvim-web-devicons API for compatibility
---
--- nvim-notify:
---   Beautiful notification system with:
---   - Fade in/slide out animations
---   - 60 FPS rendering
---   - Auto-dismiss after timeout
---   - Notification history
---   - Top-down positioning

return {
    ----------------------------------------
    -- mini.icons - Icon Provider
    ----------------------------------------
    {
        'echasnovski/mini.icons',
        lazy = true,  -- Loaded by other plugins as needed

        ----------------------------------------
        -- Compatibility Layer
        ----------------------------------------
        -- Mock nvim-web-devicons for plugins expecting it
        init = function()
            package.preload['nvim-web-devicons'] = function()
                require('mini.icons').mock_nvim_web_devicons()
                return package.loaded['nvim-web-devicons']
            end
        end,
    },

    ----------------------------------------
    -- nui.nvim - UI Component Library
    ----------------------------------------
    {
        'MunifTanjim/nui.nvim',
        lazy = true,  -- Loaded by Noice and other UI plugins
    },

    ----------------------------------------
    -- nvim-notify - Notification System
    ----------------------------------------
    {
        'rcarriga/nvim-notify',
        lazy = true,  -- Loaded by Noice

        ----------------------------------------
        -- Configuration
        ----------------------------------------
        opts = {
            ----------------------------------------
            -- Appearance
            ----------------------------------------
            background_colour = 'NotifyBackground',  -- Background color

            fps = 60,  -- Animation frame rate

            -- Notification icons by log level
            icons = {
                DEBUG = '',                              -- Debug icon
                ERROR = PickleVim.icons.diagnostics.error, -- Error icon ( )
                INFO = PickleVim.icons.diagnostics.info,   -- Info icon ( )
                TRACE = '✎',                              -- Trace icon
                WARN = PickleVim.icons.diagnostics.warn,   -- Warning icon ( )
            },

            ----------------------------------------
            -- Behavior
            ----------------------------------------
            level = vim.log.levels.TRACE,  -- Show all log levels

            minimum_width = 50,  -- Minimum notification width

            render = 'default',  -- Default render style

            stages = 'fade_in_slide_out',  -- Animation: fade in, slide out

            ----------------------------------------
            -- Time Formatting
            ----------------------------------------
            time_formats = {
                notification = '%T',         -- Time format in notification (HH:MM:SS)
                notification_history = '%FT%T',  -- History format (YYYY-MM-DDTHH:MM:SS)
            },

            ----------------------------------------
            -- Timing
            ----------------------------------------
            timeout = 3500,  -- Auto-dismiss after 3.5 seconds

            ----------------------------------------
            -- Positioning
            ----------------------------------------
            top_down = true,  -- Stack notifications top to bottom
        },

        ----------------------------------------
        -- Setup
        ----------------------------------------
        config = function(_, opts)
            require('notify').setup(opts)
        end,
    },
}
