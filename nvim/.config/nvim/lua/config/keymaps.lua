local map = vim.keymap.set

-- ---- Basics -----------------------------------------------------------------
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Write" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit" })
map("n", "<leader>Q", "<cmd>qall!<cr>", { desc = "Quit all, discard" })

-- ---- Clipboard --------------------------------------------------------------
-- clipboard=unnamedplus is deliberately OFF: it makes every delete clobber the
-- system clipboard. Explicit <leader>y / <leader>p instead.
map({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
map({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste from system clipboard" })
map("n", "<leader>Y", '"+Y', { desc = "Yank line to system clipboard" })
-- Paste over a selection without losing the register.
map("x", "p", [["_dP]], { desc = "Paste without yanking selection" })

-- ---- Movement ---------------------------------------------------------------
-- Move by screen line when wrapped, unless a count was given (so 5j still
-- works with relativenumber).
map(
  { "n", "x" },
  "j",
  "v:count == 0 ? 'gj' : 'j'",
  { expr = true, silent = true }
)
map(
  { "n", "x" },
  "k",
  "v:count == 0 ? 'gk' : 'k'",
  { expr = true, silent = true }
)

-- Keep the cursor centred on big jumps and search hops.
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- ---- Windows ----------------------------------------------------------------
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
map("n", "<C-Up>", "<cmd>resize +2<cr>")
map("n", "<C-Down>", "<cmd>resize -2<cr>")
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>")
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>")
map("n", "<leader>-", "<cmd>split<cr>", { desc = "Split below" })
map("n", "<leader>|", "<cmd>vsplit<cr>", { desc = "Split right" })

-- ---- Buffers ----------------------------------------------------------------
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })
map("n", "<leader>`", "<cmd>e #<cr>", { desc = "Last buffer" })

-- ---- Editing ----------------------------------------------------------------
map("v", "<", "<gv", { desc = "Outdent, keep selection" })
map("v", ">", ">gv", { desc = "Indent, keep selection" })
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
map("n", "J", "mzJ`z", { desc = "Join, keep cursor" })

-- ---- Diagnostics ------------------------------------------------------------
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "[d", function()
  vim.diagnostic.jump({ count = -1 })
end, { desc = "Prev diagnostic" })
map("n", "]d", function()
  vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic" })

-- ---- Quickfix ---------------------------------------------------------------
map("n", "[q", "<cmd>cprev<cr>", { desc = "Prev quickfix" })
map("n", "]q", "<cmd>cnext<cr>", { desc = "Next quickfix" })

-- ---- Terminal ---------------------------------------------------------------
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })
