-- Markdown rendered in the buffer itself — no browser, no external binary.
--
-- It renders continuously as you move; there is no command to run. The line
-- the cursor is on is un-rendered (anti_conceal) so you always edit raw text
-- where you are, and see the rendered form everywhere else.

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      -- Reveal the raw source on the cursor's line only.
      anti_conceal = { enabled = true },
      heading = { sign = false },
      code = {
        sign = false,
        width = "block",
        right_pad = 2,
      },
      -- No colours set here on purpose: it derives from the active
      -- colorscheme, so it follows whatever theme is chosen later.
    },
    keys = {
      {
        "<leader>um",
        "<cmd>RenderMarkdown toggle<cr>",
        desc = "Toggle markdown rendering",
      },
    },
  },
}
