--- TypeScript/JavaScript LSP configuration
--- Uses VTSLS (Visual Studio Code TypeScript Language Features)
--- Provides enhanced TypeScript support with advanced refactoring and code actions
---
--- Features:
---   - Source definition navigation (implementation, not just types)
---   - File reference search (find all imports of current file)
---   - Import management (organize, add missing, remove unused)
---   - Fix all diagnostics
---   - TypeScript version selection (workspace vs global)
---   - Move-to-file refactoring with UI picker
---   - Inlay hints for types, parameters, return types
---   - Server-side fuzzy matching for completions
---
--- Custom Keymaps:
---   gD - Goto source definition (implementation)
---   gR - Find all file references
---   <leader>co - Organize imports
---   <leader>cM - Add missing imports
---   <leader>cu - Remove unused imports
---   <leader>cD - Fix all diagnostics
---   <leader>cV - Select TypeScript workspace version
---
--- Root Detection:
---   - Uses lockfiles (package-lock.json, yarn.lock, pnpm-lock.yaml, bun.lockb)
---   - Falls back to jsconfig.json

return {
    {
        'neovim/nvim-lspconfig',
        opts = {
            ---@type picklevim.lsp.server[]
            servers = {
                vtsls = {
                    enabled = true,
                    mason = true,

                    ----------------------------------------
                    -- TypeScript-Specific Keymaps
                    ----------------------------------------
                    keys = {
                        -- Goto Source Definition (implementation, not type definition)
                        {
                            'gD',
                            function()
                                local params = vim.lsp.util.make_position_params(0, 'utf-8')
                                PickleVim.lsp.execute({
                                    command = 'typescript.goToSourceDefinition',
                                    arguments = { params.textDocument.uri, params.position },
                                    open = true,
                                })
                            end,
                            desc = 'Goto Source Definition',
                        },

                        -- Find All File References (find all files that import current file)
                        {
                            'gR',
                            function()
                                PickleVim.lsp.execute({
                                    command = 'typescript.findAllFileReferences',
                                    arguments = { vim.uri_from_bufnr(0) },
                                    open = true,
                                })
                            end,
                            desc = 'File References',
                        },

                        -- Organize Imports (sort and remove unused)
                        {
                            '<leader>co',
                            PickleVim.lsp.action['source.organizeImports'],
                            desc = 'Organize Imports',
                        },

                        -- Add Missing Imports
                        {
                            '<leader>cM',
                            PickleVim.lsp.action['source.addMissingImports.ts'],
                            desc = 'Add missing imports',
                        },

                        -- Remove Unused Imports
                        {
                            '<leader>cu',
                            PickleVim.lsp.action['source.removeUnused.ts'],
                            desc = 'Remove unused imports',
                        },

                        -- Fix All Diagnostics (auto-fix all fixable issues)
                        {
                            '<leader>cD',
                            PickleVim.lsp.action['source.fixAll.ts'],
                            desc = 'Fix all diagnostics',
                        },

                        -- Select TypeScript Version (workspace vs global)
                        {
                            '<leader>cV',
                            function()
                                PickleVim.lsp.execute({ command = 'typescript.selectTypeScriptVersion' })
                            end,
                            desc = 'Select TS workspace version',
                        },
                    },

                    ----------------------------------------
                    -- VTSLS Configuration
                    ----------------------------------------
                    opts = {
                        -- Root directory markers (package managers)
                        root_markers = {
                            'package-lock.json',  -- npm
                            'yarn.lock',          -- Yarn
                            'pnpm-lock.yaml',     -- pnpm
                            'bun.lockb',          -- Bun (binary)
                            'bun.lock',           -- Bun (text)
                            'jsconfig.json',      -- JavaScript project config
                        },

                        -- Supported filetypes
                        filetypes = {
                            'javascript',
                            'javascriptreact',
                            'javascript.jsx',
                            'typescript',
                            'typescriptreact',
                            'typescript.tsx',
                        },

                        settings = {
                            -- Complete function calls with parentheses and parameters
                            complete_function_calls = true,

                            ----------------------------------------
                            -- VTSLS-Specific Settings
                            ----------------------------------------
                            vtsls = {
                                -- Enable "Move to File" code action
                                enableMoveToFileCodeAction = true,

                                -- Auto-detect and use workspace TypeScript version
                                autoUseWorkspaceTsdk = true,

                                experimental = {
                                    -- Max length for inlay hints before truncation
                                    maxInlayHintLength = 80,

                                    completion = {
                                        -- Enable fuzzy matching on server side (faster)
                                        enableServerSideFuzzyMatch = true,
                                    },
                                },
                            },

                            ----------------------------------------
                            -- TypeScript Language Settings
                            ----------------------------------------
                            typescript = {
                                -- Update imports when moving files
                                updateImportsOnFileMove = { enabled = 'always' },

                                -- Completion settings
                                suggest = {
                                    completeFunctionCalls = true, -- Include () in function completions
                                },

                                -- Import preferences
                                preferences = {
                                    -- Prefer non-relative imports (e.g., @/components vs ../../components)
                                    importModuleSpecifier = 'non-relative',

                                    -- Prefer 'import type' for types (better tree-shaking)
                                    preferTypeOnlyAutoImports = true,
                                },

                                -- TypeScript Server settings
                                tsserver = {
                                    experimental = {
                                        -- Disable project-wide diagnostics (performance)
                                        enableProjectDiagnostics = false,
                                    },
                                },

                                -- Inlay Hints Configuration
                                inlayHints = {
                                    enumMemberValues = { enabled = true },        -- Show: EnumMember = 1
                                    functionLikeReturnTypes = { enabled = true }, -- Show: function(): string
                                    parameterNames = { enabled = true },          -- Show: function(param: value)
                                    parameterTypes = { enabled = true },          -- Show: function(param: Type)
                                    propertyDeclarationTypes = { enabled = true }, -- Show: property: Type
                                    variableTypes = { enabled = false },          -- Don't show: const x: Type
                                },
                            },
                        },
                    },
                },
            },

            ----------------------------------------
            -- Custom Setup Function
            ----------------------------------------
            ---@type picklevim.lsp.setup
            setup = {
                vtsls = function(server, opts)
                    -- Register custom move-to-file refactoring command handler
                    PickleVim.lsp.on_attach(function(client, _)
                        -- Handle move-to-file refactoring with UI picker
                        client.commands['_typescript.moveToFileRefactoring'] = function(command, _)
                            local action, uri, range = unpack(command.arguments)

                            -- Execute move with new file path
                            local move = function(newf)
                                client:request('workspace/executeCommand', {
                                    command = command.command,
                                    arguments = { action, uri, range, newf },
                                })
                            end

                            ---@cast uri string
                            local fname = vim.uri_to_fname(uri)

                            -- Handle user's file selection
                            local on_choice = function(f)
                                if f and f:find('^Enter new path') then
                                    -- User wants to enter custom path
                                    vim.ui.input({
                                        prompt = 'Enter move destination:',
                                        default = vim.fn.fnamemodify(fname, ':h') .. '/',
                                        completion = 'file',
                                    }, function(newf)
                                        if newf then
                                            move(newf)
                                        end
                                    end)
                                elseif f then
                                    -- User selected existing file
                                    move(f)
                                end
                            end

                            -- Request suggested file destinations from server
                            local handler = function(_, result)
                                local files = result.body.files

                                -- Add custom path option at top
                                table.insert(files, 1, 'Enter new path...')

                                -- Show file picker
                                vim.ui.select(files, {
                                    prompt = 'Select move destination:',
                                    format_item = function(f)
                                        return vim.fn.fnamemodify(f, ':~:.')
                                    end,
                                }, on_choice)
                            end

                            -- Request file suggestions from TypeScript server
                            client:request('workspace/executeCommand', {
                                command = 'typescript.tsserverRequest',
                                arguments = {
                                    'getMoveToRefactoringFileSuggestions',
                                    ---@cast range lsp.Range
                                    {
                                        file = fname,
                                        startLine = range.start.line + 1,
                                        startOffset = range.start.character + 1,
                                        endLine = range['end'].line + 1,
                                        endOffset = range['end'].character + 1,
                                    },
                                },
                            }, handler)
                        end
                    end, 'vtsls')

                    -- Share TypeScript settings with JavaScript
                    opts.settings.javascript =
                        vim.tbl_deep_extend('force', {}, opts.settings.typescript or {}, opts.settings.javascript or {})

                    -- Configure and enable VTSLS
                    vim.lsp.config(server, opts)
                    vim.lsp.enable(server)

                    return true
                end,
            },
        },
    },
}
