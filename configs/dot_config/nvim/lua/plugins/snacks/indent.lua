return {
    {
        'folke/snacks.nvim',
        opts = {
            indent = {
                enabled = true,

                indent = {
                    enabled = true,
                    priority = 1,

                    char = '│',

                    only_scope = false,
                    only_current = false,

                    hl = 'SnacksIndent',
                },

                animate = {
                    enabled = true,

                    style = 'up_down',
                    easing = 'linear',
                    duration = {
                        step = 25,
                        total = 500,
                    },
                },

                scope = {
                    enabled = true,
                    priority = 200,

                    char = '│',

                    underline = false,
                    only_current = false,

                    hl = 'SnacksIndentScope',
                },

                chunk = {
                    enabled = true,
                    priority = 200,

                    only_current = false,

                    hl = 'SnacksIndentChunk',

                    char = {
                        corner_top = '╭',
                        corner_bottom = '╰',
                        horizontal = '─',
                        vertical = '│',
                        -- arrow = '▶',
                        arrow = '─',
                    },
                },

                filter = function(buf)
                    return vim.g.snacks_indent ~= false
                        and vim.b[buf].snacks_indent ~= false
                        and vim.bo[buf].buftype == ''
                end,
            },

            scope = {
                enabled = true,
                priority = 200,

                min_size = 2,
                max_size = nil,

                cursor = false,
                edge = true,
                siblings = false,

                filter = function(buf)
                    return vim.bo[buf].buftype == ''
                        and vim.b[buf].snacks_scope ~= false
                        and vim.g.snacks_scope ~= false
                end,

                debounce = 50,

                treesitter = {
                    enabled = true,

                    injections = true,

                    blocks = {
                        enabled = false,

                        'function_declaration',
                        'function_definition',
                        'method_declaration',
                        'method_definition',
                        'class_declaration',
                        'class_definition',
                        'do_statement',
                        'while_statement',
                        'repeat_statement',
                        'if_statement',
                        'for_statement',
                    },

                    field_blocks = {
                        'local_declaration',
                    },
                },

                keys = {
                    ---@type table<string, snacks.scope.TextObject | { desc?: string }>
                    textobject = {
                        ii = {
                            min_size = 2, -- minimum size of the scope
                            edge = true, -- inner scope
                            cursor = false,
                            treesitter = {
                                blocks = {
                                    enabled = false,
                                },
                            },
                            desc = 'inner scope',
                        },
                        ai = {
                            cursor = false,
                            min_size = 2, -- minimum size of the scope
                            treesitter = {
                                blocks = {
                                    enabled = false,
                                },
                            },
                            desc = 'full scope',
                        },
                    },

                    ---@type table<string, snacks.scope.Jump | { desc?: string }>
                    jump = {
                        ['[i'] = {
                            min_size = 1, -- allow single line scopes
                            bottom = false,
                            cursor = false,
                            edge = true,
                            treesitter = {
                                blocks = {
                                    enabled = true,
                                },
                            },
                            desc = 'jump to top edge of scope',
                        },
                        [']i'] = {
                            min_size = 1, -- allow single line scopes
                            bottom = true,
                            cursor = false,
                            edge = true,
                            treesitter = {
                                blocks = {
                                    enabled = false,
                                },
                            },
                            desc = 'jump to bottom edge of scope',
                        },
                    },
                },
            },
        },
    },
}
