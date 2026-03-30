---@param name string Augroup name (will be prefixed with 'picklevim_')
---@return integer group Augroup ID
local augroup = function(name)
    return vim.api.nvim_create_augroup('picklevim_' .. name, { clear = true })
end

local autocmd = vim.api.nvim_create_autocmd

autocmd({ 'FocusGained', 'TermClose', 'TermLeave' }, {
    group = augroup('checktime'),
    callback = function()
        if vim.o.buftype ~= 'nofile' then
            vim.cmd('checktime')
        end
    end,
})

autocmd({ 'BufWritePre' }, {
    group = augroup('auto_create_dir'),
    callback = function(event)
        if event.match:match('^%w%w+:[\\/][\\/]') then
            return
        end

        local file = vim.uv.fs_realpath(event.match) or event.match
        vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
    end,
})

autocmd({ 'TextYankPost' }, {
    group = augroup('highlight_yank'),
    callback = function()
        vim.hl.on_yank({
            higroup = 'IncSearch',
            timeout = 200,
        })
    end,
})

autocmd({ 'VimResized' }, {
    group = augroup('resize_splits'),
    callback = function()
        vim.cmd('tabdo wincmd =')
        vim.cmd('tabnext ' .. vim.fn.tabpagenr())
    end,
})

autocmd({ 'BufReadPost' }, {
    group = augroup('last_loc'),
    callback = function(event)
        local exclude = { 'gitcommit' }
        local buf = event.buf

        if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].picklevim_last_loc then
            return
        end

        vim.b[buf].picklevim_last_loc = true

        local ok, mark = pcall(vim.api.nvim_buf_get_mark, buf, '"')
        if not ok or not mark then
            return
        end

        local lcount = vim.api.nvim_buf_line_count(buf)

        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

-- These are read-only or auxiliary filetypes where 'q' should close the buffer
-- rather than triggering macro recording
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
        vim.bo[event.buf].buflisted = false

        vim.schedule(function()
            vim.keymap.set('n', 'q', function()
                vim.cmd('close')
                pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
            end, {
                buffer = event.buf,
                desc = 'Quit Buffer',
            })
        end)
    end,
})

autocmd({ 'FileType' }, {
    group = augroup('man_unlisted'),
    pattern = { 'man' },
    callback = function(event)
        vim.bo[event.buf].buflisted = false
    end,
})

autocmd({ 'FileType' }, {
    group = augroup('json_conceal'),
    pattern = { 'json', 'jsonc', 'json5' },
    callback = function()
        vim.opt_local.conceallevel = 0
    end,
})

autocmd({ 'VimLeavePre' }, {
    group = augroup('auto_stop_lsp'),
    callback = function()
        vim.iter(vim.lsp.get_clients()):each(function(client)
            client:stop()
        end)
    end,
})
