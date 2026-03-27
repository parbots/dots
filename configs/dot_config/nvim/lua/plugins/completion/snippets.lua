--- LuaSnip - Snippet engine for Neovim
--- Powers snippet expansion in blink.cmp completion
--- Supports VSCode-style snippets and custom Lua snippets
---
--- Features:
---   - VSCode snippet format support
---   - Friendly-snippets collection (hundreds of built-in snippets)
---   - Custom snippets from ~/.config/nvim/snippets/
---   - Filetype-specific snippets with inheritance
---   - JavaScript regex support for advanced transformations
---
--- Filetype Inheritance:
---   - TypeScript inherits JavaScript snippets
---   - React (JSX/TSX) inherits JavaScript/TypeScript + HTML snippets
---
--- Snippet Sources:
---   1. friendly-snippets - Community-maintained snippet collection
---   2. Custom snippets in ~/.config/nvim/snippets/ (VSCode format)
---
--- Usage:
---   - Snippets appear in completion menu (via blink.cmp)
---   - <Tab> to expand and jump to next placeholder
---   - <S-Tab> to jump to previous placeholder
---   - Type trigger text and accept completion to expand

return {
    ----------------------------------------
    -- LuaSnip - Snippet Engine
    ----------------------------------------
    {
        'L3MON4D3/LuaSnip',
        lazy = true,  -- Loaded by blink.cmp when needed
        version = 'v2.*',  -- Use stable v2.x releases
        build = 'make install_jsregexp',  -- Build JavaScript regex support

        dependencies = {
            'rafamadriz/friendly-snippets',  -- Community snippet collection
        },

        opts = {},  -- Use default LuaSnip options

        ----------------------------------------
        -- Configuration
        ----------------------------------------
        config = function(_, opts)
            local luasnip = require('luasnip')
            luasnip.setup(opts)

            ----------------------------------------
            -- Filetype Inheritance
            ----------------------------------------
            -- Allow TypeScript to use JavaScript snippets
            luasnip.filetype_extend('typescript', { 'javascript' })

            -- Allow JSX to use JavaScript and HTML snippets
            luasnip.filetype_extend('javascriptreact', { 'javascript', 'html' })

            -- Allow TSX to use TypeScript and HTML snippets
            luasnip.filetype_extend('typescriptreact', { 'typescript', 'html' })

            ----------------------------------------
            -- Load Snippet Collections
            ----------------------------------------
            -- Load friendly-snippets (community collection)
            -- Lazy-loaded: snippets are loaded on demand per filetype
            require('luasnip.loaders.from_vscode').lazy_load()

            -- Load custom snippets from config directory
            -- Place VSCode-style snippets in ~/.config/nvim/snippets/
            require('luasnip.loaders.from_vscode').lazy_load({
                paths = { vim.fn.stdpath('config') .. '/snippets' },
            })
        end,
    },
}
