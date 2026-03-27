--- Global keymaps configuration
--- Defines all non-plugin-specific key mappings
--- Plugin-specific mappings are defined in their respective plugin specs
--- LSP mappings are defined in lua/utils/lsp/keymaps.lua

local map = vim.keymap.set

----------------------------------------
-- Better Movement
----------------------------------------
-- Use gj/gk for display line movement (respects word wrap)
map({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { desc = 'Down', expr = true, silent = true })
map({ 'n', 'x' }, '<Down>', "v:count == 0 ? 'gj' : 'j'", { desc = 'Down', expr = true, silent = true })
map({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { desc = 'Up', expr = true, silent = true })
map({ 'n', 'x' }, '<Up>', "v:count == 0 ? 'gk' : 'k'", { desc = 'Up', expr = true, silent = true })

----------------------------------------
-- Window Navigation
----------------------------------------
map('n', '<C-h>', '<C-w>h', { desc = 'Go to Left Window', remap = true })
map('n', '<C-j>', '<C-w>j', { desc = 'Go to Lower Window', remap = true })
map('n', '<C-k>', '<C-w>k', { desc = 'Go to Upper Window', remap = true })
map('n', '<C-l>', '<C-w>l', { desc = 'Go to Right Window', remap = true })

----------------------------------------
-- Buffer Navigation and Management
----------------------------------------
map('n', '<S-h>', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
map('n', '<S-l>', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
map('n', '[b', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
map('n', ']b', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
map('n', '<leader>bb', '<cmd>e #<cr>', { desc = 'Switch to Other Buffer' })
map('n', '<leader>`', '<cmd>e #<cr>', { desc = 'Switch to Other Buffer' })
map('n', '<leader>bd', function()
    Snacks.bufdelete()
end, { desc = 'Delete Buffer' })
map('n', '<leader>bx', function()
    Snacks.bufdelete()
end, { desc = 'Delete Buffer' })
map('n', '<leader>bo', function()
    Snacks.bufdelete.other()
end, { desc = 'Delete Other Buffers' })
map('n', '<leader>bD', '<cmd>:bd<cr>', { desc = 'Delete Buffer and Window' })

----------------------------------------
-- Search and Highlighting
----------------------------------------
-- Escape clears search highlighting
map({ 'i', 'n', 's' }, '<esc>', function()
    vim.cmd('noh')
    return '<esc>'
end, { expr = true, desc = 'Escape and Clear hlsearch' })

-- Clear search, update diff, and redraw screen
map(
    'n',
    '<leader>ur',
    '<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>',
    { desc = 'Redraw / Clear hlsearch / Diff Update' }
)

-- Consistent search direction (n always forward, N always backward)
-- Also centers cursor and opens folds
-- Source: https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
map('n', 'n', "'Nn'[v:searchforward].'zzzv'", { expr = true, desc = 'Next Search Result' })
map('x', 'n', "'Nn'[v:searchforward]", { expr = true, desc = 'Next Search Result' })
map('o', 'n', "'Nn'[v:searchforward]", { expr = true, desc = 'Next Search Result' })
map('n', 'N', "'nN'[v:searchforward].'zzzv'", { expr = true, desc = 'Prev Search Result' })
map('x', 'N', "'nN'[v:searchforward]", { expr = true, desc = 'Prev Search Result' })
map('o', 'N', "'nN'[v:searchforward]", { expr = true, desc = 'Prev Search Result' })

----------------------------------------
-- Editing
----------------------------------------
-- Add undo break-points at punctuation for better undo granularity
map('i', ',', ',<c-g>u')
map('i', '.', '.<c-g>u')
map('i', ';', ';<c-g>u')

-- Save file
map({ 'i', 'x', 'n', 's' }, '<C-s>', '<cmd>w<cr><esc>', { desc = 'Save File' })
map('n', '<leader>ww', '<CMD>write<CR><ESC>', { desc = 'Save File' })

-- Better visual indenting (maintains selection)
map('v', '<', '<gv')
map('v', '>', '>gv')

----------------------------------------
-- Application
----------------------------------------
map('n', '<leader>qq', '<cmd>qa<cr>', { desc = 'Quit All' })

----------------------------------------
-- Inspection and Debugging
----------------------------------------
map('n', '<leader>ui', vim.show_pos, { desc = 'Inspect Pos' })
map('n', '<leader>uI', function()
    vim.treesitter.inspect_tree()
    vim.api.nvim_input('I')
end, { desc = 'Inspect Tree' })

----------------------------------------
-- Terminal
----------------------------------------
map('n', '<c-/>', function()
    Snacks.terminal(nil, { cwd = PickleVim.root() })
end, { desc = 'Terminal (Root Dir)' })

-- Terminal Mappings
map('t', '<C-/>', '<cmd>close<cr>', { desc = 'Hide Terminal' })

-- windows
map('n', '<leader>-', '<C-W>s', { desc = 'Split Window Below', remap = true })
map('n', '<leader>|', '<C-W>v', { desc = 'Split Window Right', remap = true })
map('n', '<leader>wd', '<C-W>c', { desc = 'Delete Window', remap = true })

-- tabs
map('n', '<leader><tab>l', '<cmd>tablast<cr>', { desc = 'Last Tab' })
map('n', '<leader><tab>o', '<cmd>tabonly<cr>', { desc = 'Close Other Tabs' })
map('n', '<leader><tab>f', '<cmd>tabfirst<cr>', { desc = 'First Tab' })
map('n', '<leader><tab><tab>', '<cmd>tabnew<cr>', { desc = 'New Tab' })
map('n', '<leader><tab>]', '<cmd>tabnext<cr>', { desc = 'Next Tab' })
map('n', '<leader><tab>d', '<cmd>tabclose<cr>', { desc = 'Close Tab' })
map('n', '<leader><tab>[', '<cmd>tabprevious<cr>', { desc = 'Previous Tab' })

-- lsp
map('n', '<leader>cx', function()
    PickleVim.lsp.restart()
end, { desc = 'Restart LSP servers' })
