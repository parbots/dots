--- Neovim options configuration
--- Sets up all vim options, globals, and editor behavior
--- Organized into logical sections for readability

----------------------------------------
-- PickleVim Global Settings
----------------------------------------
-- Root detection configuration (see lua/utils/root.lua)
vim.g.root_spec = { 'lsp', { '.git', 'lua' }, 'cwd' }
vim.g.root_lsp_ignore = {} -- LSP servers to ignore for root detection (e.g., {'null-ls'})

-- Plugin feature toggles
vim.g.lazydev_enabled = true -- Enable lazydev for Neovim Lua development
vim.g.autoformat = false -- Auto-format on save (toggle with PickleVim.formatting.toggle())
vim.g.picklevim_prettier_needs_config = false -- Prettier behavior

-- Markdown settings
vim.g.markdown_recommended_style = 0 -- Disable markdown recommended indent

-- Snacks.nvim feature toggles
vim.g.snacks_animate = true -- Enable animations
vim.g.snacks_indent = true -- Enable indent guides
vim.g.snacks_scope = true -- Enable scope highlighting
vim.g.snacks_scroll = true -- Enable smooth scrolling

-- Plugin settings
vim.g.hardtime_enabled = true -- Enable hardtime.nvim

----------------------------------------
-- Disable Built-in Plugins
----------------------------------------
vim.g.loaded_netrw = 0 -- Using Oil.nvim instead
vim.g.loaded_perl_provider = 0 -- Don't load Perl provider
vim.g.loaded_ruby_provider = 0 -- Don't load Ruby provider

----------------------------------------
-- Vim Options
----------------------------------------
local o, opt = vim.o, vim.opt

----------------------------------------
-- General Editor Behavior
----------------------------------------
o.allowrevins = false -- Don't allow reverse insert mode
o.autochdir = false -- Don't auto change directory
o.autoread = true -- Auto reload files changed outside vim
o.autowrite = true -- Auto write before :next, :make, etc.
o.autowriteall = false -- Don't write on every command
o.background = 'dark' -- Dark background
o.belloff = 'all' -- Disable all bells
o.confirm = true -- Confirm before closing unsaved buffers
o.emoji = true -- Enable emoji support
o.hidden = false -- Don't keep hidden buffers
o.history = 10000 -- Command history size
o.magic = true -- Use magic patterns in search
o.mouse = 'a' -- Enable mouse in all modes
o.mousefocus = false -- Don't auto focus on mouse hover
o.mousehide = true -- Hide mouse when typing
o.report = 2 -- Report on 2+ lines changed
o.startofline = false -- Keep cursor column when moving
o.timeout = true -- Enable timeout for mappings
o.timeoutlen = vim.g.vscode and 1000 or 300 -- Timeout length (300ms, 1000ms in VSCode)
o.ttimeout = true -- Enable timeout for key codes
o.ttimeoutlen = 50 -- Key code timeout (50ms)
o.updatetime = 1000 -- CursorHold delay and swap write interval
o.virtualedit = 'block' -- Allow cursor beyond end of line in visual block mode

----------------------------------------
-- Clipboard
----------------------------------------
o.clipboard = vim.env.SSH_TTY and '' or 'unnamedplus' -- Use system clipboard (disabled in SSH)

----------------------------------------
-- Search
----------------------------------------
o.hlsearch = true -- Highlight search matches
o.ignorecase = true -- Ignore case in search
o.inccommand = 'split' -- Live preview of substitution in split
o.incsearch = true -- Incremental search
o.infercase = true -- Infer case in completion
o.smartcase = true -- Override ignorecase if search has uppercase
o.gdefault = false -- Don't default to global substitution
o.grepformat = '%f:%l:%c:%m'
o.grepprg = 'rg --vimgrep'

----------------------------------------
-- Indentation
----------------------------------------
o.autoindent = true -- Copy indent from current line
o.breakindent = true -- Wrapped lines continue indent
opt.breakindentopt = { -- Breakindent options
    'min:20',
    'shift:4',
    'list:-1',
}
o.copyindent = false -- Don't copy exact indent structure
o.expandtab = true -- Use spaces instead of tabs
o.shiftround = true -- Round indent to multiple of shiftwidth
o.shiftwidth = 4 -- Indent width
o.smartindent = true -- Smart autoindenting
o.smarttab = true -- Smart tab behavior
o.softtabstop = 4 -- Spaces for <Tab> in insert mode
o.tabstop = 4 -- Tab display width

----------------------------------------
-- Backups and Undo
----------------------------------------
o.backup = false -- Don't keep backup files
o.backupcopy = 'auto' -- Auto backup strategy
o.backupdir = '.,$XDG_STATE_HOME/nvim/backup//'
o.backupext = '~' -- Backup file extension
o.swapfile = true -- Use swap files
o.undofile = true -- Persistent undo
o.undolevels = 10000 -- Maximum undo levels
o.updatecount = 200 -- Update swap after 200 chars
o.writebackup = true -- Make backup before overwriting

----------------------------------------
-- UI and Appearance
----------------------------------------
o.cmdheight = 0 -- Hide command line when not used
o.cmdwinheight = 3 -- Command window height
o.conceallevel = 2 -- Conceal level for markdown, etc.
o.cursorline = true -- Highlight cursor line
o.cursorlineopt = 'both' -- Highlight both line and number
o.laststatus = 3 -- Global statusline
o.linebreak = true -- Break lines at word boundaries
o.list = true -- Show invisible characters
opt.listchars = { -- Invisible character display
    tab = ' ',

    lead = '',
    trail = '',

    extends = '»',
    precedes = '«',

    nbsp = '×',
}
o.matchtime = 5 -- Tenths of a second to show matching bracket
o.number = true -- Show line numbers
o.numberwidth = 3 -- Line number column width
o.pumblend = 10 -- Popup menu transparency
o.pumheight = 15 -- Max popup menu height
o.pumwidth = 15 -- Popup menu width
o.redrawtime = 200 -- Max time for syntax highlighting redraw
o.relativenumber = true -- Relative line numbers
o.ruler = false -- Don't show ruler (using statusline)
o.scrolloff = 4 -- Keep 4 lines above/below cursor
o.shortmess = 'ltToOCFmwWIcC' -- Shorten various messages
o.showcmd = true -- Show command in status line
o.showmatch = true -- Highlight matching brackets
o.showmode = false -- Don't show mode (using statusline)
o.showtabline = 1 -- Show tabline only if multiple tabs
o.sidescroll = 1 -- Horizontal scroll increment
o.sidescrolloff = 8 -- Keep 8 columns beside cursor
o.signcolumn = 'yes' -- Always show sign column
o.smoothscroll = true -- Smooth scrolling
o.splitbelow = true -- Horizontal splits below
o.splitkeep = 'screen' -- Keep screen position on split
o.splitright = true -- Vertical splits right
o.statuscolumn = [[%!v:lua.require'snacks.statuscolumn'.get()]] -- Custom status column
o.synmaxcol = 3000 -- Max column for syntax highlighting
o.termguicolors = true -- Enable 24-bit RGB colors
o.termsync = true -- Sync terminal output
o.textwidth = 80 -- Text width for formatting
o.winminwidth = 5 -- Minimum window width
o.wrap = false -- Don't wrap lines

----------------------------------------
-- Cursor
----------------------------------------
opt.guicursor = {
    'n-sm:block',
    'v:hor50',
    'c-ci-cr-i-ve:ver10',
    'o-r:hor10',
    'a:Cursor/Cursor-blinkwait1-blinkon1-blinkoff1',
}

----------------------------------------
-- Backspace Behavior
----------------------------------------
opt.backspace = {
    'indent',
    'eol',
    'start',
}

----------------------------------------
-- Case and Character Handling
----------------------------------------
opt.casemap = {
    'internal',
    'keepascii',
}
o.fileignorecase = true -- Ignore case in file/directory names
o.nrformats = 'alpha' -- Increment/decrement letters with <C-a>/<C-x>

----------------------------------------
-- Fill Characters
----------------------------------------
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

----------------------------------------
-- Folding
----------------------------------------
o.fixendofline = true
o.foldclose = ''
o.foldcolumn = 'auto'
o.foldenable = false
o.foldexpr = 'v:lua.PickleVim.ui.foldexpr()'
o.foldlevel = 99
o.foldmethod = 'expr'
o.foldtext = '' -- Use default (more performant in Neovim 0.10+)

----------------------------------------
-- Formatting
----------------------------------------
o.formatexpr = 'v:lua.PickleVim.format.formatexpr()'
o.formatoptions = 'jcroqlnt'
o.fsync = true

----------------------------------------
-- Completion and Wildmenu
----------------------------------------
o.wildmenu = true -- Enhanced command-line completion
o.wildmode = 'longest:full,full' -- Complete longest common string, then full match

----------------------------------------
-- Spelling
----------------------------------------
o.spelllang = 'en'

----------------------------------------
-- Jump and Session
----------------------------------------
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
