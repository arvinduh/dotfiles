---
name: python-guide
description: >-
  Personal Python standard — the Google Python Style Guide with two deviations
  (2-space indent, no `from __future__ import annotations`), enforced by Ruff
  and Basedpyright. Use this whenever you write, edit, review, or refactor
  Python (.py files, pyproject.toml, ruff config), even for a one-line fix.
---

# Python Engineering Guide

The standard is the
[Google Python Style Guide](https://google.github.io/styleguide/pyguide.html).
Tools enforce most of it, so this guide lists only the deviations and the rules
no tool checks. A rule a tool can check does not belong in prose.

## 0. Precedence

This guide is the default. A repository's own `AGENTS.md`/`CLAUDE.md`,
`pyproject.toml`, or `ruff.toml` wins where it says something different. Never
"fix" a repo toward this guide as a side effect of other work.

## 1. Enforced by tools

| Tool           | Covers                                                    |
| -------------- | --------------------------------------------------------- |
| `ruff format`  | layout: 2-space indent, 80 columns, double quotes         |
| `ruff check`   | import order, docstrings, annotations, naming, bug idioms |
| `basedpyright` | types                                                     |

Never reason about layout; the edit hook formats each file. The same hook
reports the lint findings it could not fix. Fix each one; silence a rule only on
the one line, with the reason: `# noqa: B006 - <why>`.

Gate: `ruff format --check . && ruff check . && basedpyright`.

## 2. Deviations from Google

- **Indent is 2 spaces**, not 4.
- **No `from __future__ import annotations`.** Quote a forward reference
  instead: `def parent(self) -> "Node":`.

## 3. Rules no tool checks

- **Import modules, not symbols.** `from package import module`, then
  `module.function()`. Never `from module import function`. Exception: names
  from `typing` and `collections.abc`.
- **Docstrings say what the signature cannot:** intent, units, invariants.
  `Args:`/`Returns:`/`Raises:` only where they add information.
- **Streams stay lazy.** Yield records instead of building a list a caller only
  iterates once.
