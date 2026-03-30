return {
    {
        'echasnovski/mini.icons',
        lazy = true,

        -- Mock nvim-web-devicons for plugins expecting it
        init = function()
            package.preload['nvim-web-devicons'] = function()
                require('mini.icons').mock_nvim_web_devicons()
                return package.loaded['nvim-web-devicons']
            end
        end,
    },

    {
        'MunifTanjim/nui.nvim',
        lazy = true,
    },

    {
        'rcarriga/nvim-notify',
        lazy = true,

        opts = {
            background_colour = 'NotifyBackground',

            fps = 60,

            icons = {
                DEBUG = '',
                ERROR = PickleVim.icons.diagnostics.error,
                INFO = PickleVim.icons.diagnostics.info,
                TRACE = '✎',
                WARN = PickleVim.icons.diagnostics.warn,
            },

            level = vim.log.levels.TRACE,

            minimum_width = 50,

            render = 'default',

            stages = 'fade_in_slide_out',

            time_formats = {
                notification = '%T',
                notification_history = '%FT%T',
            },

            timeout = 3500,

            top_down = true,
        },

        config = function(_, opts)
            require('notify').setup(opts)
        end,
    },
}
