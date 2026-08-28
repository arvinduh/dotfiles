local aug = function(name)
  return vim.api.nvim_create_augroup("dot_" .. name, { clear = true })
end

-- Briefly highlight what you just yanked.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = aug("yank_highlight"),
  callback = function()
    vim.hl.on_yank({ timeout = 150 })
  end,
})

-- Prose filetypes: soft wrap, and add 't' to formatoptions so paragraphs
-- auto-wrap at textwidth as you type. Code never gets 't' — auto-wrapping a
-- line of code mid-keystroke is maddening.
vim.api.nvim_create_autocmd("FileType", {
  group = aug("prose"),
  pattern = { "markdown", "text", "gitcommit", "typst", "tex" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
    vim.opt_local.formatoptions:append("t")
  end,
})

-- Never continue a comment leader onto a line you opened manually. (Set here
-- rather than in options.lua because ftplugins reset formatoptions.)
vim.api.nvim_create_autocmd("FileType", {
  group = aug("formatoptions"),
  callback = function()
    vim.opt_local.formatoptions:remove({ "o" })
  end,
})

-- Restore the cursor to where you left the file.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = aug("last_position"),
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Strip trailing whitespace on save, except where it is significant.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = aug("trim_whitespace"),
  callback = function(ev)
    local ft = vim.bo[ev.buf].filetype
    if ft == "markdown" or ft == "diff" then
      return -- markdown: two trailing spaces are a hard line break
    end
    local save = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(save)
  end,
})

-- Create missing parent directories when writing a new file.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = aug("mkdir"),
  callback = function(ev)
    if ev.match:match("^%w%w+://") then
      return
    end
    vim.fn.mkdir(vim.fn.fnamemodify(vim.uv.fs_realpath(ev.match) or ev.match, ":p:h"), "p")
  end,
})

-- q closes these throwaway windows.
vim.api.nvim_create_autocmd("FileType", {
  group = aug("close_with_q"),
  pattern = { "help", "man", "qf", "checkhealth", "lspinfo", "startuptime" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})

-- Reload files changed outside nvim (needs tmux focus-events on).
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = aug("checktime"),
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})
