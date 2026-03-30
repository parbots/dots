return {
    {
        'folke/which-key.nvim',
        opts = {
            spec = {
                { '<C-Space>', desc = 'Increment Selection', mode = { 'x', 'n' } },
                { '<BS>', desc = 'Decrement Selection', mode = 'x' },
            },
        },
    },

    {
        'nvim-treesitter/nvim-treesitter',
        branch = 'main',
        build = ':TSUpdate',
        lazy = false,
        cmd = { 'TSUpdate', 'TSInstall', 'TSUninstall' },

        config = function()
            require('nvim-treesitter').setup({})

            local installed = require('nvim-treesitter').get_installed()
            if #installed == 0 then
                require('nvim-treesitter').install('stable')
            end

            vim.api.nvim_create_autocmd('FileType', {
                group = vim.api.nvim_create_augroup('picklevim_treesitter', { clear = true }),
                callback = function(args)
                    local buf = args.buf

                    if vim.bo[buf].buftype ~= '' then
                        return
                    end

                    if vim.treesitter.get_parser(buf) then
                        -- Some built-in ftplugins call vim.treesitter.start() automatically
                        pcall(vim.treesitter.start, buf)

                        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                    end
                end,
            })

            local selection_node = nil

            local function init_or_increment_selection()
                local node = vim.treesitter.get_node()
                if not node then
                    return
                end

                local mode = vim.fn.mode()
                if mode == 'n' then
                    selection_node = node
                    local sr, sc, er, ec = node:range()
                    vim.fn.setpos("'<", { 0, sr + 1, sc + 1, 0 })
                    vim.fn.setpos("'>", { 0, er + 1, ec, 0 })
                    vim.cmd('normal! gv')
                    return
                end

                if selection_node then
                    local parent = selection_node:parent()
                    if parent then
                        selection_node = parent
                    end
                else
                    selection_node = node
                end

                local sr, sc, er, ec = selection_node:range()
                vim.fn.setpos("'<", { 0, sr + 1, sc + 1, 0 })
                vim.fn.setpos("'>", { 0, er + 1, ec, 0 })
                vim.cmd('normal! gv')
            end

            local function decrement_selection()
                if not selection_node then
                    return
                end

                local child = nil
                for i = 0, selection_node:named_child_count() - 1 do
                    child = selection_node:named_child(i)
                    if child then
                        break
                    end
                end

                if child then
                    selection_node = child
                else
                    return
                end

                local sr, sc, er, ec = selection_node:range()
                vim.fn.setpos("'<", { 0, sr + 1, sc + 1, 0 })
                vim.fn.setpos("'>", { 0, er + 1, ec, 0 })
                vim.cmd('normal! gv')
            end

            vim.api.nvim_create_autocmd('ModeChanged', {
                group = vim.api.nvim_create_augroup('picklevim_ts_selection_reset', { clear = true }),
                pattern = '[vV\x16]*:n',
                callback = function()
                    selection_node = nil
                end,
            })

            vim.keymap.set({ 'n', 'x' }, '<C-Space>', init_or_increment_selection, { desc = 'Increment Selection' })
            vim.keymap.set('x', '<BS>', decrement_selection, { desc = 'Decrement Selection' })
        end,
    },

    {
        'nvim-treesitter/nvim-treesitter-textobjects',
        branch = 'main',
        event = { 'LazyFile' },
        dependencies = {
            'nvim-treesitter/nvim-treesitter',
        },

        config = function()
            local move = require('nvim-treesitter-textobjects.move')

            require('nvim-treesitter-textobjects').setup({
                move = {
                    set_jumps = true,
                },
            })

            vim.keymap.set({ 'n', 'x', 'o' }, ']f', function()
                move.goto_next_start('@function.outer', 'textobjects')
            end, { desc = 'Next Function Start' })

            vim.keymap.set({ 'n', 'x', 'o' }, ']c', function()
                move.goto_next_start('@class.outer', 'textobjects')
            end, { desc = 'Next Class Start' })

            vim.keymap.set({ 'n', 'x', 'o' }, ']a', function()
                move.goto_next_start('@parameter.inner', 'textobjects')
            end, { desc = 'Next Parameter Start' })

            vim.keymap.set({ 'n', 'x', 'o' }, ']F', function()
                move.goto_next_end('@function.outer', 'textobjects')
            end, { desc = 'Next Function End' })

            vim.keymap.set({ 'n', 'x', 'o' }, ']C', function()
                move.goto_next_end('@class.outer', 'textobjects')
            end, { desc = 'Next Class End' })

            vim.keymap.set({ 'n', 'x', 'o' }, ']A', function()
                move.goto_next_end('@parameter.inner', 'textobjects')
            end, { desc = 'Next Parameter End' })

            vim.keymap.set({ 'n', 'x', 'o' }, '[f', function()
                move.goto_previous_start('@function.outer', 'textobjects')
            end, { desc = 'Prev Function Start' })

            vim.keymap.set({ 'n', 'x', 'o' }, '[c', function()
                move.goto_previous_start('@class.outer', 'textobjects')
            end, { desc = 'Prev Class Start' })

            vim.keymap.set({ 'n', 'x', 'o' }, '[a', function()
                move.goto_previous_start('@parameter.inner', 'textobjects')
            end, { desc = 'Prev Parameter Start' })

            vim.keymap.set({ 'n', 'x', 'o' }, '[F', function()
                move.goto_previous_end('@function.outer', 'textobjects')
            end, { desc = 'Prev Function End' })

            vim.keymap.set({ 'n', 'x', 'o' }, '[C', function()
                move.goto_previous_end('@class.outer', 'textobjects')
            end, { desc = 'Prev Class End' })

            vim.keymap.set({ 'n', 'x', 'o' }, '[A', function()
                move.goto_previous_end('@parameter.inner', 'textobjects')
            end, { desc = 'Prev Parameter End' })

            -- In diff mode, ]c/[c fall back to vim's native diff navigation
            local orig_next_class = move.goto_next_start
            local orig_prev_class = move.goto_previous_start

            vim.keymap.set({ 'n', 'x', 'o' }, ']c', function()
                if vim.wo.diff then
                    vim.cmd('normal! ]c')
                else
                    orig_next_class('@class.outer', 'textobjects')
                end
            end, { desc = 'Next Class / Diff Hunk' })

            vim.keymap.set({ 'n', 'x', 'o' }, '[c', function()
                if vim.wo.diff then
                    vim.cmd('normal! [c')
                else
                    orig_prev_class('@class.outer', 'textobjects')
                end
            end, { desc = 'Prev Class / Diff Hunk' })
        end,
    },

    {
        'windwp/nvim-ts-autotag',
        ft = { 'html', 'xml', 'astro', 'javascriptreact', 'typescriptreact', 'svelte', 'vue', 'markdown' },

        opts = {
            opts = {
                enable_close = true,
                enable_rename = true,
                enable_close_on_slash = true,
            },
        },
    },
}
