if vim.loader then
    vim.loader.enable(true)
end

-- Setup lazy.nvim and initialize config and imports
require('config.lazy').setup({
    spec = {
        { import = 'plugins' }, -- Core plugins and config
        { import = 'plugins.coding' }, -- Language plugins and tools
        { import = 'plugins.completion' }, -- Blink.nvim and snippets
        { import = 'plugins.editor' }, -- Flash.nvim, find and replace, etc...
        { import = 'plugins.formatting' }, -- Conform.nvim and formatting utils
        { import = 'plugins.ui' }, -- Lualine, Bufferline, Noice, etc...
        { import = 'plugins.lsp' }, -- Mason, lspconfig, lsp utils
        { import = 'plugins.snacks' }, -- All snacks config
    },

    profiling = {
        loader = false,
        require = false,
    },
})
