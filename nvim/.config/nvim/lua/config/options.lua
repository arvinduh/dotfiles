local platform = require("config.platform")

local o = vim.opt

-- ---- Indentation ------------------------------------------------------------
-- These are the FALLBACK. Neovim has built-in EditorConfig support (on by
-- default since 0.9), so ~/.editorconfig overrides all of this per-project,
-- and a project's own .editorconfig overrides that. This is only what applies
-- when nothing else has an opinion.
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2
o.shiftround = true
o.smartindent = true

-- ---- Line width -------------------------------------------------------------
o.textwidth = 80
o.colorcolumn = "80"
o.wrap = false -- soft-wrap off for code; the autocmd turns it on for prose

-- ---- UI ---------------------------------------------------------------------
o.number = true
o.relativenumber = true
o.signcolumn = "yes" -- always on, so the gutter never shifts
o.cursorline = true
o.scrolloff = 8
o.sidescrolloff = 8
o.termguicolors = true
o.showmode = false -- the statusline already says it
o.laststatus = 3 -- one global statusline, not one per split
o.cmdheight = 1
o.pumheight = 12
o.winborder = "rounded" -- 0.11: every float gets a border for free
o.fillchars = { eob = " ", fold = " ", foldopen = "▾", foldclose = "▸" }
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- ---- Search -----------------------------------------------------------------
o.ignorecase = true
o.smartcase = true -- a capital in the pattern makes it case-sensitive
o.hlsearch = true
o.incsearch = true
o.inccommand = "split" -- live preview of :s///

-- ---- Splits -----------------------------------------------------------------
o.splitright = true
o.splitbelow = true
o.splitkeep = "screen"

-- ---- Files ------------------------------------------------------------------
o.undofile = true -- undo history survives closing the file
o.undolevels = 10000
o.swapfile = false
o.backup = false
o.writebackup = false
o.autoread = true
o.confirm = true -- prompt instead of failing on unsaved changes

-- ---- Timing -----------------------------------------------------------------
o.updatetime = 200 -- drives CursorHold, gitsigns, LSP highlights
o.timeoutlen = 400 -- which-key popup delay
o.ttimeoutlen = 10

-- ---- Completion -------------------------------------------------------------
o.completeopt = { "menu", "menuone", "noselect" }
o.wildmode = "longest:full,full"

-- ---- Folding (treesitter-driven, but open by default) -----------------------
o.foldmethod = "expr"
o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
o.foldlevel = 99
o.foldtext = ""

-- ---- Misc -------------------------------------------------------------------
o.mouse = "a"
o.clipboard = "" -- deliberately NOT unnamedplus; see keymaps for explicit yanks
o.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help" }
vim.g.editorconfig = true -- explicit, though it is the default

-- Comment/format behaviour. 'c' auto-wraps COMMENTS at textwidth; 't' (which
-- would auto-wrap code) is deliberately absent — an autocmd adds it back for
-- prose filetypes only.
o.formatoptions = "jcroqlnt"

platform.setup_clipboard()

-- Disable unused built-in providers; each one is a startup cost.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
