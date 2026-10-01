#!/usr/bin/env python3
"""Symlinks this repository's configs into place, on Linux, Windows, and cloud.

The LINKS table below is the whole map. Each entry names a source inside this
repository and a target per platform; a platform with no target skips the
entry. The script only creates symlinks. It never installs packages (see the
bootstrap block in README.md) and never overwrites a real file: anything in
the way is moved to `<target>.bak-<timestamp>` first.

Usage:
  python3 link.py                    # Linux / WSL
  uv run link.py                     # Windows (or `py link.py`)
  python3 link.py --platform cloud   # Claude Code cloud sessions
  python3 link.py --dry-run          # show what would change, change nothing
"""

from __future__ import annotations

import argparse
import os
import pathlib
import re
import sys
import time

REPO = pathlib.Path(__file__).resolve().parent

# source: path in this repo. A trailing `/*` links each match into the target
#   directory instead of linking the source itself.
# home: target on both Linux and Windows. `linux` / `windows` override it, or
#   stand alone for a one-platform link. `~` is the home directory, `%NAME%` an
#   environment variable (`%DOCUMENTS%` is the Windows Documents folder).
# cloud: also link `home` in Claude Code cloud sessions.
LINKS = [
  # --- agents: one copy of directives and skills, linked into each tool ----
  {"source": "agents", "home": "~/.agents", "cloud": True},
  {"source": "claude/CLAUDE.md", "home": "~/.claude/CLAUDE.md", "cloud": True},
  {
    "source": "claude/settings.json",
    "home": "~/.claude/settings.json",
    "cloud": True,
  },
  # One link per skill: ~/.claude/skills/synced holds claude.ai's own skills.
  {"source": "agents/skills/*", "home": "~/.claude/skills", "cloud": True},
  {"source": "agents/AGENTS.md", "home": "~/.gemini/config/AGENTS.md"},
  {"source": "agents/skills", "home": "~/.gemini/config/skills"},
  {"source": "gemini/hooks.json", "home": "~/.gemini/config/hooks.json"},
  # --- editor: VS Code and Antigravity share one settings file --------------
  {
    "source": "vscode/settings.json",
    "linux": "~/.config/Code/User/settings.json",
    "windows": "%APPDATA%/Code/User/settings.json",
  },
  {
    "source": "vscode/settings.json",
    "linux": "~/.config/Antigravity/User/settings.json",
    "windows": "%APPDATA%/Antigravity/User/settings.json",
  },
  # --- formatting -------------------------------------------------------------
  {
    "source": "format/format-file",
    "home": "~/.local/bin/format-file",
    "cloud": True,
  },
  {
    "source": "format/format-file.cmd",
    "windows": "~/.local/bin/format-file.cmd",
  },
  # These tools find config only by walking up from the file, so ~ is the one
  # place that covers every project.
  {"source": "format/.editorconfig", "home": "~/.editorconfig"},
  {"source": "format/.clang-format", "home": "~/.clang-format"},
  {"source": "format/.prettierrc", "home": "~/.prettierrc"},
  {"source": "format/.taplo.toml", "home": "~/.taplo.toml"},
  {"source": "format/.clippy.toml", "home": "~/.clippy.toml"},
  # These have a real per-user config location, so they stay out of ~.
  {
    "source": "format/rustfmt.toml",
    "linux": "~/.config/rustfmt/rustfmt.toml",
    "windows": "%APPDATA%/rustfmt/rustfmt.toml",
  },
  {
    "source": "format/ruff.toml",
    "linux": "~/.config/ruff/ruff.toml",
    "windows": "%APPDATA%/ruff/ruff.toml",
  },
  # format-file passes this path to markdownlint-cli2 explicitly.
  {
    "source": "format/.markdownlint-cli2.jsonc",
    "home": "~/.config/markdownlint/.markdownlint-cli2.jsonc",
  },
  # --- shell and git ---------------------------------------------------------
  # Directory links on purpose: zsh's local.zsh is written back through it
  # (gitignored).
  {"source": "zsh/.zshenv", "linux": "~/.zshenv"},
  {"source": "zsh", "linux": "~/.config/zsh"},
  {"source": "git", "home": "~/.config/git"},
  {"source": "atuin", "linux": "~/.config/atuin"},
  {"source": "bat", "linux": "~/.config/bat"},
  {"source": "bat/config", "windows": "%APPDATA%/bat/config"},
  {"source": "windows/starship.toml", "windows": "~/.config/starship.toml"},
  # PowerShell 7's profile, not Windows PowerShell 5.1's (left alone).
  {
    "source": "windows/profile.ps1",
    "windows": "%DOCUMENTS%/PowerShell/Microsoft.PowerShell_profile.ps1",
  },
]

PLATFORMS = ("linux", "windows", "cloud")


def documents_dir() -> str:
  """Returns the Windows Documents folder, following OneDrive redirection."""
  import winreg  # Windows-only module; imported only when a target needs it.

  key_path = (
    r"Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
  )
  with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path) as key:
    value, _ = winreg.QueryValueEx(key, "Personal")
  return os.path.expandvars(value)


def expand(target: str) -> pathlib.Path:
  """Expands `~` and `%NAME%` in a target path.

  Raises:
    KeyError: The path names an environment variable that is not set.
  """

  def env(match: re.Match[str]) -> str:
    name = match.group(1)
    if name == "DOCUMENTS" and name not in os.environ:
      os.environ[name] = documents_dir()
    return os.environ[name]

  return pathlib.Path(os.path.expanduser(re.sub(r"%(\w+)%", env, target)))


def resolve(platform: str) -> list[tuple[pathlib.Path, pathlib.Path]]:
  """Returns (source, target) pairs for one platform, globs expanded."""
  pairs = []
  for entry in LINKS:
    if platform == "cloud":
      raw = entry.get("home") if entry.get("cloud") else None
    else:
      raw = entry.get(platform, entry.get("home"))
    if raw is None:
      continue
    target = expand(raw)
    if entry["source"].endswith("/*"):
      parent = REPO / entry["source"][:-2]
      pairs += [(m, target / m.name) for m in sorted(parent.iterdir())]
    else:
      pairs.append((REPO / entry["source"], target))
  return pairs


def inside_repo(path: pathlib.Path) -> bool:
  """Reports whether a path resolves to somewhere inside this repository."""
  try:
    path.resolve().relative_to(REPO)
  except ValueError:
    return False
  return True


def same_link(target: pathlib.Path, source: pathlib.Path) -> bool:
  """Reports whether `target` is already a symlink to `source`."""
  if not target.is_symlink():
    return False
  current = os.readlink(target).removeprefix("\\\\?\\")
  return _norm(current) == _norm(str(source))


def _norm(path: str) -> str:
  """Normalizes a path for comparison (case-insensitive on Windows)."""
  return os.path.normcase(os.path.normpath(path))


def link_one(
  source: pathlib.Path, target: pathlib.Path, dry_run: bool, stamp: str
) -> tuple[str, str]:
  """Links `target` to `source`.

  Returns:
    A (status, note) pair for the report. Statuses starting with an uppercase
    letter are failures.

  Raises:
    OSError: The symlink could not be created (on Windows, usually missing
      Developer Mode).
  """
  if not source.exists():
    return "MISSING", f"no {source.relative_to(REPO)} in repo"
  if same_link(target, source):
    return "ok", "already linked"
  # A parent folded into this repo by stow would make every write below land
  # inside the repo, and the backup step would move a tracked file.
  if inside_repo(target.parent):
    return "CONFLICT", "parent dir is a link into this repo; run `stow -D` once"

  if target.is_symlink():
    action, note = "relink", "replaced stale link"
  elif target.exists():
    backup = target.with_name(f"{target.name}.bak-{stamp}")
    action, note = "backup", f"saved {backup.name}"
  else:
    action, note = "create", ""
  if dry_run:
    return f"would {action}", f"-> {source.relative_to(REPO)}"

  target.parent.mkdir(parents=True, exist_ok=True)
  if action == "relink":
    target.unlink()
  elif action == "backup":
    target.rename(backup)
  os.symlink(source, target, target_is_directory=source.is_dir())
  return "linked", note


def main() -> int:
  """Parses arguments and links everything for one platform."""
  parser = argparse.ArgumentParser(
    description=__doc__.splitlines()[0],
    formatter_class=argparse.RawDescriptionHelpFormatter,
  )
  parser.add_argument(
    "--platform",
    choices=PLATFORMS,
    default="windows" if os.name == "nt" else "linux",
  )
  parser.add_argument("--dry-run", action="store_true")
  args = parser.parse_args()

  stamp = time.strftime("%Y%m%d-%H%M%S")
  rows = []
  for source, target in resolve(args.platform):
    try:
      status, note = link_one(source, target, args.dry_run, stamp)
    except OSError as e:
      status, note = "FAILED", e.strerror or str(e)
      if os.name == "nt" and getattr(e, "winerror", None) == 1314:
        note = "no symlink permission: turn on Developer Mode, or run elevated"
    rows.append((status, str(target), note))

  width = max(len(r[0]) for r in rows)
  for status, target, note in rows:
    print(f"{status:<{width}}  {target}  {note}".rstrip())
  failed = sum(1 for r in rows if r[0][0].isupper())
  if failed:
    print(f"\n{failed} link(s) did not resolve.", file=sys.stderr)

  return 1 if failed else 0


if __name__ == "__main__":
  sys.exit(main())
