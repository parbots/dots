---@class picklevim.utils.ui
local M = {}

---@return string|number
M.foldexpr = function()
    local buf = vim.api.nvim_get_current_buf()

    if vim.b[buf].ts_folds == nil then
        if vim.bo[buf].filetype == '' then
            return 0
        end

        if vim.bo[buf].filetype:find('dashboard') then
            vim.b[buf].ts_folds = false
        else
            vim.b[buf].ts_folds = vim.treesitter.get_parser(buf) ~= nil
        end
    end

    return vim.b[buf].ts_folds and vim.treesitter.foldexpr() or '0'
end

return M
