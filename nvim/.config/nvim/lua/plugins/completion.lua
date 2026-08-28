return {
  {
    "saghen/blink.cmp",
    event = "InsertEnter",
    version = "*", -- uses the prebuilt Rust fuzzy matcher; no cargo needed
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
      keymap = {
        preset = "default", -- <C-space> open, <C-n>/<C-p> cycle, <C-y> accept
        ["<Tab>"] = { "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
      },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        accept = { auto_brackets = { enabled = true } },
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        ghost_text = { enabled = false }, -- conflicts visually with zsh's
        list = { selection = { preselect = false, auto_insert = true } },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      signature = { enabled = true },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    opts_extend = { "sources.default" },
  },
}
