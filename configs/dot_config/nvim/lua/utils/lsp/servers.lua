--- LSP server configurations
--- Defines settings and options for all Language Server Protocol servers
--- Each server can be enabled/disabled, auto-installed via Mason, and configured
--- with server-specific settings, keymaps, and options
---
--- Structure:
---   M.<server_name> = {
---     enabled = boolean,      -- Enable/disable this server
---     mason = boolean,        -- Auto-install via Mason
---     keys = {...},          -- Server-specific keymaps
---     opts = {...},          -- LSP server configuration (passed to vim.lsp.config)
---   }
---
--- Usage:
---   - Servers are loaded by lua/plugins/lsp/init.lua
---   - Mason auto-installs servers where mason = true
---   - Opts are merged with defaults and passed to vim.lsp.config()
---
--- Adding a new server:
---   1. Add M.<server_name> = { enabled = true, mason = true, opts = {} }
---   2. Configure server-specific settings in opts.settings
---   3. Add custom root_dir function if needed
---   4. Define server-specific keymaps in keys array

----------------------------------------
-- Type Definitions
----------------------------------------

--- LSP server configuration options (passed to vim.lsp.config)
---@alias picklevim.lsp.server.opts vim.lsp.Config

--- LSP server definition
---@class picklevim.lsp.server
---@field enabled? boolean Enable this server (default: true)
---@field mason? boolean Auto-install via Mason.nvim (default: true)
---@field opts? picklevim.lsp.server.opts Server configuration options
---@field keys? picklevim.lsp.keys.spec[] Server-specific keymaps

--- Table of LSP server configurations
---@type table<string, picklevim.lsp.server>
local M = {}

----------------------------------------
-- Web Development
----------------------------------------

--- Astro Language Server
--- Provides LSP support for Astro framework files (.astro)
M.astro = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {},
}

--- CSS Language Server
--- Provides LSP support for CSS, SCSS, and Less
M.cssls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {},
}

--- HTML Language Server
--- Provides LSP support for HTML and Django HTML templates
M.html = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        filetypes = { 'html', 'htmldjango' },
    },
}

--- MDX Analyzer
--- Provides LSP support for MDX (Markdown + JSX) files
M.mdx_analyzer = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {},
}

--- TypeScript/JavaScript Language Server (VTSLS)
--- Enhanced TypeScript server based on vscode-typescript-language-features
--- Provides superior performance and features compared to tsserver
--- See lua/plugins/lsp/typescript.lua for extended commands
M.vtsls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {},
}

----------------------------------------
-- Python
----------------------------------------

--- BasedPyright Language Server
--- Community fork of Pyright with additional features
--- Provides type checking, IntelliSense, and code navigation for Python
M.basedpyright = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        settings = {
            basedpyright = {
                analysis = {
                    typeCheckingMode = 'basic',       -- Type checking strictness (off/basic/strict)
                    autoSearchPaths = true,           -- Auto-search for imports
                    useLibraryCodeForTypes = true,    -- Infer types from library code
                    diagnosticMode = 'openFilesOnly', -- Only check open files (faster)
                    autoImportCompletions = true,     -- Enable auto-import completions
                },
            },
        },
    },
}

----------------------------------------
-- Go
----------------------------------------

--- Go Language Server (gopls)
--- Official Go LSP server with comprehensive Go support
--- Includes gofumpt formatting, inlay hints, codelenses, and static analysis
M.gopls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        settings = {
            gopls = {
                gofumpt = true, -- Use gofumpt for stricter formatting

                -- Code lenses for various Go operations
                codelenses = {
                    gc_details = false,            -- GC optimization details
                    generate = true,               -- go generate commands
                    regenerate_cgo = true,         -- Regenerate cgo definitions
                    run_govulncheck = true,        -- Vulnerability checking
                    test = true,                   -- Run/debug tests
                    tidy = true,                   -- go mod tidy
                    upgrade_dependency = true,     -- Upgrade dependencies
                    vendor = true,                 -- go mod vendor
                },

                -- Inlay hints for type information
                hints = {
                    assignVariableTypes = true,    -- x := <int>
                    compositeLiteralFields = true, -- struct{field: <type>}
                    compositeLiteralTypes = true,  -- []<type>{...}
                    constantValues = true,         -- const x = <value>
                    functionTypeParameters = true, -- func[<T any>]()
                    parameterNames = true,         -- function(<param>: value)
                    rangeVariableTypes = true,     -- for i<int>, v<string> := range
                },

                -- Static analysis passes
                analyses = {
                    fieldalignment = true,         -- Detect inefficient struct field ordering
                    nilness = true,                -- Detect nil pointer dereferences
                    unusedparams = true,           -- Detect unused function parameters
                    unusedwrite = true,            -- Detect unused variable assignments
                    useany = true,                 -- Suggest using 'any' instead of 'interface{}'
                },

                usePlaceholders = true,            -- Insert placeholders in completions
                completeUnimported = true,         -- Complete from unimported packages
                staticcheck = true,                -- Enable staticcheck integration
                directoryFilters = {               -- Exclude directories from analysis
                    '-.git',
                    '-.vscode',
                    '-.idea',
                    '-.vscode-test',
                    '-node_modules',
                },
                semanticTokens = true,             -- Enable semantic highlighting
            },
        },
    },
}

----------------------------------------
-- Lua
----------------------------------------

--- Lua Language Server
--- Official Lua LSP server with Neovim-specific enhancements
--- Workspace libraries are populated by lazydev.nvim for Neovim API support
M.lua_ls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        filetypes = { 'lua' },

        -- Custom root detection for Lua projects
        root_dir = function(fname)
            -- Convert buffer number to filename if needed
            if type(fname) == 'number' then
                fname = vim.api.nvim_buf_get_name(fname)
            end

            -- Look for common Lua project markers
            local markers = {
                'lazy-lock.json',  -- Lazy.nvim lockfile
                '.luarc.json',     -- Lua config
                '.luarc.jsonc',
                '.luacheckrc',     -- Luacheck config
                '.stylua.toml',    -- Stylua formatter
                'stylua.toml',
                'selene.toml',     -- Selene linter
                'selene.yml',
                '.git',
            }
            local root = vim.fs.dirname(vim.fs.find(markers, { path = fname, upward = true })[1])
            return root or vim.fs.dirname(fname)
        end,

        settings = {
            Lua = {
                runtime = {
                    version = 'LuaJIT', -- Neovim uses LuaJIT
                },

                codeLens = {
                    enable = true,
                },

                completion = {
                    enable = true,

                    autoRequire = true,       -- Auto-require modules
                    callSnippet = 'Replace',  -- Replace function calls with snippets
                    displayContext = 5,       -- Context lines in hover
                    keywordSnippet = 'Replace', -- Replace keywords with snippets
                    postfix = '@',            -- Postfix completion trigger
                    requireSeparator = '.',   -- Module separator
                    showParams = true,        -- Show function parameters
                    showWord = 'Fallback',    -- Show word completions as fallback
                    workspaceWord = true,     -- Complete words from workspace
                },

                diagnostics = {
                    enable = true,

                    globals = { 'vim' },       -- Recognize 'vim' as global
                    workspaceDelay = 1000,     -- Delay before workspace diagnostics
                    workspaceEvent = 'OnChange', -- Trigger workspace diagnostics on change
                },

                doc = {
                    privateName = { '^_' },    -- Private names start with underscore
                },

                hint = {
                    enable = true,

                    arrayIndex = 'Auto',       -- Array index hints (Auto/Enable/Disable)
                    await = true,              -- Hint for await keyword
                    paramName = 'All',         -- Parameter name hints (All/Literal/Disable)
                    paramType = true,          -- Parameter type hints
                    semicolon = 'Disable',     -- Semicolon hints
                    setType = true,            -- Variable type hints
                },

                hover = {
                    enable = true,

                    enumsLimit = 10,           -- Max enum values to show
                    expandAlias = true,        -- Expand type aliases in hover
                    previewFields = 50,        -- Max fields to preview in hover
                    viewNumber = true,         -- Show number values
                    viewString = true,         -- Show string contents
                    viewStringMax = 1000,      -- Max string length in hover
                },

                semantic = {
                    enable = true,

                    annotation = true,         -- Semantic tokens for annotations
                    keyword = false,           -- Don't override keyword highlighting
                    variable = true,           -- Semantic tokens for variables
                },

                signatureHelp = {
                    enable = true,
                },

                workspace = {
                    checkThirdParty = false,   -- Don't prompt for third-party libraries
                    library = {},              -- Populated by lazydev.nvim for Neovim API
                },

                telemetry = {
                    enable = false,            -- Disable telemetry
                },
            },
        },
    },
}

----------------------------------------
-- Data Formats
----------------------------------------

--- JSON Language Server
--- Provides LSP support for JSON with schema validation
--- Includes schemas for common config files (package.json, tsconfig, etc.)
M.jsonls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        settings = {
            json = {
                colorDecorators = {
                    enable = true,             -- Show color decorators for color values
                },
                maxItemsComputed = 5000,       -- Max items for completion/hover
                validate = {
                    enable = true,             -- Enable schema validation
                },
                format = {
                    enable = true,             -- Enable formatting

                    keepLines = false,         -- Don't preserve newlines
                },
                schemaDownload = {
                    enable = true,             -- Auto-download schemas
                },
                -- JSON schemas for validation
                schemas = {
                    {
                        fileMatch = { 'package.json' },
                        url = 'https://json.schemastore.org/package.json',
                    },
                    {
                        fileMatch = { 'tsconfig*.json' },
                        url = 'https://json.schemastore.org/tsconfig.json',
                    },
                    {
                        fileMatch = {
                            '.prettierrc',
                            '.prettierrc.json',
                            'prettier.config.json',
                        },
                        url = 'https://json.schemastore.org/prettierrc.json',
                    },
                    {
                        fileMatch = { '.eslintrc', '.eslintrc.json' },
                        url = 'https://json.schemastore.org/eslintrc.json',
                    },

                    {
                        fileMatch = { 'vercel.json' },
                        url = 'https://openapi.vercel.sh/vercel.json',
                    },
                },
            },
        },
    },
}

--- YAML Language Server
--- Provides LSP support for YAML with schema validation
--- Includes schemas for GitHub workflows and actions
M.yamlls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        settings = {
            yaml = {
                -- YAML schemas for validation
                schemas = {
                    ['https://json.schemastore.org/github-workflow.json'] = '.github/workflows/*.{yml,yaml}',
                    ['https://json.schemastore.org/github-action.json'] = '.github/action.{yml,yaml}',
                },
            },
        },
    },
}

--- TOML Language Server (Taplo)
--- Provides LSP support for TOML configuration files
--- Includes custom root detection for Rust and Python projects
M.taplo = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        filetypes = { 'toml' },

        -- Custom root detection for TOML files
        root_dir = function(fname)
            -- Convert buffer number to filename if needed
            if type(fname) == 'number' then
                fname = vim.api.nvim_buf_get_name(fname)
            end

            -- Look for common TOML project markers
            local markers = { '.git', 'Cargo.toml', 'pyproject.toml' }
            local root = vim.fs.dirname(vim.fs.find(markers, { path = fname, upward = true })[1])

            -- Fallback to the directory containing the TOML file
            return root or vim.fs.dirname(fname)
        end,
    },
}

--- SQL Language Server
--- Provides LSP support for SQL queries and scripts
M.sqlls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {},
}

----------------------------------------
-- Markdown
----------------------------------------

--- Marksman Language Server
--- Provides LSP support for Markdown files
--- Features: document symbols, links, references, wiki-links
M.marksman = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        filetypes = { 'markdown', 'markdown.mdx' },
    },
}

return M
