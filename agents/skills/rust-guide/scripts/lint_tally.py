#!/usr/bin/env python3
"""Tally clippy findings per lint for the rust-guide lint baseline.

Runs `cargo clippy --all-targets --message-format=json` with the guide's lint
set passed on the command line (no config edits), de-duplicates findings that
appear once per target, and prints unique sites per lint, most frequent first.

Usage:
  lint_tally.py                 # guide lint set + clippy::pedantic
  lint_tally.py --no-pedantic   # guide lint set only
  lint_tally.py --sites LINT    # list file:line for one lint
  lint_tally.py -- -W clippy::nursery   # extra flags forwarded to clippy
"""

import argparse
import collections
import json
import subprocess
import sys

GUIDE_LINTS = [
  "unused_qualifications",
  "clippy::wildcard_imports",
  "clippy::dbg_macro",
  "clippy::todo",
  "clippy::undocumented_unsafe_blocks",
  "clippy::redundant_clone",
]


def main() -> int:
  """Prints unique clippy sites per lint and returns the exit status."""
  parser = argparse.ArgumentParser(description=(__doc__ or "").splitlines()[0])
  parser.add_argument("--no-pedantic", action="store_true")
  parser.add_argument("--sites", metavar="LINT", help="list sites for a lint")
  parser.add_argument("extra", nargs="*", help="flags forwarded to clippy")
  args = parser.parse_args()

  flags: list[str] = []
  for lint in GUIDE_LINTS:
    flags += ["-W", lint]
  if not args.no_pedantic:
    flags += ["-W", "clippy::pedantic"]
  flags += args.extra

  cmd = [
    "cargo",
    "clippy",
    "--all-targets",
    "--message-format=json",
    "--",
    *flags,
  ]
  proc = subprocess.run(cmd, capture_output=True, text=True, check=False)

  seen: set[tuple[str, str, int]] = set()
  counts: collections.Counter[str] = collections.Counter()
  sites: collections.defaultdict[str, list[str]] = collections.defaultdict(list)
  for line in proc.stdout.splitlines():
    try:
      msg = json.loads(line)
    except json.JSONDecodeError:
      continue
    if msg.get("reason") != "compiler-message":
      continue
    diag = msg["message"]
    if not diag.get("code") or not diag["spans"]:
      continue
    code = diag["code"]["code"]
    if not code:
      continue
    span = next((s for s in diag["spans"] if s["is_primary"]), diag["spans"][0])
    key = (code, span["file_name"], span["line_start"])
    if key in seen:
      continue
    seen.add(key)
    counts[code] += 1
    sites[code].append(f"{span['file_name']}:{span['line_start']}")

  if proc.returncode != 0 and not counts:
    sys.stderr.write(proc.stderr[-4000:])
    return proc.returncode

  if args.sites:
    for site in sorted(sites.get(args.sites, [])):
      print(site)
    return 0

  for code, n in counts.most_common():
    print(f"{n:5d}  {code}")
  print(f"{sum(counts.values()):5d}  total")
  return 0


if __name__ == "__main__":
  sys.exit(main())
