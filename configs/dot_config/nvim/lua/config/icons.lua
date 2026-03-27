--- Icon definitions for PickleVim
--- Centralized icon repository used throughout the configuration
--- Provides consistent visual identity across plugins and UI components
--- All icons use Nerd Font symbols and require a patched font to display correctly
---
--- Usage:
---   local icons = require('config.icons')
---   print(icons.diagnostics.error)  -- ' '
---   print(icons.git.added)          -- ' '
---
--- Global access:
---   PickleVim.icons.diagnostics.error

---@class picklevim.icons
local M = {}

----------------------------------------
-- Filetype Icons
----------------------------------------
-- Icons specific to certain file types or plugins

M.ft = {
    octo = '', -- GitHub Octocat icon for octo.nvim (GitHub integration)
}

----------------------------------------
-- Diagnostic Icons
----------------------------------------
-- Used by LSP diagnostics, linters, and error displays
-- Appears in: sign column, statusline, floating windows, Trouble.nvim

M.diagnostics = {
    error = ' ', -- Critical errors that prevent functionality
    warn = ' ', -- Warnings that should be addressed
    hint = ' ', -- Suggestions for improvement
    info = ' ', -- Informational messages
}

----------------------------------------
-- Git Icons
----------------------------------------
-- Used by git integrations: Gitsigns, Neogit, Snacks.git, statusline
-- Appears in: sign column, statusline, git blame, diff views

M.git = {
    added = ' ', -- New lines added
    modified = ' ', -- Lines modified
    removed = ' ', -- Lines deleted
    commit = '󰜘 ', -- Commit symbol
    staged = '●', -- Files staged for commit
    ignored = ' ', -- Files in .gitignore
    renamed = '', -- Renamed files
    unmerged = ' ', -- Merge conflicts
    untracked = '?', -- Files not tracked by git
}

----------------------------------------
-- LSP Symbol Kinds
----------------------------------------
-- Used by completion menus, document symbols, aerial, outline
-- Maps to LSP CompletionItemKind and SymbolKind
-- Appears in: Blink.cmp, Telescope symbols, nvim-navic breadcrumbs

M.kinds = {
    Array = ' ',
    Boolean = '󰨙 ',
    Class = ' ',
    Codeium = '󰘦 ',
    Color = ' ',
    Control = ' ',
    Collapsed = ' ',
    Constant = '󰏿 ',
    Constructor = ' ',
    Copilot = ' ',
    Enum = ' ',
    EnumMember = ' ',
    Event = ' ',
    Field = ' ',
    File = ' ',
    Folder = ' ',
    Function = '󰊕 ',
    Interface = ' ',
    Key = ' ',
    Keyword = ' ',
    Method = '󰊕 ',
    Module = ' ',
    Namespace = '󰦮 ',
    Null = ' ',
    Number = '󰎠 ',
    Object = ' ',
    Operator = ' ',
    Package = ' ',
    Property = ' ',
    Reference = ' ',
    Snippet = '󱄽 ',
    String = ' ',
    Struct = '󰆼 ',
    Supermaven = ' ',
    TabNine = '󰏚 ',
    Text = ' ',
    TypeParameter = ' ',
    Unit = ' ',
    Value = ' ',
    Variable = '󰀫 ',
}

----------------------------------------
-- Miscellaneous Icons
----------------------------------------
-- General-purpose icons used in various contexts

M.misc = {
    dots = '󰇘', -- Ellipsis for truncated text or loading indicators
}

return M
