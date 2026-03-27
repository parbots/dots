--- Colorscheme configuration
--- Uses Catppuccin theme with Mocha flavor (dark mode)
--- Provides consistent theming across all plugins and UI elements
---
--- Catppuccin Flavors:
---   - Latte (light)
---   - Frappé (medium)
---   - Macchiato (medium-dark)
---   - Mocha (dark) ← Currently selected
---
--- Features:
---   - Dim inactive windows for focus clarity
---   - Italic comments, keywords, and functions
---   - Bold and italic type annotations
---   - LSP diagnostic styling (undercurl for errors/warnings)
---   - Integrated with 20+ plugins for consistent look
---
--- Plugin Integrations:
---   - Completion: blink.cmp
---   - UI: bufferline, dropbar, noice, which-key
---   - Editor: flash, grug-far, mini, snacks
---   - Git: gitsigns, neogit, diffview
---   - LSP: trouble, treesitter
---   - Misc: mason, notify, render-markdown

return {
    ----------------------------------------
    -- Catppuccin Theme
    ----------------------------------------
    {
        'catppuccin/nvim',
        priority = 1000,    -- Load before other plugins (highest priority)
        lazy = false,       -- Load immediately (needed for colorscheme)
        name = 'catppuccin',

        -- Plugin-specific integrations
        specs = {
            {
                'akinsho/bufferline.nvim',
                optional = true,
                opts = function(_, opts)
                    -- Apply Catppuccin theme to bufferline
                    opts.highlights = require('catppuccin.special.bufferline').get_theme()
                end,
            },
        },

        ---@class CatppuccinOptions
        opts = {
            ----------------------------------------
            -- Theme Variant
            ----------------------------------------
            flavour = 'mocha',  -- Dark theme (latte/frappé/macchiato/mocha)

            -- Theme selection based on vim background
            background = {
                light = 'latte',  -- Use Latte for light mode
                dark = 'mocha',   -- Use Mocha for dark mode
            },

            ----------------------------------------
            -- Display Options
            ----------------------------------------
            transparent_background = false,  -- Use opaque background
            show_end_of_buffer = false,      -- Hide ~ characters at end of buffer
            term_colors = false,             -- Don't set terminal colors

            ----------------------------------------
            -- Window Dimming
            ----------------------------------------
            -- Dim inactive windows to highlight active buffer
            dim_inactive = {
                enabled = true,    -- Enable window dimming

                shade = 'dark',    -- Darken inactive windows
                percentage = 0.25, -- 25% darker
            },

            ----------------------------------------
            -- Style Toggles
            ----------------------------------------
            no_italic = false,    -- Allow italic text
            no_bold = false,      -- Allow bold text
            no_underline = false, -- Allow underlined text

            ----------------------------------------
            -- Syntax Highlighting Styles
            ----------------------------------------
            styles = {
                comments = { 'bold', 'italic' },  -- Comments: bold + italic
                conditionals = { 'italic' },      -- if/else/switch: italic
                loops = { 'italic' },             -- for/while: italic
                functions = { 'italic' },         -- Function names: italic
                keywords = { 'italic' },          -- Keywords (let/const/var): italic
                strings = {},                     -- Strings: default
                variables = {},                   -- Variables: default
                numbers = {},                     -- Numbers: default
                booleans = { 'italic' },          -- true/false: italic
                properties = {},                  -- Object properties: default
                types = { 'bold', 'italic' },     -- Type annotations: bold + italic
                operators = {},                   -- +/-/*: default
            },

            ----------------------------------------
            -- LSP Diagnostic Styles
            ----------------------------------------
            lsp_styles = {
                enabled = true,  -- Apply custom LSP styles

                -- Virtual text styles (inline diagnostics)
                virtual_text = {
                    errors = { 'italic' },
                    hints = { 'italic' },
                    warnings = { 'italic' },
                    information = { 'italic' },
                    ok = { 'italic' },
                },

                -- Diagnostic underline styles
                underlines = {
                    errors = { 'undercurl' },      -- Errors: undercurl (wavy underline)
                    hints = { 'underline' },       -- Hints: straight underline
                    warnings = { 'undercurl' },    -- Warnings: undercurl
                    information = { 'underline' }, -- Info: straight underline
                    ok = { 'underline' },          -- OK: straight underline
                },

                -- Inlay hints styling
                inlay_hints = {
                    background = true,  -- Show background for inlay hints
                },
            },

            ----------------------------------------
            -- Plugin Integrations
            ----------------------------------------
            default_integrations = true,  -- Enable default integrations
            auto_integrations = true,     -- Auto-detect and integrate plugins

            integrations = {
                -- Completion
                blink_cmp = {
                    style = 'solid',  -- Solid background for completion menu
                },
                blink_indent = true,  -- Blink indent integration
                blink_pairs = true,   -- Blink pairs integration
                cmp = true,           -- Legacy nvim-cmp (if used)

                -- UI Components
                dropbar = {
                    enabled = true,
                    color_mode = true,  -- Color dropbar items by type
                },
                noice = true,           -- Noice UI integration
                notifier = true,        -- Snacks notifier
                notify = true,          -- nvim-notify
                which_key = true,       -- Which-key menu

                -- Editor
                flash = true,           -- Flash search/jump
                grug_far = true,        -- Grug-far search/replace
                mini = {
                    enabled = true,     -- Mini.nvim plugins
                },
                snacks = {
                    enabled = true,     -- Snacks.nvim features
                },

                -- Git
                gitsigns = {
                    enabled = true,
                    transparent = true, -- Transparent sign column
                },
                neogit = true,          -- Neogit git UI
                diffview = true,        -- Diffview

                -- LSP and Diagnostics
                lsp_trouble = true,     -- Trouble.nvim
                mason = true,           -- Mason package manager

                -- Language Features
                treesitter_context = true,  -- Treesitter context
                render_markdown = true,     -- Markdown rendering
            },
        },
    },
}
