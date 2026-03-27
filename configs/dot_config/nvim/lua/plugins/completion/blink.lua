--- Blink.cmp - Rust-based completion engine
--- High-performance, feature-rich completion with fuzzy matching and LSP integration
--- Significantly faster than nvim-cmp due to Rust backend
---
--- Features:
---   - Fuzzy matching with frecency (frequency + recency) scoring
---   - Ghost text preview (AI-like inline suggestions)
---   - Signature help with parameter hints
---   - Multiple sources: LSP, snippets, path, buffer, lazydev
---   - Treesitter highlighting in completion menu
---   - Automatic documentation popup
---   - Mini.icons integration for LSP kind icons
---   - Proximity-based sorting (prefer nearby symbols)
---
--- Sources (in priority order):
---   1. lazydev - Lua API completion for Neovim development
---   2. lsp - Language Server Protocol completions
---   3. snippets - LuaSnip snippets
---   4. path - File path completions
---   5. buffer - Text from open buffers
---
--- Keybindings:
---   <C-Space> - Show/hide completion menu or documentation
---   <CR> - Accept selected completion
---   <Tab> / <S-Tab> - Navigate completions
---   <C-n> / <C-p> - Navigate completions (vim-style)
---   <Up> / <Down> - Navigate completions
---   <C-b> / <C-f> - Scroll documentation
---   <C-e> - Close completion menu
---   <C-k> - Show/hide signature help
---   <C-y> - Accept completion

return {
    ----------------------------------------
    -- Blink.cmp - Main Configuration
    ----------------------------------------
    {
        'saghen/blink.cmp',
        version = '*',  -- Use latest stable release
        event = { 'InsertEnter', 'LazyFile' },  -- Load on insert mode or file open
        build = 'cargo build --release',  -- Compile Rust backend
        dependencies = {
            'L3MON4D3/LuaSnip',  -- Snippet engine
            {
                'saghen/blink.compat',  -- Compatibility layer for nvim-cmp sources
                optional = true,
            },
        },

        ---@type blink.cmp.Config
        opts = {
            ----------------------------------------
            -- Command Line Completion
            ----------------------------------------
            -- Disable command line completion (use default vim completion)
            cmdline = { enabled = false },

            ----------------------------------------
            -- Completion Behavior
            ----------------------------------------
            completion = {
                ----------------------------------------
                -- Keyword Detection
                ----------------------------------------
                keyword = {
                    range = 'full',  -- Use full word for matching (not just prefix)
                },

                ----------------------------------------
                -- Acceptance Behavior
                ----------------------------------------
                accept = {
                    -- Don't auto-add brackets after function completions
                    auto_brackets = {
                        enabled = false,
                    },

                    -- Timeout for resolving completion details (ms)
                    resolve_timeout_ms = 50,
                },

                ----------------------------------------
                -- Trigger Behavior
                ----------------------------------------
                trigger = {
                    show_on_keyword = true,  -- Show on typing keywords

                    show_on_trigger_character = true,  -- Show on LSP trigger chars (., :, etc.)
                    show_on_blocked_trigger_characters = {},  -- Characters that block trigger

                    show_on_insert_on_trigger_character = true,  -- Show after inserting trigger char
                    show_on_accept_on_trigger_character = true,  -- Show after accepting completion
                    show_on_x_blocked_trigger_characters = {},   -- Additional blocked chars
                },

                ----------------------------------------
                -- Completion List
                ----------------------------------------
                list = {
                    max_items = 100,  -- Maximum items in completion menu

                    -- Selection behavior
                    selection = {
                        auto_insert = true,   -- Auto-insert first item
                        preselect = false,    -- Don't preselect first item
                    },

                    -- Cycling behavior (wrap around at top/bottom)
                    cycle = {
                        from_bottom = true,  -- Cycle from bottom to top
                        from_top = true,     -- Cycle from top to bottom
                    },
                },

                ----------------------------------------
                -- Completion Menu
                ----------------------------------------
                menu = {
                    enabled = true,   -- Enable completion menu
                    auto_show = true, -- Automatically show menu

                    border = 'rounded',  -- Rounded border
                    winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None',

                    scrollbar = true,  -- Show scrollbar for long lists

                    -- Drawing configuration
                    draw = {
                        -- Sources to use Treesitter highlighting for
                        treesitter = {
                            'lazydev',
                            'lsp',
                            'snippets',
                        },

                        align_to = 'label',  -- Align columns to label

                        -- Column layout: [icon] [label] [kind]
                        columns = {
                            { 'kind_icon', gap = 1 },
                            { 'label', 'label_description', gap = 1 },
                            { 'kind', gap = 1 },
                        },

                        -- Component rendering functions
                        components = {
                            -- Kind icon (e.g., 󰊕 for function)
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

                            -- Kind text (Function, Variable, etc.)
                            kind = {
                                ellipsis = false,
                                width = { fill = true },
                                highlight = function(ctx)
                                    local _, hl, _ = require('mini.icons').get('lsp', ctx.kind)
                                    return hl
                                end,
                            },

                            -- Completion label (main text)
                            label = {
                                ellipsis = false,
                                width = { fill = true },
                            },

                            -- Label description (e.g., function signature)
                            label_description = {
                                ellipsis = true,
                                width = { max = 30 },
                            },

                            -- Source name (LSP, snippet, etc.)
                            source_name = {
                                ellipsis = false,
                                width = { fill = true },
                            },
                        },
                    },
                },

                ----------------------------------------
                -- Documentation Popup
                ----------------------------------------
                documentation = {
                    auto_show = true,        -- Automatically show docs
                    auto_show_delay_ms = 100, -- Delay before showing (ms)

                    window = {
                        border = 'rounded',
                        winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None',
                    },
                },

                ----------------------------------------
                -- Ghost Text (Inline Preview)
                ----------------------------------------
                -- Shows completion preview inline (like GitHub Copilot)
                ghost_text = {
                    enabled = true,  -- Enable ghost text

                    show_with_menu = true,       -- Show when menu is visible
                    show_without_menu = true,    -- Show when menu is hidden
                    show_with_selection = true,  -- Show when item is selected
                    show_without_selection = false, -- Don't show when no selection
                },
            },

            ----------------------------------------
            -- Fuzzy Matching
            ----------------------------------------
            fuzzy = {
                -- Use Rust implementation (faster than Lua)
                implementation = 'prefer_rust_with_warning',

                -- Frecency: frequency + recency scoring
                -- Prefer items used recently and frequently
                frecency = {
                    enabled = true,
                },

                -- Proximity: prefer symbols defined nearby
                use_proximity = true,

                -- Sort order for completions
                sorts = {
                    'exact',      -- Exact matches first
                    'score',      -- Fuzzy match score
                    'sort_text',  -- LSP sort text
                    'label',      -- Alphabetical
                    'kind',       -- Group by kind
                },
            },

            ----------------------------------------
            -- Snippet Configuration
            ----------------------------------------
            snippets = {
                preset = 'luasnip',  -- Use LuaSnip as snippet engine
            },

            ----------------------------------------
            -- Appearance
            ----------------------------------------
            appearance = {
                nerd_font_variant = 'mono',  -- Use monospaced Nerd Font icons
            },

            ----------------------------------------
            -- Signature Help
            ----------------------------------------
            -- Shows function signatures and parameter hints
            signature = {
                enabled = true,  -- Enable signature help

                -- Trigger behavior
                trigger = {
                    enabled = true,

                    show_on_keyword = true,                     -- Show on typing keywords
                    show_on_trigger_character = true,           -- Show on trigger chars
                    show_on_insert = true,                      -- Show on entering insert mode
                    show_on_insert_on_trigger_character = true, -- Show after trigger char
                    show_on_accept = true,                      -- Show after accepting completion
                    show_on_accept_on_trigger_character = true, -- Show after trigger char
                },

                window = {
                    border = 'rounded',
                    winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder',
                    scrollbar = true,
                },
            },

            ----------------------------------------
            -- Completion Sources
            ----------------------------------------
            sources = {
                compat = nil,  -- Compatibility sources (nvim-cmp sources)

                -- Default source priority order
                default = { 'lazydev', 'lsp', 'snippets', 'path', 'buffer' },

                ----------------------------------------
                -- Source Providers
                ----------------------------------------
                providers = {
                    -- Lua API completion for Neovim development
                    lazydev = {
                        name = 'lazy',
                        kind = 'lazy',
                        module = 'lazydev.integrations.blink',

                        min_keyword_length = 0,  -- No minimum length
                        max_items = 5,           -- Limit items
                    },

                    -- LSP completions (primary source)
                    lsp = {
                        name = 'lsp ',
                        kind = 'lsp',
                        module = 'blink.cmp.sources.lsp',

                        min_keyword_length = 0,
                        max_items = 10,

                        -- Filter out generic "Text" kind items (low quality)
                        transform_items = function(_, items)
                            local text_kind = require('blink.cmp.types').CompletionItemKind.Text

                            return vim.tbl_filter(function(item)
                                return item.kind ~= text_kind
                            end, items)
                        end,

                        fallbacks = {},  -- No fallback sources

                        -- Override trigger characters
                        override = {
                            get_trigger_characters = function(self)
                                local trigger_characters = self:get_trigger_characters() or {}
                                -- Add newline, tab, space as triggers
                                vim.list_extend(trigger_characters, { '\n', '\t', ' ' })
                                return trigger_characters
                            end,
                        },
                    },

                    -- Snippet completions
                    snippets = {
                        name = 'snip',
                        kind = 'snippet',
                        module = 'blink.cmp.sources.snippets',

                        min_keyword_length = 0,
                        max_items = 5,

                        opts = {
                            use_show_condition = true,  -- Only show when applicable
                            show_autosnippets = true,   -- Include auto-expanding snippets
                        },
                    },

                    -- File path completions
                    path = {
                        name = 'path',
                        kind = 'path',
                        module = 'blink.cmp.sources.path',

                        min_keyword_length = 0,
                        max_items = 5,

                        opts = {
                            trailing_slash = true,               -- Add trailing slash to dirs
                            label_trailing_slash = true,         -- Show trailing slash in label
                            show_hidden_files_by_default = true, -- Show dotfiles
                            get_cwd = PickleVim.root.cwd,        -- Use project root
                        },
                    },

                    -- Buffer text completions
                    buffer = {
                        name = 'buf ',
                        kind = 'buffer',
                        module = 'blink.cmp.sources.buffer',

                        min_keyword_length = 0,
                        max_items = 5,

                        opts = {
                            get_bufnrs = vim.api.nvim_list_bufs,  -- Complete from all buffers
                        },
                    },
                },
            },

            ----------------------------------------
            -- Keybindings
            ----------------------------------------
            keymap = {
                -- Show/hide completion or documentation
                ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },

                -- Close completion menu
                ['<C-e>'] = { 'hide', 'fallback' },

                -- Accept completion
                ['<CR>'] = { 'select_and_accept', 'fallback' },

                -- Navigate completions
                ['<Tab>'] = { 'select_next', 'fallback' },
                ['<S-Tab>'] = { 'select_prev', 'fallback' },

                ['<Up>'] = { 'select_prev', 'fallback' },
                ['<Down>'] = { 'select_next', 'fallback' },
                ['<C-p>'] = { 'select_prev', 'fallback_to_mappings' },
                ['<C-n>'] = { 'select_next', 'fallback_to_mappings' },

                -- Scroll documentation
                ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
                ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },

                -- Signature help toggle
                ['<C-k>'] = { 'show_signature', 'hide_signature', 'fallback' },

                -- Accept without fallback
                ['<C-y>'] = { 'select_and_accept' },
            },
        },

        ----------------------------------------
        -- Configuration Function
        ----------------------------------------
        config = function(_, opts)
            local enabled = opts.sources.default

            ----------------------------------------
            -- Setup Compatibility Sources
            ----------------------------------------
            -- Register nvim-cmp compatible sources
            for _, source in ipairs(opts.sources.compat or {}) do
                opts.sources.providers[source] = vim.tbl_deep_extend(
                    'force',
                    { name = source, module = 'blink.compat.source' },
                    opts.sources.providers[source] or {}
                )

                -- Add to enabled sources list
                if type(enabled) == 'table' and not vim.tbl_contains(enabled, source) then
                    table.insert(enabled, source)
                end
            end

            ----------------------------------------
            -- Register Custom Kind Icons
            ----------------------------------------
            -- Set up custom completion kinds with icons
            for _, provider in pairs(opts.sources.providers or {}) do
                if provider.kind then
                    local CompletionItemKind = require('blink.cmp.types').CompletionItemKind
                    local kind_idx = #CompletionItemKind + 1

                    -- Register new kind
                    CompletionItemKind[kind_idx] = provider.kind
                    CompletionItemKind[provider.kind] = kind_idx

                    -- Transform items to use custom kind
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

    ----------------------------------------
    -- Blink.cmp - Icon Integration
    ----------------------------------------
    {
        'saghen/blink.cmp',
        opts = function(_, opts)
            -- Merge PickleVim icon definitions into blink.cmp
            opts.appearance = opts.appearance or {}
            opts.appearance.kind_icons =
                vim.tbl_extend('force', opts.appearance.kind_icons or {}, PickleVim.icons.kinds)
        end,
    },
}
