---
name: python-guide
description: >-
  Comprehensive guide for writing, reviewing, and refactoring Python code.
  Enforces Google Python Style Guide standards, Ruff formatting (2-space,
  80-col), Basedpyright type checking, explicit module imports, and Google
  docstring conventions. Activate whenever working with Python (.py) files.
---

# Python Engineering Guide — Google Style & Architecture Specification

This guide defines formatting, structural constraints, and type checking
standards for Python development across projects in this environment.

---

## 1. Mechanical Formatter & Linter (`ruff.toml`)

All Python formatting (2-space indents, 80-column lines, quote styles, import
sorting) is enforced 100% mechanically by Ruff (`ruff format`,
`ruff check --fix`) via Antigravity disk hooks and Git pre-commit hooks. Do not
waste tokens or reasoning on manual whitespace layout.

---

## 2. Import Conventions (Google Style)

### Import Modules, Not Symbols

- **Rule:** Use `import x` for packages and modules.
- **Allowed:** `from package import module` to qualify submodule paths.
- **Forbidden:** Do not import classes or functions directly from internal
  modules (e.g., `from my_module import calculate_metric` is forbidden; write
  `from package import my_module` and call `my_module.calculate_metric()`).
- **Typing Exception:** Type annotations may be imported directly from `typing`
  and `collections.abc` (e.g., `from typing import Any, Self`).
- **No Wildcard Imports:** `from foo import *` is strictly forbidden.

---

## 3. Strict Type Annotations (`basedpyright`)

Every module must pass static type checking under Basedpyright:

1. **Complete Function Signatures:** All function and method parameters, as well
   as return values, must have explicit type annotations.
2. **Modern Standard Collections:** Use built-in generics directly (`list[T]`,
   `dict[K, V]`, `set[T]`, `tuple[T, ...]`) rather than legacy `typing.List`.
3. **Explicit Optionality:** Use `T | None` rather than `Optional[T]`.

---

## 4. Google Docstring Format

Every public module, class, and function must have a Google-style docstring:

```python
def process_record(record_id: str, count: int = 1) -> bool:
  """Processes an incoming data record and persists updates.

  Args:
    record_id: Unique string identifier of the entity.
    count: Number of event occurrences to register.

  Returns:
    True if the record was processed and committed, False otherwise.

  Raises:
    ValueError: If record_id is empty or count is non-positive.
  """
  ...
```

---

## 5. Idioms & Defensive Engineering

1. **No Mutable Defaults:** Never use mutable objects (`[]`, `{}`) as default
   parameter values. Use `None` as a sentinel:

   ```python
   # Correct:
   def append_item(val: str, target: list[str] | None = None) -> list[str]:
     items = target if target is not None else []
     items.append(val)
     return items
   ```

2. **Context Managers for I/O:** Always use `with open(...)` or managed contexts
   for file handles, database transactions, and concurrency locks.
3. **Generators for Large Streams:** Prefer generator expressions and `yield`
   over accumulating massive in-memory lists when streaming records.
