--- Treesitter - Advanced syntax parsing and highlighting
--- Provides AST-based syntax highlighting, indentation, and text objects
--- Much more accurate than regex-based syntax highlighting
---
--- Features:
---   - Syntax highlighting for 100+ languages
---   - Treesitter-based indentation
---   - Incremental selection (expand/shrink selection by AST node)
---   - Text object navigation (functions, classes, parameters)
---   - Auto-install parsers for opened filetypes
---   - HTML/XML auto-tag closing and renaming
---
--- Incremental Selection:
---   <C-Space> - Init selection or expand to next node
---   <BS> - Shrink selection to previous node
---
--- Text Object Navigation:
---   ]f / [f - Next/prev function start
---   ]F / [F - Next/prev function end
---   ]c / [c - Next/prev class start
---   ]C / [C - Next/prev class end
---   ]a / [a - Next/prev parameter start
---   ]A / [A - Next/prev parameter end
---
--- Commands:
---   :TSUpdate - Update all parsers
---   :TSUpdateSync - Update parsers synchronously
---   :TSInstall <lang> - Install parser for language

return {
    ----------------------------------------
    -- Which-key Integration (for Treesitter keymaps)
    ----------------------------------------
    {
        'folke/which-key.nvim',
        opts = {
            spec = {
                -- Document incremental selection keymaps
                { '<C-Space>', desc = 'Increment Selection', mode = { 'x', 'n' } },
                { '<BS>', desc = 'Decrement Selection', mode = 'x' },
            },
        },
    },

    ----------------------------------------
    -- Treesitter - Main Plugin
    ----------------------------------------
    {
        'nvim-treesitter/nvim-treesitter',
        version = false,  -- Use latest commit (not versioned releases)
        branch = 'master',  -- Track master branch
        event = { 'LazyFile' },  -- Load when opening files
        lazy = vim.fn.argc(-1) == 0,  -- Don't lazy load if opening files on startup
        build = ':TSUpdate',  -- Update all parsers on plugin install/update
        cmd = { 'TSUpdateSync', 'TSUpdate', 'TSInstall' },  -- Lazy-load on commands

        ----------------------------------------
        -- Keybindings
        ----------------------------------------
        keys = {
            -- Incremental selection (expand selection by AST node)
            { '<C-Space>', desc = 'Increment Selection', mode = { 'x', 'n' } },
            -- Decremental selection (shrink selection)
            { '<BS>', desc = 'Decrement Selection', mode = 'x' },
        },

        ----------------------------------------
        -- Initialization
        ----------------------------------------
        -- Pre-load query predicates before plugin setup
        init = function(plugin)
            -- Add plugin to runtimepath early
            require('lazy.core.loader').add_to_rtp(plugin)
            -- Load query predicates (for queries like #set!, #eq?, etc.)
            require('nvim-treesitter.query_predicates')
        end,

        ----------------------------------------
        -- Configuration
        ----------------------------------------
        opts = {
            ----------------------------------------
            -- Parser Installation
            ----------------------------------------
            ensure_installed = 'all',  -- Install all maintained parsers
            ignore_install = {},       -- Don't ignore any parsers

            auto_install = true,   -- Auto-install parser for opened filetype
            sync_install = false,  -- Install parsers asynchronously

            ----------------------------------------
            -- Syntax Highlighting
            ----------------------------------------
            highlight = {
                enable = true,  -- Enable Treesitter-based highlighting
            },

            ----------------------------------------
            -- Indentation
            ----------------------------------------
            indent = {
                enable = true,  -- Enable Treesitter-based indentation
            },

            ----------------------------------------
            -- Incremental Selection
            ----------------------------------------
            -- Smart selection expansion/shrinking by AST nodes
            incremental_selection = {
                enable = true,

                keymaps = {
                    init_selection = '<C-space>',    -- Start selection
                    node_incremental = '<C-space>',  -- Expand to next node
                    scope_incremental = false,       -- Disabled (not used)
                    node_decremental = '<bs>',       -- Shrink to previous node
                },
            },

            ----------------------------------------
            -- Text Objects Navigation
            ----------------------------------------
            -- Jump between functions, classes, parameters
            textobjects = {
                move = {
                    enable = true,

                    -- Jump to next start of node
                    goto_next_start = {
                        [']f'] = '@function.outer',  -- Next function start
                        [']c'] = '@class.outer',     -- Next class start
                        [']a'] = '@parameter.inner', -- Next parameter start
                    },

                    -- Jump to next end of node
                    goto_next_end = {
                        [']F'] = '@function.outer',  -- Next function end
                        [']C'] = '@class.outer',     -- Next class end
                        [']A'] = '@parameter.inner', -- Next parameter end
                    },

                    -- Jump to previous start of node
                    goto_previous_start = {
                        ['[f'] = '@function.outer',  -- Prev function start
                        ['[c'] = '@class.outer',     -- Prev class start
                        ['[a'] = '@parameter.inner', -- Prev parameter start
                    },

                    -- Jump to previous end of node
                    goto_previous_end = {
                        ['[F'] = '@function.outer',  -- Prev function end
                        ['[C'] = '@class.outer',     -- Prev class end
                        ['[A'] = '@parameter.inner', -- Prev parameter end
                    },
                },
            },

            modules = {},  -- Additional modules (unused)
        },

        ----------------------------------------
        -- Setup Function
        ----------------------------------------
        config = function(_, opts)
            require('nvim-treesitter.configs').setup(opts)
        end,
    },

    ----------------------------------------
    -- Treesitter Text Objects
    ----------------------------------------
    {
        'nvim-treesitter/nvim-treesitter-textobjects',
        event = { 'LazyFile' },
        dependencies = {
            'nvim-treesitter/nvim-treesitter',
        },

        ----------------------------------------
        -- Configuration
        ----------------------------------------
        config = function()
            -- If treesitter is already loaded, reconfigure for textobjects
            if PickleVim.is_loaded('nvim-treesitter') then
                local opts = PickleVim.plugin.opts('nvim-treesitter')
                ---@diagnostic disable: missing-fields
                require('nvim-treesitter.configs').setup({ textobjects = opts.textobjects })
            end

            ----------------------------------------
            -- Diff Mode Compatibility
            ----------------------------------------
            -- In diff mode, use default vim text objects (c/C) instead of Treesitter
            local move = require('nvim-treesitter.textobjects.move') ---@type table<string,fun(...)>
            local configs = require('nvim-treesitter.configs')

            -- Patch all goto functions to check diff mode
            for name, fn in pairs(move) do
                if name:find('goto') == 1 then
                    move[name] = function(q, ...)
                        -- If in diff mode, use default vim navigation
                        if vim.wo.diff then
                            local config = configs.get_module('textobjects.move')[name] ---@type table<string,string>
                            for key, query in pairs(config or {}) do
                                -- If query matches and key is ]c/[c/]C/[C, use vim default
                                if q == query and key:find('[%]%[][cC]') then
                                    vim.cmd('normal! ' .. key)
                                    return
                                end
                            end
                        end
                        -- Otherwise, use Treesitter navigation
                        return fn(q, ...)
                    end
                end
            end
        end,
    },

    ----------------------------------------
    -- Auto-tag (HTML/XML Tag Closing)
    ----------------------------------------
    {
        'windwp/nvim-ts-autotag',
        event = { 'BufReadPre', 'BufNewFile' },

        opts = {
            opts = {
                enable_close = true,           -- Auto-close tags (<div>|</div>)
                enable_rename = true,          -- Auto-rename closing tag when changing opening
                enable_close_on_slash = true,  -- Auto-close on typing </
            },
        },
    },
}
