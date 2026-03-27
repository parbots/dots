--- Mini.nvim plugins configuration
--- Collection of minimal, focused plugins from echasnovski/mini.nvim
---
--- Plugins:
---   - mini.ai: Enhanced text objects with Treesitter integration
---   - mini.pairs: Smart auto-pairing of brackets, quotes, etc.
---   - mini.surround: Add/delete/replace surrounding characters
---
--- Text Objects (mini.ai):
---   o - Code block (function body, conditional, loop)
---   f - Function (around/inside)
---   c - Class (around/inside)
---   t - HTML/XML tags
---   d - Digits
---   e - Word with case (camelCase, PascalCase)
---   g - Entire buffer
---   u - Function call (Usage)
---   U - Function call (without dot in name)
---
---   Usage: v/d/c + a/i + object
---   Examples:
---     vaf - Select around function
---     dif - Delete inside function
---     cit - Change inside tag
---     vag - Select entire buffer
---
--- Auto-pairs (mini.pairs):
---   ( ) [ ] { } " " ' ' ` `
---   Smart skipping over closing pairs
---   Treesitter-aware (doesn't pair inside strings)
---   Markdown-aware
---
--- Surround (mini.surround):
---   gsa - Add surrounding (normal/visual)
---   gsd - Delete surrounding
---   gsf - Find surrounding (right)
---   gsF - Find surrounding (left)
---   gsh - Highlight surrounding
---   gsr - Replace surrounding
---   gsn - Update n_lines
---
---   Examples:
---     gsaiw" - Surround word with "
---     gsd" - Delete surrounding "
---     gsr"' - Replace " with '

return {
    ----------------------------------------
    -- mini.ai - Enhanced Text Objects
    ----------------------------------------
    {
        'echasnovski/mini.ai',
        event = { 'LazyFile' },

        opts = function()
            local ai = require('mini.ai')

            return {
                -- Search in 500 lines around cursor for text objects
                n_lines = 500,

                ----------------------------------------
                -- Custom Text Objects
                ----------------------------------------
                custom_textobjects = {
                    -- o: Code block (conditional, loop, function body)
                    -- Uses Treesitter to detect blocks
                    o = ai.gen_spec.treesitter({
                        a = { '@block.outer', '@conditional.outer', '@loop.outer' },
                        i = { '@block.inner', '@conditional.inner', '@loop.inner' },
                    }),

                    -- f: Function
                    -- vaf = select around function, dif = delete inside function
                    f = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),

                    -- c: Class
                    -- vac = select around class, dic = delete inside class
                    c = ai.gen_spec.treesitter({ a = '@class.outer', i = '@class.inner' }),

                    -- t: HTML/XML tags
                    -- vit = select inside tag, dat = delete around tag
                    t = { '<([%p%w]-)%f[^<%w][^<>]->.-</%1>', '^<.->().*()</[^/]->$' },

                    -- d: Digits
                    -- vid = select digits, cid = change digits
                    d = { '%f[%d]%d+' },

                    -- e: Word with case (camelCase, PascalCase, snake_case)
                    -- vie = select case-aware word
                    e = {
                        {
                            '%u[%l%d]+%f[^%l%d]',  -- PascalCase
                            '%f[%S][%l%d]+%f[^%l%d]',  -- lowercase word
                            '%f[%P][%l%d]+%f[^%l%d]',  -- word after punctuation
                            '^[%l%d]+%f[^%l%d]',  -- word at start
                        },
                        '^().*()$',
                    },

                    -- g: Entire buffer
                    -- vag = select entire buffer
                    g = PickleVim.mini.ai_buffer,

                    -- u: Function call (Usage)
                    -- viu = select inside function call args
                    u = ai.gen_spec.function_call(),

                    -- U: Function call without dot in name
                    -- Matches foo() but not obj.foo()
                    U = ai.gen_spec.function_call({ name_pattern = '[%w_]' }),
                },
            }
        end,

        config = function(_, opts)
            require('mini.ai').setup(opts)

            -- Register with which-key for documentation
            PickleVim.on_load('which-key.nvim', function()
                vim.schedule(function()
                    PickleVim.mini.ai_whichkey(opts)
                end)
            end)
        end,
    },

    ----------------------------------------
    -- mini.pairs - Smart Auto-pairing
    ----------------------------------------
    {
        'echasnovski/mini.pairs',
        event = { 'LazyFile' },

        opts = {
            ----------------------------------------
            -- Mode Configuration
            ----------------------------------------
            modes = {
                insert = true,    -- Enable in insert mode
                command = true,   -- Enable in command mode
                terminal = false, -- Disable in terminal mode
            },

            ----------------------------------------
            -- Smart Skipping
            ----------------------------------------
            -- Skip pairing when next character matches pattern
            -- Prevents double-pairing like (()) when typing ((
            skip_next = [=[[%w%%%'%[%"%.%`%$]]=],

            -- Skip pairing inside Treesitter nodes
            -- e.g., don't pair quotes inside strings
            skip_ts = { 'string' },

            -- Skip closing pair if opening pair is unbalanced
            -- Prevents auto-pairing breaking syntax
            skip_unbalanced = true,

            ----------------------------------------
            -- Language-Specific
            ----------------------------------------
            -- Enable markdown-specific pairing rules
            markdown = true,
        },

        config = function(_, opts)
            -- Custom setup with smart skipping logic
            -- See lua/utils/mini.lua for implementation
            PickleVim.mini.pairs(opts)
        end,
    },

    ----------------------------------------
    -- mini.surround - Surround Text Objects
    ----------------------------------------
    {
        'echasnovski/mini.surround',
        event = { 'LazyFile' },

        -- Register keymaps with which-key for documentation
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

            -- Filter out empty mappings
            mappings = vim.tbl_filter(function(m)
                return m[1] and #m[1] > 0
            end, mappings)

            return vim.list_extend(mappings, keys)
        end,

        opts = {
            ----------------------------------------
            -- Keymap Configuration
            ----------------------------------------
            mappings = {
                add = 'gsa',            -- Add surrounding (normal/visual): gsaiw" = surround word with "
                delete = 'gsd',         -- Delete surrounding: gsd" = delete surrounding "
                find = 'gsf',           -- Find surrounding (to the right)
                find_left = 'gsF',      -- Find surrounding (to the left)
                highlight = 'gsh',      -- Highlight surrounding
                replace = 'gsr',        -- Replace surrounding: gsr"' = replace " with '
                update_n_lines = 'gsn', -- Update search line count

                suffix_last = 'l',      -- Suffix to search with "prev" method
                suffix_next = 'n',      -- Suffix to search with "next" method
            },
        },
    },
}
