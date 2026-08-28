-- oil.nvim: edit the filesystem as a normal buffer. Rename with `cw`, delete
-- with `dd`, create by typing a line, then `:w` to commit. netrw is disabled
-- in lazy.lua because this replaces it.

return {
  {
    "stevearc/oil.nvim",
    lazy = false, -- must own the netrw hijack at startup
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
      { "<leader>fe", "<cmd>Oil<cr>", desc = "File explorer" },
    },
    opts = {
      default_file_explorer = true,
      delete_to_trash = true,
      skip_confirm_for_simple_edits = true,
      view_options = { show_hidden = true },
      keymaps = {
        ["<C-h>"] = false, -- keep window-left navigation
        ["<C-l>"] = false,
        ["q"] = "actions.close",
      },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },
}
