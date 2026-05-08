---@alias ConformCtx { buf: number, filename: string, dirname: string }

local M = {}

local supported_filetypes = {
    'astro',
    'css',
    'html',
    'htmldjango',
    'javascript',
    'javascriptreact',
    'json',
    'jsonc',
    'less',
    'markdown',
    'markdown.mdx',
    'mdx',
    'scss',
    'typescript',
    'typescriptreact',
    'vue',
    'yaml',
}

-- Base Prettier options used when a project has no local Prettier config.
-- A project-local config (.prettierrc, prettier.config.js, etc.) takes precedence.
local base_config = {
    experimentalTernaries = true,
    experimentalOperatorPosition = 'start',
    printWidth = 80,
    tabWidth = 4,
    useTabs = false,
    semi = true,
    singleQuote = true,
    quoteProps = 'as-needed',
    jsxSingleQuote = true,
    trailingComma = 'all',
    bracketSpacing = true,
    objectWrap = 'preserve',
    bracketSameLine = false,
    arrowParens = 'always',
    proseWrap = 'preserve',
    htmlWhitespaceSensitivity = 'css',
    endOfLine = 'lf',
    embeddedLanguageFormatting = 'auto',
    singleAttributePerLine = false,
}

---@param name string Prettier option name in camelCase
---@return string flag CLI flag in kebab-case (e.g. 'jsxSingleQuote' -> '--jsx-single-quote')
local function option_to_flag(name)
    return '--' .. (name:gsub('(%l)(%u)', '%1-%2')):lower()
end

---@param config table<string, any> Prettier options in camelCase
---@return string[] args Prettier CLI args expressing the given options
local function config_to_cli_args(config)
    local args = {}
    for name, value in pairs(config) do
        local flag = option_to_flag(name)
        if type(value) == 'boolean' then
            table.insert(args, value and flag or '--no-' .. flag:sub(3))
        else
            table.insert(args, flag .. '=' .. tostring(value))
        end
    end
    return args
end

local base_args = config_to_cli_args(base_config)

---@param ctx ConformCtx Conform context with buffer and file info
---@return boolean has_config Whether a Prettier config was found
M.has_config = function(ctx)
    vim.fn.system({ 'prettier', '--find-config-path', ctx.filename })
    return vim.v.shell_error == 0
end

---@param ctx ConformCtx Conform context with buffer and file info
---@return boolean has_parser Whether Prettier can parse the file
M.has_parser = function(ctx)
    local ft = vim.bo[ctx.buf].filetype

    if vim.tbl_contains(supported_filetypes, ft) then
        return true
    end

    -- Fallback: ask Prettier if it can infer a parser for the file
    local ret = vim.fn.system({ 'prettier', '--file-info', ctx.filename })
    local ok, parser = pcall(function()
        return vim.fn.json_decode(ret).inferredParser
    end)

    return ok and parser and parser ~= vim.NIL
end

local function ctx_filename(ctx)
    return ctx.filename
end
M.has_config = PickleVim.memoize(M.has_config, ctx_filename)
M.has_parser = PickleVim.memoize(M.has_parser, ctx_filename)

return {
    {
        'stevearc/conform.nvim',
        opts = function(_, opts)
            opts.formatters_by_ft = opts.formatters_by_ft or {}

            for _, ft in pairs(supported_filetypes) do
                opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
                table.insert(opts.formatters_by_ft[ft], 'prettier')
            end

            opts.formatters = opts.formatters or {}

            opts.formatters.prettier = {
                ---@param _ any Self (unused)
                ---@param ctx ConformCtx Context with buffer and file info
                ---@return boolean should_format Whether to use Prettier
                condition = function(_, ctx)
                    local has_parser = M.has_parser(ctx)

                    -- When vim.g.picklevim_prettier_needs_config is true, require a
                    -- config file (.prettierrc, prettier.config.js, etc.) to exist in
                    -- the project. This prevents Prettier from reformatting files in
                    -- projects that don't use it.
                    local needs_config = vim.g.picklevim_prettier_needs_config == true

                    return has_parser and (not needs_config or M.has_config(ctx))
                end,

                ---@param _ any Self (unused)
                ---@param ctx ConformCtx Context with buffer and file info
                ---@return string[] args CLI args to prepend (base config when project has none)
                prepend_args = function(_, ctx)
                    if M.has_config(ctx) then
                        return {}
                    end
                    return base_args
                end,
            }
        end,
    },
}
