---@type PicklePicker
local picker = {
    name = 'snacks',
    commands = {
        files = 'files',
        live_grep = 'grep',
        oldfiles = 'recent',
    },

    ---@param source string
    ---@param opts ? snacks.picker.Config
    open = function(source, opts)
        return Snacks.picker.pick(source, opts)
    end,
}

if not PickleVim.pick.register(picker) then
    return {}
end

return {
    {
        'folke/snacks.nvim',
        opts = {
            ---@type snacks.picker.Config
            picker = {
                win = {
                    input = {
                        keys = {
                            ['<a-c>'] = {
                                'toggle_cwd',
                                mode = { 'n', 'i' },
                            },
                        },
                    },
                },

                actions = {
                    ---@param p snacks.Picker
                    toggle_cwd = function(p)
                        local root = PickleVim.root({ buf = p.input.filter.current_buf, normalize = true })
                        local cwd = vim.fs.normalize((vim.uv or vim.loop).cwd() or '.')
                        local current = p:cwd()

                        p:set_cwd(current == root and cwd or root)
                        p:find()
                    end,
                },

                matcher = {
                    fuzzy = true, -- use fuzzy matching
                    smartcase = true, -- use smartcase
                    ignorecase = true, -- use ignorecase
                    sort_empty = false, -- sort results when the search string is empty
                    filename_bonus = true, -- give bonus for matching file names (last part of the path)
                    file_pos = true, -- support patterns like `file:line:col` and `file:line`
                    -- the bonusses below, possibly require string concatenation and path normalization,
                    -- so this can have a performance impact for large lists and increase memory usage
                    cwd_bonus = false, -- give bonus for matching files in the cwd
                    frecency = false, -- frecency bonus
                    history_bonus = false, -- give more weight to chronological order
                },

                formatters = {
                    text = {
                        ft = nil, ---@type string? filetype for highlighting
                    },

                    file = {
                        filename_first = true, -- display filename before the file path
                        truncate = 40, -- truncate the file path to (roughly) this length
                        filename_only = false, -- only show the filename
                        icon_width = 2, -- width of the icon (in characters)
                        git_status_hl = true, -- use the git status highlight group for the filename
                    },

                    selected = {
                        show_always = false, -- only show the selected column when there are multiple selections
                        unselected = true, -- use the unselected icon for unselected items
                    },

                    severity = {
                        icons = true, -- show severity icons
                        level = false, -- show severity level
                        ---@type "left"|"right"
                        pos = 'left', -- position of the diagnostics
                    },
                },

                icons = {
                    diagnostics = {
                        Error = PickleVim.icons.diagnostics.error,
                        Warn = PickleVim.icons.diagnostics.warn,
                        Hint = PickleVim.icons.diagnostics.hint,
                        Info = PickleVim.icons.diagnostics.info,
                    },

                    files = {
                        enabled = true, -- show file icons
                        dir = ' ',
                        dir_open = ' ',
                        file = ' ',
                    },

                    git = {
                        enabled = true,

                        added = PickleVim.icons.git.added,
                        modified = PickleVim.icons.git.modified,
                        deleted = PickleVim.icons.git.removed,

                        commit = '󰜘 ', -- used by git log
                        staged = '●', -- staged changes. always overrides the type icons
                        ignored = ' ',
                        renamed = '',
                        unmerged = ' ',
                        untracked = '?',
                    },

                    keymaps = {},

                    lsp = {
                        unavailable = '',
                        enabled = ' ',
                        disabled = ' ',
                        attached = '󰖩 ',
                    },

                    tree = {},

                    undo = {},

                    ui = {},

                    kinds = {},
                },

                sources = {
                    files = {
                        hidden = true,
                        ignored = false,

                        diagnostics = true,

                        git_status = true,

                        supports_live = true,
                        watch = true,

                        formatters = {
                            file = {
                                filename_first = true,
                            },
                        },
                    },
                },
            },
        },
        keys = {
            {
                '<leader>,',
                function()
                    Snacks.picker.buffers()
                end,
                desc = 'Buffers',
            },
            { '<leader>/', PickleVim.pick('grep'), desc = 'Grep (Root Dir)' },
            {
                '<leader>:',
                function()
                    Snacks.picker.command_history()
                end,
                desc = 'Command History',
            },
            { '<leader><space>', PickleVim.pick('files'), desc = 'Find Files (Root Dir)' },
            {
                '<leader>n',
                function()
                    Snacks.picker.notifications()
                end,
                desc = 'Notification History',
            },
            -- find
            {
                '<leader>fb',
                function()
                    Snacks.picker.buffers()
                end,
                desc = 'Buffers',
            },
            {
                '<leader>fB',
                function()
                    Snacks.picker.buffers({ hidden = true, nofile = true })
                end,
                desc = 'Buffers (all)',
            },
            { '<leader>fc', PickleVim.pick.config_files(), desc = 'Find Config File' },
            { '<leader>ff', PickleVim.pick('files'), desc = 'Find Files (Root Dir)' },
            { '<leader>fF', PickleVim.pick('files', { root = false }), desc = 'Find Files (cwd)' },
            {
                '<leader>fg',
                function()
                    Snacks.picker.git_files()
                end,
                desc = 'Find Files (git-files)',
            },
            { '<leader>fr', PickleVim.pick('oldfiles'), desc = 'Recent' },
            {
                '<leader>fR',
                function()
                    Snacks.picker.recent({ filter = { cwd = true } })
                end,
                desc = 'Recent (cwd)',
            },
            {
                '<leader>fp',
                function()
                    Snacks.picker.projects()
                end,
                desc = 'Projects',
            },
            -- git
            {
                '<leader>gd',
                function()
                    Snacks.picker.git_diff()
                end,
                desc = 'Git Diff (hunks)',
            },
            {
                '<leader>gs',
                function()
                    Snacks.picker.git_status()
                end,
                desc = 'Git Status',
            },
            {
                '<leader>gS',
                function()
                    Snacks.picker.git_stash()
                end,
                desc = 'Git Stash',
            },
            -- Grep
            {
                '<leader>sb',
                function()
                    Snacks.picker.lines()
                end,
                desc = 'Buffer Lines',
            },
            {
                '<leader>sB',
                function()
                    Snacks.picker.grep_buffers()
                end,
                desc = 'Grep Open Buffers',
            },
            { '<leader>sg', PickleVim.pick('live_grep'), desc = 'Grep (Root Dir)' },
            { '<leader>sG', PickleVim.pick('live_grep', { root = false }), desc = 'Grep (cwd)' },
            {
                '<leader>sp',
                function()
                    Snacks.picker.lazy()
                end,
                desc = 'Search for Plugin Spec',
            },
            {
                '<leader>sw',
                PickleVim.pick('grep_word'),
                desc = 'Visual selection or word (Root Dir)',
                mode = { 'n', 'x' },
            },
            {
                '<leader>sW',
                PickleVim.pick('grep_word', { root = false }),
                desc = 'Visual selection or word (cwd)',
                mode = { 'n', 'x' },
            },
            -- search
            {
                '<leader>s"',
                function()
                    Snacks.picker.registers()
                end,
                desc = 'Registers',
            },
            {
                '<leader>s/',
                function()
                    Snacks.picker.search_history()
                end,
                desc = 'Search History',
            },
            {
                '<leader>sa',
                function()
                    Snacks.picker.autocmds()
                end,
                desc = 'Autocmds',
            },
            {
                '<leader>sc',
                function()
                    Snacks.picker.command_history()
                end,
                desc = 'Command History',
            },
            {
                '<leader>sC',
                function()
                    Snacks.picker.commands()
                end,
                desc = 'Commands',
            },
            {
                '<leader>sd',
                function()
                    Snacks.picker.diagnostics()
                end,
                desc = 'Diagnostics',
            },
            {
                '<leader>sD',
                function()
                    Snacks.picker.diagnostics_buffer()
                end,
                desc = 'Buffer Diagnostics',
            },
            {
                '<leader>sh',
                function()
                    Snacks.picker.help()
                end,
                desc = 'Help Pages',
            },
            {
                '<leader>sH',
                function()
                    Snacks.picker.highlights()
                end,
                desc = 'Highlights',
            },
            {
                '<leader>si',
                function()
                    Snacks.picker.icons()
                end,
                desc = 'Icons',
            },
            {
                '<leader>sj',
                function()
                    Snacks.picker.jumps()
                end,
                desc = 'Jumps',
            },
            {
                '<leader>sk',
                function()
                    Snacks.picker.keymaps()
                end,
                desc = 'Keymaps',
            },
            {
                '<leader>sl',
                function()
                    Snacks.picker.loclist()
                end,
                desc = 'Location List',
            },
            {
                '<leader>sM',
                function()
                    Snacks.picker.man()
                end,
                desc = 'Man Pages',
            },
            {
                '<leader>sm',
                function()
                    Snacks.picker.marks()
                end,
                desc = 'Marks',
            },
            {
                '<leader>sR',
                function()
                    Snacks.picker.resume()
                end,
                desc = 'Resume',
            },
            {
                '<leader>sq',
                function()
                    Snacks.picker.qflist()
                end,
                desc = 'Quickfix List',
            },
            {
                '<leader>su',
                function()
                    Snacks.picker.undo()
                end,
                desc = 'Undotree',
            },
            -- ui
            {
                '<leader>uC',
                function()
                    Snacks.picker.colorschemes()
                end,
                desc = 'Colorschemes',
            },
        },
    },

    {
        'folke/snacks.nvim',
        optional = true,
        opts = function(_, opts)
            if PickleVim.plugin.has('trouble.nvim') then
                return vim.tbl_deep_extend('force', opts or {}, {
                    picker = {
                        actions = require('trouble.sources.snacks').actions,
                        win = {
                            input = {
                                keys = {
                                    ['<c-t>'] = {
                                        'trouble_open',
                                        mode = { 'n', 'i' },
                                    },
                                },
                            },
                        },
                    },
                })
            end
        end,
    },

    {
        'neovim/nvim-lspconfig',
        optional = true,
        opts = function()
            local Keys = PickleVim.lsp.keymaps.get()
            vim.list_extend(Keys, {
                {
                    'gd',
                    function()
                        Snacks.picker.lsp_definitions()
                    end,
                    desc = 'Goto Definition',
                    has = 'definition',
                },
                {
                    'gr',
                    function()
                        Snacks.picker.lsp_references()
                    end,
                    nowait = true,
                    desc = 'References',
                },
                {
                    'gI',
                    function()
                        Snacks.picker.lsp_implementations()
                    end,
                    desc = 'Goto Implementation',
                },
                {
                    'gy',
                    function()
                        Snacks.picker.lsp_type_definitions()
                    end,
                    desc = 'Goto T[y]pe Definition',
                },
                {
                    '<leader>ss',
                    function()
                        Snacks.picker.lsp_symbols({ filter = PickleVim.config.kind_filter })
                    end,
                    desc = 'LSP Symbols',
                    has = 'documentSymbol',
                },
                {
                    '<leader>sS',
                    function()
                        Snacks.picker.lsp_workspace_symbols({ filter = PickleVim.config.kind_filter })
                    end,
                    desc = 'LSP Workspace Symbols',
                    has = 'workspace/symbols',
                },
            })
        end,
    },

    {
        'folke/todo-comments.nvim',
        optional = true,
        keys = {
            {
                '<leader>st',
                function()
                    ---@diagnostic disable-next-line: undefined-field
                    Snacks.picker.todo_comments()
                end,
                desc = 'Todo',
            },
            {
                '<leader>sT',
                function()
                    ---@diagnostic disable-next-line: undefined-field
                    Snacks.picker.todo_comments({ keywords = { 'TODO', 'FIX', 'FIXME' } })
                end,
                desc = 'Todo/Fix/Fixme',
            },
        },
    },

    {
        'folke/flash.nvim',
        optional = true,
        specs = {
            {
                'folke/snacks.nvim',
                opts = {
                    picker = {
                        win = {
                            input = {
                                keys = {
                                    ['<a-s>'] = { 'flash', mode = { 'n', 'i' } },
                                    ['s'] = { 'flash' },
                                },
                            },
                        },
                        actions = {
                            flash = function(snacks_picker)
                                require('flash').jump({
                                    pattern = '^',
                                    label = { after = { 0, 0 } },
                                    search = {
                                        mode = 'search',
                                        exclude = {
                                            function(win)
                                                return vim.bo[vim.api.nvim_win_get_buf(win)].filetype
                                                    ~= 'snacks_picker_list'
                                            end,
                                        },
                                    },
                                    action = function(match)
                                        local idx = snacks_picker.list:row2idx(match.pos[1])
                                        snacks_picker.list:_move(idx, true, true)
                                    end,
                                })
                            end,
                        },
                    },
                },
            },
        },
    },
}
