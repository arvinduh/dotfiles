#!/usr/bin/env python3
"""Gatekeeper stop hook enforcing clean lints and types before an agent finishes.

Runs on the 'Stop' lifecycle event for both Antigravity and Claude Code.
Inspects modified and untracked files in the current git repository and runs
canonical linters/typecheckers.
"""

import json
import pathlib
import shutil
import subprocess
import sys


def find_tool(name: str) -> str | None:
  """Finds an executable in PATH, returning its path or None."""
  return shutil.which(name)


def parse_context() -> tuple[dict[str, object], bool]:
  """Reads stdin context payload."""
  if sys.stdin.isatty():
    return {}, False

  try:
    content = sys.stdin.read()
    if not content.strip():
      return {}, False
    data: dict[str, object] = json.loads(content)
  except Exception:
    return {}, False

  is_antigravity = "conversationId" in data
  return data, is_antigravity


def get_modified_files() -> list[pathlib.Path]:
  """Returns a list of modified, added, or untracked files from git status."""
  git = find_tool("git")
  if not git:
    return []

  res = subprocess.run(
    [git, "status", "--porcelain"],
    capture_output=True,
    text=True,
    check=False,
  )
  if res.returncode != 0:
    return []

  files: list[pathlib.Path] = []
  for line in res.stdout.splitlines():
    if len(line) < 4:
      continue
    raw_path = line[3:].strip().strip('"')
    if " -> " in raw_path:
      raw_path = raw_path.split(" -> ")[-1].strip('"')
    path = pathlib.Path(raw_path)
    if path.is_file():
      files.append(path)

  return files


def check_python(files: list[pathlib.Path]) -> list[str]:
  """Runs ruff and basedpyright checks on Python files."""
  errors: list[str] = []
  ruff = find_tool("ruff")
  if ruff:
    res = subprocess.run(
      [
        ruff,
        "check",
        "--quiet",
        "--output-format",
        "concise",
        *[str(f) for f in files],
      ],
      capture_output=True,
      text=True,
      check=False,
    )
    if res.returncode != 0:
      output = res.stdout.strip() or res.stderr.strip()
      if output:
        errors.append(f"ruff check:\n{output}")

  basedpyright = find_tool("basedpyright")
  if basedpyright:
    res = subprocess.run(
      [basedpyright, *[str(f) for f in files]],
      capture_output=True,
      text=True,
      check=False,
    )
    if res.returncode != 0:
      output = res.stdout.strip() or res.stderr.strip()
      if output:
        errors.append(f"basedpyright:\n{output}")

  return errors


def check_rust(files: list[pathlib.Path]) -> list[str]:
  """Runs cargo check if any Rust files are modified."""
  cargo = find_tool("cargo")
  if not cargo or not files:
    return []

  res = subprocess.run(
    [cargo, "check", "--message-format=short"],
    capture_output=True,
    text=True,
    check=False,
  )
  if res.returncode != 0:
    output = res.stderr.strip() or res.stdout.strip()
    if output:
      return [f"cargo check:\n{output}"]
  return []


def check_markdown(files: list[pathlib.Path]) -> list[str]:
  """Runs markdownlint-cli2 on modified markdown files."""
  mdlint = find_tool("markdownlint-cli2")
  if not mdlint or not files:
    return []

  res = subprocess.run(
    [mdlint, *[str(f) for f in files]],
    capture_output=True,
    text=True,
    check=False,
  )
  if res.returncode != 0:
    output = res.stderr.strip() or res.stdout.strip()
    if output:
      return [f"markdownlint:\n{output}"]
  return []


def check_toml(files: list[pathlib.Path]) -> list[str]:
  """Runs taplo check on modified TOML files."""
  taplo = find_tool("taplo")
  if not taplo or not files:
    return []

  res = subprocess.run(
    [taplo, "check", *[str(f) for f in files]],
    capture_output=True,
    text=True,
    check=False,
  )
  if res.returncode != 0:
    output = res.stderr.strip() or res.stdout.strip()
    if output:
      return [f"taplo check:\n{output}"]
  return []


def main() -> int:
  """Main entry point for stop-gate."""
  context, is_antigravity = parse_context()

  if is_antigravity:
    termination_reason = context.get("terminationReason")
    if termination_reason and termination_reason != "model_stop":
      print("{}")
      return 0

  modified = get_modified_files()
  if not modified:
    print("{}")
    return 0

  py_files = [f for f in modified if f.suffix.lower() == ".py"]
  rs_files = [f for f in modified if f.suffix.lower() == ".rs"]
  md_files = [f for f in modified if f.suffix.lower() == ".md"]
  toml_files = [f for f in modified if f.suffix.lower() == ".toml"]

  findings: list[str] = []
  if py_files:
    findings.extend(check_python(py_files))
  if rs_files:
    findings.extend(check_rust(rs_files))
  if md_files:
    findings.extend(check_markdown(md_files))
  if toml_files:
    findings.extend(check_toml(toml_files))

  if not findings:
    print("{}")
    return 0

  error_summary = (
    "Gatekeeper lint check failed on modified files:\n\n"
    + "\n\n".join(findings)
    + "\n\nPlease fix these errors before completing the task."
  )

  if is_antigravity:
    print(
      json.dumps(
        {
          "decision": "continue",
          "reason": error_summary,
        }
      )
    )
    return 0

  sys.stderr.write(f"{error_summary}\n")
  return 2


if __name__ == "__main__":
  sys.exit(main())
