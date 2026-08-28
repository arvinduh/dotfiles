return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000, -- must load before everything else
    opts = {
      flavour = "mocha", -- matches starship / tmux / fzf / bat
      transparent_background = false,
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
      },
      integrations = {
        blink_cmp = true,
        fzf = true,
        gitsigns = true,
        mason = true,
        mini = { enabled = true },
        native_lsp = { enabled = true, inlay_hints = { background = true } },
        treesitter = true,
        which_key = true,
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
