-- Single place that knows which OS we are on. Everything else asks this
-- module rather than calling has() inline, so the Windows/WSL branches are
-- greppable in one file.

local M = {}

M.is_windows = vim.fn.has("win32") == 1
M.is_wsl = (not M.is_windows) and vim.fn.has("unix") == 1
  and (vim.fn.system("uname -r"):lower():find("microsoft") ~= nil)
M.is_linux = vim.fn.has("unix") == 1 and not M.is_wsl

-- Treesitter needs a C compiler. Windows has no cc by default; LLVM's clang
-- is the least painful option and is what packages/winget.txt installs.
function M.ts_compilers()
  if M.is_windows then
    return { "clang", "zig", "cl", "gcc" }
  end
  return { "gcc", "cc", "clang" }
end

-- Clipboard. WSL has no X server, so route through the Windows clipboard.
function M.setup_clipboard()
  if M.is_wsl then
    vim.g.clipboard = {
      name = "WslClipboard",
      copy = {
        ["+"] = "clip.exe",
        ["*"] = "clip.exe",
      },
      paste = {
        ["+"] = 'powershell.exe -NoProfile -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
        ["*"] = 'powershell.exe -NoProfile -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
      },
      cache_enabled = 0,
    }
  end
end

return M
