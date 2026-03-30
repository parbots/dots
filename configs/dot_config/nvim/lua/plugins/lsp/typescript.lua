return {
    {
        'neovim/nvim-lspconfig',
        opts = {
            ---@type picklevim.lsp.server[]
            servers = {
                vtsls = {
                    enabled = true,
                    mason = true,

                    keys = {
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

                        {
                            '<leader>co',
                            PickleVim.lsp.action['source.organizeImports'],
                            desc = 'Organize Imports',
                        },

                        {
                            '<leader>cM',
                            PickleVim.lsp.action['source.addMissingImports.ts'],
                            desc = 'Add missing imports',
                        },

                        {
                            '<leader>cu',
                            PickleVim.lsp.action['source.removeUnused.ts'],
                            desc = 'Remove unused imports',
                        },

                        {
                            '<leader>cD',
                            PickleVim.lsp.action['source.fixAll.ts'],
                            desc = 'Fix all diagnostics',
                        },

                        {
                            '<leader>cV',
                            function()
                                PickleVim.lsp.execute({ command = 'typescript.selectTypeScriptVersion' })
                            end,
                            desc = 'Select TS workspace version',
                        },
                    },

                    opts = {
                        root_markers = {
                            'package-lock.json',
                            'yarn.lock',
                            'pnpm-lock.yaml',
                            'bun.lockb',
                            'bun.lock',
                            'jsconfig.json',
                        },

                        filetypes = {
                            'javascript',
                            'javascriptreact',
                            'javascript.jsx',
                            'typescript',
                            'typescriptreact',
                            'typescript.tsx',
                        },

                        settings = {
                            complete_function_calls = true,

                            vtsls = {
                                enableMoveToFileCodeAction = true,
                                autoUseWorkspaceTsdk = true,

                                experimental = {
                                    maxInlayHintLength = 80,

                                    completion = {
                                        enableServerSideFuzzyMatch = true,
                                    },
                                },
                            },

                            typescript = {
                                updateImportsOnFileMove = { enabled = 'always' },

                                suggest = {
                                    completeFunctionCalls = true,
                                },

                                preferences = {
                                    importModuleSpecifier = 'non-relative',
                                    preferTypeOnlyAutoImports = true,
                                },

                                tsserver = {
                                    experimental = {
                                        enableProjectDiagnostics = false,
                                    },
                                },

                                inlayHints = {
                                    enumMemberValues = { enabled = true },
                                    functionLikeReturnTypes = { enabled = true },
                                    parameterNames = { enabled = true },
                                    parameterTypes = { enabled = true },
                                    propertyDeclarationTypes = { enabled = true },
                                    variableTypes = { enabled = false },
                                },
                            },
                        },
                    },
                },
            },

            ---@type picklevim.lsp.setup
            setup = {
                vtsls = function(server, opts)
                    PickleVim.lsp.on_attach(function(client, _)
                        -- Handle move-to-file refactoring: prompts for destination via UI picker,
                        -- then executes the workspace command with the chosen path
                        client.commands['_typescript.moveToFileRefactoring'] = function(command, _)
                            local action, uri, range = unpack(command.arguments)

                            local move = function(newf)
                                client:request('workspace/executeCommand', {
                                    command = command.command,
                                    arguments = { action, uri, range, newf },
                                })
                            end

                            ---@cast uri string
                            local fname = vim.uri_to_fname(uri)

                            local on_choice = function(f)
                                if f and f:find('^Enter new path') then
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
                                    move(f)
                                end
                            end

                            local handler = function(_, result)
                                local files = result.body.files

                                table.insert(files, 1, 'Enter new path...')

                                vim.ui.select(files, {
                                    prompt = 'Select move destination:',
                                    format_item = function(f)
                                        return vim.fn.fnamemodify(f, ':~:.')
                                    end,
                                }, on_choice)
                            end

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

                    vim.lsp.config(server, opts)
                    vim.lsp.enable(server)

                    return true
                end,
            },
        },
    },
}
