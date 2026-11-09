local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    {
      "nvim-telescope/telescope.nvim",
      branch = "master",
      dependencies = { "nvim-lua/plenary.nvim" },
    },
    { "nvim-telescope/telescope-ui-select.nvim" },

    { "rose-pine/neovim", name = "rose-pine" },
    { "Mofiqul/vscode.nvim" },
    { "bluz71/vim-nightfly-colors" },
    {
      "catppuccin/nvim",
      name = "catppuccin",
      config = function()
        vim.cmd("colorscheme catppuccin-mocha")
      end,
    },

    { "folke/trouble.nvim", dependencies = { "nvim-tree/nvim-web-devicons" } },

    -- master is frozen but still has nvim-treesitter.configs, which after/plugin/treesitter.lua uses
    { "nvim-treesitter/nvim-treesitter", branch = "master", build = ":TSUpdate" },

    { "theprimeagen/harpoon" },
    { "mbbill/undotree" },
    { "tpope/vim-fugitive" },
    { "tpope/vim-rhubarb" },

    {
      "lewis6991/gitsigns.nvim",
      opts = {
        on_attach = function(bufnr)
          local gitsigns = require("gitsigns")
          local opts = { buffer = bufnr }

          vim.keymap.set("n", "]c", function()
            if vim.wo.diff then
              vim.cmd.normal({ "]c", bang = true })
            else
              gitsigns.nav_hunk("next")
            end
          end, opts)
          vim.keymap.set("n", "[c", function()
            if vim.wo.diff then
              vim.cmd.normal({ "[c", bang = true })
            else
              gitsigns.nav_hunk("prev")
            end
          end, opts)
          vim.keymap.set("n", "<leader>gp", gitsigns.preview_hunk, opts)
          vim.keymap.set("n", "<leader>gS", gitsigns.stage_hunk, opts)
          vim.keymap.set("n", "<leader>gr", gitsigns.reset_hunk, opts)
          vim.keymap.set("n", "<leader>gB", gitsigns.blame_line, opts)
        end,
      },
    },

    {
      "stevearc/conform.nvim",
      opts = {
        formatters_by_ft = {
          javascript = { "prettierd", "prettier", stop_after_first = true },
          javascriptreact = { "prettierd", "prettier", stop_after_first = true },
          typescript = { "prettierd", "prettier", stop_after_first = true },
          typescriptreact = { "prettierd", "prettier", stop_after_first = true },
          json = { "prettierd", "prettier", stop_after_first = true },
          css = { "prettierd", "prettier", stop_after_first = true },
          markdown = { "prettierd", "prettier", stop_after_first = true },
          yaml = { "prettierd", "prettier", stop_after_first = true },
        },
        default_format_opts = { lsp_format = "fallback" },
      },
    },

    -- LSP Support
    { "neovim/nvim-lspconfig" },
    { "williamboman/mason.nvim" },
    { "williamboman/mason-lspconfig.nvim" },

    -- Autocompletion
    { "hrsh7th/nvim-cmp" },
    { "hrsh7th/cmp-buffer" },
    { "hrsh7th/cmp-path" },
    { "saadparwaiz1/cmp_luasnip" },
    { "hrsh7th/cmp-nvim-lsp" },
    { "hrsh7th/cmp-nvim-lua" },

    -- Snippets
    { "L3MON4D3/LuaSnip" },
    { "rafamadriz/friendly-snippets" },

    { "folke/zen-mode.nvim" },
    { "laytan/cloak.nvim" },
    { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" } },

    { "yegappan/mru" },
    { "David-Kunz/jester" },
    {
      "nvim-neo-tree/neo-tree.nvim",
      branch = "v3.x",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
      },
      opts = {
        git_status = {
          window = {
            mappings = {
              -- gd: open file under cursor and show side-by-side git diff (fugitive)
              ["gd"] = function(state)
                local node = state.tree:get_node()
                if node.type ~= "file" then return end
                require("neo-tree.sources.common.commands").open(state)
                vim.cmd("Gvdiffsplit")
              end,
            },
          },
        },
      },
    },

    {
      "polarmutex/git-worktree.nvim",
      version = "^2",
      dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
      config = function()
        require("telescope").load_extension("git_worktree")
      end,
    },

    { "pest-parser/pest.vim" },
    { "linrongbin16/lsp-progress.nvim" },

    {
      "kristijanhusak/vim-dadbod-ui",
      dependencies = {
        { "tpope/vim-dadbod", lazy = true },
        { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "psql" }, lazy = true },
      },
      cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
      init = function()
        vim.g.db_ui_use_nerd_fonts = 1
      end,
    },

    {
      "CopilotC-Nvim/CopilotChat.nvim",
      dependencies = { "zbirenbaum/copilot.lua", "nvim-lua/plenary.nvim" },
      build = "make tiktoken",
      opts = { debug = false },
    },

    { "sontungexpt/better-diagnostic-virtual-text", opts = {} },

    {
      "pwntester/octo.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
        "nvim-tree/nvim-web-devicons",
      },
      opts = {},
    },

    { "kdheepak/lazygit.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
    { "nvim-lua/lsp-status.nvim" },
    { "coder/claudecode.nvim", dependencies = { "folke/snacks.nvim" } },

    -- Multi-cursor: <C-s> selects word under cursor, repeat to add next match
    {
      "mg979/vim-visual-multi",
      branch = "master",
      init = function()
        vim.g.VM_maps = {
          ["Find Under"] = "<C-s>",
          ["Find Subword Under"] = "<C-s>",
        }
      end,
    },
  },
  install = { colorscheme = { "nightfly" } },
  rocks = { enabled = false },
  change_detection = { notify = false },
})
