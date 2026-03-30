---@class config.lazy
local M = {}

local setup_lazypath = function()
    local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'

    if not (vim.uv or vim.loop).fs_stat(lazypath) then
        local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
        local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath })

        if vim.v.shell_error ~= 0 then
            vim.api.nvim_echo({
                { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
                { out, 'WarningMsg' },
                { '\nPress any key to exit...' },
            }, true, {})

            vim.fn.getchar()

            os.exit(1)
        end
    end

    vim.opt.rtp:prepend(lazypath)
end

vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

--- See: https://lazy.folke.io/configuration
local config = {
    root = vim.fn.stdpath('data') .. '/lazy',
    defaults = {
        lazy = false,
        version = false,
        cond = nil, ---@type boolean|fun(self:LazyPlugin):boolean|nil
    },
    spec = nil,      ---@type LazySpec
    local_spec = true,
    lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json',
    concurrency = jit.os:find('Windows') and (vim.uv.available_parallelism() * 2) or nil,

    git = {
        log = { '-8' },
        timeout = 120,
        url_format = 'https://github.com/%s.git',
        filter = true,
        throttle = {
            enabled = false,
            rate = 2,
            duration = 5 * 1000,
        },
        cooldown = 0,
    },

    pkg = {
        enabled = true,
        cache = vim.fn.stdpath('state') .. '/lazy/pkg-cache.lua',
        sources = {
            'lazy',
            'rockspec',
            '●',
        },
    },

    rocks = {
        enabled = true,
        root = vim.fn.stdpath('data') .. '/lazy-rocks',
        server = 'https://nvim-neorocks.github.io/rocks-binaries/',
        hererocks = nil,
    },

    dev = {
        patterns = {},
        fallback = false,
    },

    install = {
        missing = true,
        colorscheme = { 'catppuccin' },
    },

    ui = {
        size = { width = 0.8, height = 0.8 },
        wrap = true,
        border = 'solid',
        backdrop = 60,
        title = nil, ---@type string
        title_pos = 'center', ---@type "center" | "left" | "right"
        pills = true, ---@type boolean
        icons = {
            cmd = ' ',
            config = '',
            debug = '● ',
            event = ' ',
            favorite = ' ',
            ft = ' ',
            init = ' ',
            import = ' ',
            keys = ' ',
            lazy = '󰒲 ',
            loaded = '●',
            not_loaded = '○',
            plugin = ' ',
            runtime = ' ',
            require = '󰢱 ',
            source = ' ',
            start = ' ',
            task = '✔ ',
            list = {
                '●',
                '➜',
                '★',
                '‒',
            },
        },
        browser = nil, ---@type string?
        throttle = 1000 / 30,
        custom_keys = {
            ['<localleader>l'] = {
                function(plugin)
                    require('lazy.util').float_term({ 'lazygit', 'log' }, {
                        cwd = plugin.dir,
                    })
                end,
                desc = 'Open lazygit log',
            },

            ['<localleader>t'] = {
                function(plugin)
                    require('lazy.util').float_term(nil, {
                        cwd = plugin.dir,
                    })
                end,
                desc = 'Open terminal in plugin dir',
            },
        },
    },

    headless = {
        process = true,
        log = true,
        task = true,
        colors = true,
    },

    diff = {
        cmd = 'git',
    },

    checker = {
        enabled = true,
        concurrency = nil, ---@type number?
        notify = true,
        frequency = 3600,
        check_pinned = false,
    },

    change_detection = {
        enabled = true,
        notify = false,
    },

    performance = {
        cache = {
            enabled = true,
        },
        reset_packpath = true,
        rtp = {
            reset = true,
            paths = {},
            -- Disable built-in plugins that are replaced by lazy-loaded alternatives
            -- or are unused (e.g., netrwPlugin replaced by Oil.nvim)
            disabled_plugins = {
                'gzip',
                'netrwPlugin',
                'tarPlugin',
                'tohtml',
                'tutor',
                'zipPlugin',
            },
        },
    },

    readme = {
        enabled = true,
        root = vim.fn.stdpath('state') .. '/lazy/readme',
        files = { 'README.md', 'lua/**/README.md' },
        skip_if_doc_exists = true,
    },

    state = vim.fn.stdpath('state') .. '/lazy/state.json',
    profiling = {
        loader = false,
        require = false,
    },
}

---@param opts? LazyConfig
M.setup = function(opts)
    opts = vim.tbl_deep_extend('force', config, opts or {}) or {}

    setup_lazypath()

    require('lazy').setup(opts)

    require('config').setup()
end

return M
