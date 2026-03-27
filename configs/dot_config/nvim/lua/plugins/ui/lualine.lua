--- Lualine - Statusline plugin
--- Provides a beautiful, informative statusline with multiple sections
--- Integrates with Git, LSP, diagnostics, and other plugins
---
--- Features:
---   - Catppuccin theme integration
---   - Global statusline (single statusline for all windows)
---   - Git branch and diff indicators (via gitsigns)
---   - LSP status and active clients
---   - Diagnostic counts with icons
---   - Current mode indicator
---   - File path with custom formatting
---   - Search count display
---   - Lazy.nvim plugin status
---   - Noice command/mode integration
---   - Profiler status (Snacks.nvim)
---
--- Layout (left to right):
---   Section A: Mode (NORMAL, INSERT, VISUAL, etc.)
---   Section B: Git branch, diff stats
---   Section C: Root directory, file path, search count
---   Section X: Profiler, Noice cmd/mode, Lazy status
---   Section Y: Diagnostics, LSP clients, filetype
---   Section Z: Cursor location
---
--- Extensions:
---   - lazy (Lazy.nvim UI)
---   - man (Man pages)
---   - mason (Mason UI)
---   - oil (Oil file explorer)
---   - trouble (Trouble diagnostics)

return {
    ----------------------------------------
    -- Lualine - Statusline
    ----------------------------------------
    {
        'nvim-lualine/lualine.nvim',
        event = { 'VeryLazy' },  -- Load after startup
        dependencies = {
            'folke/noice.nvim',  -- For cmd/mode integration
        },

        ----------------------------------------
        -- Initialization
        ----------------------------------------
        -- Hide statusline on startup for better first impression
        init = function()
            -- Save the original laststatus setting
            vim.g.lualine_laststatus = vim.o.laststatus

            -- If opening files directly (not dashboard)
            if vim.fn.argc(-1) > 0 then
                vim.o.statusline = ' '  -- Show minimal statusline
            else
                vim.o.laststatus = 0  -- Hide statusline completely (dashboard)
            end
        end,

        ----------------------------------------
        -- Configuration
        ----------------------------------------
        opts = function()
            -- Patch lualine require to work with lazy loading
            local lualine_require = require('lualine_require')
            lualine_require.require = require

            -- Restore original laststatus setting
            vim.o.laststatus = vim.g.lualine_laststatus

            local opts = {
                ----------------------------------------
                -- General Options
                ----------------------------------------
                options = {
                    theme = 'catppuccin-mocha',  -- Use Catppuccin theme colors

                    -- Use global statusline (single statusline for all windows)
                    globalstatus = vim.o.laststatus == 3,

                    -- Don't show statusline in these filetypes
                    disabled_filetypes = {
                        statusline = { 'snacks_dashboard' },
                    },
                },

                ----------------------------------------
                -- Statusline Sections
                ----------------------------------------
                sections = {
                    ----------------------------------------
                    -- Section A: Mode (left-most)
                    ----------------------------------------
                    lualine_a = {
                        {
                            'mode',  -- NORMAL, INSERT, VISUAL, etc.
                            padding = { left = 1, right = 1 },
                        },
                    },

                    ----------------------------------------
                    -- Section B: Git Information
                    ----------------------------------------
                    lualine_b = {
                        -- Git branch name
                        {
                            'branch',
                            icon = '',  -- Git branch icon
                            padding = { left = 1, right = 1 },
                        },

                        -- Git diff stats (added/modified/removed lines)
                        {
                            'diff',
                            symbols = {
                                added = PickleVim.icons.git.added,
                                modified = PickleVim.icons.git.modified,
                                removed = PickleVim.icons.git.removed,
                            },
                            -- Get diff stats from Gitsigns buffer variable
                            source = function()
                                local gitsigns = vim.b.gitsigns_status_dict
                                if gitsigns then
                                    return {
                                        added = gitsigns.added,
                                        modified = gitsigns.changed,
                                        removed = gitsigns.removed,
                                    }
                                else
                                    return nil
                                end
                            end,
                        },
                    },

                    ----------------------------------------
                    -- Section C: File Information (center-left)
                    ----------------------------------------
                    lualine_c = {
                        PickleVim.lualine.root_dir(),     -- Project root directory
                        PickleVim.lualine.pretty_path(),  -- Current file path (formatted)
                        {
                            'searchcount',  -- Search results count (e.g., [1/5])
                        },
                    },

                    ----------------------------------------
                    -- Section X: Status Indicators (center-right)
                    ----------------------------------------
                    lualine_x = {
                        Snacks.profiler.status(),         -- Profiler status (if active)
                        PickleVim.lualine.noice_cmd(),    -- Current command (via Noice)
                        PickleVim.lualine.noice_mode(),   -- Current mode (via Noice)
                        PickleVim.lualine.lazy_status(),  -- Lazy.nvim pending updates
                    },

                    ----------------------------------------
                    -- Section Y: Diagnostics and File Info
                    ----------------------------------------
                    lualine_y = {
                        -- LSP diagnostics count
                        {
                            'diagnostics',
                            sources = {
                                'nvim_diagnostic',
                            },
                            symbols = {
                                error = PickleVim.icons.diagnostics.error,
                                warn = PickleVim.icons.diagnostics.warn,
                                info = PickleVim.icons.diagnostics.info,
                                hint = PickleVim.icons.diagnostics.hint,
                            },
                            padding = { left = 1, right = 1 },
                        },

                        -- LSP client status (active LSP servers)
                        PickleVim.lualine.lsp_status(),

                        -- Current filetype with icon
                        {
                            'filetype',
                            icon_only = false,  -- Show both icon and name
                            draw_empty = false, -- Don't show for empty filetype
                            padding = { left = 1, right = 1 },
                        },
                    },

                    ----------------------------------------
                    -- Section Z: Cursor Location (right-most)
                    ----------------------------------------
                    lualine_z = {
                        {
                            'location',  -- Line:Column (e.g., 42:12)
                            icon = '',  -- Location icon
                            padding = { left = 1, right = 1 },
                        },
                    },
                },

                ----------------------------------------
                -- Extensions
                ----------------------------------------
                -- Special statuslines for specific plugin windows
                extensions = {
                    'lazy',    -- Lazy.nvim plugin manager
                    'man',     -- Man page viewer
                    'mason',   -- Mason package manager
                    'oil',     -- Oil file explorer
                    'trouble', -- Trouble diagnostics viewer
                },
            }

            return opts
        end,
    },
}
