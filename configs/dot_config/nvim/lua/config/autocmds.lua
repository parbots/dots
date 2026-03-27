--- Auto commands configuration
--- Defines automatic behaviors triggered by editor events
--- All autocmds are organized into named augroups with the 'picklevim_' prefix

----------------------------------------
-- Helper Functions
----------------------------------------

--- Create a namespaced augroup
--- Clears any existing autocmds in the group to prevent duplication
---@param name string Augroup name (will be prefixed with 'picklevim_')
---@return integer group Augroup ID
local augroup = function(name)
    return vim.api.nvim_create_augroup('picklevim_' .. name, { clear = true })
end

local autocmd = vim.api.nvim_create_autocmd

----------------------------------------
-- File Handling
----------------------------------------

-- Check if file needs to be reloaded when it changed outside of Neovim
-- Triggers on focus gain, terminal close/leave
autocmd({ 'FocusGained', 'TermClose', 'TermLeave' }, {
    group = augroup('checktime'),
    callback = function()
        -- Only check for normal buffers (not special buffers like terminals)
        if vim.o.buftype ~= 'nofile' then
            vim.cmd('checktime')
        end
    end,
})

-- Auto-create parent directories when saving a file
-- Prevents "E212: Can't open file for writing" errors
autocmd({ 'BufWritePre' }, {
    group = augroup('auto_create_dir'),
    callback = function(event)
        -- Skip special protocols (http://, ftp://, etc.)
        if event.match:match('^%w%w+:[\\/][\\/]') then
            return
        end

        -- Get real path and create parent directories recursively
        local file = vim.uv.fs_realpath(event.match) or event.match
        vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
    end,
})

----------------------------------------
-- Visual Feedback
----------------------------------------

-- Briefly highlight yanked text
-- Provides visual confirmation of yank operation
autocmd({ 'TextYankPost' }, {
    group = augroup('highlight_yank'),
    callback = function()
        vim.hl.on_yank({
            higroup = 'IncSearch',
            timeout = 200, -- 200ms highlight duration
        })
    end,
})

----------------------------------------
-- Window and Layout Management
----------------------------------------

-- Equalize split sizes when Neovim window is resized
-- Maintains balanced window layout on terminal resize
autocmd({ 'VimResized' }, {
    group = augroup('resize_splits'),
    callback = function()
        -- Equalize windows in all tabs
        vim.cmd('tabdo wincmd =')
        -- Return to original tab
        vim.cmd('tabnext ' .. vim.fn.tabpagenr())
    end,
})

----------------------------------------
-- Buffer Behavior
----------------------------------------

-- Restore cursor position when opening a buffer
-- Jumps to last known cursor position (using '" mark)
autocmd({ 'BufReadPost' }, {
    group = augroup('last_loc'),
    callback = function(event)
        -- Don't restore position for these filetypes
        local exclude = { 'gitcommit' }
        local buf = event.buf

        -- Skip if filetype excluded or already processed
        if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].picklevim_last_loc then
            return
        end

        -- Mark buffer as processed to prevent duplicate runs
        vim.b[buf].picklevim_last_loc = true

        -- Get last cursor position from '" mark
        local ok, mark = pcall(vim.api.nvim_buf_get_mark, buf, '"')
        if not ok or not mark then
            return
        end

        local lcount = vim.api.nvim_buf_line_count(buf)

        -- Only restore if position is valid (within buffer bounds)
        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

----------------------------------------
-- Filetype-Specific Behavior
----------------------------------------

-- Close special buffers with 'q' key
-- Provides consistent quick-exit for temporary/auxiliary buffers
autocmd({ 'FileType' }, {
    group = augroup('close_with_q'),
    pattern = {
        'PlenaryTestPopup',
        'checkhealth',
        'dbout',
        'gitsigns-blame',
        'grug-far',
        'help',
        'lspinfo',
        'neotest-output',
        'neotest-output-panel',
        'neotest-summary',
        'notify',
        'qf',
        'query',
        'spectre_panel',
        'startuptime',
        'tsplayground',
        'oil',
    },
    callback = function(event)
        -- Don't show these buffers in buffer list
        vim.bo[event.buf].buflisted = false

        -- Schedule keymap creation to avoid conflicts during setup
        vim.schedule(function()
            vim.keymap.set('n', 'q', function()
                vim.cmd('close')
                -- Force delete buffer to free memory
                pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
            end, {
                buffer = event.buf,
                desc = 'Quit Buffer',
            })
        end)
    end,
})

-- Hide man pages from buffer list
-- Man pages are typically temporary reference, not part of workflow
autocmd({ 'FileType' }, {
    group = augroup('man_unlisted'),
    pattern = { 'man' },
    callback = function(event)
        vim.bo[event.buf].buflisted = false
    end,
})

-- Disable concealing in JSON files
-- JSON concealing can hide important syntax (quotes, braces)
autocmd({ 'FileType' }, {
    group = augroup('json_conceal'),
    pattern = { 'json', 'jsonc', 'json5' },
    callback = function()
        vim.opt_local.conceallevel = 0
    end,
})

----------------------------------------
-- LSP Cleanup
----------------------------------------

-- Gracefully stop all LSP clients before exiting Neovim
-- Prevents orphaned LSP server processes
autocmd({ 'VimLeavePre' }, {
    group = augroup('auto_stop_lsp'),
    callback = function()
        vim.iter(vim.lsp.get_clients()):each(function(client)
            client:stop()
        end)
    end,
})
