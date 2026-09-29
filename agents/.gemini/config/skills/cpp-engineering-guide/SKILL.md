---
name: cpp-engineering-guide
description: >-
  Comprehensive guide for writing, reviewing, and refactoring C++ code. Enforces
  Google C++ Style Guide standards, 2-space/80-col formatting,
  Include-What-You-Use (IWYU), explicit namespace qualification, RAII ownership,
  and clang-format alignment. Activate whenever working with C/C++ files.
---

# C++ Engineering Guide — Google Style & Architecture Specification

This guide defines formatting, structural constraints, and architectural
invariants for C++ development across projects in this environment.

---

## 1. Mechanical Formatter (`.clang-format`)

All C++ formatting is mechanically governed by the global `.clang-format` based
on Google C++ style:

- **Indentation:** 2 spaces (`IndentWidth: 2`, `TabWidth: 2`, `UseTab: Never`).
- **Column Limit:** 80 characters (`ColumnLimit: 80`).
- **Pointers & References:** Left-aligned (`PointerAlignment: Left`, e.g.,
  `int* p`, `const std::string& ref`).
- **Reflow:** Comment reflow enabled (`ReflowComments: true`).
- **Includes:** Regrouped and case-sensitively sorted (`IncludeBlocks: Regroup`,
  `SortIncludes: CaseSensitive`).

---

## 2. Include What You Use (IWYU) & Manifest Hierarchy

Every file must explicitly include the exact headers defining the symbols it
uses. Never rely on transitive includes.

### Header Ordering

Group headers in this exact order, separated by a single blank line:

1. Related header (for implementation files, e.g., `foo.h` in `foo.cc`).
2. C system headers (e.g., `<sys/types.h>`, `<unistd.h>`).
3. C++ standard library headers (e.g., `<memory>`, `<string>`, `<vector>`).
4. Other third-party libraries (e.g., `<absl/...>`).
5. Project-internal headers (e.g., `"subsystem/module.h"`).

---

## 3. Namespace Discipline & Symbol Qualification

### No Scope Pollution

- **`using namespace ...;` is strictly forbidden** in headers and at file scope
  in source files.
- Never use `using namespace std;`.

### Explicit Qualification

- Qualify standard and third-party types explicitly (`std::unique_ptr`,
  `std::string_view`, `absl::StrCat`).
- Deep internal types may use local scope aliases inside function bodies or
  private namespaces:
  ```cpp
  namespace {
  using SubsystemRecord = ::project::internal::SubsystemRecord;
  }
  ```

---

## 4. Ownership, Memory, and Resource Management

1. **RAII by Default:** Every resource (memory, file descriptors, sockets, mutex
   locks) must be bound to object lifetime.
2. **Smart Pointers Over Raw Pointers:**
   - Use `std::unique_ptr` for exclusive dynamic ownership.
   - Use `std::shared_ptr` only when ownership is genuinely shared.
   - Raw pointers (`T*`) and references (`T&`) denote non-owning borrowing.
3. **No Raw `new` or `delete`:** Always prefer `std::make_unique` or
   `std::make_shared`.
4. **Pass by Reference or View:** Pass cheap-to-copy types by value, large
   read-only objects by `const T&`, and string parameters by `std::string_view`.
