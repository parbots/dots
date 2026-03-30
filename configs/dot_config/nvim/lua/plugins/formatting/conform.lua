return {
    {
        'stevearc/conform.nvim',
        dependencies = { 'mason.nvim' },
        event = { 'LazyFile' },
        cmd = { 'ConformInfo' },

        keys = {
            {
                '<c-f>',
                '<CMD>PickleFormat<CR>',
                mode = { 'n', 'i', 'v' },
                desc = 'Format File',
            },

            {
                '<leader>cf',
                '<CMD>PickleFormatInfo<CR>',
                mode = { 'n' },
                desc = 'Format Info',
            },
        },

        init = function()
            PickleVim.on_very_lazy(function()
                PickleVim.formatting.register({
                    name = 'conform.nvim',
                    priority = 100,
                    primary = true,

                    ---@param buf number Buffer number to format
                    ---@return boolean success Whether formatting succeeded
                    format = function(buf)
                        return require('conform').format({ bufnr = buf }) or false
                    end,

                    ---@param buf number Buffer number
                    ---@return string[] sources List of formatter names
                    sources = function(buf)
                        local ret = require('conform').list_formatters(buf)

                        ---@param v conform.FormatterInfo
                        return vim.tbl_map(function(v)
                            return v.name
                        end, ret)
                    end,
                })
            end)
        end,

        opts = {
            -- Disabled: handled by PickleVim.formatting system instead
            format_on_save = nil,
            format_after_save = nil,

            default_format_opts = {
                timeout_ms = 3000,
                async = false,
                quiet = false,
                lsp_format = 'fallback',
            },

            formatters_by_ft = PickleVim.formatting.list_by_ft,
            formatters = PickleVim.formatting.list,
        },
    },
}
