# PickleVim

A modern, modular Neovim configuration built for efficiency and productivity.

## Features

- **Plugin Management**: [Lazy.nvim](https://github.com/folke/lazy.nvim) with organized, modular specs
- **LSP Support**: Full LSP integration with Mason for automatic server installation
- **Modern Completion**: [Blink.cmp](https://github.com/Saghen/blink.cmp) - Rust-based completion engine with fuzzy matching
- **Code Formatting**: Conform.nvim with auto-format on save (toggle-able)
- **Syntax Highlighting**: Treesitter with incremental selection and text objects
- **UI Enhancements**: Lualine, Bufferline, Noice, and Dropbar breadcrumbs
- **Git Integration**: Gitsigns for inline git blame and LazyGit integration
- **File Navigation**: Snacks picker, Oil.nvim file browser
- **Theme**: Catppuccin (Mocha) with extensive plugin integrations
- **Utilities**: Snacks.nvim for dashboard, terminal, notifications, and more

## Requirements

- Neovim >= 0.11.0
- Git
- A [Nerd Font](https://www.nerdfonts.com/) for icons
- ripgrep (for grep/search functionality)
- fd (optional, for faster file finding)
- Node.js (for LSP servers)

## Installation

1. **Backup existing configuration**:
   ```bash
   mv ~/.config/nvim ~/.config/nvim.backup
   mv ~/.local/share/nvim ~/.local/share/nvim.backup
   ```

2. **Clone this repository**:
   ```bash
   git clone <your-repo-url> ~/.config/nvim
   ```

3. **Launch Neovim**:
   ```bash
   nvim
   ```
   Lazy.nvim will automatically install all plugins on first launch.

4. **Install LSP servers**:
   Most LSP servers will be installed automatically via Mason. You can manually manage them with:
   ```vim
   :Mason
   ```

## Key Bindings

### General
- **Leader Key**: `<Space>`
- **Local Leader**: `\`

### Navigation
- `<C-h/j/k/l>` - Navigate between windows
- `<S-h/l>` - Previous/next buffer
- `<leader>bb` - Switch to other buffer
- `<leader>bd` - Delete buffer

### File Operations
- `<C-s>` - Save file
- `<leader>ww` - Save file

### Search & Find
- `<leader>ff` - Find files
- `<leader>fg` - Grep search
- `<leader>fb` - Browse buffers
- `<leader>fr` - Recent files

### LSP
- `gd` - Go to definition
- `gD` - Go to declaration (TypeScript: source definition)
- `gr` - Go to references
- `gi` - Go to implementation
- `K` - Hover documentation
- `<leader>cr` - Rename symbol
- `<leader>ca` - Code action
- `<leader>cx` - Restart LSP servers

### TypeScript Specific
- `<leader>co` - Organize imports
- `<leader>cM` - Add missing imports
- `<leader>cu` - Remove unused imports
- `<leader>cD` - Fix all diagnostics
- `<leader>cV` - Select TypeScript version

### Formatting
- `<C-f>` - Format current buffer
- `<leader>cf` - Show formatter info
- Auto-format on save (disabled by default, see Formatting section below)

### Terminal
- `<C-/>` - Toggle floating terminal

### Git
- `<leader>gg` - LazyGit
- `]h` / `[h` - Next/previous git hunk
- `<leader>hs` - Stage hunk
- `<leader>hr` - Reset hunk
- `<leader>hb` - Git blame line

### Windows & Tabs
- `<leader>-` - Split window below
- `<leader>|` - Split window right
- `<leader>wd` - Delete window
- `<leader><tab><tab>` - New tab
- `<leader><tab>d` - Close tab

### Misc
- `<leader>qq` - Quit all
- `<leader>ui` - Inspect position (Treesitter)
- `<leader>ur` - Clear hlsearch / redraw

## Configuration Structure

```
~/.config/nvim/
├── init.lua                    # Entry point
├── lazy-lock.json              # Plugin versions lock file
├── lua/
│   ├── config/                 # Core configuration
│   │   ├── init.lua            # Main config module
│   │   ├── lazy.lua            # Lazy.nvim setup
│   │   ├── options.lua         # Vim options
│   │   ├── keymaps.lua         # Key bindings
│   │   ├── autocmds.lua        # Auto commands
│   │   └── icons.lua           # Icon definitions
│   ├── utils/                  # Utility modules
│   │   ├── init.lua            # Main utils (PickleVim namespace)
│   │   ├── lsp/                # LSP utilities
│   │   ├── formatting/         # Formatting system
│   │   └── ...
│   └── plugins/                # Plugin specifications
│       ├── coding/             # Language tools
│       ├── completion/         # Completion engine
│       ├── editor/             # Editor enhancements
│       ├── formatting/         # Formatter config
│       ├── lsp/                # LSP configuration
│       ├── snacks/             # Snacks.nvim modules
│       └── ui/                 # UI plugins
```

## Customization

### Adding a Plugin

Create a new file in the appropriate `lua/plugins/*/` directory:

```lua
-- lua/plugins/editor/my-plugin.lua
return {
  'author/plugin-name',
  event = 'VeryLazy',
  opts = {
    -- plugin options
  },
  keys = {
    { '<leader>mp', '<cmd>MyPlugin<cr>', desc = 'My Plugin' },
  },
}
```

The plugin will be automatically loaded based on the import structure in `init.lua`.

### Adding an LSP Server

1. Add configuration to `lua/utils/lsp/servers.lua`:
   ```lua
   M.servers = {
     your_server = {
       settings = {
         -- server-specific settings
       },
     },
   }
   ```

2. Mason will automatically install it, or install manually with `:Mason`.

### Adding a Formatter

1. Add to `lua/utils/formatting/formatters.lua`:
   ```lua
   PickleVim.formatting.register({
     name = 'your_formatter',
     primary = true,
     sources = { 'conform' },
     priority = 100,
     ft = { 'yourfiletype' },
   })
   ```

2. Configure in Conform.nvim (`lua/plugins/formatting/conform.lua`).

### Changing Theme

Edit `lua/config/init.lua`:
```lua
local defaults = {
  colorscheme = 'your-theme',
  -- ...
}
```

### Modifying Keymaps

- **Global keymaps**: Edit `lua/config/keymaps.lua`
- **Plugin-specific keymaps**: Add `keys = {}` table in plugin spec
- **LSP keymaps**: Edit `lua/utils/lsp/keymaps.lua`

## Supported Languages

LSP servers are configured for:
- TypeScript/JavaScript (vtsls)
- Lua (lua_ls)
- Rust (rust-analyzer via rustaceanvim)
- Python (basedpyright)
- HTML/CSS (html, cssls)
- JSON/YAML (jsonls, yamlls)
- Astro, MDX, SQL, TOML

Formatters available for:
- Lua (stylua)
- Rust (rustfmt)
- TOML (taplo)
- Shell (shfmt)
- And more via Conform.nvim

## Commands

### Custom Commands
- `:PickleFormat` - Format current buffer (force)
- `:PickleFormatInfo` - Show available formatters for current buffer
- `:PickleRoot` - Display detected project root

### Plugin Management
- `:Lazy` - Open Lazy.nvim UI
- `:Lazy update` - Update all plugins
- `:Lazy sync` - Sync plugins with lock file
- `:Lazy clean` - Remove unused plugins

### LSP
- `:LspInfo` - Show attached LSP clients
- `:LspRestart` - Restart LSP servers
- `:Mason` - Open Mason UI for managing LSP servers

## Troubleshooting

### Plugins not loading
```vim
:Lazy restore  " Restore plugins from lock file
:Lazy sync     " Sync plugins
```

### LSP not working
```vim
:LspInfo       " Check if LSP is attached
:Mason         " Install missing servers
:checkhealth   " Check Neovim health
```

### Formatting not working
```vim
:PickleFormatInfo          " Check available formatters
:lua vim.print(vim.g.autoformat)  " Check if auto-format is enabled
:lua vim.g.autoformat = true      " Enable auto-format globally
:lua vim.b.autoformat = true      " Enable auto-format for current buffer
```

### Clear cache and reset
```bash
rm -rf ~/.local/share/nvim
rm -rf ~/.local/state/nvim
nvim  # Reinstall everything
```

## Performance

This configuration is optimized for fast startup:
- Lazy loading for most plugins
- Vim loader enabled for faster module loading
- Custom LazyFile event for file-related plugins
- Minimal plugins loaded at startup (mainly Snacks.nvim)

Check startup time:
```bash
nvim --startuptime startup.log
```

## Credits

Built with:
- [Lazy.nvim](https://github.com/folke/lazy.nvim) - Plugin manager
- [Snacks.nvim](https://github.com/folke/snacks.nvim) - Utility suite
- [Blink.cmp](https://github.com/Saghen/blink.cmp) - Completion engine
- [Catppuccin](https://github.com/catppuccin/nvim) - Theme
- And many more excellent plugins

## License

MIT
