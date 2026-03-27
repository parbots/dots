--- Trouble.nvim configuration
--- A pretty diagnostics, references, telescope results, quickfix and location list
--- Provides a structured view of LSP diagnostics, symbols, and references
---
--- Features:
---   - Pretty list of diagnostics with icons and severity colors
---   - Jump to locations in code
---   - Auto-preview on cursor movement
---   - Multiple display modes (diagnostics, symbols, LSP, quickfix, loclist)
---   - Indent guides for nested items
---
--- Keybindings:
---   <leader>xx - Toggle diagnostics (all workspace)
---   <leader>xX - Toggle buffer diagnostics (current buffer only)
---   <leader>cs - Toggle symbols (document symbols)
---   <leader>cS - Toggle LSP (references, definitions, etc.)
---   <leader>xL - Toggle location list
---   <leader>xQ - Toggle quickfix list

return {
    'folke/trouble.nvim',
    lazy = true,
    cmd = { 'Trouble' },

    ---@class trouble.Config
    opts = {
        ----------------------------------------
        -- Behavior
        ----------------------------------------
        auto_close = false,   -- Don't auto-close when no items
        auto_open = false,    -- Don't auto-open on diagnostics
        auto_preview = true,  -- Auto-preview location on cursor move
        auto_refresh = true,  -- Auto-refresh on diagnostics change
        auto_jump = false,    -- Don't auto-jump to first item

        focus = true,         -- Focus Trouble window when opened
        restore = true,       -- Restore last window position
        follow = true,        -- Follow current buffer for diagnostics

        ----------------------------------------
        -- Display
        ----------------------------------------
        indent_guides = true, -- Show indent guides for nested items
        max_items = 200,      -- Max items to show
        multiline = true,     -- Show multiline messages
        pinned = false,       -- Don't pin window

        warn_no_results = true,  -- Warn when no results
        open_no_results = false, -- Don't open when no results

        ----------------------------------------
        -- Window Configuration
        ----------------------------------------
        win = {},             -- Use default window configuration

        ----------------------------------------
        -- Preview
        ----------------------------------------
        preview = {
            type = 'main',    -- Preview in main window (not split)

            scratch = true,   -- Use scratch buffer for preview
        },

        ----------------------------------------
        -- Performance
        ----------------------------------------
        throttle = {
            refresh = 20,     -- Throttle refresh (ms)
            update = 10,      -- Throttle updates (ms)
            render = 10,      -- Throttle rendering (ms)
            follow = 100,     -- Throttle follow (ms)

            preview = {
                ms = 100,     -- Preview throttle (ms)
                debounce = true, -- Debounce preview updates
            },
        },

        ----------------------------------------
        -- Keymaps (Internal)
        ----------------------------------------
        keys = {},            -- Use defaults

        ----------------------------------------
        -- Mode Configuration
        ----------------------------------------
        modes = {
            lsp = {
                win = { position = 'right' }, -- LSP window on right side
            },
        },

        ----------------------------------------
        -- Icons
        ----------------------------------------
        icons = {
            -- Indent guide characters
            indent = {
                top = '│ ',
                middle = '├╴',
                last = '╰╴',
                fold_open = ' ',
                fold_closed = ' ',
                ws = '  ',
            },

            -- LSP symbol kinds (from PickleVim icons)
            kinds = PickleVim.icons.kinds,
        },

        ----------------------------------------
        -- Debug
        ----------------------------------------
        debug = {},
    },

    ----------------------------------------
    -- Lazy.nvim Keybindings
    ----------------------------------------
    keys = {
        -- Diagnostics
        { '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Diagnostics (Trouble)' },
        { '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = 'Buffer Diagnostics (Trouble)' },

        -- Symbols and LSP
        { '<leader>cs', '<cmd>Trouble symbols toggle<cr>', desc = 'Symbols (Trouble)' },
        { '<leader>cS', '<cmd>Trouble lsp toggle<cr>', desc = 'LSP references/definitions/... (Trouble)' },

        -- Lists
        { '<leader>xL', '<cmd>Trouble loclist toggle<cr>', desc = 'Location List (Trouble)' },
        { '<leader>xQ', '<cmd>Trouble qflist toggle<cr>', desc = 'Quickfix List (Trouble)' },
    },
}
