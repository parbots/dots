--- Bufferline - Buffer tabs at the top of the editor
--- Displays open buffers as tabs with visual indicators
--- Integrates with LSP diagnostics, file icons, and buffer management
---
--- Features:
---   - Minimal style preset (clean, uncluttered look)
---   - Buffer pinning (keep important buffers visible)
---   - LSP diagnostic indicators per buffer
---   - File type icons (via mini.icons)
---   - Smart buffer closing (via Snacks.bufdelete)
---   - Buffer navigation and reordering
---   - Hover to reveal close button
---   - Auto-hide when only one buffer
---
--- Keybindings:
---   Navigation:
---     <S-h> / [b - Previous buffer
---     <S-l> / ]b - Next buffer
---     [B - Move buffer left
---     ]B - Move buffer right
---
---   Management:
---     <leader>bp - Toggle pin buffer
---     <leader>bP - Close all unpinned buffers
---     <leader>br - Close buffers to the right
---     <leader>bl - Close buffers to the left
---
--- Diagnostic Indicators:
---   Shows count of errors, warnings, hints, info per buffer
---   Example: " 2  1" (2 errors, 1 warning)

return {
    ----------------------------------------
    -- Bufferline - Buffer Tabs
    ----------------------------------------
    'akinsho/bufferline.nvim',
    event = { 'VeryLazy' },  -- Load after startup

    ----------------------------------------
    -- Keybindings
    ----------------------------------------
    keys = {
        -- Buffer pinning
        { '<leader>bp', '<Cmd>BufferLineTogglePin<CR>', desc = 'Toggle Pin' },
        { '<leader>bP', '<Cmd>BufferLineGroupClose ungrouped<CR>', desc = 'Delete Non-Pinned Buffers' },

        -- Close buffers relative to current
        { '<leader>br', '<Cmd>BufferLineCloseRight<CR>', desc = 'Delete Buffers to the Right' },
        { '<leader>bl', '<Cmd>BufferLineCloseLeft<CR>', desc = 'Delete Buffers to the Left' },

        -- Navigate buffers
        { '<S-h>', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev Buffer' },
        { '<S-l>', '<cmd>BufferLineCycleNext<cr>', desc = 'Next Buffer' },
        { '[b', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev Buffer' },
        { ']b', '<cmd>BufferLineCycleNext<cr>', desc = 'Next Buffer' },

        -- Move buffers
        { '[B', '<cmd>BufferLineMovePrev<cr>', desc = 'Move buffer prev' },
        { ']B', '<cmd>BufferLineMoveNext<cr>', desc = 'Move buffer next' },
    },

    ----------------------------------------
    -- Configuration
    ----------------------------------------
    opts = function()
        local bufferline = require('bufferline')
        local ret = {
            ----------------------------------------
            -- General Options
            ----------------------------------------
            options = {
                mode = 'buffers',  -- Show buffers (not tabs)

                style_preset = bufferline.style_preset.minimal,  -- Minimal UI style

                themable = true,  -- Allow theme to style bufferline

                numbers = 'none',  -- Don't show buffer numbers

                ----------------------------------------
                -- Buffer Closing
                ----------------------------------------
                -- Use Snacks.bufdelete for smart buffer closing
                -- (preserves window layout, closes LSP if last buffer)
                close_command = function(n)
                    Snacks.bufdelete(n)
                end,

                ----------------------------------------
                -- Visual Indicators
                ----------------------------------------
                indicator = {
                    style = 'underline',  -- Underline active buffer
                },

                ----------------------------------------
                -- Icons
                ----------------------------------------
                buffer_close_icon = '󰅖 ',  -- Close button icon
                modified_icon = '● ',      -- Modified buffer indicator
                close_icon = ' ',         -- Close all icon
                left_trunc_marker = ' ',  -- Truncation indicator (left)
                right_trunc_marker = ' ', -- Truncation indicator (right)

                ----------------------------------------
                -- Name Truncation
                ----------------------------------------
                max_name_length = 18,     -- Maximum buffer name length
                max_prefix_length = 15,   -- Maximum directory prefix length
                truncate_names = true,    -- Truncate long names
                tab_size = 18,            -- Fixed tab width

                ----------------------------------------
                -- LSP Diagnostics Integration
                ----------------------------------------
                diagnostics = 'nvim_lsp',                 -- Use LSP diagnostics
                diagnostics_update_in_insert = false,     -- Don't update while typing
                diagnostics_update_on_event = true,       -- Update on LSP events

                -- Custom diagnostic indicator function
                -- Shows count of each diagnostic severity with icons
                ---@param _ any Context (unused)
                ---@param __ any Level (unused)
                ---@param ___ any Diagnostics (unused)
                ---@param context table Buffer context
                ---@return string indicator Diagnostic indicator text
                diagnostics_indicator = function(_, _, ___, context)
                    -- Get all diagnostics for this buffer
                    local diagnostics = vim.diagnostic.get(context.buffer.id)

                    -- Return empty if no diagnostics
                    if #diagnostics < 1 then
                        return ''
                    end

                    local severity = vim.diagnostic.severity

                    -- Count diagnostics by severity
                    local diags = {
                        [severity.ERROR] = {
                            icon = PickleVim.icons.diagnostics.error,
                            count = 0,
                        },
                        [severity.WARN] = {
                            icon = PickleVim.icons.diagnostics.warn,
                            count = 0,
                        },
                        [severity.HINT] = {
                            icon = PickleVim.icons.diagnostics.hint,
                            count = 0,
                        },
                        [severity.INFO] = {
                            icon = PickleVim.icons.diagnostics.info,
                            count = 0,
                        },
                    }

                    -- Count each diagnostic by severity
                    for _, diag in ipairs(diagnostics) do
                        diags[diag.severity].count = diags[diag.severity].count + 1
                    end

                    local error = diags[severity.ERROR]
                    local warn = diags[severity.WARN]
                    local hint = diags[severity.HINT]
                    local info = diags[severity.INFO]

                    ---@type string
                    local ret = ''

                    -- Build indicator string (e.g., " 2  1")
                    if error.count > 0 then
                        ret = ret .. error.icon .. error.count
                    end

                    if warn.count > 0 then
                        ret = ret .. ' ' .. warn.icon .. warn.count
                    end

                    if hint.count > 0 then
                        ret = ret .. ' ' .. hint.icon .. hint.count
                    end

                    if info.count > 0 then
                        ret = ret .. ' ' .. info.icon .. info.count
                    end

                    return ret
                end,

                ----------------------------------------
                -- Window Offsets
                ----------------------------------------
                -- Reserve space for sidebar windows
                offsets = {
                    {
                        filetype = 'snacks_layout_box',  -- Snacks.nvim sidebar
                    },
                },

                ----------------------------------------
                -- Icons and Display
                ----------------------------------------
                color_icons = true,  -- Use colored filetype icons

                -- Get filetype icon from PickleVim icons
                get_element_icon = function(opts)
                    return PickleVim.icons.ft[opts.filetype]
                end,

                show_buffer_icons = true,         -- Show filetype icons
                show_buffer_close_icons = false,  -- Hide individual close buttons
                show_close_icon = false,          -- Hide global close button
                show_tab_indicators = true,       -- Show tab indicators
                show_duplicate_prefix = true,     -- Show directory for duplicate names

                ----------------------------------------
                -- Behavior
                ----------------------------------------
                duplicates_across_groups = true,  -- Show duplicates even in groups
                persist_buffer_sort = false,      -- Don't persist sort order
                move_wraps_at_ends = true,        -- Wrap when moving at ends
                separator_style = 'thin',         -- Thin separator style
                enforce_regular_tabs = false,     -- Allow variable tab widths

                always_show_bufferline = false,   -- Hide when only one buffer
                auto_toggle_bufferline = true,    -- Auto-show/hide

                ----------------------------------------
                -- Hover Behavior
                ----------------------------------------
                hover = {
                    enabled = true,   -- Enable hover effects
                    delay = 200,      -- Delay before showing (ms)
                    reveal = { 'close' },  -- Reveal close button on hover
                },
            },
        }

        return ret
    end,
}
