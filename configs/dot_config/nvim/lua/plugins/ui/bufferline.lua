return {
    'akinsho/bufferline.nvim',
    event = { 'VeryLazy' },

    keys = {
        { '<leader>bp', '<Cmd>BufferLineTogglePin<CR>', desc = 'Toggle Pin' },
        { '<leader>bP', '<Cmd>BufferLineGroupClose ungrouped<CR>', desc = 'Delete Non-Pinned Buffers' },

        { '<leader>br', '<Cmd>BufferLineCloseRight<CR>', desc = 'Delete Buffers to the Right' },
        { '<leader>bl', '<Cmd>BufferLineCloseLeft<CR>', desc = 'Delete Buffers to the Left' },

        { '<S-h>', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev Buffer' },
        { '<S-l>', '<cmd>BufferLineCycleNext<cr>', desc = 'Next Buffer' },
        { '[b', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev Buffer' },
        { ']b', '<cmd>BufferLineCycleNext<cr>', desc = 'Next Buffer' },

        { '[B', '<cmd>BufferLineMovePrev<cr>', desc = 'Move buffer prev' },
        { ']B', '<cmd>BufferLineMoveNext<cr>', desc = 'Move buffer next' },
    },

    opts = function()
        local bufferline = require('bufferline')
        local ret = {
            options = {
                mode = 'buffers',

                style_preset = bufferline.style_preset.minimal,

                themable = true,

                numbers = 'none',

                -- Preserves window layout and closes LSP if last buffer
                close_command = function(n)
                    Snacks.bufdelete(n)
                end,

                indicator = {
                    style = 'underline',
                },

                buffer_close_icon = '󰅖 ',
                modified_icon = '● ',
                close_icon = ' ',
                left_trunc_marker = ' ',
                right_trunc_marker = ' ',

                max_name_length = 18,
                max_prefix_length = 15,
                truncate_names = true,
                tab_size = 18,

                diagnostics = 'nvim_lsp',
                diagnostics_update_in_insert = false,
                diagnostics_update_on_event = true,

                ---@param _ any Context (unused)
                ---@param __ any Level (unused)
                ---@param ___ any Diagnostics (unused)
                ---@param context table Buffer context
                ---@return string indicator Diagnostic indicator text
                diagnostics_indicator = function(_, _, ___, context)
                    local diagnostics = vim.diagnostic.get(context.buffer.id)

                    if #diagnostics < 1 then
                        return ''
                    end

                    local severity = vim.diagnostic.severity

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

                    for _, diag in ipairs(diagnostics) do
                        diags[diag.severity].count = diags[diag.severity].count + 1
                    end

                    local error = diags[severity.ERROR]
                    local warn = diags[severity.WARN]
                    local hint = diags[severity.HINT]
                    local info = diags[severity.INFO]

                    ---@type string
                    local ret = ''

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

                offsets = {
                    {
                        filetype = 'snacks_layout_box',
                    },
                },

                color_icons = true,

                get_element_icon = function(opts)
                    return PickleVim.icons.ft[opts.filetype]
                end,

                show_buffer_icons = true,
                show_buffer_close_icons = false,
                show_close_icon = false,
                show_tab_indicators = true,
                show_duplicate_prefix = true,

                duplicates_across_groups = true,
                persist_buffer_sort = false,
                move_wraps_at_ends = true,
                separator_style = 'thin',
                enforce_regular_tabs = false,

                always_show_bufferline = false,
                auto_toggle_bufferline = true,

                hover = {
                    enabled = true,
                    delay = 200,
                    reveal = { 'close' },
                },
            },
        }

        return ret
    end,
}
