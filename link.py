#!/usr/bin/env python3
"""Symlinks this repository's configs into place, on Linux, Windows, and cloud.

Link mappings are defined declaratively in `links.toml`.
The script only creates symlinks. It never installs packages (see the
bootstrap block in README.md) and never overwrites a real file: anything in
the way is moved to `<target>.bak-<timestamp>` first.

Usage:
  python3 link.py                    # Linux / WSL
  uv run link.py                     # Windows (or `py link.py`)
  python3 link.py --platform cloud   # Claude Code cloud sessions
  python3 link.py --dry-run          # show what would change, change nothing
"""

import argparse
import os
import pathlib
import re
import sys
import time
import tomllib
from typing import cast

REPO = pathlib.Path(__file__).resolve().parent
LINKS_CONFIG = REPO / "links.toml"
PLATFORMS = ("linux", "windows", "cloud")


def load_links(config_file: pathlib.Path) -> list[dict[str, object]]:
  """Loads declarative link mappings from links.toml."""
  if not config_file.is_file():
    return []
  with config_file.open("rb") as f:
    data = tomllib.load(f)
  raw = data.get("link", [])
  if not isinstance(raw, list):
    return []
  raw_list = cast(list[object], raw)
  return [cast(dict[str, object], i) for i in raw_list if isinstance(i, dict)]


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


def resolve(
  links: list[dict[str, object]], platform: str
) -> list[tuple[pathlib.Path, pathlib.Path]]:
  """Returns (source, target) pairs for one platform, globs expanded."""
  pairs: list[tuple[pathlib.Path, pathlib.Path]] = []
  for entry in links:
    if platform == "cloud":
      raw = entry.get("home") if entry.get("cloud") else None
    else:
      raw = entry.get(platform, entry.get("home"))
    if not isinstance(raw, str):
      continue
    target = expand(raw)
    source = str(entry.get("source", ""))
    if source.endswith("/*"):
      parent = REPO / source[:-2]
      pairs += [(m, target / m.name) for m in sorted(parent.iterdir())]
    else:
      pairs.append((REPO / source, target))
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

  backup = target.with_name(f"{target.name}.bak-{stamp}")
  if target.is_symlink():
    action, note = "relink", "replaced stale link"
  elif target.exists():
    action, note = "backup", f"saved {backup.name}"
  else:
    action, note = "create", ""
  if dry_run:
    return f"would {action}", f"-> {source.relative_to(REPO)}"

  # Create the new link under a temporary name first. If the OS refuses it
  # (Windows without Developer Mode), nothing has been moved or deleted yet.
  target.parent.mkdir(parents=True, exist_ok=True)
  staged = target.with_name(f"{target.name}.link-{stamp}")
  os.symlink(source, staged, target_is_directory=source.is_dir())
  if action == "relink":
    target.unlink()
  elif action == "backup":
    target.rename(backup)
  staged.rename(target)
  return "linked", note


def main() -> int:
  """Parses arguments and links everything for one platform."""
  parser = argparse.ArgumentParser(
    description=(__doc__ or "").splitlines()[0],
    formatter_class=argparse.RawDescriptionHelpFormatter,
  )
  parser.add_argument(
    "--platform",
    choices=PLATFORMS,
    default="windows" if os.name == "nt" else "linux",
  )
  parser.add_argument("--dry-run", action="store_true")
  args = parser.parse_args()

  links = load_links(LINKS_CONFIG)
  stamp = time.strftime("%Y%m%d-%H%M%S")
  rows: list[tuple[str, str, str]] = []
  for source, target in resolve(links, args.platform):
    try:
      status, note = link_one(source, target, args.dry_run, stamp)
    except OSError as e:
      status, note = "FAILED", e.strerror or str(e)
      if os.name == "nt" and getattr(e, "winerror", None) == 1314:
        note = "no symlink permission: turn on Developer Mode, or run elevated"
    rows.append((status, str(target), note))

  width = max((len(r[0]) for r in rows), default=6)
  for status, target, note in rows:
    print(f"{status:<{width}}  {target}  {note}".rstrip())
  failed = sum(1 for r in rows if r[0][0].isupper())
  if failed:
    print(f"\n{failed} link(s) did not resolve.", file=sys.stderr)

  return 1 if failed else 0


if __name__ == "__main__":
  sys.exit(main())
