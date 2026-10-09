# /// script
# requires-python = ">=3.14"
# dependencies = ["pillow", "resvg-py"]
# ///
"""Builds and applies the folder icon scheme declared in icons.toml.

`build` fetches each glyph's Fluent Color SVGs (the full-color Windows 11
style) at the pinned commit, cached under ~/.cache/fluent-icons, renders every
icon size with resvg, and packs one .ico per glyph next to this script. `apply`
writes each folder's desktop.ini with only an IconResource line, so Explorer
shows the folder's real name, and marks the folder read-only so Explorer
honors the file. A value of the form `<dll>,<id>` (e.g. `imageres.dll,-184`)
names a built-in System32 icon instead; `build` skips it. Windows-only.

Usage:
  uv run windows/icons/icons.py build
  uv run windows/icons/icons.py apply
"""

import argparse
import ctypes
import io
import os
import pathlib
import sys
import tomllib
from typing import cast
import urllib.error
import urllib.parse
import urllib.request

from PIL import Image
import resvg_py

HERE = pathlib.Path(__file__).resolve().parent
CONFIG = HERE / "icons.toml"
RAW = "https://raw.githubusercontent.com/microsoft/fluentui-system-icons"
# Fluent ships hand-tuned SVGs per size; each ICO size renders from the
# smallest source at least that big, so small sizes stay crisp.
SOURCE_SIZES = (16, 20, 24, 28, 32, 48)
ICO_SIZES = (16, 20, 24, 32, 40, 48, 64, 256)


def load_config() -> tuple[str, dict[str, str]]:
  """Returns (Fluent commit, {folder relative to ~: Fluent asset})."""
  with CONFIG.open("rb") as f:
    data = tomllib.load(f)
  commit, folders = data.get("fluent_commit"), data.get("folders")
  if not isinstance(commit, str) or not isinstance(folders, dict):
    raise SystemExit(f"{CONFIG} needs fluent_commit and a [folders] table")
  items = cast(dict[object, object], folders).items()
  return commit, {str(k): str(v) for k, v in items}


def is_builtin(glyph: str) -> bool:
  """Reports whether a config value names a System32 icon, not a Fluent one."""
  return ".dll," in glyph


def slug(glyph: str) -> str:
  """Returns the .ico stem for a Fluent asset name, e.g. `scan-person`."""
  return glyph.lower().replace(" ", "-")


def fetch_svgs(commit: str, glyph: str) -> dict[int, str]:
  """Returns {source size: svg text} for a Fluent Color glyph, cached."""
  snake = glyph.lower().replace(" ", "_")
  cache = pathlib.Path.home() / ".cache" / "fluent-icons" / commit
  cache.mkdir(parents=True, exist_ok=True)
  svgs: dict[int, str] = {}
  for size in SOURCE_SIZES:
    name = f"ic_fluent_{snake}_{size}_color.svg"
    path = cache / name
    if not path.exists():
      asset = urllib.parse.quote(glyph)
      url = f"{RAW}/{commit}/assets/{asset}/SVG/{name}"
      try:
        with urllib.request.urlopen(url) as resp:
          path.write_bytes(resp.read())
      except urllib.error.HTTPError as e:
        if e.code == 404:
          continue
        raise
    svgs[size] = path.read_text(encoding="utf-8")
  if not svgs:
    raise SystemExit(f"no Fluent Color SVGs for glyph {glyph!r}")
  return svgs


def render(svg: str, px: int) -> Image.Image:
  """Renders an SVG at px x px."""
  png = resvg_py.svg_to_bytes(svg_string=svg, width=px, height=px)
  return Image.open(io.BytesIO(bytes(png))).convert("RGBA")


def build_icon(commit: str, glyph: str, dest: pathlib.Path) -> None:
  """Packs every ICO size of one glyph into dest."""
  svgs = fetch_svgs(commit, glyph)
  frames: list[Image.Image] = []
  for px in ICO_SIZES:
    fits = [s for s in svgs if s >= px]
    frames.append(render(svgs[min(fits) if fits else max(svgs)], px))
  frames[-1].save(
    dest,
    format="ICO",
    sizes=[(px, px) for px in ICO_SIZES],
    append_images=frames[:-1],
  )


def build(commit: str, folders: dict[str, str]) -> None:
  """Renders one .ico per glyph, then prunes any .ico no longer referenced."""
  done: set[str] = set()
  for glyph in folders.values():
    if is_builtin(glyph) or slug(glyph) in done:
      continue
    build_icon(commit, glyph, HERE / f"{slug(glyph)}.ico")
    done.add(slug(glyph))
    print(f"built  {slug(glyph)}.ico")
  for stale in HERE.glob("*.ico"):
    if stale.stem not in done:
      stale.unlink()
      print(f"pruned {stale.name}")


def set_attrs(path: pathlib.Path, attrs: int) -> None:
  """Sets Win32 file attributes, raising on failure."""
  if not ctypes.windll.kernel32.SetFileAttributesW(str(path), attrs):
    raise ctypes.WinError()


def apply(folders: dict[str, str]) -> None:
  """Points each existing folder's desktop.ini at its icon."""
  normal, readonly, hidden, system = 0x80, 0x1, 0x2, 0x4
  home = pathlib.Path.home()
  shell = ctypes.windll.shell32
  for rel, glyph in folders.items():
    folder = home / rel
    if not folder.is_dir():
      print(f"skip   ~/{rel} (missing)")
      continue
    if is_builtin(glyph):
      icon_ref = rf"%SystemRoot%\system32\{glyph}"
    else:
      ico = str(HERE / f"{slug(glyph)}.ico")
      icon_ref = ico.replace(str(home), "%USERPROFILE%") + ",0"
    ini = folder / "desktop.ini"
    if ini.exists():
      set_attrs(ini, normal)  # a hidden+system file refuses to be rewritten
    # Text mode on Windows already writes \n as CRLF.
    ini.write_text(
      f"[.ShellClassInfo]\nIconResource={icon_ref}\n", encoding="utf-8"
    )
    set_attrs(ini, hidden | system)
    set_attrs(folder, os.stat(folder).st_file_attributes | readonly)
    shell.SHChangeNotify(0x1000, 0x5, str(folder), None)  # UPDATEDIR, PATHW
    print(f"icon   ~/{rel} -> {pathlib.PureWindowsPath(icon_ref).name}")
  shell.SHChangeNotify(0x8000000, 0, None, None)  # ASSOCCHANGED: refresh icons


def main() -> int:
  """Dispatches to build or apply."""
  parser = argparse.ArgumentParser(description=(__doc__ or "").splitlines()[0])
  parser.add_argument("command", choices=("build", "apply"))
  args = parser.parse_args()
  commit, folders = load_config()
  if args.command == "build":
    build(commit, folders)
  else:
    apply(folders)
  return 0


if __name__ == "__main__":
  sys.exit(main())
