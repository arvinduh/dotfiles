-- fzf-lua rather than telescope: it shells out to the same fzf binary the
-- shell uses, so the keybinds, colours and matching behaviour are identical
-- in and out of the editor, and it stays fast in very large repos.

return {
  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    keys = {
      { "<leader><space>", "<cmd>FzfLua files<cr>", desc = "Find files" },
      { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Grep (live)" },
      { "<leader>fw", "<cmd>FzfLua grep_cword<cr>", desc = "Grep word under cursor" },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
      { "<leader>fh", "<cmd>FzfLua helptags<cr>", desc = "Help" },
      { "<leader>fk", "<cmd>FzfLua keymaps<cr>", desc = "Keymaps" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent files" },
      { "<leader>fd", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Diagnostics" },
      { "<leader>fc", "<cmd>FzfLua git_commits<cr>", desc = "Git commits" },
      { "<leader>fs", "<cmd>FzfLua git_status<cr>", desc = "Git status" },
      { "<leader>f/", "<cmd>FzfLua blines<cr>", desc = "Search in buffer" },
      { "<leader>fR", "<cmd>FzfLua resume<cr>", desc = "Resume last picker" },
    },
    opts = {
      "default-title",
      winopts = {
        height = 0.85,
        width = 0.85,
        border = "rounded",
        preview = { default = "bat", layout = "flex", scrollbar = "float" },
      },
      files = {
        cwd_prompt = false,
        fd_opts = "--type f --hidden --follow --exclude .git",
      },
      grep = {
        rg_opts = "--column --line-number --no-heading --color=always "
          .. "--smart-case --max-columns=4096 --hidden --glob=!.git/",
      },
      keymap = {
        builtin = {
          ["<C-d>"] = "preview-page-down",
          ["<C-u>"] = "preview-page-up",
          ["<C-/>"] = "toggle-help",
        },
      },
    },
  },
}
