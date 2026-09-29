return {
  -- mini.* — small, single-purpose, one maintainer, no dependency graph.
  {
    "echasnovski/mini.nvim",
    version = false,
    event = "VeryLazy",
    config = function()
      -- ai: better text objects. `ci(` works across lines, `cif` = change
      -- inside function, `cia` = inside argument. Treesitter-aware.
      require("mini.ai").setup({ n_lines = 500 })

      -- surround: `sa` add, `sd` delete, `sr` replace.
      --   saiw)  -> surround inner word with parens
      --   sd"    -> delete surrounding quotes
      require("mini.surround").setup()

      -- pairs: auto-close brackets and quotes.
      require("mini.pairs").setup()

      -- comment: `gcc` line, `gc` in visual. Treesitter-aware, so it gets
      -- embedded languages right (JS inside HTML, etc.).
      require("mini.comment").setup()
    end,
  },

  -- flash: `s` + two characters jumps anywhere on screen. Replaces the
  -- reflex of mashing `w` or counting lines for relativenumber jumps.
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = { modes = { char = { enabled = false } } },
    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump()
        end,
        desc = "Flash jump",
      },
      {
        "S",
        mode = { "n", "x", "o" },
        function()
          require("flash").treesitter()
        end,
        desc = "Flash treesitter",
      },
      {
        "<C-s>",
        mode = { "c" },
        function()
          require("flash").toggle()
        end,
        desc = "Toggle flash search",
      },
    },
  },

  -- Auto-detect indentation in files that lack an .editorconfig. Complements
  -- rather than overrides editorconfig, which always wins when present.
  {
    "NMAC427/guess-indent.nvim",
    event = "BufReadPre",
    opts = {},
  },
}
