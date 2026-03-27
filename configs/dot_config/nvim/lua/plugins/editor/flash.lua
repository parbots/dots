--- Flash.nvim - Enhanced jump/search motion plugin
--- Provides fast, accurate navigation anywhere in the visible editor
--- Like easymotion/hop/leap but with better algorithms and UI
---
--- Features:
---   - Character-based jumping (type 2 chars, jump to match)
---   - Treesitter node selection (select entire AST nodes)
---   - Remote operations (operate on distant text without moving cursor)
---   - Treesitter search (search and select nodes)
---   - Integration with search (/) with optional toggle
---   - Multi-window support (jump across windows)
---   - Label generation that avoids common finger fatigue
---
--- Keybindings:
---   s - Flash jump (normal/visual/operator-pending)
---       Type 2 characters to jump to any match
---
---   S - Flash Treesitter (normal/visual/operator-pending)
---       Select entire Treesitter nodes (function, class, etc.)
---
---   r - Remote Flash (operator-pending only)
---       Operate on distant text: press r, operator, then jump
---       Example: dry - delete remote yank (yank without moving cursor)
---
---   R - Treesitter Search (visual/operator-pending)
---       Search for Treesitter nodes and select matches
---
---   <C-s> - Toggle Flash in search mode (command-line)
---       While in / search, toggle Flash highlighting
---
--- Examples:
---   s + "fu" - Jump to next occurrence of "fu"
---   dsy - Delete to next "y" (operator + flash jump)
---   S - Select entire function/class under cursor
---   dry - Yank distant text without moving cursor

return {
    ----------------------------------------
    -- Flash.nvim - Jump Navigation
    ----------------------------------------
    {
        'folke/flash.nvim',
        event = { 'VeryLazy' },  -- Load after startup

        ----------------------------------------
        -- Keybindings
        ----------------------------------------
        keys = {
            -- Flash jump: press s, then 2 chars to jump anywhere
            {
                's',
                mode = { 'n', 'x', 'o' },
                function()
                    require('flash').jump()
                end,
                desc = 'Flash',
            },

            -- Treesitter flash: jump to/select Treesitter nodes
            {
                'S',
                mode = { 'n', 'x', 'o' },
                function()
                    require('flash').treesitter()
                end,
                desc = 'Flash Treesitter',
            },

            -- Remote flash: operate on distant text without moving cursor
            -- Example: dry - yank from distant location
            {
                'r',
                mode = { 'o' },  -- Operator-pending only
                function()
                    require('flash').remote()
                end,
                desc = 'Remote Flash',
            },

            -- Treesitter search: search for and select Treesitter nodes
            {
                'R',
                mode = { 'x', 'o' },  -- Visual and operator-pending
                function()
                    require('flash').treesitter_search()
                end,
                desc = 'Flash Treesitter Search',
            },

            -- Toggle flash in command-line search
            -- While in / search mode, press <C-s> to toggle Flash
            {
                '<c-s>',
                mode = { 'c' },  -- Command-line mode
                function()
                    require('flash').toggle()
                end,
                desc = 'Toggle Flash Search',
            },
        },

        ----------------------------------------
        -- Configuration
        ----------------------------------------
        opts = {},  -- Use default Flash configuration
    },
}
