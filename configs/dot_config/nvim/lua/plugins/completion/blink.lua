return {
    {
        'saghen/blink.cmp',
        version = '*',
        event = { 'InsertEnter', 'LazyFile' },
        build = 'cargo build --release',
        dependencies = {
            'L3MON4D3/LuaSnip',
            {
                'saghen/blink.compat',
                optional = true,
            },
        },

        ---@type blink.cmp.Config
        opts = {
            cmdline = { enabled = false },

            completion = {
                keyword = {
                    range = 'full',
                },

                accept = {
                    auto_brackets = {
                        enabled = false,
                    },

                    resolve_timeout_ms = 50,
                },

                trigger = {
                    show_on_keyword = true,

                    show_on_trigger_character = true,
                    show_on_blocked_trigger_characters = {},

                    show_on_insert_on_trigger_character = true,
                    show_on_accept_on_trigger_character = true,
                    show_on_x_blocked_trigger_characters = {},
                },

                list = {
                    max_items = 100,

                    selection = {
                        auto_insert = true,
                        preselect = false,
                    },

                    cycle = {
                        from_bottom = true,
                        from_top = true,
                    },
                },

                menu = {
                    enabled = true,
                    auto_show = true,

                    border = 'rounded',
                    winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None',

                    scrollbar = true,

                    draw = {
                        treesitter = {
                            'lazydev',
                            'lsp',
                            'snippets',
                        },

                        align_to = 'label',

                        columns = {
                            { 'kind_icon', gap = 1 },
                            { 'label', 'label_description', gap = 1 },
                            { 'kind', gap = 1 },
                        },

                        components = {
                            kind_icon = {
                                ellipsis = false,
                                text = function(ctx)
                                    local kind_icon, _, _ = require('mini.icons').get('lsp', ctx.kind)
                                    return kind_icon .. ctx.icon_gap
                                end,
                                highlight = function(ctx)
                                    local _, hl, _ = require('mini.icons').get('lsp', ctx.kind)
                                    return hl
                                end,
                                width = { max = 2 },
                            },

                            kind = {
                                ellipsis = false,
                                width = { fill = true },
                                highlight = function(ctx)
                                    local _, hl, _ = require('mini.icons').get('lsp', ctx.kind)
                                    return hl
                                end,
                            },

                            label = {
                                ellipsis = false,
                                width = { fill = true },
                            },

                            label_description = {
                                ellipsis = true,
                                width = { max = 30 },
                            },

                            source_name = {
                                ellipsis = false,
                                width = { fill = true },
                            },
                        },
                    },
                },

                documentation = {
                    auto_show = true,
                    auto_show_delay_ms = 100,

                    window = {
                        border = 'rounded',
                        winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None',
                    },
                },

                ghost_text = {
                    enabled = true,

                    show_with_menu = true,
                    show_without_menu = true,
                    show_with_selection = true,
                    show_without_selection = false,
                },
            },

            fuzzy = {
                implementation = 'prefer_rust_with_warning',

                frecency = {
                    enabled = true,
                },

                use_proximity = true,

                sorts = {
                    'exact',
                    'score',
                    'sort_text',
                    'label',
                    'kind',
                },
            },

            snippets = {
                preset = 'luasnip',
            },

            appearance = {
                nerd_font_variant = 'mono',
            },

            signature = {
                enabled = true,

                trigger = {
                    enabled = true,

                    show_on_keyword = true,
                    show_on_trigger_character = true,
                    show_on_insert = true,
                    show_on_insert_on_trigger_character = true,
                    show_on_accept = true,
                    show_on_accept_on_trigger_character = true,
                },

                window = {
                    border = 'rounded',
                    winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder',
                    scrollbar = true,
                },
            },

            sources = {
                compat = nil,

                default = { 'lazydev', 'lsp', 'snippets', 'path', 'buffer' },

                providers = {
                    lazydev = {
                        name = 'lazy',
                        kind = 'lazy',
                        module = 'lazydev.integrations.blink',

                        min_keyword_length = 0,
                        max_items = 5,
                    },

                    lsp = {
                        name = 'lsp ',
                        kind = 'lsp',
                        module = 'blink.cmp.sources.lsp',

                        min_keyword_length = 0,
                        max_items = 10,

                        -- Drop generic "Text" kind items: they're low-signal noise from servers
                        -- that index every word in the buffer.
                        transform_items = function(_, items)
                            local text_kind = require('blink.cmp.types').CompletionItemKind.Text

                            return vim.tbl_filter(function(item)
                                return item.kind ~= text_kind
                            end, items)
                        end,

                        fallbacks = {},

                        override = {
                            get_trigger_characters = function(self)
                                local trigger_characters = self:get_trigger_characters() or {}
                                vim.list_extend(trigger_characters, { '\n', '\t', ' ' })
                                return trigger_characters
                            end,
                        },
                    },

                    snippets = {
                        name = 'snip',
                        kind = 'snippet',
                        module = 'blink.cmp.sources.snippets',

                        min_keyword_length = 0,
                        max_items = 5,

                        opts = {
                            use_show_condition = true,
                            show_autosnippets = true,
                        },
                    },

                    path = {
                        name = 'path',
                        kind = 'path',
                        module = 'blink.cmp.sources.path',

                        min_keyword_length = 0,
                        max_items = 5,

                        opts = {
                            trailing_slash = true,
                            label_trailing_slash = true,
                            show_hidden_files_by_default = true,
                            get_cwd = PickleVim.root.cwd,
                        },
                    },

                    buffer = {
                        name = 'buf ',
                        kind = 'buffer',
                        module = 'blink.cmp.sources.buffer',

                        min_keyword_length = 0,
                        max_items = 5,

                        opts = {
                            get_bufnrs = vim.api.nvim_list_bufs,
                        },
                    },
                },
            },

            keymap = {
                ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },

                ['<C-e>'] = { 'hide', 'fallback' },

                ['<CR>'] = { 'select_and_accept', 'fallback' },

                ['<Tab>'] = { 'select_next', 'fallback' },
                ['<S-Tab>'] = { 'select_prev', 'fallback' },

                ['<Up>'] = { 'select_prev', 'fallback' },
                ['<Down>'] = { 'select_next', 'fallback' },
                ['<C-p>'] = { 'select_prev', 'fallback_to_mappings' },
                ['<C-n>'] = { 'select_next', 'fallback_to_mappings' },

                ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
                ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },

                ['<C-k>'] = { 'show_signature', 'hide_signature', 'fallback' },

                ['<C-y>'] = { 'select_and_accept' },
            },
        },

        config = function(_, opts)
            local enabled = opts.sources.default

            for _, source in ipairs(opts.sources.compat or {}) do
                opts.sources.providers[source] = vim.tbl_deep_extend(
                    'force',
                    { name = source, module = 'blink.compat.source' },
                    opts.sources.providers[source] or {}
                )

                if type(enabled) == 'table' and not vim.tbl_contains(enabled, source) then
                    table.insert(enabled, source)
                end
            end

            for _, provider in pairs(opts.sources.providers or {}) do
                if provider.kind then
                    local CompletionItemKind = require('blink.cmp.types').CompletionItemKind
                    local kind_idx = #CompletionItemKind + 1

                    CompletionItemKind[kind_idx] = provider.kind
                    CompletionItemKind[provider.kind] = kind_idx

                    local transform_items = provider.transform_items
                    provider.transform_items = function(ctx, items)
                        items = transform_items and transform_items(ctx, items) or items
                        for _, item in ipairs(items) do
                            item.kind = kind_idx or item.kind
                            item.kind_icon = PickleVim.icons.kinds[item.kind_name] or item.kind_icon or nil
                        end

                        return items
                    end

                    provider.kind = nil
                end
            end

            require('blink.cmp').setup(opts)
        end,
    },

    {
        'saghen/blink.cmp',
        opts = function(_, opts)
            opts.appearance = opts.appearance or {}
            opts.appearance.kind_icons =
                vim.tbl_extend('force', opts.appearance.kind_icons or {}, PickleVim.icons.kinds)
        end,
    },
}
