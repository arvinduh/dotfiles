return {
  -- mini.statusline instead of lualine: ~200 lines vs ~3000, no config needed,
  -- and it renders the same information.
  {
    "echasnovski/mini.statusline",
    version = false,
    event = "VeryLazy",
    opts = { use_icons = true },
  },

  -- which-key: press <leader> and wait to see what is available. This is the
  -- reason a large keymap stays learnable.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      spec = {
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>u", group = "ui/toggle" },
      },
    },
    keys = {
      { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Buffer keymaps" },
    },
  },

  -- Indent guides, scoped to the current block.
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "│" },
      scope = { enabled = true, show_start = false, show_end = false },
      exclude = { filetypes = { "help", "lazy", "mason", "oil", "checkhealth" } },
    },
  },
}
