--- Lazy.nvim plugin manager configuration
--- Handles bootstrapping, installation, and plugin management setup

---@class config.lazy
local M = {}

--- Bootstrap lazy.nvim plugin manager
--- Clones lazy.nvim if not installed and adds to runtime path
local setup_lazypath = function()
    local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'

    -- Check if lazy.nvim is already installed
    if not (vim.uv or vim.loop).fs_stat(lazypath) then
        local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
        local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath })

        -- Handle clone failure
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

    -- Add lazy.nvim to runtime path
    vim.opt.rtp:prepend(lazypath)
end

-- Set leader keys before lazy.nvim loads
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

--- Lazy.nvim configuration
--- See: https://lazy.folke.io/configuration
local config = {
    ----------------------------------------
    -- Core Settings
    ----------------------------------------
    root = vim.fn.stdpath('data') .. '/lazy', -- Plugin installation directory
    defaults = {
        lazy = false,    -- Plugins load at startup by default (use events/keys for lazy loading)
        version = false, -- Don't pin to versions (use latest commits)
        cond = nil,      ---@type boolean|fun(self:LazyPlugin):boolean|nil
    },
    spec = nil,      ---@type LazySpec Plugin specifications (set in init.lua)
    local_spec = true, -- Load project-specific .lazy.lua files
    lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json', -- Lock file for reproducible installs
    concurrency = jit.os:find('Windows') and (vim.uv.available_parallelism() * 2) or nil, -- Windows: use 2x parallelism

    ----------------------------------------
    -- Git Configuration
    ----------------------------------------
    git = {
        log = { '-8' },  -- Show last 8 commits in git log
        timeout = 120,   -- Kill git processes after 2 minutes
        url_format = 'https://github.com/%s.git',
        filter = true,   -- Use --filter=blob:none for faster clones
        throttle = {
            enabled = false, -- Throttling disabled by default
            rate = 2,
            duration = 5 * 1000, -- 5 seconds in milliseconds
        },
        cooldown = 0,
    },

    ----------------------------------------
    -- Package Management
    ----------------------------------------
    pkg = {
        enabled = true,
        cache = vim.fn.stdpath('state') .. '/lazy/pkg-cache.lua',
        sources = {
            'lazy',
            'rockspec', -- Used when rocks.enabled is true
            'packspec',
        },
    },

    ----------------------------------------
    -- Lua Rocks Support
    ----------------------------------------
    rocks = {
        enabled = true,
        root = vim.fn.stdpath('data') .. '/lazy-rocks',
        server = 'https://nvim-neorocks.github.io/rocks-binaries/',
        hererocks = nil,
    },

    ----------------------------------------
    -- Development Settings
    ----------------------------------------
    dev = {
        patterns = {},       -- Local dev patterns (e.g., {"folke"} for local folke/* plugins)
        fallback = false,    -- Don't fall back to git if local plugin missing
    },

    ----------------------------------------
    -- Installation
    ----------------------------------------
    install = {
        missing = true,                 -- Auto-install missing plugins on startup
        colorscheme = { 'catppuccin' }, -- Colorschemes to try during installation
    },

    ----------------------------------------
    -- UI Configuration
    ----------------------------------------
    ui = {
        size = { width = 0.8, height = 0.8 },
        wrap = true, -- wrap the lines in the ui
        border = 'none',
        backdrop = 60,
        title = nil, ---@type string only works when border is not "none"
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
        throttle = 1000 / 30, -- how frequently should the ui process render events
        -- Custom keymaps in Lazy.nvim UI
        custom_keys = {
            -- Open lazygit log for plugin
            ['<localleader>l'] = {
                function(plugin)
                    require('lazy.util').float_term({ 'lazygit', 'log' }, {
                        cwd = plugin.dir,
                    })
                end,
                desc = 'Open lazygit log',
            },

            -- Open terminal in plugin directory
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

    ----------------------------------------
    -- Headless Mode Settings
    ----------------------------------------
    headless = {
        process = true,
        log = true,
        task = true,
        colors = true,
    },

    ----------------------------------------
    -- Diff Configuration
    ----------------------------------------
    diff = {
        cmd = 'git',
    },

    ----------------------------------------
    -- Update Checker
    ----------------------------------------
    checker = {
        enabled = true,              -- Enable automatic update checking
        concurrency = nil,           ---@type number? Set to 1 for slow checking
        notify = true,               -- Notify when updates found
        frequency = 3600,            -- Check every hour
        check_pinned = false,        -- Don't check pinned packages
    },

    ----------------------------------------
    -- File Change Detection
    ----------------------------------------
    change_detection = {
        enabled = true,   -- Enable file change detection
        notify = false,   -- Don't notify on changes (can be noisy)
    },

    ----------------------------------------
    -- Performance Optimizations
    ----------------------------------------
    performance = {
        cache = {
            enabled = true, -- Enable module caching for faster startup
        },
        reset_packpath = true, -- Reset packpath for faster startup
        rtp = {
            reset = true, -- Reset runtime path to defaults
            paths = {},   -- Additional custom paths for rtp
            -- Disable built-in plugins we don't use
            disabled_plugins = {
                'gzip',
                -- "matchit",    -- Uncomment if not needed
                -- "matchparen", -- Uncomment if not needed
                'netrwPlugin',  -- Disabled (using Oil.nvim instead)
                'tarPlugin',
                'tohtml',
                'tutor',
                'zipPlugin',
            },
        },
    },

    ----------------------------------------
    -- README Generation
    ----------------------------------------
    readme = {
        enabled = true,
        root = vim.fn.stdpath('state') .. '/lazy/readme',
        files = { 'README.md', 'lua/**/README.md' },
        skip_if_doc_exists = true, -- Skip if :help docs exist
    },

    ----------------------------------------
    -- State and Profiling
    ----------------------------------------
    state = vim.fn.stdpath('state') .. '/lazy/state.json', -- Checker state
    profiling = {
        loader = false,  -- Don't profile loader
        require = false, -- Don't profile requires
    },
}

--- Setup lazy.nvim and PickleVim configuration
--- Bootstraps lazy.nvim, loads plugin specs, and initializes config
---@param opts? LazyConfig Optional configuration overrides
M.setup = function(opts)
    -- Merge user options with defaults
    opts = vim.tbl_deep_extend('force', config, opts or {}) or {}

    -- Bootstrap lazy.nvim if not installed
    setup_lazypath()

    -- Initialize lazy.nvim with plugin specs
    require('lazy').setup(opts)

    -- Initialize PickleVim configuration
    require('config').setup()
end

return M
