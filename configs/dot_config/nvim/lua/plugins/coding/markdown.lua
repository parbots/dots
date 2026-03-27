--- render-markdown.nvim - Live Markdown rendering
--- Renders Markdown with beautiful formatting in Neovim
--- Shows headings, lists, code blocks, tables, and more with proper styling
---
--- Features:
---   - Real-time Markdown rendering
---   - Obsidian-style preset (clean, modern look)
---   - Code block syntax highlighting
---   - Table rendering with borders
---   - Checkbox/task list rendering
---   - Callout/admonition support
---   - Math/LaTeX rendering (disabled)
---   - Blink.cmp completion integration
---
--- Render Modes:
---   - n (normal): Render in normal mode
---   - c (command): Render in command mode
---   - t (terminal): Render in terminal mode
---   - NOT in insert mode (raw markdown for editing)
---
--- Commands:
---   :RenderMarkdown - Toggle Markdown rendering
---
--- File Size Limit:
---   Max 10MB for performance
---
--- Preset:
---   Obsidian - Mimics Obsidian.md styling

return {
    ----------------------------------------
    -- render-markdown.nvim - Markdown Rendering
    ----------------------------------------
    {
        'MeanderingProgrammer/render-markdown.nvim',
        dependencies = {
            'nvim-treesitter/nvim-treesitter',  -- Required for parsing
            'echasnovski/mini.icons',           -- Icons for callouts
        },

        ----------------------------------------
        -- Loading
        ----------------------------------------
        ft = { 'markdown' },  -- Load only for Markdown files
        cmd = { 'RenderMarkdown' },  -- Lazy-load on command

        ----------------------------------------
        -- Configuration
        ----------------------------------------
        opts = {
            ----------------------------------------
            -- Enable/Disable
            ----------------------------------------
            enabled = true,  -- Enable rendering by default

            ----------------------------------------
            -- Render Modes
            ----------------------------------------
            -- Which modes to render Markdown in
            -- Excludes insert mode for raw editing
            render_modes = { 'n', 'c', 't' },

            ----------------------------------------
            -- Performance
            ----------------------------------------
            max_file_size = 10.0,  -- Max file size in MB (10MB limit)

            debounce = 100,  -- Debounce rendering updates (ms)

            ----------------------------------------
            -- Styling Preset
            ----------------------------------------
            preset = 'obsidian',  -- Use Obsidian.md-style rendering

            ----------------------------------------
            -- Completion Integration
            ----------------------------------------
            completions = {
                blink = {
                    enabled = true,  -- Enable blink.cmp integration
                },
            },

            ----------------------------------------
            -- LaTeX Rendering
            ----------------------------------------
            latex = {
                enabled = false,  -- Disable LaTeX/math rendering
            },
        },
    },
}
