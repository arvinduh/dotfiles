#!/usr/bin/env python3
"""Formats one file with the canonical formatter for its type.

Supports CLI invocation ($1), git pre-commit, and PostToolUse hooks (stdin
JSON) from both Antigravity and Claude Code.
"""

import json
import pathlib
import shutil
import subprocess
import sys
from typing import cast


def find_tool(name: str) -> str | None:
  """Finds an executable in PATH, returning its path or None."""
  return shutil.which(name)


def parse_target_file(args: list[str]) -> tuple[str, bool]:
  """Extracts the file path and whether the caller is Claude Code."""
  if args:
    return args[0], False

  if sys.stdin.isatty():
    return "", False

  try:
    payload = sys.stdin.read()
    if not payload.strip():
      return "", False
    data_raw: object = json.loads(payload)
    if not isinstance(data_raw, dict):
      return "", False
    data = cast(dict[str, object], data_raw)
  except Exception:
    return "", False

  tool_call = data.get("toolCall")
  tool_call_dict = (
    cast(dict[str, object], tool_call) if isinstance(tool_call, dict) else {}
  )
  tool_call_args_raw = tool_call_dict.get("args")
  tool_call_args = (
    cast(dict[str, object], tool_call_args_raw)
    if isinstance(tool_call_args_raw, dict)
    else {}
  )

  tool_input_raw = data.get("tool_input")
  tool_input = (
    cast(dict[str, object], tool_input_raw)
    if isinstance(tool_input_raw, dict)
    else {}
  )

  target_file = tool_call_args.get("TargetFile") or tool_input.get("file_path")
  file_path = str(target_file) if isinstance(target_file, str) else ""
  is_claude = "tool_input" in data
  return file_path, is_claude


def format_markdown(path: pathlib.Path) -> None:
  """Formats markdown using prettier and markdownlint-cli2."""
  prettier = find_tool("prettier")
  if prettier:
    subprocess.run(
      [prettier, "--write", str(path)],
      capture_output=True,
      check=False,
    )

  mdlint = find_tool("markdownlint-cli2")
  if not mdlint:
    return

  parent_dir = path.parent
  git_cmd = ["git", "-C", str(parent_dir), "rev-parse", "--show-toplevel"]
  git_res = subprocess.run(git_cmd, capture_output=True, text=True, check=False)
  repo_root = (
    pathlib.Path(git_res.stdout.strip())
    if git_res.returncode == 0
    else parent_dir
  )

  has_local_config = any(repo_root.glob(".markdownlint*"))
  global_config = (
    pathlib.Path.home()
    / ".config"
    / "markdownlint"
    / ".markdownlint-cli2.jsonc"
  )

  config_args: list[str] = []
  if not has_local_config and global_config.is_file():
    config_args = [f"--config={global_config}"]

  subprocess.run(
    [mdlint, "--fix", *config_args, str(path)],
    cwd=repo_root,
    capture_output=True,
    check=False,
  )


def format_file(path: pathlib.Path) -> str:
  """Applies the canonical formatter to the given file."""
  suffix = path.suffix.lower()
  findings = ""

  if suffix == ".rs":
    tool = find_tool("rustfmt")
    if tool:
      subprocess.run([tool, str(path)], capture_output=True, check=False)
  elif suffix == ".py":
    ruff = find_tool("ruff")
    if ruff:
      subprocess.run(
        [ruff, "check", "--fix", "--quiet", str(path)],
        capture_output=True,
        check=False,
      )
      subprocess.run(
        [ruff, "format", str(path)],
        capture_output=True,
        check=False,
      )
      check_res = subprocess.run(
        [ruff, "check", "--quiet", "--output-format", "concise", str(path)],
        capture_output=True,
        text=True,
        check=False,
      )
      findings = check_res.stdout.strip() or check_res.stderr.strip()
  elif suffix in {
    ".c",
    ".cc",
    ".cpp",
    ".cxx",
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
  }:
    tool = find_tool("clang-format")
    if tool:
      subprocess.run(
        [tool, "-i", str(path)],
        capture_output=True,
        check=False,
      )
  elif suffix == ".toml":
    tool = find_tool("taplo")
    if tool:
      subprocess.run(
        [tool, "format", str(path)],
        capture_output=True,
        check=False,
      )
  elif suffix in {".json", ".jsonc", ".yaml", ".yml"}:
    tool = find_tool("prettier")
    if tool:
      subprocess.run(
        [tool, "--write", str(path)],
        capture_output=True,
        check=False,
      )
  elif suffix == ".md":
    format_markdown(path)

  return findings


def main() -> int:
  """Main entry point for format-file."""
  file_path_str, is_claude = parse_target_file(sys.argv[1:])

  # Antigravity PostToolUse hook expects empty JSON on stdout
  if not is_claude and not sys.stdin.isatty():
    print("{}")

  if not file_path_str:
    return 0

  target = pathlib.Path(file_path_str)
  if not target.is_file():
    return 0

  findings = format_file(target)

  if is_claude and findings:
    sys.stderr.write(f"{findings}\n")
    return 2

  return 0


if __name__ == "__main__":
  sys.exit(main())
