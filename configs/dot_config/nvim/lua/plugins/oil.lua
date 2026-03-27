--- Oil.nvim - File explorer in a buffer
--- Edit your filesystem like you edit text
--- Navigate directories and manipulate files using Vim motions and commands
---
--- Features:
---   - Edit filesystem as if it's a buffer (dd to delete, yy to copy, etc.)
---   - Vertical preview of file contents
---   - LSP integration for file operations (updates imports on rename)
---   - Show hidden files by default
---   - Natural file ordering (case-insensitive, numbers sorted correctly)
---   - Auto-save buffer changes before navigating
---   - Watch for external filesystem changes
---
--- Keybindings:
---   <leader>oo - Open Oil in floating window with preview
---   <leader>fe - Open Oil in current window
---
--- Within Oil buffer:
---   - - Navigate up one directory
---   <CR> - Open file or directory
---   g. - Toggle hidden files
---   g\\ - Toggle trash mode
---   <C-p> - Preview file
---   <C-s> - Split window
---   <C-v> - Vsplit window
---   <C-h> - Split and open file
---   gd - Show file detail view

return {
    ----------------------------------------
    -- Oil.nvim - Buffer-Based File Explorer
    ----------------------------------------
    {
        'stevearc/oil.nvim',
        cmd = 'Oil',
        dependencies = {
            'echasnovski/mini.icons',  -- File type icons
        },

        ----------------------------------------
        -- Keybindings
        ----------------------------------------
        keys = {
            -- Open Oil in floating window with vertical preview
            {
                '<leader>oo',
                function()
                    require('oil').open_float(nil, {
                        preview = {
                            vertical = true,  -- Show preview in vertical split
                        },
                    }, nil)
                end,
                desc = 'Open oil (float)',
            },

            -- Open Oil in current window
            {
                '<leader>fe',
                '<CMD>Oil<CR>',
                desc = 'Open oil',
            },
        },

        ---@module 'oil'
        ---@type oil.SetupOpts
        opts = {
            ----------------------------------------
            -- Explorer Behavior
            ----------------------------------------
            -- Don't replace netrw as the default file explorer
            default_file_explorer = false,

            ----------------------------------------
            -- Display Configuration
            ----------------------------------------
            -- Columns to display in the explorer
            columns = {
                'icon',  -- Show file type icons (requires mini.icons or nvim-web-devicons)
            },

            ----------------------------------------
            -- Buffer Configuration
            ----------------------------------------
            buf_options = {
                buflisted = false,  -- Don't show Oil buffers in buffer list
                bufhidden = 'hide', -- Hide buffer when abandoned (don't unload)
            },

            ----------------------------------------
            -- Window Configuration
            ----------------------------------------
            win_options = {
                wrap = false,            -- Don't wrap long file names
                signcolumn = 'yes',      -- Always show sign column (for marks, etc.)
                cursorcolumn = false,    -- Don't highlight cursor column
                foldcolumn = '0',        -- No fold column
                spell = false,           -- Disable spell checking
                list = false,            -- Don't show whitespace characters
                conceallevel = 3,        -- Conceal special markup (for better UX)
                concealcursor = 'nvic',  -- Conceal in all modes
            },

            ----------------------------------------
            -- File Operations
            ----------------------------------------
            -- Move deleted files to trash instead of permanent deletion
            delete_to_trash = false,

            -- Skip confirmation for simple edits (rename without changing directory)
            skip_confirm_for_simple_edits = true,

            -- Prompt to save buffer changes when navigating to new entry
            prompt_save_on_select_new_entry = true,

            -- Delay before cleaning up hidden buffers (ms)
            cleanup_delay_ms = 2000,

            ----------------------------------------
            -- LSP Integration
            ----------------------------------------
            -- Use LSP file operations (updates imports when renaming files)
            lsp_file_methods = {
                enabled = true,          -- Enable LSP integration
                timeout_ms = 1000,       -- Timeout for LSP requests
                autosave_changes = false, -- Don't auto-save LSP changes
            },

            ----------------------------------------
            -- Navigation
            ----------------------------------------
            -- Constrain cursor to editable areas (file names)
            constrain_cursor = 'editable',

            -- Watch for external filesystem changes and auto-update
            watch_for_changes = true,

            ----------------------------------------
            -- View Options
            ----------------------------------------
            view_options = {
                -- Show hidden files (dotfiles)
                show_hidden = true,

                -- Natural file ordering (case-insensitive, numbers sorted correctly)
                -- "fast" uses a faster but less accurate algorithm
                natural_order = 'fast',
            },
        },
    },
}
