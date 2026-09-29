---
name: rust-engineering-guide
description: >-
  Comprehensive 3-Tier specification for writing, refactoring, and reviewing Rust code.
  Enforces Google-adapted 2-space/80-col formatting, explicit module manifests, UCS trait calls,
  thiserror error hierarchies, gatekeeper module visibility, zero-allocation idle state, and
  workspace clippy lints. Activate whenever working with Rust (.rs) files, Cargo workspaces, or
  Rust formatting/clippy issues.
---

# Rust Engineering Guide — 3-Tier Architecture & Style Specification

This guide defines the ultimate combination of mechanical formatting, static
compiler linting, and architectural principles for Rust codebases.

---

## 1. The 3-Tier Enforcement Model

```text
┌────────────────────────────────────────────────────────┐
│ Tier 1: Mechanical Formatter (.rustfmt.toml)           │
│ Enforced via `cargo +nightly fmt`                      │
│ Whitespace, 2-space indents, 80 cols, import sorting   │
├────────────────────────────────────────────────────────┤
│ Tier 2: Static Compiler & Linters ([workspace.lints])  │
│ Enforced via `cargo clippy` and `rustc`                │
│ Wildcard imports, dead code, single-component imports  │
├────────────────────────────────────────────────────────┤
│ Tier 3: Architectural Policy Codex (AGENTS.md)         │
│ Enforced via Agent System Instructions & Code Review   │
│ YAGNI, push-over-poll, module gatekeepers, errors     │
└────────────────────────────────────────────────────────┘
```

---

## 2. Tier 1: Mechanical Formatter (`.rustfmt.toml`)

All code formatting is purely mechanical. Formatting debates are forbidden.

### Core Configuration
- **Indentation:** 2 spaces (`tab_spaces = 2`, `hard_tabs = false`).
- **Line Width:** 80 columns (`max_width = 80`).
- **Newlines:** Unix LF (`newline_style = "Unix"`).
- **Edition:** Modern Rust (`edition = "2024"`).
- **Import Ordering:** Standard library first, then external crates, then
  internal modules (`group_imports = "StdExternalCrate"`).
- **Binary Operators:** Multiline operators placed at the start of continuation
  lines (`binop_separator = "Front"`).
- **Reflow:** Nightly comment and string reflow (`wrap_comments = true`,
  `format_strings = true`, `format_code_in_doc_comments = true`).

---

## 3. Tier 2: Static Compiler & Clippy Lints (`[workspace.lints]`)

Configured centrally in root `Cargo.toml` and inherited across workspace crates
via `[lints] workspace = true`.

### Required Lint Invariants

```toml
[workspace.lints.rust]
missing_docs = "warn"
unsafe_op_in_unsafe_fn = "deny"
unused_qualifications = "warn"

[workspace.lints.clippy]
# --- Google Namespace & Import Rules ---
wildcard_imports = "deny"
single_component_path_imports = "allow" # Required for file-header crate manifests

# --- Production Hygiene & Diagnostics ---
dbg_macro = "deny"
todo = "warn"
undocumented_unsafe_blocks = "deny"

# --- Rust 2024 & Modern Idioms ---
collapsible_if = "warn"
collapsible_match = "warn"
manual_let_else = "warn"
match_same_arms = "warn"
semicolon_if_nothing_returned = "warn"

# --- Performance & Zero-Waste Computation ---
redundant_clone = "warn"
cloned_instead_of_copied = "warn"
needless_borrow = "warn"
explicit_deref_methods = "warn"
```

---

## 4. Tier 3: Rust Architecture & Module System

### A. Strict File Header Manifest (IWYU Principle)
Every file must begin with an explicit manifest of all external crates and
internal modules it consumes.

- **Group external crates first, followed by internal `crate::` modules:**
  ```rust
  use thiserror;
  use wasm_bindgen::closure;
  use web_sys;

  use crate::web::canvas;
  use crate::web::window;
  ```
- **Never import items or types directly:**
  ```rust
  // FORBIDDEN:
  use crate::web::canvas::Canvas;
  use crate::web::window::Window;
  use wasm_bindgen::closure::Closure;
  use wasm_bindgen::JsValue;
  ```
- **No Glob Imports (`*`):** `use foo::*` is strictly forbidden.
- **No Anonymous Trait Imports (`as _`):** Do not write `use foo::Trait as _;`.
  Anonymous imports create an untraceable origin black hole.

### B. Qualification in Code
- Always qualify every struct, enum, and function by its module or crate:
  ```rust
  let window = window::Window::new()?;
  let canvas = canvas::Canvas::new(&document)?;
  let element: web_sys::HtmlCanvasElement = ...;
  ```
- **Universal Call Syntax (UCS) for Traits:** When calling non-prelude trait
  methods, invoke them explicitly via Universal Call Syntax:
  ```rust
  let canvas_element =
    wasm_bindgen::JsCast::dyn_into::<web_sys::HtmlCanvasElement>(element)?;
  let js_callback = wasm_bindgen::JsCast::unchecked_ref(listener.as_ref());
  ```
  *Rationale:* Makes the origin of every method 100% grepable and searchable.
- **Prelude Exception:** Standard library prelude types (`Option`, `Result`,
  `String`, `Vec`, `Clone`, `Default`) remain unqualified.

### C. Hierarchical Error Architecture (`thiserror`)
Errors must follow a clean hierarchy mirroring the module tree:

```text
Level 3 (Application):       app::Error
                                ▲
                                │ #[from]
Level 2 (Parent Subsystem):   web::Error
                                ▲
                   ┌────────────┴────────────┐
             #[from]                         #[from]
Level 1 (Leaves):     window::Error            canvas::Error
```

- **Leaf Modules:** Localized `pub enum Error` containing only errors that leaf
  module can trigger. Never import sibling errors.
- **Parent Modules:** Aggregate child errors via
  `#[error(transparent)] Child(#[from] child::Error)`. Zero manual `impl From`.
- **Zero Error Stuttering:** `window::Error`, NOT `window::WindowError`.

### D. Visibility as Gatekeeper
- Submodules remain private by default (`mod submodule;`).
- The parent module (`mod_name.rs`) and crate root (`lib.rs`) act as the
  **gatekeepers to visibility**. Only expose public entry points that callers
  actively require.
- Avoid noisy, repetitive `pub(crate)` annotations throughout internal code.

### E. WebAssembly & Resource Efficiency Standards
- **Push over Poll when idle:** Never run a `requestAnimationFrame` loop when
  the screen is static. Use DOM event listeners that consume 0% CPU when idle.
- **Cache DOM lookups:** `document.get_element_by_id` must execute *once* on
  initialization. Never query the DOM during frame loops.
- **Rich Callbacks:** Event callbacks must pass all metrics directly by value
  (e.g., `on_resize(|width, height, dpr)|`).
