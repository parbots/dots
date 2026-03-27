# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is **PickleVim**, a comprehensive Neovim configuration built on **Lazy.nvim** with a modular architecture. The configuration is organized into logical categories with a global `PickleVim` namespace providing centralized utilities.

## Architecture

### Entry Point & Plugin Loading
- `init.lua` bootstraps Lazy.nvim and loads plugin specs from organized categories
- `lua/config/lazy.lua` configures Lazy.nvim and initializes the main config module
- `lua/config/init.lua` sets up the `PickleVim` global namespace and core configuration

### Plugin Organization
Plugins are organized into categories, each imported as a separate spec:
- `plugins/` - Core plugins (snacks.nvim, plenary, web-devicons)
- `plugins/coding/` - Language tools (treesitter, ts-comments, lazydev)
- `plugins/completion/` - Blink.cmp completion engine and snippets
- `plugins/editor/` - Navigation and editing tools (flash, todo-comments, grug-far)
- `plugins/formatting/` - Conform.nvim formatter
- `plugins/ui/` - Visual enhancements (lualine, bufferline, noice, dropbar)
- `plugins/lsp/` - LSP configuration (mason, lspconfig, trouble)
- `plugins/snacks/` - Modular snacks.nvim configurations

### Global Namespace: `PickleVim`
The `PickleVim` global table (defined in `lua/utils/init.lua`) provides centralized utilities:
- `PickleVim.config` - Configuration system
- `PickleVim.icons` - Icon definitions
- `PickleVim.formatting` - Formatter registry and management
- `PickleVim.lsp` - LSP utilities and callbacks
- `PickleVim.root` - Project root detection
- `PickleVim.plugin` - Plugin management helpers
- `PickleVim.ui` - UI utilities (folding, etc)

The namespace uses a metatable to lazy-load utility modules from `lua/utils/`.

## LSP Configuration

### Server Setup
LSP servers are configured in `lua/utils/lsp/servers.lua` with detailed per-server settings. Key servers include:
- **vtsls** - TypeScript/JavaScript (enhanced)
- **lua_ls** - Lua with workspace and diagnostic settings
- **jsonls** - JSON with schema validation
- **cssls, html, astro, mdx_analyzer** - Web development
- **sqlls, yamlls, taplo** - Data formats

### LSP Core System (`lua/utils/lsp/init.lua`)
- `on_attach()` - Register LSP callbacks per buffer/client
- `on_supports_method()` - Feature-gated functionality based on capabilities
- `action()` - Dynamic code action execution
- `execute()` - Execute workspace commands

### Language-Specific Features
**TypeScript** (`lua/plugins/lsp/typescript.lua`):
- Extended commands for source definition, file references, organize/add/remove imports
- Fix all diagnostics, select TS version
- Monorepo and package manager detection

**Rust** (`lua/plugins/lsp/rust.lua`):
- Configured via rustaceanvim with separate LSP client

## Formatting System

### Architecture
The formatting system (`lua/utils/formatting/init.lua`) provides:
- **Formatter Registry**: Priority-based formatter resolution per buffer
- **Auto-format on Save**: Controlled via `vim.g.autoformat` (global) and `vim.b.autoformat` (buffer-local)
- **Format Commands**: `:PickleFormat` (force format) and `:PickleFormatInfo` (show available formatters)

### Formatter Definitions
Formatters are defined in `lua/utils/formatting/formatters.lua`:
- lua → stylua
- toml → taplo
- rust → rustfmt
- shell → shfmt
- all → trim (custom whitespace handler: converts tabs to spaces, trims trailing whitespace, reduces consecutive empty lines to one, removes trailing newlines)

### Conform.nvim Integration
`lua/plugins/formatting/conform.lua` integrates Conform.nvim with the registry system. Formatting is triggered via:
- Auto-format on save (when enabled)
- `<C-f>` keybinding
- `:PickleFormat` command

### Formatting API
- `PickleVim.formatting.format(opts?)` - Format buffer (respects autoformat setting unless `opts.force = true`)
- `PickleVim.formatting.toggle(buf?)` - Toggle autoformat (global if buf is nil, buffer-local if buf number provided)
- `PickleVim.formatting.enable(enable?, buf?)` - Enable/disable autoformat (global if buf is nil, buffer-local if buf number provided)
- `PickleVim.formatting.enabled(buf?)` - Check if autoformat is enabled for buffer
- `PickleVim.formatting.info(buf?)` - Display formatter info for buffer

## Root Detection

The root detection system (`lua/utils/root.lua`) intelligently finds project roots using multiple strategies:
1. LSP workspace folders
2. Git directories (`.git`)
3. Pattern matching (configurable via `vim.g.root_spec`)
4. Current working directory (fallback)

Results are cached per buffer for performance. Use `:PickleRoot` to display detected root.

### Root Detection API
- `PickleVim.root.get(opts?)` - Get root directory for buffer (cached, respects normalize option)
- `PickleVim.root.get_default()` - Get default root (first detected root or cwd, uncached)
- `PickleVim.root.detect(opts?)` - Detect all matching roots for buffer
- `PickleVim.root.info()` - Display root detection information
- `PickleVim.root.git()` - Get git root directory
- `PickleVim.root.cwd()` - Get current working directory (normalized)

## Configuration Files

### Core Configuration
- `lua/config/options.lua` - All Vim options (leader keys, UI settings, editing behavior)
- `lua/config/keymaps.lua` - Global keybindings
- `lua/config/autocmds.lua` - Auto commands
- `lua/config/icons.lua` - Icon definitions used throughout

### Key Settings
- Leader key: `<Space>`
- Local leader: `\`
- Auto-format: Disabled by default (`vim.g.autoformat = false`)
- Colorscheme: Catppuccin (mocha flavor)
- Root spec: `{ 'lsp', { '.git', 'lua' }, 'cwd' }`
- Root LSP ignore: `{}` - List of LSP server names to exclude from root detection (e.g., `{ 'tsserver', 'null-ls' }`)

## Plugin Utilities (`lua/utils/plugin.lua`)

- `PickleVim.plugin.has(name)` - Check if plugin is installed
- `PickleVim.plugin.get(name)` - Get plugin spec
- `PickleVim.plugin.opts(name)` - Get plugin options
- `PickleVim.plugin.setup_lazy_file()` - Custom LazyFile event for better lazy loading

## Completion System

Uses **Blink.cmp** (Rust-based completion engine) configured in `lua/plugins/completion/blink.lua`:
- Sources: LSP, lazydev, snippets, path, buffer
- Ghost text for AI-like completion preview
- Fuzzy matching with frecency and proximity
- Signature help with border and treesitter highlighting

Snippets via **LuaSnip** with friendly-snippets integration.

## Common Patterns

### Lazy Loading
- Most plugins are lazy-loaded via events, keys, or commands
- Custom `LazyFile` event used for file-related plugins
- `VeryLazy` event for deferred setup

### Error Handling
Use `PickleVim.try()` for safe execution:
```lua
PickleVim.try(function()
  -- code
end, {
  msg = 'Error message',
  on_error = function(msg) end
})
```

### Conditional Setup
Use `PickleVim.on_load(plugin_name, callback)` for plugin-specific initialization:
```lua
PickleVim.on_load('nvim-cmp', function()
  -- setup code
end)
```

## Modifying the Configuration

### Adding a New Plugin
1. Create a spec file in the appropriate `lua/plugins/*/` directory
2. Return a Lazy.nvim spec table with plugin URL, dependencies, config, keys, etc.
3. The spec will be auto-imported based on the directory structure defined in `init.lua`

### Adding an LSP Server
1. Add server configuration to `lua/utils/lsp/servers.lua`
2. Mason will auto-install if configured in `lua/plugins/lsp/init.lua`
3. Language-specific setup goes in `lua/plugins/lsp/<language>.lua`

### Adding a Formatter
1. Define formatter in `lua/utils/formatting/formatters.lua`
2. Register it with `PickleVim.formatting.register()` with priority
3. Conform.nvim will use it when formatting

### Modifying Keymaps
- Global keymaps: `lua/config/keymaps.lua`
- LSP keymaps: `lua/utils/lsp/keymaps.lua`
- Plugin-specific keymaps: In the plugin's spec file under `keys = {}`

## Testing Changes

Since this is a Neovim configuration, test changes by:
1. Reloading the configuration: `:Lazy reload <plugin>` or restart Neovim
2. Checking for errors: `:messages` or `:checkhealth`
3. Testing LSP: `:LspInfo` to see attached clients
4. Testing formatters: `:PickleFormatInfo` to see available formatters

## Git Workflow

### Commit Conventions
This repository uses **Conventional Commits** with **atomic commits**:

**Commit Format**:
```
<type>(<scope>): <description>

[optional body]

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Types**:
- `feat` - New features
- `fix` - Bug fixes
- `docs` - Documentation changes
- `style` - Code style changes (formatting, missing semi-colons, etc)
- `refactor` - Code refactoring without functionality changes
- `perf` - Performance improvements
- `test` - Adding or updating tests
- `chore` - Maintenance tasks (dependencies, build config, etc)

**Scopes** (optional but recommended):
- `lsp` - LSP-related changes
- `formatting` - Formatter changes
- `completion` - Completion system changes
- `ui` - UI plugin changes
- `config` - Core configuration changes
- `plugins` - Plugin additions/modifications

**Atomic Commits**:
- Each commit should represent a single logical change
- If adding multiple unrelated features/fixes, create separate commits
- Group related changes together (e.g., plugin + its configuration in one commit)

**Examples**:
```bash
# Single feature
git commit -m "feat(lsp): add gopls configuration for Go development"

# Documentation
git commit -m "docs: update README with new keybindings"

# Bug fix
git commit -m "fix(formatting): resolve stylua config path issue"

# Multiple related changes
git commit -m "feat(completion): add blink.cmp with LSP integration

- Configure blink.cmp as primary completion engine
- Add fuzzy matching and ghost text
- Integrate with LuaSnip for snippets"
```

### Branch Strategy
- `dev` - Development branch (default)
- Feature branches for major changes

### Commit Message Format with Heredoc
When committing from command line, use heredoc for proper formatting:
```bash
git commit -m "$(cat <<'EOF'
feat(lsp): add rust-analyzer configuration

Configure rust-analyzer with custom settings for:
- Inlay hints for type annotations
- Cargo check on save
- Clippy integration

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
```

## Snacks.nvim Integration

Snacks.nvim provides comprehensive utilities split across multiple config files:
- `plugins/snacks/init.lua` - Core snacks (animation, dashboard, dim, terminal, notifier)
- `plugins/snacks/picker.lua` - File/search pickers
- `plugins/snacks/explorer.lua` - File explorer
- `plugins/snacks/indent.lua` - Indentation guides

Access snacks features via the global `Snacks` table or keybindings (e.g., `<leader>` prefix).

## Code Philosophy

Code should be self documenting.

How you split logic into functions and shape the data they pass around determines how well a codebase holds up over time.

### Semantic Functions

Semantic functions are the building blocks of any codebase, a good semantic function should be as minimal as possible in order to prioritize correctness in it. A semantic function should take in all required inputs to complete its goal and return all necessary outputs directly. Semantic functions can wrap other semantic functions to describe desired flows and usage; as the building blocks of the codebase, if there are complex flows used everywhere that are well defined, use a semantic function to codify them.

Side effects are generally undesirable in semantic functions unless they are the explicit goal because semantic functions should be safe to re-use without understanding their internals for what they say they do. If logic is complicated and it's not clear what it does in a large flow, a good pattern is to break that flow up into a series of self describing semantic functions that take in what they need, return the data necessary for the next step, and don't do anything else. Examples of good semantic functions range from quadratic_formula() to retry_with_exponential_backoff_and_run_y_in_between<Y: func, X: Func>(x: X, y: Y). Even if these functions are never used again, future humans and agents going over the code will appreciate the indexing of information.

Semantic functions should not need any comments around them, the code itself should be a self describing definition of what it does. Semantic functions should ideally be extremely unit testable because a good semantic function is a well defined one.

### Pragmatic Functions

Pragmatic functions should be used as wrappers around a series of semantic functions and unique logic. They are the complex processes of your codebase. When making production systems it's natural for the logic to get messy, pragmatic functions are the organization for these. These should generally not be used in more than a few places, if they are, consider breaking down the explicit logic and moving it into semantic functions. For example provision_new_workspace_for_github_repo(repo, user) or handle_user_signup_webhook(). Testing pragmatic functions falls into the realm of integration testing, and is often done within the context of testing whole app functionality. Pragmatic functions are expected to change completely over time, from their insides to what they do. To help with that, it's good to have doc comments above them. Avoid restating the function name or obvious traits about it, instead note unexpected things like "fails early on balance less than 10", or combatting other misconceptions coming from the function name. As a reader of doc comments take them with a grain of salt, coders working inside the function may have forgotten to update them, and it's good to fact check them when you think they might be incorrect.

### Models

The shape of your data should make wrong states impossible. If a model allows a combination of fields that should never exist together in practice, the model isn't doing its job. Every optional field is a question the rest of the codebase has to answer every time it touches that data, and every loosely typed field is an invitation for callers to pass something that looks right but isn't. When models enforce correctness, bugs surface at the point of construction rather than deep inside some unrelated flow where the assumptions finally collapse. A model's name should be precise enough that you can look at any field and know whether it belongs — if the name doesn't tell you, the model is trying to be too many things. When two concepts are often needed together but are independent, compose them rather than merging them — e.g. UserAndWorkspace { user: User, workspace: Workspace } keeps both models intact instead of flattening workspace fields into the user. Good names like UnverifiedEmail, PendingInvite, and BillingAddress tell you exactly what fields belong. If you see a phone_number field on BillingAddress, you know something went wrong.

Values with identical shapes can represent completely different domain concepts: { id: "123" } might be a DocumentReference in one place and a MessagePointer in another, and if your functions just accept { id: String }, the code will accept either one without complaint. Brand types solve this by wrapping a primitive in a distinct type so the compiler treats them as separate: DocumentId(UUID) instead of a bare UUID. With branding in place, accidentally swapping two IDs becomes a syntax error instead of a silent bug that surfaces three layers deep.

### Where Things Break

Breaks commonly happen when a semantic function morphs into a pragmatic function for ease, and then other places in the codebase that rely on it end up doing things they didn't intend. To solve this, be explicit when creating a function by naming it instead of by what it does, but by where it's used. The nature of their names should make it clear to other programmers in their names that their behavior is not tightly defined and should not be relied on for the internals to do an exact task, and make debugging regressions from them easier.

Models break the same way but slower. They start focused, then someone adds "just one more" optional field because it's easier than creating a new model, and then someone else does the same, and eventually the model is a loose bag of half-related data where every consumer has to guess which fields are actually set and why. The name stops describing what the data is, the fields stop cohering around a single concept, and every new feature that touches the model has to navigate states it was never designed to represent. When a model's fields no longer cohere around its name, that's the signal to split it into the distinct things it's been coupling together.
