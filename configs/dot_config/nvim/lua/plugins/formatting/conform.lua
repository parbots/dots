--- Conform.nvim - Formatter runner and manager
--- Integrates with PickleVim.formatting system as the primary formatter
--- Provides auto-format on save and manual formatting via keybindings
---
--- Features:
---   - Priority-based formatter registration (priority 100)
---   - LSP fallback formatting when no dedicated formatter exists
---   - Manual formatting via Ctrl-F or :PickleFormat
---   - Format info command to see available formatters
---   - Auto-format on save (when enabled via vim.g.autoformat or vim.b.autoformat)
---   - Async formatting support
---
--- Architecture:
---   - Conform.nvim runs formatters (prettier, stylua, rustfmt, etc.)
---   - PickleVim.formatting provides formatter registry and auto-format logic
---   - Formatter definitions in lua/utils/formatting/formatters.lua
---   - LSP formatting used as fallback (lsp_format = 'fallback')
---
--- Keybindings:
---   <C-f> - Format current file/selection (normal, insert, visual)
---   <leader>cf - Show format info (available formatters)
---
--- Commands:
---   :PickleFormat - Format buffer (force format)
---   :PickleFormatInfo - Show available formatters and their status
---   :ConformInfo - Show Conform-specific debug info

return {
    ----------------------------------------
    -- Conform.nvim - Formatter Runner
    ----------------------------------------
    {
        'stevearc/conform.nvim',
        dependencies = { 'mason.nvim' },  -- Mason provides formatter binaries
        event = { 'LazyFile', 'InsertEnter' },  -- Load on file open or insert mode
        cmd = { 'ConformInfo' },  -- Lazy-load on :ConformInfo command

        ----------------------------------------
        -- Keybindings
        ----------------------------------------
        keys = {
            -- Format current file/selection
            {
                '<c-f>',
                '<CMD>PickleFormat<CR>',
                mode = { 'n', 'i', 'v' },
                desc = 'Format File',
            },

            -- Show format info
            {
                '<leader>cf',
                '<CMD>PickleFormatInfo<CR>',
                mode = { 'n' },
                desc = 'Format Info',
            },
        },

        ----------------------------------------
        -- Formatter Registration
        ----------------------------------------
        -- Register Conform as the primary formatter in PickleVim.formatting system
        init = function()
            PickleVim.on_very_lazy(function()
                -- Register Conform with high priority (100)
                -- This makes Conform the primary formatting backend
                PickleVim.formatting.register({
                    name = 'conform.nvim',  -- Formatter name (shown in :PickleFormatInfo)
                    priority = 100,         -- High priority (runs before other formatters)
                    primary = true,         -- Mark as primary formatter

                    -- Format function called by PickleVim.formatting.format()
                    ---@param buf number Buffer number to format
                    ---@return boolean success Whether formatting succeeded
                    format = function(buf)
                        return require('conform').format({ bufnr = buf }) or false
                    end,

                    -- Get list of available formatters for buffer
                    ---@param buf number Buffer number
                    ---@return string[] sources List of formatter names
                    sources = function(buf)
                        local ret = require('conform').list_formatters(buf)

                        ---@param v conform.FormatterInfo
                        return vim.tbl_map(function(v)
                            return v.name
                        end, ret)
                    end,
                })
            end)
        end,

        ----------------------------------------
        -- Conform Configuration
        ----------------------------------------
        opts = {
            -- Disable Conform's built-in format-on-save
            -- (handled by PickleVim.formatting system instead)
            format_on_save = nil,
            format_after_save = nil,

            ----------------------------------------
            -- Default Format Options
            ----------------------------------------
            default_format_opts = {
                timeout_ms = 3000,       -- Timeout for formatter execution
                async = false,           -- Synchronous formatting (wait for completion)
                quiet = false,           -- Show error notifications
                lsp_format = 'fallback', -- Use LSP formatting as fallback when no formatter exists
            },

            ----------------------------------------
            -- Formatter Definitions
            ----------------------------------------
            -- Import formatters from PickleVim.formatting system
            -- Defined in lua/utils/formatting/formatters.lua
            formatters_by_ft = PickleVim.formatting.list_by_ft,  -- Map filetypes to formatters
            formatters = PickleVim.formatting.list,              -- Formatter configurations
        },
    },
}
