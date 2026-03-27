---@module 'utils.formatting.formatters'
---Formatter definitions and filetype mappings
local M = {}

--- Formatter mapping by filetype
--- Keys are filetypes, values are arrays of formatter names (in priority order)
--- Special keys: '*' applies to all files, '_' applies to files without filetype
M.by_ft = {
    lua = { 'stylua' },

    toml = { 'taplo' },
    rust = { 'rustfmt' },

    -- Shell scripts
    zsh = { 'shfmt' },
    zshrc = { 'shfmt' },
    bash = { 'shfmt' },
    sh = { 'shfmt' },

    -- Universal formatters
    ['*'] = { 'trim' }, -- Applies to all files
    ['_'] = { 'trim' }, -- Applies to files without filetype
}

--- All formatter configurations
--- Keys are formatter names, values are configuration tables
--- These configurations extend or override Conform.nvim defaults
M.all = {

    ----------------------------------------
    -- Language-specific formatters
    ----------------------------------------

    -- Lua: stylua
    stylua = {
        inherit = true, -- Inherit Conform.nvim defaults
        prepend_args = {
            '--indent-type',
            'Spaces',
            '--quote-style',
            'AutoPreferSingle',
        },
    },

    -- TOML: taplo
    taplo = {},

    -- Rust: rustfmt
    rustfmt = {
        -- Uncomment to use specific rustfmt binary
        -- command = '~/.cargo/bin/rustfmt',
    },

    ----------------------------------------
    -- Universal formatters
    ----------------------------------------

    -- Custom whitespace trimmer
    -- Applies to all files to clean up whitespace
    trim = {
        inherit = false, -- Custom formatter, don't use Conform defaults
        format = function(_, _, lines, callback)
            -- Step 1: Convert tabs to spaces and trim trailing whitespace
            local trimmed_lines = {}
            for _, line in ipairs(lines) do
                -- Convert tabs to 4 spaces
                local trimmed = line:gsub('[\t]+', '    ')
                -- Remove trailing whitespace
                trimmed = trimmed:gsub('%s+$', '')
                table.insert(trimmed_lines, trimmed)
            end

            -- Step 2: Reduce consecutive empty lines to one empty line
            local result = {}
            local prev_empty = false
            for _, line in ipairs(trimmed_lines) do
                local is_empty = line == ''
                -- Skip line if both current and previous are empty
                if not (is_empty and prev_empty) then
                    table.insert(result, line)
                end
                prev_empty = is_empty
            end

            -- Step 3: Remove all trailing newlines at end of file
            while #result > 0 and result[#result] == '' do
                table.remove(result)
            end

            -- Return formatted lines (nil error, result lines)
            callback(nil, result)
        end,
    },

    ----------------------------------------
    -- Shell formatters
    ----------------------------------------

    -- Shell: shfmt
    shfmt = {},
}

return M
