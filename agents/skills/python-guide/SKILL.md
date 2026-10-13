---
name: python-guide
description: >-
  Personal Python standard — the Google Python Style Guide with personal
  engineering directives (2-space indent, 80 columns, no `from __future__ import
  annotations`, logging over printing in libraries, narrow try-except scoping,
  match/case guard clauses, zero-overhead row wrappers), enforced by Ruff and
  Basedpyright. Use whenever writing, editing, reviewing, or refactoring Python.
---

# Python Engineering Guide

The standard builds on the
[Google Python Style Guide](https://google.github.io/styleguide/pyguide.html).
Enforce through tools wherever possible. Prose covers architectural boundaries,
computational efficiency, error invariants, and language idioms.

## 0. Precedence

This guide is the default. A repository's own `AGENTS.md`/`CLAUDE.md`,
`pyproject.toml`, or `ruff.toml` wins where it says something different. Never
"fix" a repo toward this guide as a side effect of other work.

Where this guide and the Google Python Style Guide differ, **this guide's rules
take precedence**.

## 1. Toolchain & Enforcement

| Tool           | Covers                                                   |
| -------------- | -------------------------------------------------------- |
| `ruff format`  | layout: 2-space indent, 80 columns, double quotes        |
| `ruff check`   | import order, annotations, naming, bug idioms, dead code |
| `basedpyright` | static types, variance, strict None safety               |

- Never reason about layout; run the formatter.
- Silence a linter rule only on the exact line with an explanatory comment:
  `# noqa: <RULE> - <why>`.
- Silence a type error only on the exact line:
  `# pyright: ignore[<RULE>] - <why>`.
- Suppress unused argument warnings by deleting variables at the start of the
  function body: `del beans, eggs  # Unused.` (never rename to `_arg` or
  `unused_arg`, which breaks keyword argument callers).

Gate: `ruff format --check . && ruff check . && basedpyright`.

## 2. Core Deviations from Google Style Guide

- **Indentation:** 2 spaces, not 4 spaces.
- **Future Annotations:** **No `from __future__ import annotations`.** Quote
  forward references instead: `def parent(self) -> "Node":`.
- **String Quotes:** Double quotes (`"..."`) preferred and enforced by
  `ruff format`.
- **Tooling:** `ruff` replaces `pylint`/`flake8`/`black`; `basedpyright`
  replaces `pytype`/`mypy`.

## 3. Architecture & Operational Invariants

### A. Logging in Libraries; Printing Only in Entrypoints

- **Always prioritize `absl.logging` over standard `logging`.** Import
  `from absl import logging`, then use `logging.info()`, `logging.warning()`,
  `logging.error()`, `logging.debug()`.
- **Pattern-strings only in logging:** Pass string literals with `%s` and
  positional parameters (e.g.,
  `logging.info("Processed %d items for %s", count, user)`). Never pass
  f-strings or pre-interpolated strings to logging calls; pattern-strings allow
  log collectors to aggregate messages and prevent wasted rendering.
- **Never `print()` inside library modules.** Libraries emit diagnostics via
  `logging`.
- Console printing (`print()`, `sys.stdout`, `sys.stderr`) and interactive user
  prompts (`input()`, `getpass()`) belong exclusively to application entrypoints
  (`main.py`, CLI commands, binary scripts).

### B. Narrow Try-Except Scoping, Exceptions & Error Propagation

- **Never wrap multi-line business logic in a `try` block.** A `try` block must
  enclose only the specific statement or I/O call that can raise.
- **Catch specific exceptions:** Catch `httpx.HTTPError`, `sqlite3.Error`,
  `json.JSONDecodeError`. Never use bare `except:` or catch-all
  `except Exception:` unless re-raising or at an outermost process/thread
  isolation boundary.
- **Use `finally` for cleanup** when context managers cannot be used.
- **Use built-in exceptions where applicable:** Raise `ValueError` or
  `TypeError` for precondition violations and API misuse instead of creating
  redundant custom exceptions.
- **Custom exception conventions:** Subclass an existing exception (usually
  `Exception` or a domain base error). Suffix class names with `Error`. Do not
  repeat package names (`storage.StorageError`, not
  `storage.StorageStorageError`).
- **Never use `assert` for application logic or precondition checks.** Asserts
  can be compiled out (`python -O`). Use `assert` strictly in `pytest` test
  suites or for internal unreachable invariants.
- **Fail fast on missing or corrupt data.** Do not synthesize fake, mock, or
  fallback data to mask failures.
- **Error message design:**
  - Messages must match the exact failure condition (never guess a cause).
  - Interpolated values must be clearly identifiable (e.g.,
    `f"Invalid port: {port=}"`).
  - Keep message prefixes static and greppable.
- **Explicit boundary for User-Facing vs. Developer-Facing Errors:**
  - _Developer-Facing_: Internal exceptions (`ValueError`, `RuntimeError`,
    `sqlite3.DatabaseError`) and library logger diagnostics
    (`logging.error(...)`) carrying technical parameters, query text, and
    invariant conditions.
  - _User-Facing_: API responses (`fastapi.HTTPException(status_code, detail)`)
    and CLI exit summaries. These must explain what failed and how the user can
    resolve it, without leaking stack traces or database internals.

### C. Flat Control Flow, Guard Clauses & Strict YAGNI

- **Flat control flow over nested branching.** Use early-return guard clauses
  and clean `match/case` or `if/elif` chains to keep the happy path at the
  lowest indentation level.
- **Small, focused functions:** Prefer functions <= 40 lines. Break long
  routines into orthogonal, single-responsibility helpers.
- **One statement per line:** Never use semicolons `;`. Never place `try/except`
  on a single line. Single-line `if cond: return` is permitted only if trivial
  and fits in 80 columns without `else`.
- **Strict YAGNI:** Write only what immediate callers consume right now. No
  speculative helpers, getters, wrappers, or unused features.
- **Well-scoped utilities:** Helper functions must be tightly focused on a
  single invariant, never sprawling or duplicating logic.

### D. Computational Efficiency & Data Structures

- **Avoid string accumulation with `+`/`+=` in loops:** Repeated concatenation
  causes quadratic runtime. Append chunks to a list and use `"".join(...)`, or
  write to an `io.StringIO` buffer.
- **Zero mutable global state:** Avoid module-level mutable state. If a process
  cache or registry is necessary, prefix with an underscore (`_cache = ...`),
  access via functions/methods, and document the architectural reason.
- **Module constants encouraged:** Use `CAPS_WITH_UNDER` (`_MAX_RETRIES = 3`,
  `DEFAULT_TIMEOUT = 30.0`).
- **Default argument values:** Never use mutable defaults (`[]`, `{}`). Use
  `None` and initialize inside the function (`if items is None: items = []`), or
  use immutable default tuples `()`.
- **Comprehensions & generators:** Keep comprehensions simple (at most one `for`
  clause and one optional `if` filter). Multiple `for` clauses must be written
  as explicit nested loops. Prefer generator expressions when streaming or
  consuming once.
- **Default iterators & membership:** Use `for key in adict:`,
  `if item in alist:`, `for line in afile:`, `for k, v in adict.items():`. Avoid
  `.keys()` and `.readlines()`. Never mutate a container during iteration.
- **Implicit boolean evaluation:**
  - Use `if not seq:` for empty strings, lists, dicts.
  - Explicit `if val is None:` or `if val is not None:` for `None` checks.
  - Never compare booleans to `True` or `False` using `==`.
  - For integers, compare explicitly against 0 (`if count == 0:`) to avoid
    confusing 0 with `None`.
  - For numpy arrays, check `.size` (`if not arr.size:`).
- **Structured table abstractions over scattered raw SQL strings:** Represent
  database entities via clean `Database` and `Table` abstractions that
  encapsulate schema, lookups, and parameterization, avoiding repetitive SQL
  string construction.
- **Zero unnecessary conversions:** Avoid converting
  `Row -> dict -> BaseModel -> dict -> JSON`. Work with underlying row mappings
  or lightweight property accessors directly.
- **Streams stay lazy:** Yield records via generators instead of constructing
  intermediate lists that callers iterate only once.

### E. Declarative Schemas & Database Structure

- Group DDL table definitions into clean declarative sequences or migration
  scripts executed in single transactions (`executescript` or parameterized
  batch execution) rather than chaining repeated imperative `.execute()` calls.

### F. Resource Management: Files, Sockets, and Connections

- **Always manage stateful resources via `with` statements** for files, sockets,
  database connections, and locks.
- For resources not supporting the context manager protocol natively, wrap with
  `contextlib.closing()` or create a `@contextlib.contextmanager`.
- **Never rely on `__del__` or garbage collection** to close resources or
  finalize state.
- **Thread synchronization:** Do not assume built-in types (e.g., dicts, lists)
  are atomic across threads. Use `queue.Queue` for inter-thread communication,
  or `threading.Condition` / locks.

### G. Imports & Packaging

- **Do not create empty `__init__.py` files.** Python 3.3+ provides native PEP
  420 namespace packages. Use `__init__.py` only when actively exporting a
  curated package-level public API or configuring package-level initialization.
- **Import modules, not symbols:** `from package import module`, then
  `module.function()`. Never `from module import function`.
  - _Exemptions:_ symbols from `typing`, `collections.abc`, and
    `typing_extensions`.
- **Full package pathnames (no relative imports):** Always use full module paths
  (`from sound.effects import echo`, never `from . import echo` or
  `import echo`).
- **Import aliasing (`as`):** Use aliases only when module names collide,
  conflict with a top-level symbol or parameter name, or are standard
  abbreviations (`import numpy as np`).
- **Import ordering & grouping:**
  1. Standard library (`import sys`, `from collections.abc import Sequence`)
  2. Third-party packages (`import numpy as np`, `from absl import logging`)
  3. First-party sub-packages (`from myproject.backend import storage`) One
     import per line (except `typing` and `collections.abc`).

### H. Object-Oriented & Functional Design

- **Properties vs. Getters/Setters:**
  - Use `@property` only for cheap, trivial, unsurprising attribute access or
    lightweight lazy computation.
  - Do NOT wrap simple internal attributes in properties without logic; make the
    attribute public directly.
  - Use explicit methods (`get_foo()`, `set_foo()`) when access involves
    expensive computation, I/O, cache invalidation, or non-trivial side effects.
- **Avoid `@staticmethod`:** Define a module-level private or public function
  instead.
- **Limit `@classmethod`:** Use only for alternative constructors (e.g.
  `from_dict()`) or class-specific cache operations.
- **Nested functions/classes:** Use only when closing over local variables (e.g.
  decorators, closures). Never nest a function solely to hide it; use
  module-level private functions (`_helper()`) so they remain unittestable.
- **Lambdas:** Allow only simple one-line expressions (<= 60-80 chars). Prefer
  `operator` module functions (`operator.mul`, `operator.itemgetter`) over
  lambdas. Prefer generator expressions over `map()` or `filter()` with lambdas.
- **Avoid power features:** Do not use custom metaclasses, bytecode
  introspection, dynamic inheritance, monkey patching, runtime object
  reparenting, or `__del__`. Standard library uses (`abc.ABC`, `dataclasses`,
  `enum.Enum`) are allowed.

### I. Naming Conventions

- `lower_with_under`: Packages, modules, functions, methods, parameters,
  variables.
- `CapWords`: Classes, exception classes, type aliases.
- `CAPS_WITH_UNDER`: Module-level and class-level constants.
- **Internal / Protected:** Prefix with a single underscore (`_helper()`,
  `_internal_cache`). Avoid double underscore `__` name mangling.
- **Filenames:** Must have `.py` extension and use `lower_with_under.py`. Never
  use dashes `-`.
- **Names to avoid:**
  - Single-character names, except counters/iterators (`i`, `j`), exceptions in
    catch blocks (`e`), file handles in `with` (`f`), or unconstrained type
    variables (`_T`).
  - Redundant type suffixes (e.g., `user_dict`, `names_list`).
  - Python dunder names (`__custom__`).
- **Mathematical notation:** Established paper/spec notation is permitted if the
  source reference is cited in the docstring and `# noqa: N806` or
  `# pylint: disable=invalid-name` is narrowly scoped.

### J. Executable Entrypoints

- Modules must be importable without side effects (safe for pydoc and test
  runners).
- Main logic belongs in a `main()` function:

  ```python
  from collections.abc import Sequence
  from absl import app

  def main(argv: Sequence[str]) -> None:
    ...

  if __name__ == "__main__":
    app.run(main)
  ```

  Or for non-absl scripts:

  ```python
  def main() -> None:
    ...

  if __name__ == "__main__":
    main()
  ```

### K. Type Annotations (Basedpyright)

- **Abstract over concrete in parameters:** Use `collections.abc.Sequence[T]`,
  `Mapping[K, V]`, `Iterable[T]` for function parameters. Use concrete types
  (`list`, `dict`) for return types only when callers rely on mutable container
  behavior.
- **Modern union syntax:** Use `T | None` and `A | B`. Never use `Optional[T]`
  or `Union[A, B]`.
- **Explicit `| None`:** Always write `val: str | None = None`. Never rely on
  implicit optionals (`val: str = None`).
- **No `from __future__ import annotations`:** Forward references must be
  string-quoted: `def parent(self) -> "Node":`.
- **Generic types:** Always parameterize generics explicitly (`Sequence[str]`,
  not raw `Sequence`).
- **Type variables:** Internal unconstrained type variables use
  `_T = TypeVar("_T")`, `_P = ParamSpec("_P")`. Constrained or public type
  variables use descriptive names (`AddableType = TypeVar(...)`).
- **No `typing.Text`:** Use `str` for text, `bytes` for binary data.

### L. Documentation & Docstrings

- **Module docstrings:**
  1. A one-sentence summary of the module's core responsibility.
  2. Architectural boundary (what it owns vs. neighboring layers own).
- **Docstring formatting:**
  - Always use triple double quotes `"""`.
  - One-line summary <= 80 characters terminated by a period.
  - Blank line followed by description.
  - Sections: `Args:`, `Returns:` (or `Yields:` for generators), `Raises:`.
  - 2-space indentation within sections (matching guide indent).
- **Class docstrings:** One-sentence summary of what the instance represents,
  followed by an `Attributes:` section for public attributes.
- **Overridden methods:** Methods decorated with `@override` require docstrings
  only if they refine the contract or introduce specific side effects.
- **Test functions:** Do not write redundant docstrings that simply restate the
  test name.
- **TODO comments:** `# TODO: <issue-or-link> - <explanation>`. Always link to
  an issue, date, or event.
