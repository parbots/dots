--- Git integration plugins
--- Provides git signs in the gutter, inline blame, and LazyGit terminal UI
---
--- Gitsigns Features:
---   - Visual indicators for added/changed/deleted lines
---   - Inline git blame with author and time
---   - Hunk navigation and staging
---   - Preview changes inline
---   - Diff views
---   - Text objects for hunks (ih)
---
--- LazyGit Features:
---   - Full-featured git UI in floating terminal
---   - Staging, committing, pushing, pulling
---   - Branch management
---   - Conflict resolution
---   - Rebase, merge, cherry-pick
---
--- Keybindings (Gitsigns):
---   ]h / [h - Next/prev hunk
---   ]H / [H - First/last hunk
---   <leader>ghs - Stage hunk
---   <leader>ghr - Reset hunk
---   <leader>ghS - Stage buffer
---   <leader>ghu - Undo stage hunk
---   <leader>ghR - Reset buffer
---   <leader>ghp - Preview hunk inline
---   <leader>ghb - Blame line (full)
---   <leader>ghB - Blame buffer
---   <leader>ghd - Diff this
---   <leader>ghD - Diff this ~
---   ih (visual/operator) - Select hunk text object
---
--- Keybindings (LazyGit):
---   <leader>gg - Open LazyGit

return {
    ----------------------------------------
    -- Gitsigns - Git Signs and Inline Blame
    ----------------------------------------
    {
        'lewis6991/gitsigns.nvim',
        event = { 'LazyFile' },  -- Load when opening files

        opts = {
            ----------------------------------------
            -- Sign Column Icons
            ----------------------------------------
            -- Icons for unstaged changes
            signs = {
                add = { text = '▎' },          -- Added lines
                change = { text = '▎' },       -- Modified lines
                delete = { text = '' },       -- Deleted lines (bottom)
                topdelete = { text = '' },    -- Deleted lines (top)
                changedelete = { text = '▎' }, -- Changed + deleted
                untracked = { text = '┆' },    -- Untracked files
            },

            -- Icons for staged changes
            signs_staged = {
                add = { text = '▎' },
                change = { text = '▎' },
                delete = { text = '' },
                topdelete = { text = '' },
                changedelete = { text = '▎' },
                untracked = { text = '┆' },
            },

            ----------------------------------------
            -- Display Options
            ----------------------------------------
            numhl = true,  -- Highlight line numbers for changed lines

            attach_to_untracked = true,  -- Show signs for untracked files

            ----------------------------------------
            -- Git Blame Configuration
            ----------------------------------------
            current_line_blame = true,  -- Show inline git blame

            current_line_blame_opts = {
                virt_text = true,           -- Use virtual text for blame
                virt_text_pos = 'eol',      -- Position at end of line (eol/overlay/right_align)
                delay = 1000,               -- Delay before showing blame (ms)
                ignore_whitespace = false,  -- Don't ignore whitespace changes
                virt_text_priority = 100,   -- Virtual text priority
                use_focus = true,           -- Only show on focused window
            },

            -- Blame format: "Author, Time - Summary"
            current_line_blame_formatter = '<author>, <author_time:%R> - <summary>',

            ----------------------------------------
            -- Preview Window Configuration
            ----------------------------------------
            preview_config = {
                border = 'rounded',     -- Rounded border for preview
                style = 'minimal',      -- Minimal style (no UI chrome)
                relative = 'cursor',    -- Position relative to cursor
                row = 0,                -- Vertical offset
                col = 1,                -- Horizontal offset
            },

            ----------------------------------------
            -- Integrations
            ----------------------------------------
            trouble = true,  -- Integrate with Trouble.nvim

            ----------------------------------------
            -- Keybindings
            ----------------------------------------
            on_attach = function(buffer)
                local gs = package.loaded.gitsigns

                -- Helper to set buffer-local keymaps
                local map = function(mode, l, r, desc)
                    vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
                end

                ----------------------------------------
                -- Hunk Navigation
                ----------------------------------------
                -- Next hunk (or ]c in diff mode)
                map('n', ']h', function()
                    if vim.wo.diff then
                        vim.cmd.normal({ ']c', bang = true })
                    else
                        gs.nav_hunk('next')
                    end
                end, 'Next Hunk')

                -- Previous hunk (or [c in diff mode)
                map('n', '[h', function()
                    if vim.wo.diff then
                        vim.cmd.normal({ '[c', bang = true })
                    else
                        gs.nav_hunk('prev')
                    end
                end, 'Prev Hunk')

                -- Last hunk in buffer
                map('n', ']H', function()
                    gs.nav_hunk('last')
                end, 'Last Hunk')

                -- First hunk in buffer
                map('n', '[H', function()
                    gs.nav_hunk('first')
                end, 'First Hunk')

                ----------------------------------------
                -- Hunk Actions
                ----------------------------------------
                map({ 'n', 'v' }, '<leader>ghs', ':Gitsigns stage_hunk<CR>', 'Stage Hunk')
                map({ 'n', 'v' }, '<leader>ghr', ':Gitsigns reset_hunk<CR>', 'Reset Hunk')
                map('n', '<leader>ghS', gs.stage_buffer, 'Stage Buffer')
                map('n', '<leader>ghu', gs.undo_stage_hunk, 'Undo Stage Hunk')
                map('n', '<leader>ghR', gs.reset_buffer, 'Reset Buffer')
                map('n', '<leader>ghp', gs.preview_hunk_inline, 'Preview Hunk Inline')

                ----------------------------------------
                -- Blame
                ----------------------------------------
                -- Show full blame for current line
                map('n', '<leader>ghb', function()
                    gs.blame_line({ full = true })
                end, 'Blame Line')

                -- Show blame for entire buffer
                map('n', '<leader>ghB', function()
                    gs.blame()
                end, 'Blame Buffer')

                ----------------------------------------
                -- Diff
                ----------------------------------------
                -- Diff current buffer against index
                map('n', '<leader>ghd', gs.diffthis, 'Diff This')

                -- Diff current buffer against HEAD~
                map('n', '<leader>ghD', function()
                    gs.diffthis('~')
                end, 'Diff This ~')

                ----------------------------------------
                -- Text Objects
                ----------------------------------------
                -- Select hunk as text object (visual/operator pending)
                map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', 'GitSigns Select Hunk')
            end,
        },

        config = function(_, opts)
            require('gitsigns').setup(opts)
        end,
    },

    ----------------------------------------
    -- LazyGit - Terminal UI for Git
    ----------------------------------------
    {
        'kdheepak/lazygit.nvim',
        lazy = true,
        cmd = {
            'LazyGit',                  -- Open LazyGit
            'LazyGitConfig',            -- Edit LazyGit config
            'LazyGitCurrentFile',       -- Open LazyGit for current file
            'LazyGitFilter',            -- Filter commits
            'LazyGitFilterCurrentFile', -- Filter commits for current file
        },
        dependencies = {
            'nvim-lua/plenary.nvim',
        },
        keys = {
            { '<leader>gg', '<cmd>LazyGit<cr>', desc = 'LazyGit' },
        },
    },

    ----------------------------------------
    -- Neogit - Alternative Git UI (Commented Out)
    ----------------------------------------
    -- Alternative to LazyGit - Lua-native git UI
    -- Uncomment to use instead of/alongside LazyGit
    -- {
    --     'NeogitOrg/neogit',
    --     dependencies = {
    --         'nvim-lua/plenary.nvim',  -- required
    --         'sindrets/diffview.nvim', -- optional - Diff integration
    --
    --         -- Picker integration (choose one):
    --         -- 'nvim-telescope/telescope.nvim',
    --         -- 'ibhagwan/fzf-lua',
    --         'echasnovski/mini.pick',
    --     },
    -- },
}
