---@class picklevim.utils.ui
local M = {}

--- Custom foldtext that shows the first line of the fold
--- Used with 'foldtext' option
---@return string text First line of the folded region
M.foldtext = function()
    return vim.api.nvim_buf_get_lines(0, vim.v.lnum - 1, vim.v.lnum, false)[1]
end

--- Custom fold expression that uses Treesitter when available
--- Falls back to manual folding if Treesitter parser not available
--- Used with 'foldexpr' option
---@return string|number fold_level Fold level or '0' for no fold
M.foldexpr = function()
    local buf = vim.api.nvim_get_current_buf()

    -- Cache whether Treesitter folds are available for this buffer
    if vim.b[buf].ts_folds == nil then
        -- No folding for empty filetype
        if vim.bo[buf].filetype == '' then
            return 0
        end

        -- Disable Treesitter folds for dashboard
        if vim.bo[buf].filetype:find('dashboard') then
            vim.b[buf].ts_folds = false
        else
            -- Check if Treesitter parser is available
            -- In Neovim 0.12+, get_parser returns nil instead of throwing
            vim.b[buf].ts_folds = vim.treesitter.get_parser(buf) ~= nil
        end
    end

    -- Use Treesitter foldexpr if available, otherwise no folding
    return vim.b[buf].ts_folds and vim.treesitter.foldexpr() or '0'
end

return M
