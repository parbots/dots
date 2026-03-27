---@class picklevim.utils.mini
---Mini.nvim integration helpers
local M = {}

--- Create a text object for the entire buffer
--- Used with mini.ai for 'g' text object (entire file)
---@param ai_type string 'a' for around (including whitespace) or 'i' for inside (excluding leading/trailing blank lines)
---@return table region Region specification with 'from' and 'to' positions
M.ai_buffer = function(ai_type)
    local start_line, end_line = 1, vim.fn.line('$')

    -- For 'inside', exclude leading and trailing blank lines
    if ai_type == 'i' then
        local first_nonblank, last_nonblank = vim.fn.nextnonblank(start_line), vim.fn.prevnonblank(end_line)

        -- If entire buffer is blank, return start position only
        if first_nonblank == 0 or last_nonblank == 0 then
            return { from = { line = start_line, col = 1 } }
        end

        start_line, end_line = first_nonblank, last_nonblank
    end

    -- Calculate end column (at least 1 for empty lines)
    local to_col = math.max(vim.fn.getline(end_line):len(), 1)
    return { from = { line = start_line, col = 1 }, to = { line = end_line, col = to_col } }
end

--- Register mini.ai text objects with which-key for better discoverability
--- Adds descriptions for all text objects (around/inside/next/last)
---@param opts table mini.ai configuration options
M.ai_whichkey = function(opts)
    -- All available mini.ai text objects with descriptions
    local objects = {
        { ' ', desc = 'whitespace' },
        { '"', desc = '" string' },
        { "'", desc = "' string" },
        { '(', desc = '() block' },
        { ')', desc = '() block with ws' },
        { '<', desc = '<> block' },
        { '>', desc = '<> block with ws' },
        { '?', desc = 'user prompt' },
        { 'U', desc = 'use/call without dot' },
        { '[', desc = '[] block' },
        { ']', desc = '[] block with ws' },
        { '_', desc = 'underscore' },
        { '`', desc = '` string' },
        { 'a', desc = 'argument' },
        { 'b', desc = ')]} block' },
        { 'c', desc = 'class' },
        { 'd', desc = 'digit(s)' },
        { 'e', desc = 'CamelCase / snake_case' },
        { 'f', desc = 'function' },
        { 'g', desc = 'entire file' },
        { 'i', desc = 'indent' },
        { 'o', desc = 'block, conditional, loop' },
        { 'q', desc = 'quote `"\'' },
        { 't', desc = 'tag' },
        { 'u', desc = 'use/call' },
        { '{', desc = '{} block' },
        { '}', desc = '{} with ws' },
    }

    local ret = { mode = { 'o', 'x' } }

    -- Get mapping configuration (a, i, an, in, al, il)
    ---@type table<string, string>
    local mappings = vim.tbl_extend('force', {}, {
        around = 'a',
        inside = 'i',
        around_next = 'an',
        inside_next = 'in',
        around_last = 'al',
        inside_last = 'il',
    }, opts.mappings or {})

    -- Remove goto mappings (not text objects)
    mappings.goto_left = nil
    mappings.goto_right = nil

    -- Register each prefix with all text objects
    for name, prefix in pairs(mappings) do
        -- Clean up name for display
        name = name:gsub('^around_', ''):gsub('^inside_', '')
        ret[#ret + 1] = { prefix, group = name }

        -- Add all text objects with this prefix
        for _, obj in ipairs(objects) do
            local desc = obj.desc

            -- Remove 'with ws' for inside text objects
            if prefix:sub(1, 1) == 'i' then
                desc = desc:gsub(' with ws', '')
            end

            ret[#ret + 1] = { prefix .. obj[1], desc = obj.desc }
        end
    end

    require('which-key').add(ret, { notify = false })
end

--- Enhanced mini.pairs setup with smart skipping logic
--- Adds context-aware auto-pairing that respects:
--- - Characters after cursor (skip if alphanumeric)
--- - Treesitter context (skip in strings/comments)
--- - Balanced pairs (skip if would create imbalance)
--- - Markdown code blocks (expand `` to code fence)
---@param opts { skip_next: string, skip_ts: string[], skip_unbalanced: boolean, markdown: boolean }
M.pairs = function(opts)
    local pairs = require('mini.pairs')
    pairs.setup(opts)

    -- Save original open function
    local mini_open = pairs.open

    --- Enhanced open function with smart skipping
    ---@param pair string Character pair (e.g., "()")
    ---@param neigh_pattern string | nil Neighbor pattern
    ---@return string result Character to insert
    local new_open = function(pair, neigh_pattern)
        -- Don't interfere with command-line mode
        if vim.fn.getcmdline() ~= '' then
            return mini_open(pair, neigh_pattern)
        end

        local o, c = pair:sub(1, 1), pair:sub(2, 2)
        local line = vim.api.nvim_get_current_line()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local next = line:sub(cursor[2] + 1, cursor[2] + 1)
        local before = line:sub(1, cursor[2])

        -- Special case: Markdown code blocks (`` -> code fence)
        if opts.markdown and o == '`' and vim.bo.filetype == 'markdown' and before:match('^%s*``') then
            return '`\n```' .. vim.api.nvim_replace_termcodes('<up>', true, true, true)
        end

        -- Skip if next character matches skip pattern (e.g., alphanumeric)
        if opts.skip_next and next ~= '' and next:match(opts.skip_next) then
            return o
        end

        -- Skip if inside certain Treesitter captures (e.g., string, comment)
        if opts.skip_ts and #opts.skip_ts > 0 then
            local ok, captures = pcall(vim.treesitter.get_captures_at_pos, 0, cursor[1] - 1, math.max(cursor[2] - 1, 0))
            for _, capture in ipairs(ok and captures or {}) do
                if vim.tbl_contains(opts.skip_ts, capture.capture) then
                    return o
                end
            end
        end

        -- Skip if would create unbalanced pairs
        if opts.skip_unbalanced and next == c and c ~= o then
            local _, count_open = line:gsub(vim.pesc(pair:sub(1, 1)), '')
            local _, count_close = line:gsub(vim.pesc(pair:sub(2, 2)), '')

            -- If more closes than opens, adding another pair would create imbalance
            if count_close > count_open then
                return o
            end
        end

        -- Use default mini.pairs behavior
        return mini_open(pair, neigh_pattern)
    end

    -- Replace open function with enhanced version
    pairs.open = new_open
end

return M
