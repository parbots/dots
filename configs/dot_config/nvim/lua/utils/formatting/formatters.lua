---@module 'utils.formatting.formatters'
local M = {}

M.by_ft = {
    lua = { 'stylua' },

    toml = { 'taplo' },
    rust = { 'rustfmt' },

    zsh = { 'shfmt' },
    zshrc = { 'shfmt' },
    bash = { 'shfmt' },
    sh = { 'shfmt' },

    ['*'] = { 'trim' },
    ['_'] = { 'trim' },
}

M.all = {

    stylua = {
        inherit = true,
        prepend_args = {
            '--indent-type',
            'Spaces',
            '--quote-style',
            'AutoPreferSingle',
        },
    },

    taplo = {},

    rustfmt = {},

    trim = {
        inherit = false,
        format = function(_, _, lines, callback)
            local trimmed_lines = {}
            for _, line in ipairs(lines) do
                local trimmed = line:gsub('[\t]+', '    ')
                trimmed = trimmed:gsub('%s+$', '')
                table.insert(trimmed_lines, trimmed)
            end

            local result = {}
            local prev_empty = false
            for _, line in ipairs(trimmed_lines) do
                local is_empty = line == ''
                if not (is_empty and prev_empty) then
                    table.insert(result, line)
                end
                prev_empty = is_empty
            end

            while #result > 0 and result[#result] == '' do
                table.remove(result)
            end

            callback(nil, result)
        end,
    },

    shfmt = {},
}

return M
