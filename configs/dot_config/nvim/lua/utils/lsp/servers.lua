---@alias picklevim.lsp.server.opts vim.lsp.Config

--- LSP server definition
---@class picklevim.lsp.server
---@field enabled? boolean Enable this server (default: true)
---@field mason? boolean Auto-install via Mason.nvim (default: true)
---@field opts? picklevim.lsp.server.opts Server configuration options
---@field keys? picklevim.lsp.keys.spec[] Server-specific keymaps

---@type table<string, picklevim.lsp.server>
local M = {}

M.astro = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {},
}

M.cssls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {},
}

M.html = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        filetypes = { 'html', 'htmldjango' },
    },
}

M.mdx_analyzer = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {},
}

M.vtsls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {},
}

M.basedpyright = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        settings = {
            basedpyright = {
                analysis = {
                    typeCheckingMode = 'basic',
                    autoSearchPaths = true,
                    useLibraryCodeForTypes = true,
                    diagnosticMode = 'openFilesOnly',
                    autoImportCompletions = true,
                },
            },
        },
    },
}

M.glsl_analyzer = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {},
}

M.gopls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        settings = {
            gopls = {
                gofumpt = true,

                codelenses = {
                    gc_details = false,
                    generate = true,
                    regenerate_cgo = true,
                    run_govulncheck = true,
                    test = true,
                    tidy = true,
                    upgrade_dependency = true,
                    vendor = true,
                },

                hints = {
                    assignVariableTypes = true,
                    compositeLiteralFields = true,
                    compositeLiteralTypes = true,
                    constantValues = true,
                    functionTypeParameters = true,
                    parameterNames = true,
                    rangeVariableTypes = true,
                },

                analyses = {
                    fieldalignment = true,
                    nilness = true,
                    unusedparams = true,
                    unusedwrite = true,
                    useany = true,
                },

                usePlaceholders = true,
                completeUnimported = true,
                staticcheck = true,
                directoryFilters = {
                    '-.git',
                    '-.vscode',
                    '-.idea',
                    '-.vscode-test',
                    '-node_modules',
                },
                semanticTokens = true,
            },
        },
    },
}

M.lua_ls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        filetypes = { 'lua' },

        root_markers = {
            'lazy-lock.json',
            '.luarc.json',
            '.luarc.jsonc',
            '.luacheckrc',
            '.stylua.toml',
            'stylua.toml',
            'selene.toml',
            'selene.yml',
            '.git',
        },

        settings = {
            Lua = {
                runtime = {
                    version = 'LuaJIT',
                },

                codeLens = {
                    enable = true,
                },

                completion = {
                    enable = true,

                    autoRequire = true,
                    callSnippet = 'Replace',
                    displayContext = 5,
                    keywordSnippet = 'Replace',
                    postfix = '@',
                    requireSeparator = '.',
                    showParams = true,
                    showWord = 'Fallback',
                    workspaceWord = true,
                },

                diagnostics = {
                    enable = true,

                    globals = { 'vim' },
                    workspaceDelay = 1000,
                    workspaceEvent = 'OnChange',
                },

                doc = {
                    privateName = { '^_' },
                },

                hint = {
                    enable = true,

                    arrayIndex = 'Auto',
                    await = true,
                    paramName = 'All',
                    paramType = true,
                    semicolon = 'Disable',
                    setType = true,
                },

                hover = {
                    enable = true,

                    enumsLimit = 10,
                    expandAlias = true,
                    previewFields = 50,
                    viewNumber = true,
                    viewString = true,
                    viewStringMax = 1000,
                },

                semantic = {
                    enable = true,

                    annotation = true,
                    keyword = false,
                    variable = true,
                },

                signatureHelp = {
                    enable = true,
                },

                workspace = {
                    checkThirdParty = false,
                    library = {},
                },

                telemetry = {
                    enable = false,
                },
            },
        },
    },
}

M.jsonls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        settings = {
            json = {
                colorDecorators = {
                    enable = true,
                },
                maxItemsComputed = 5000,
                validate = {
                    enable = true,
                },
                format = {
                    enable = true,

                    keepLines = false,
                },
                schemaDownload = {
                    enable = true,
                },
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

M.yamlls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        settings = {
            yaml = {
                schemas = {
                    ['https://json.schemastore.org/github-workflow.json'] = '.github/workflows/*.{yml,yaml}',
                    ['https://json.schemastore.org/github-action.json'] = '.github/action.{yml,yaml}',
                },
            },
        },
    },
}

M.taplo = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        filetypes = { 'toml' },

        root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            local markers = { '.git', 'Cargo.toml', 'pyproject.toml' }
            local root = vim.fs.dirname(vim.fs.find(markers, { path = fname, upward = true })[1])
            on_dir(root or vim.fs.dirname(fname))
        end,
    },
}

M.sqlls = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {},
}

M.marksman = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        filetypes = { 'markdown', 'markdown.mdx' },
    },
}

M.tailwindcss = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        filetypes = {
            'html',
            'htmldjango',
            'css',
            'scss',
            'less',
            'sass',
            'javascript',
            'javascriptreact',
            'typescript',
            'typescriptreact',
            'vue',
            'svelte',
            'astro',
        },

        settings = {
            tailwindCSS = {
                -- Detect class names inside common React/utility helpers and
                -- tagged template literals (cva, cx, cn, clsx, tw``).
                experimental = {
                    classRegex = {
                        { 'cva\\(([^)]*)\\)', '["\'`]([^"\'`]*).*?["\'`]' },
                        { 'cx\\(([^)]*)\\)', '["\'`]([^"\'`]*).*?["\'`]' },
                        { 'cn\\(([^)]*)\\)', '["\'`]([^"\'`]*).*?["\'`]' },
                        { 'clsx\\(([^)]*)\\)', '["\'`]([^"\'`]*).*?["\'`]' },
                        'tw`([^`]*)',
                        'tw="([^"]*)',
                        'tw={"([^"}]*)',
                    },
                },

                validate = true,
            },
        },
    },
}

M.eslint = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        -- Fix-on-format is wired in lua/plugins/lsp/web.lua via the
        -- source.fixAll.eslint code action; diagnostics are always on.
        settings = {
            workingDirectories = { mode = 'auto' },
        },
    },
}

M.emmet_language_server = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {
        filetypes = {
            'html',
            'htmldjango',
            'css',
            'scss',
            'less',
            'sass',
            'javascriptreact',
            'typescriptreact',
            'vue',
            'svelte',
            'astro',
        },
    },
}

M.vue_ls = {
    enabled = true,
    mason = true,

    keys = {},

    -- Volar hybrid mode: vue_ls handles template/style, vtsls handles
    -- TypeScript via the @vue/typescript-plugin (wired in web.lua).
    opts = {},
}

M.svelte = {
    enabled = true,
    mason = true,

    keys = {},

    opts = {},
}

return M
