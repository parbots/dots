return {
    {
        'echasnovski/mini.ai',
        event = { 'LazyFile' },

        opts = function()
            local ai = require('mini.ai')

            return {
                n_lines = 500,

                custom_textobjects = {
                    o = ai.gen_spec.treesitter({
                        a = { '@block.outer', '@conditional.outer', '@loop.outer' },
                        i = { '@block.inner', '@conditional.inner', '@loop.inner' },
                    }),

                    f = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),

                    c = ai.gen_spec.treesitter({ a = '@class.outer', i = '@class.inner' }),

                    t = { '<([%p%w]-)%f[^<%w][^<>]->.-</%1>', '^<.->().*()</[^/]->$' },

                    d = { '%f[%d]%d+' },

                    e = {
                        {
                            '%u[%l%d]+%f[^%l%d]',
                            '%f[%S][%l%d]+%f[^%l%d]',
                            '%f[%P][%l%d]+%f[^%l%d]',
                            '^[%l%d]+%f[^%l%d]',
                        },
                        '^().*()$',
                    },

                    g = PickleVim.mini.ai_buffer,

                    u = ai.gen_spec.function_call(),

                    U = ai.gen_spec.function_call({ name_pattern = '[%w_]' }),
                },
            }
        end,

        config = function(_, opts)
            require('mini.ai').setup(opts)

            PickleVim.on_load('which-key.nvim', function()
                vim.schedule(function()
                    PickleVim.mini.ai_whichkey(opts)
                end)
            end)
        end,
    },

    {
        'echasnovski/mini.pairs',
        event = { 'LazyFile' },

        opts = {
            modes = {
                insert = true,
                command = true,
                terminal = false,
            },

            -- Skip autopair when the next char is a word char, bracket, quote, dot,
            -- backtick, or dollar sign (avoids doubling when cursor is adjacent to existing text)
            skip_next = [=[[%w%%%'%[%"%.%`%$]]=],

            skip_ts = { 'string' },

            skip_unbalanced = true,

            markdown = true,
        },

        config = function(_, opts)
            PickleVim.mini.pairs(opts)
        end,
    },

    {
        'echasnovski/mini.surround',
        event = { 'LazyFile' },

        keys = function(_, keys)
            local opts = PickleVim.plugin.opts('mini.surround')

            local mappings = {
                { opts.mappings.add, desc = 'Add Surrounding', mode = { 'n', 'v' } },
                { opts.mappings.delete, desc = 'Delete Surrounding' },
                { opts.mappings.find, desc = 'Find Right Surrounding' },
                { opts.mappings.find_left, desc = 'Find Left Surrounding' },
                { opts.mappings.highlight, desc = 'Highlight Surrounding' },
                { opts.mappings.replace, desc = 'Replace Surrounding' },
                { opts.mappings.update_n_lines, desc = 'Update `MiniSurround.config.n_lines`' },
            }

            mappings = vim.tbl_filter(function(m)
                return m[1] and #m[1] > 0
            end, mappings)

            return vim.list_extend(mappings, keys)
        end,

        opts = {
            mappings = {
                add = 'gsa',
                delete = 'gsd',
                find = 'gsf',
                find_left = 'gsF',
                highlight = 'gsh',
                replace = 'gsr',
                update_n_lines = 'gsn',

                suffix_last = 'l',
                suffix_next = 'n',
            },
        },
    },
}
