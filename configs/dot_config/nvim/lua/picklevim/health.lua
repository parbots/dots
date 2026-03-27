---@class picklevim.health
local M = {}

M.check = function()
    vim.health.start('PickleVim Configuration')

    -- Check Neovim version
    local nvim_version = vim.version()
    if nvim_version.major >= 0 and nvim_version.minor >= 10 then
        vim.health.ok(
            string.format('Neovim version: %s.%s.%s', nvim_version.major, nvim_version.minor, nvim_version.patch)
        )
    else
        vim.health.error(
            string.format('Neovim version: %s.%s.%s', nvim_version.major, nvim_version.minor, nvim_version.patch),
            { 'PickleVim requires Neovim 0.10.0 or later' }
        )
    end

    -- Check required binaries
    vim.health.start('Required Binaries')
    local required = {
        { name = 'git', required = true },
        { name = 'rg', required = true, desc = 'ripgrep (for grep/search)' },
        { name = 'fd', required = false, desc = 'fd (for faster file finding)' },
        { name = 'node', required = false, desc = 'Node.js (for LSP servers)' },
    }

    for _, bin in ipairs(required) do
        local desc = bin.desc or bin.name
        if vim.fn.executable(bin.name) == 1 then
            vim.health.ok(desc .. ' found: ' .. vim.fn.exepath(bin.name))
        else
            if bin.required then
                vim.health.error(desc .. ' not found', { 'Install ' .. bin.name })
            else
                vim.health.warn(desc .. ' not found', { 'Install ' .. bin.name .. ' for better performance' })
            end
        end
    end

    -- Check LSP servers
    vim.health.start('LSP Servers')
    local servers = require('utils.lsp.servers')
    local checked_servers = {}

    for server_name, server_config in pairs(servers) do
        if type(server_config) == 'table' and server_config.enabled then
            table.insert(checked_servers, server_name)
        end
    end

    table.sort(checked_servers)

    for _, server in ipairs(checked_servers) do
        -- Try to check if the server is available
        local ok = vim.fn.executable(server) == 1
        if ok then
            vim.health.ok(server .. ' installed')
        else
            vim.health.info(server .. ' not installed', { 'Install via :Mason or manually' })
        end
    end

    -- Check formatters
    vim.health.start('Formatters')
    local formatters = {
        { name = 'stylua', ft = 'lua' },
        { name = 'prettier', ft = 'typescript/javascript' },
        { name = 'rustfmt', ft = 'rust' },
        { name = 'shfmt', ft = 'shell' },
        { name = 'taplo', ft = 'toml' },
    }

    for _, fmt in ipairs(formatters) do
        if vim.fn.executable(fmt.name) == 1 then
            vim.health.ok(string.format('%s found (%s)', fmt.name, fmt.ft))
        else
            vim.health.info(
                string.format('%s not found (%s)', fmt.name, fmt.ft),
                { 'Install via :Mason or package manager' }
            )
        end
    end

    -- Check plugin configuration
    vim.health.start('Plugin Configuration')

    -- Check if lazy.nvim is loaded
    local lazy_ok, _ = pcall(require, 'lazy')
    if lazy_ok then
        vim.health.ok('lazy.nvim loaded')
    else
        vim.health.error('lazy.nvim not loaded')
    end

    -- Check for conflicting plugins
    if PickleVim.plugin.has('nvim-cmp') and PickleVim.plugin.has('blink.cmp') then
        vim.health.warn('Both nvim-cmp and blink.cmp detected', { 'Consider using only one completion engine' })
    end

    -- Check global variables
    vim.health.start('Configuration Variables')
    local vars = {
        { name = 'mapleader', expected = ' ' },
        { name = 'maplocalleader', expected = '\\' },
        { name = 'root_spec', type = 'table' },
        { name = 'autoformat', type = 'boolean' },
    }

    for _, var in ipairs(vars) do
        local value = vim.g[var.name]
        if value == nil then
            vim.health.warn('vim.g.' .. var.name .. ' is not set')
        elseif var.expected and value ~= var.expected then
            vim.health.info(string.format('vim.g.%s = %s (expected: %s)', var.name, vim.inspect(value), var.expected))
        elseif var.type and type(value) ~= var.type then
            vim.health.warn(
                string.format('vim.g.%s has wrong type: %s (expected: %s)', var.name, type(value), var.type)
            )
        else
            vim.health.ok(string.format('vim.g.%s = %s', var.name, vim.inspect(value)))
        end
    end

    -- Check PickleVim namespace
    vim.health.start('PickleVim Namespace')
    if _G.PickleVim then
        vim.health.ok('PickleVim global namespace exists')

        local modules = { 'config', 'formatting', 'lsp', 'root', 'plugin', 'ui' }
        for _, mod in ipairs(modules) do
            if PickleVim[mod] then
                vim.health.ok(string.format('PickleVim.%s loaded', mod))
            else
                vim.health.warn(string.format('PickleVim.%s not loaded', mod))
            end
        end
    else
        vim.health.error('PickleVim global namespace not found')
    end
end

return M
