-- Entry point. Order matters: leader must be set before lazy loads, because
-- plugin specs bake <leader> into their keymaps at definition time.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.lazy") -- bootstraps lazy.nvim, then loads lua/plugins/*
require("config.keymaps")
require("config.autocmds")
