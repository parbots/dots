--- Dropbar.nvim - Winbar with breadcrumbs
--- Shows breadcrumb navigation at the top of each window
--- Displays current location in file structure (directory > file > function > etc.)
---
--- Features:
---   - LSP symbol breadcrumbs (file > class > function)
---   - File path breadcrumbs
---   - Interactive symbol picker
---   - Context navigation (jump to parent scope)
---   - Modified file indicator
---   - Catppuccin theme integration
---
--- Keybindings:
---   <leader>; - Pick symbol from dropbar (fuzzy finder for breadcrumbs)
---   [; - Go to start of current context (parent scope)
---   ]; - Select next context (sibling scope)
---
--- Breadcrumb Format:
---   directory  file.ts  Class  method()
---   └─ path    └─ file   └─ LSP symbols
---
--- Modified Indicator:
---   file.ts [+] - Shows [+] when file has unsaved changes

return {
    ----------------------------------------
    -- Dropbar.nvim - Winbar Breadcrumbs
    ----------------------------------------
    {
        'Bekaboo/dropbar.nvim',
        event = { 'LazyFile' }, -- Load when opening files

        ----------------------------------------
        -- Keybindings
        ----------------------------------------
        keys = {
            -- Pick symbol from dropbar (fuzzy finder)
            {
                '<leader>;',
                mode = { 'n' },
                function()
                    require('dropbar.api').pick()
                end,
                desc = 'Pick symbol in dropbar',
            },

            -- Go to start of current context (parent scope)
            {
                '[;',
                mode = { 'n' },
                function()
                    require('dropbar.api').goto_context_start()
                end,
                desc = 'Go to start of current context',
            },

            -- Select next context (sibling scope)
            {
                '];',
                mode = { 'n' },
                function()
                    require('dropbar.api').select_next_context()
                end,
                desc = 'Select next context',
            },
        },

        ----------------------------------------
        -- Configuration
        ----------------------------------------
        opts = {
            ----------------------------------------
            -- Bar Configuration
            ----------------------------------------
            bar = {
                update_debounce = 50, -- Debounce updates (ms)
            },

            ----------------------------------------
            -- Menu Configuration
            ----------------------------------------
            menu = {
                preview = false, -- Don't show preview in menu

                -- Scrollbar for long symbol lists
                scrollbar = {
                    enable = true, -- Enable scrollbar
                    background = true, -- Show scrollbar background
                },
            },

            ----------------------------------------
            -- Icons
            ----------------------------------------
            icons = {
                enable = true, -- Enable icons

                -- UI icons
                ui = {
                    bar = {
                        separator = '  ', -- Separator between breadcrumb items
                        extends = '…', -- Truncation indicator
                    },

                    menu = {
                        separator = ' ', -- Separator in menu
                        indicator = '  ', -- Selection indicator
                    },
                },
            },

            ----------------------------------------
            -- Sources
            ----------------------------------------
            sources = {
                -- Path source (file paths)
                path = {
                    -- Modified file indicator
                    ---@param sym any Symbol data
                    ---@return any modified Modified symbol with [+] indicator
                    modified = function(sym)
                        return sym:merge({
                            name = sym.name .. ' [+]',
                            icon = ' ',
                            name_hl = 'DiffAdded',
                            icon_hl = 'DiffAdded',
                        })
                    end,
                },
            },
        },
    },
}
