-- A thin 80-column rule instead of a filled cell.
--
-- `colorcolumn` highlights a whole cell background, because a terminal is a
-- grid of cells with nothing to draw between them. Two things then make it
-- read as broken: CursorLine wins over ColorColumn on the cursor's own line,
-- and wherever real text sits at column 80 you see the character rather than
-- a block.
--
-- virt-column draws a single │ as virtual text instead. `colorcolumn` stays
-- set (virt-column reads it), but the native highlight is cleared so the two
-- do not draw on top of each other.

return {
  {
    "lukas-reineke/virt-column.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      char = "│",
      virtcolumn = "80",
      highlight = "NonText", -- follows the colorscheme; no hardcoded colour
    },
    config = function(_, opts)
      vim.api.nvim_set_hl(0, "ColorColumn", {})
      require("virt-column").setup(opts)
    end,
  },
}
