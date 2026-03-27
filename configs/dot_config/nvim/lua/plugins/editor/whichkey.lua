--- Which-key.nvim - Keymap discovery and help
--- Shows available keybindings in a popup as you type
--- Provides hierarchical keymap organization and documentation
---
--- Features:
---   - Auto-popup showing available keys after partial sequence
---   - Group organization with descriptions and icons
---   - Buffer-specific keymaps display
---   - Window hydra mode (repeat window commands)
---   - Helix-inspired preset (clean, modern UI)
---   - Dynamic buffer/window keymap expansion
---
--- Keybindings:
---   <leader>? - Show buffer-local keymaps
---   <C-w><Space> - Window hydra mode (repeat window commands)
---
--- Key Groups:
---   <leader><tab> - Tab management
---   <leader>b - Buffer operations (with dynamic buffer list)
---   <leader>c - Code actions (LSP)
---   <leader>d - Debug operations
---   <leader>dp - Profiler
---   <leader>f - File/find operations
---   <leader>g - Git operations
---   <leader>gh - Git hunks
---   <leader>q - Quit/session
---   <leader>s - Search
---   <leader>u - UI toggles
---   <leader>w - Window operations (proxy to <C-w>)
---   <leader>x - Diagnostics/quickfix
---   [ / ] - Previous/next navigation
---   g - Goto operations
---   gs - Surround operations (mini.surround)
---   z - Fold operations
---
--- Usage:
---   - Type a leader key (<leader>, g, [, etc.) and wait briefly
---   - Which-key popup shows available completions
---   - Continue typing or select from menu

return {
    ----------------------------------------
    -- Which-key - Keymap Help
    ----------------------------------------
    {
        'folke/which-key.nvim',
        event = { 'VeryLazy' },  -- Load after startup

        ----------------------------------------
        -- Keybindings
        ----------------------------------------
        keys = {
            -- Show buffer-local keymaps
            {
                '<leader>?',
                function()
                    require('which-key').show({ global = false })
                end,
                desc = 'Buffer Keymaps (which-key)',
            },

            -- Window hydra mode: repeat window commands without <C-w>
            -- Example: <C-w><Space> then hjkl to navigate windows repeatedly
            {
                '<c-w><space>',
                function()
                    require('which-key').show({ keys = '<c-w>', loop = true })
                end,
                desc = 'Window Hydra Mode (which-key)',
            },
        },

        ----------------------------------------
        -- Configuration
        ----------------------------------------
        opts = {
            ----------------------------------------
            -- UI Preset
            ----------------------------------------
            preset = 'helix',  -- Use Helix-inspired UI (clean, modern)

            ----------------------------------------
            -- Keymap Groups
            ----------------------------------------
            spec = {
                {
                    mode = { 'n', 'v' },  -- Normal and visual modes

                    -- Leader key groups
                    { '<leader><tab>', group = 'tabs' },
                    { '<leader>c', group = 'code' },
                    { '<leader>d', group = 'debug' },
                    { '<leader>dp', group = 'profiler' },
                    { '<leader>f', group = 'file/find' },
                    { '<leader>g', group = 'git' },
                    { '<leader>gh', group = 'hunks' },
                    { '<leader>q', group = 'quit/session' },
                    { '<leader>s', group = 'search' },
                    { '<leader>u', group = 'ui', icon = { icon = '󰙵 ', color = 'cyan' } },
                    { '<leader>x', group = 'diagnostics/quickfix', icon = { icon = '󱖫 ', color = 'green' } },

                    -- Navigation groups
                    { '[', group = 'prev' },
                    { ']', group = 'next' },
                    { 'g', group = 'goto' },
                    { 'gs', group = 'surround' },
                    { 'z', group = 'fold' },

                    -- Buffer group with dynamic expansion
                    -- Shows list of open buffers
                    {
                        '<leader>b',
                        group = 'buffer',
                        expand = function()
                            return require('which-key.extras').expand.buf()
                        end,
                    },

                    -- Window group with dynamic expansion
                    -- Proxies to <C-w> commands, shows window operations
                    {
                        '<leader>w',
                        group = 'windows',
                        proxy = '<c-w>',  -- Map <leader>w to <C-w>
                        expand = function()
                            return require('which-key.extras').expand.win()
                        end,
                    },

                    ----------------------------------------
                    -- Custom Descriptions
                    ----------------------------------------
                    -- Override default descriptions for specific keys
                    { 'gx', desc = 'Open with system app' },
                },
            },
        },
    },
}
