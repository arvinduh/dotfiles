local platform = require("config.platform")

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master", -- `main` is the in-progress rewrite; master is stable
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSUpdateSync", "TSInstall" },
    opts = {
      ensure_installed = {
        -- your languages
        "python",
        "cpp",
        "c",
        "rust",
        "typescript",
        "tsx",
        "javascript",
        -- data / docs — the ones you said you touch constantly
        "markdown",
        "markdown_inline",
        "json",
        "jsonc",
        "yaml",
        "toml",
        -- infra
        "lua",
        "luadoc",
        "vim",
        "vimdoc",
        "bash",
        "query",
        "regex",
        "diff",
        "gitcommit",
        "gitignore",
        "dockerfile",
        "cmake",
        "make",
      },
      auto_install = true,
      highlight = {
        enable = true,
        -- Vim's regex indent is still better than treesitter's for these.
        additional_vim_regex_highlighting = false,
      },
      indent = { enable = true },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          node_decremental = "<BS>",
          scope_incremental = false,
        },
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.install").compilers = platform.ts_compilers()
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
}
