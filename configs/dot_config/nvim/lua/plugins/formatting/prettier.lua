--- Prettier formatter integration for Conform.nvim
--- Adds Prettier formatter with smart detection for supported filetypes
--- Only formats files when Prettier has a parser and (optionally) a config
---
--- Features:
---   - Auto-detects if Prettier can format the file (has parser)
---   - Optional config requirement via vim.g.picklevim_prettier_needs_config
---   - Caches config/parser detection for performance
---   - Supports 20+ web filetypes (JS, TS, CSS, HTML, JSON, etc.)
---
--- Configuration:
---   vim.g.picklevim_prettier_needs_config = true  -- Only format if config exists
---   vim.g.picklevim_prettier_needs_config = false -- Format if parser exists (default)
---
--- Prettier Config Files:
---   .prettierrc, .prettierrc.json, .prettierrc.yml, .prettierrc.yaml
---   .prettierrc.json5, .prettierrc.js, .prettierrc.cjs, .prettierrc.mjs
---   .prettierrc.toml, prettier.config.js, prettier.config.cjs, prettier.config.mjs

--- Context passed to condition functions
---@alias ConformCtx { buf: number, filename: string, dirname: string }

local M = {}

----------------------------------------
-- Supported Filetypes
----------------------------------------
-- Filetypes that Prettier can format
local supported_filetypes = {
    'astro',           -- Astro components
    'css',             -- CSS stylesheets
    'html',            -- HTML
    'htmldjango',      -- Django templates
    'javascript',      -- JavaScript
    'javascriptreact', -- JSX
    'json',            -- JSON
    'jsonc',           -- JSON with comments
    'less',            -- LESS stylesheets
    'markdown',        -- Markdown
    'markdown.mdx',    -- MDX (Markdown + JSX)
    'mdx',             -- MDX
    'scss',            -- SCSS/Sass
    'typescript',      -- TypeScript
    'typescriptreact', -- TSX
    'vue',             -- Vue.js components
    'yaml',            -- YAML
}

----------------------------------------
-- Config Detection
----------------------------------------
--- Check if Prettier config exists for the file
--- Runs `prettier --find-config-path` to locate config
---@param ctx ConformCtx Conform context with buffer and file info
---@return boolean has_config Whether a Prettier config was found
M.has_config = function(ctx)
    vim.fn.system({ 'prettier', '--find-config-path', ctx.filename })
    return vim.v.shell_error == 0
end

----------------------------------------
-- Parser Detection
----------------------------------------
--- Check if Prettier has a parser for the file
--- First checks supported_filetypes for known filetypes
--- Falls back to `prettier --file-info` for unknown filetypes
---@param ctx ConformCtx Conform context with buffer and file info
---@return boolean has_parser Whether Prettier can parse the file
M.has_parser = function(ctx)
    local ft = vim.bo[ctx.buf].filetype

    -- Fast path: Check if filetype is in our supported list
    if vim.tbl_contains(supported_filetypes, ft) then
        return true
    end

    -- Slow path: Ask Prettier if it can infer a parser for the file
    local ret = vim.fn.system({ 'prettier', '--file-info', ctx.filename })
    local ok, parser = pcall(function()
        return vim.fn.json_decode(ret).inferredParser
    end)

    return ok and parser and parser ~= vim.NIL
end

----------------------------------------
-- Performance Optimization
----------------------------------------
-- Memoize config and parser detection to avoid repeated shell calls
-- Cache is per-file (keyed by filename) and cleared on directory change
local function ctx_filename(ctx)
    return ctx.filename
end
M.has_config = PickleVim.memoize(M.has_config, ctx_filename)
M.has_parser = PickleVim.memoize(M.has_parser, ctx_filename)

return {
    ----------------------------------------
    -- Prettier Formatter Configuration
    ----------------------------------------
    {
        'stevearc/conform.nvim',
        opts = function(_, opts)
            -- Initialize formatters_by_ft table if not exists
            opts.formatters_by_ft = opts.formatters_by_ft or {}

            ----------------------------------------
            -- Register Prettier for Supported Filetypes
            ----------------------------------------
            -- Add 'prettier' to the formatter list for each supported filetype
            for _, ft in pairs(supported_filetypes) do
                opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
                table.insert(opts.formatters_by_ft[ft], 'prettier')
            end

            -- Initialize formatters table if not exists
            opts.formatters = opts.formatters or {}

            ----------------------------------------
            -- Prettier Formatter Definition
            ----------------------------------------
            opts.formatters.prettier = {
                -- Condition: Only use Prettier if file is supported
                ---@param _ any Self (unused)
                ---@param ctx ConformCtx Context with buffer and file info
                ---@return boolean should_format Whether to use Prettier
                condition = function(_, ctx)
                    -- Check if Prettier has a parser for this file
                    local has_parser = M.has_parser(ctx)

                    -- Check if config is required (via global setting)
                    local needs_config = vim.g.picklevim_prettier_needs_config == true

                    -- Only format if:
                    -- 1. Prettier can parse the file, AND
                    -- 2. Either config is not required OR config exists
                    return has_parser and (not needs_config or M.has_config(ctx))
                end,
            }
        end,
    },
}
