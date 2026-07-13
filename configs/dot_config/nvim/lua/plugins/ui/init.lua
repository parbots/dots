return {
    {
        'nvim-mini/mini.icons',
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
}
