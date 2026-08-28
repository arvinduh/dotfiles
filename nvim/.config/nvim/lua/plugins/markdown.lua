-- Markdown rendered in the buffer.
--
-- hybrid mode is the reason this is worth having: the document renders, but
-- the line the cursor is on drops back to raw source so you edit real text
-- where you are. linewise_hybrid_mode restricts that to the single line —
-- without it, markview un-renders the whole treesitter node under the cursor,
-- so putting the cursor in a table reveals the entire table.
--
-- Preview is off in insert mode by design: while typing you want the source.

return {
  {
    "OXY2DEV/markview.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      preview = {
        modes = { "n", "no", "c" },
        hybrid_modes = { "n" },
        linewise_hybrid_mode = true,
      },
      -- No highlight overrides: markview derives from the active colorscheme,
      -- so it follows whatever theme gets chosen later.
    },
    keys = {
      { "<leader>um", "<cmd>Markview toggle<cr>", desc = "Toggle markdown preview" },
      { "<leader>uM", "<cmd>Markview splitToggle<cr>", desc = "Markdown preview in a split" },
    },
  },
}
