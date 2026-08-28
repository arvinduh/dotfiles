-- Config tests. Run on either platform with:
--
--     nvim --headless -c 'luafile tests/run.lua'
--
-- or, equivalently, `make check` on Linux and `.\windows\check.ps1` on
-- Windows. Both are one-line wrappers around the command above.
--
-- Note it is NOT run with `nvim -l`: that executes the script before the user
-- config loads, so conform and nvim-lint would not exist yet.
--
-- Written in Lua and driven by Neovim on purpose: it is the one runtime that
-- exists identically on both machines, and it is also the thing under test.
-- A shell script would need a PowerShell twin, and the two would drift.
--
-- These exist because every bug this suite checks for was real and silent:
--   * stylua was passed --search-parent-directories twice, so it errored out
--     and Lua files were never formatted at all.
--   * taplo was handed --config before its `format` subcommand and rejected it.
--   * shfmt had its indent overridden by conform's own -i <shiftwidth>, which
--     guess-indent had set from the file being formatted.
--   * markdownlint never found its config, so every disabled rule fired again.
--
-- None of those raised an error. They just quietly did nothing.

local M = { pass = 0, fail = 0, failures = {} }

local function ok(name)
  M.pass = M.pass + 1
  io.write(string.format("  ok    %s\n", name))
end

local function fail(name, detail)
  M.fail = M.fail + 1
  table.insert(M.failures, name)
  io.write(string.format("  FAIL  %s\n          %s\n", name, detail or ""))
end

local function check(name, cond, detail)
  if cond then
    ok(name)
  else
    fail(name, detail)
  end
end

-- Windows writes CRLF unless told otherwise; compare on content, not endings.
local function lines_of(buf)
  local out = {}
  for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    table.insert(out, (l:gsub("\r$", "")))
  end
  return out
end

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")

local function write(name, text)
  local path = tmp .. "/" .. name
  local fd = assert(io.open(path, "wb"))
  fd:write(text)
  fd:close()
  return path
end

-- Format a fixture through conform exactly as saving would, and hand back the
-- resulting lines.
local function format_file(name, text)
  local path = write(name, text)
  vim.cmd.edit(vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].fileformat = "unix"
  local conform = require("conform")
  local err
  conform.format(
    { async = false, timeout_ms = 15000, lsp_format = "never" },
    function(e)
      err = e
    end
  )
  return lines_of(buf), err
end

io.write("\nformatters — every language must land on the global style\n")

-- Each case states the ONE property the global config is responsible for.
local cases = {
  {
    "python  (ruff, 2-space)",
    "t.py",
    "def f():\n    x = 1\n    return x\n",
    function(l)
      return l[2] == "  x = 1"
    end,
  },
  {
    "c++     (clang-format, Google)",
    "t.cpp",
    "int main() {\n    return 0;  // c\n}\n",
    -- Google puts TWO spaces before a trailing comment; LLVM's default is one,
    -- so this distinguishes "config applied" from "tool default".
    function(l)
      return l[2] == "  return 0;  // c"
    end,
  },
  {
    "rust    (rustfmt, 2-space)",
    "t.rs",
    "fn main() {\n    let x = 1;\n}\n",
    function(l)
      return l[2]:match("^  let")
    end,
  },
  {
    "typescript (prettier, 2-space)",
    "t.ts",
    "const a = {\n    b: 1,\n};\n",
    function(l)
      return l[2] == "  b: 1,"
    end,
  },
  {
    "lua     (stylua, 2-space)",
    "t.lua",
    "local function f()\n    return 1\nend\n",
    function(l)
      return l[2] == "  return 1"
    end,
  },
  {
    "toml    (taplo)",
    "t.toml",
    "a=[1,2]\n",
    function(l)
      return l[1] == "a = [1, 2]"
    end,
  },
  {
    "shell   (shfmt, 2-space)",
    "t.sh",
    "f() {\n    echo hi\n}\n",
    function(l)
      return l[2] == "  echo hi"
    end,
  },
  {
    "markdown (prettier, proseWrap)",
    "t.md",
    "a long markdown prose line that is definitely more than eighty characters wide for wrapping\n",
    -- proseWrap="always" is the setting under test; the default is "preserve",
    -- which would leave this on one line.
    function(l)
      return #l > 1
    end,
  },
}

for _, case in ipairs(cases) do
  local name, file, input, predicate = case[1], case[2], case[3], case[4]
  local got, err = format_file(file, input)
  if err then
    fail(name, "conform error: " .. tostring(err))
  else
    check(name, predicate(got), "got: " .. vim.inspect(got))
  end
end

io.write("\nshell indent must not follow the file it is formatting\n")

-- guess-indent.nvim sets shiftwidth from the buffer's existing indentation,
-- and conform's shfmt appends -i <shiftwidth>. A 4-space script therefore
-- stayed 4-space until shfmt's args were overridden outright.
for _, variant in ipairs({
  { "4-space", "f() {\n    echo hi\n}\n" },
  { "tabs", "f() {\n\techo hi\n}\n" },
  { "8-space", "f() {\n        echo hi\n}\n" },
}) do
  local got = format_file("i" .. variant[1]:gsub("%A", "") .. ".sh", variant[2])
  check(
    "shfmt normalises " .. variant[1],
    got[2] == "  echo hi",
    "got: " .. tostring(got[2])
  )
end

io.write("\nlinting — the config must actually be found\n")

local function diagnostics_for(name, text)
  local path = write(name, text)
  vim.cmd.edit(vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  require("lint").try_lint()
  vim.wait(15000, function()
    return #vim.diagnostic.get(buf) > 0
  end, 200)
  return vim.diagnostic.get(buf)
end

-- Positive control. Without this, "no MD013" below would also pass when the
-- linter is not running at all, which is exactly the failure being guarded.
local skipped =
  diagnostics_for("bad.md", "# a\n\n#### skipped two levels\n\ntext\n")
check(
  "markdownlint runs at all (heading increment caught)",
  #skipped > 0,
  "expected at least one diagnostic, got none — linter is not running"
)

-- MD013 is disabled in the global config. A table cannot be wrapped, so this
-- must stay silent; when the config was not being found, it did not.
local wide = diagnostics_for(
  "wide.md",
  "# t\n\n| aaaaaaaaaaaaaaaaaaaa | bbbbbbbbbbbbbbbbbbbb | cccccccccccccccccccc |\n| --- | --- | --- |\n| 1 | 2 | 3 |\n"
)
local md013 = {}
for _, d in ipairs(wide) do
  if
    tostring(d.message):match("MD013") or tostring(d.code or ""):match("MD013")
  then
    table.insert(md013, d.message)
  end
end
check(
  "MD013 stays off on a long table",
  #md013 == 0,
  "fired: " .. vim.inspect(md013)
)

io.write("\nneovim version\n")

-- Both machines must run the SAME Neovim, not merely a recent one.
--
-- lazy-lock.json pins every plugin to an exact commit, but a pinned plugin
-- only behaves identically if the host Neovim matches too. nvim-treesitter is
-- pinned to `master`, which targets 0.11 and below; 0.12 changed treesitter
-- internals that its query predicates call into, and the failure surfaces as
-- an unrelated-looking BufWinEnter traceback the first time markview parses a
-- markdown injection.
--
-- Keep this in step with the version pinned in windows/packages.txt.
local want = { major = 0, minor = 11 }
local v = vim.version()
check(
  string.format(
    "neovim is %d.%d.x (found %d.%d.%d)",
    want.major,
    want.minor,
    v.major,
    v.minor,
    v.patch
  ),
  v.major == want.major and v.minor == want.minor,
  string.format(
    "this machine runs %d.%d.%d — the other one runs %d.%d.x, and nvim-treesitter's master branch does not span both",
    v.major,
    v.minor,
    v.patch,
    want.major,
    want.minor
  )
)

io.write("\nglobal configs resolve\n")

for _, c in ipairs({
  { "~/.editorconfig", "editorconfig" },
  { "~/.clang-format", "clang-format" },
  { "~/.rustfmt.toml", "rustfmt" },
  { "~/.prettierrc", "prettier" },
  { "~/.taplo.toml", "taplo" },
  { "~/.markdownlint-cli2.jsonc", "markdownlint" },
}) do
  local path = vim.fn.expand(c[1])
  check(
    c[2] .. " config present",
    vim.uv.fs_stat(path) ~= nil,
    "missing: " .. path
  )
end

io.write("\ntools on PATH\n")

for _, exe in ipairs({
  "ruff",
  "clang-format",
  "rustfmt",
  "prettier",
  "stylua",
  "taplo",
  "shfmt",
  "markdownlint-cli2",
}) do
  check(exe, vim.fn.executable(exe) == 1, "not executable")
end

vim.fn.delete(tmp, "rf")

io.write(string.format("\n%d passed, %d failed\n", M.pass, M.fail))
if M.fail > 0 then
  io.write("failed: " .. table.concat(M.failures, ", ") .. "\n")
end
os.exit(M.fail == 0 and 0 or 1)
