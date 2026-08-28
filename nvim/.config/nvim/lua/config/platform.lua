-- Single place that knows which OS we are on. Everything else asks this
-- module rather than calling has() inline, so the Windows/WSL branches are
-- greppable in one file.

local M = {}

M.is_windows = vim.fn.has("win32") == 1
M.is_wsl = not M.is_windows
  and vim.fn.has("unix") == 1
  and (vim.fn.system("uname -r"):lower():find("microsoft") ~= nil)
M.is_linux = vim.fn.has("unix") == 1 and not M.is_wsl

-- Treesitter compiles its parsers locally, so it needs a working C compiler.
--
-- Windows has none by default, and the obvious choice is a trap: LLVM.LLVM is
-- installed by windows/packages.txt for clangd and clang-format, but that
-- standalone distribution ships NO C runtime headers. Verified 2026-08-27 --
-- compiling tree-sitter-python with it fails at the first include:
--   fatal error: 'stdlib.h' file not found
-- It needs a Windows SDK or MinGW alongside it to be a compiler at all.
--
-- nvim-treesitter picks the first name on this list that EXISTS, not the first
-- that works, so clang must come last on Windows or it wins and every parser
-- fails. llvm-mingw's gcc bundles UCRT headers and builds parsers as-is; zig
-- ships its own libc and is the good fallback; cl works when someone has the
-- MSVC C++ workload. clang stays last for the machine that does have an SDK.
function M.ts_compilers()
  if M.is_windows then
    return { "gcc", "zig", "cl", "clang" }
  end
  return { "gcc", "cc", "clang" }
end

-- Where the global stylua.toml lives.
--
-- stylua's --search-parent-directories walks up from the file and then, as a
-- last resort, checks $XDG_CONFIG_HOME -- and ONLY that. On Linux .zshenv sets
-- it, so ~/.config/stylua is found. On Windows it is unset, and stylua does
-- not fall back to %APPDATA% the way most Rust tools do: verified on 2026-08-27
-- that a file at %APPDATA%\stylua\stylua.toml was ignored (stylua emitted its
-- default TABS) until XDG_CONFIG_HOME was pointed at %APPDATA%. Rather than
-- set a broad env var for one tool, format.lua names this path outright.
function M.stylua_config()
  if M.is_windows then
    return vim.fn.expand("$APPDATA") .. "/stylua/stylua.toml"
  end
  local xdg = vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")
  return xdg .. "/stylua/stylua.toml"
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
