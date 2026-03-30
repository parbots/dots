vim.g.root_spec = { 'lsp', { '.git', 'lua' }, 'cwd' }
vim.g.root_lsp_ignore = {}

vim.g.lazydev_enabled = true
vim.g.autoformat = false
vim.g.picklevim_prettier_needs_config = false

vim.g.markdown_recommended_style = 0

vim.g.snacks_animate = true
vim.g.snacks_indent = true
vim.g.snacks_scope = true
vim.g.snacks_scroll = true

vim.g.hardtime_enabled = true

vim.g.loaded_netrw = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

local o, opt = vim.o, vim.opt

o.allowrevins = false
o.autochdir = false
o.autoread = true
o.autowrite = true
o.autowriteall = false
o.background = 'dark'
o.belloff = 'all'
o.confirm = true
o.emoji = true
o.hidden = false
o.history = 10000
o.magic = true
o.mouse = 'a'
o.mousefocus = false
o.mousehide = true
o.report = 2
o.startofline = false
o.timeout = true
o.timeoutlen = vim.g.vscode and 1000 or 300
o.ttimeout = true
o.ttimeoutlen = 50
o.updatetime = 1000
o.virtualedit = 'block'

-- Disable clipboard over SSH to avoid latency from remote clipboard sync
o.clipboard = vim.env.SSH_TTY and '' or 'unnamedplus'

o.hlsearch = true
o.ignorecase = true
o.inccommand = 'split'
o.incsearch = true
o.infercase = true
o.smartcase = true
o.gdefault = false
o.grepformat = '%f:%l:%c:%m'
o.grepprg = 'rg --vimgrep'

o.autoindent = true
o.breakindent = true
-- min:20 = minimum text width, shift:4 = extra indent for wrapped lines, list:-1 = match list indent
opt.breakindentopt = {
    'min:20',
    'shift:4',
    'list:-1',
}
o.copyindent = false
o.expandtab = true
o.shiftround = true
o.shiftwidth = 4
o.smartindent = true
o.smarttab = true
o.softtabstop = 4
o.tabstop = 4

o.backup = false
o.backupcopy = 'auto'
o.backupdir = '.,$XDG_STATE_HOME/nvim/backup//'
o.backupext = '~'
o.swapfile = true
o.undofile = true
o.undolevels = 10000
o.updatecount = 200
o.writebackup = true

o.cmdheight = 0
o.cmdwinheight = 3
o.conceallevel = 2
o.cursorline = true
o.cursorlineopt = 'both'
o.laststatus = 3
o.linebreak = true
o.list = true
opt.listchars = {
    tab = ' ',

    lead = '',
    trail = '',

    extends = '»',
    precedes = '«',

    nbsp = '×',
}
o.matchtime = 5
o.number = true
o.numberwidth = 3
o.pumblend = 0
o.pumheight = 15
o.pumwidth = 15
o.redrawtime = 200
o.relativenumber = true
o.ruler = false
o.scrolloff = 4
-- l:truncate file messages, t:truncate long messages, T:truncate middle of long messages,
-- o/O:overwrite file messages, C:no ins-completion messages, F:no file info on open,
-- m:use "[+]" for modified, w:use "[w]" for written, W:no "written" on write,
-- I:no intro message, c:no ins-completion messages, C:no scan messages
o.shortmess = 'ltToOCFmwWIcC'
o.showcmd = true
o.showmatch = true
o.showmode = false
o.showtabline = 1
o.sidescroll = 1
o.sidescrolloff = 8
o.signcolumn = 'yes'
o.smoothscroll = true
o.splitbelow = true
o.splitkeep = 'screen'
o.splitright = true
o.statuscolumn = [[%!v:lua.require'snacks.statuscolumn'.get()]]
o.synmaxcol = 3000
o.termguicolors = true
o.termsync = true
o.textwidth = 80
o.winborder = 'solid'
o.winminwidth = 5
o.wrap = false

opt.guicursor = {
    'n-sm:block',
    'v:hor50',
    'c-ci-cr-i-ve:ver10',
    'o-r:hor10',
    'a:Cursor/Cursor-blinkwait1-blinkon1-blinkoff1',
}

opt.backspace = {
    'indent',
    'eol',
    'start',
}

opt.casemap = {
    'internal',
    'keepascii',
}
o.fileignorecase = true
o.nrformats = 'alpha'

opt.fillchars = {
    eob = ' ',
    diff = '╱',

    fold = ' ',
    foldclose = '',
    foldopen = '',
    foldsep = ' ',

    msgsep = '━',

    horiz = ' ',
    horizup = ' ',
    horizdown = ' ',

    vert = ' ',
    vertleft = ' ',
    vertright = ' ',
    verthoriz = ' ',

    -- Alternative: box-drawing characters
    -- horiz = '━',
    -- horizup = '┻',
    -- horizdown = '┳',
    --
    -- vert = '┃',
    -- vertleft = '┫',
    -- vertright = '┣',
    -- verthoriz = '╋',
}

o.fixendofline = true
o.foldclose = ''
o.foldcolumn = 'auto'
o.foldenable = false
o.foldexpr = 'v:lua.PickleVim.ui.foldexpr()'
o.foldlevel = 99
o.foldmethod = 'expr'
o.foldtext = ''

o.formatexpr = 'v:lua.PickleVim.format.formatexpr()'
o.formatoptions = 'jcroqlnt'
o.fsync = true

o.wildmenu = true
o.wildmode = 'longest:full,full'

o.spelllang = 'en'

opt.jumpoptions = {
    'view',
    'clean',
}
opt.sessionoptions = {
    'buffers',
    'curdir',
    'folds',
    'globals',
    'help',
    'skiprtp',
    'tabpages',
}

vim.cmd.filetype('plugin indent on')
