-- lazy.nvim bootstrap.
--
-- Plugin SOURCE is cloned into ~/.local/share/nvim/lazy/ — outside this repo.
-- The only thing that lands in the repo is lazy-lock.json, which pins every
-- plugin to an exact commit. That separation is why `:Lazy update` can never
-- clobber your config: your customisations live in lua/plugins/*.lua as `opts`
-- tables that lazy merges over plugin defaults; you never edit plugin source.
--
--   :Lazy update    pull upstream, REWRITE lazy-lock.json  (run on one machine)
--   :Lazy restore   check out exactly what lazy-lock.json says (run elsewhere)
--   :Lazy sync      install + clean + update

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  defaults = { lazy = true },
  install = { colorscheme = { "catppuccin" } },
  checker = {
    enabled = true, -- notify when updates exist...
    notify = false, -- ...but quietly; run `dot update` when you choose to
    frequency = 86400,
  },
  change_detection = { notify = false },
  ui = { border = "rounded" },
  performance = {
    rtp = {
      -- Disable built-in plugins we replace or never use.
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        "netrwPlugin", -- oil.nvim replaces it
        "matchit",
        "matchparen",
      },
    },
  },
})
