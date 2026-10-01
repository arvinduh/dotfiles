---
name: rust-guide
description: >-
  Personal Rust engineering standard — 2-space/80-col rustfmt, module-only
  imports with qualified paths, UCS trait calls, thiserror error hierarchies
  that mirror the module tree, gatekeeper visibility, clippy lint baseline, and
  a lint-driven cleanup workflow. Use this whenever you write, edit, review,
  refactor, or clean up Rust (.rs files, Cargo.toml, rustfmt/clippy config),
  even for a one-line fix or when the user only says "clean up the code" in a
  Rust repo.
---

# Rust Engineering Guide

Three tiers, strongest enforcement first. Push every rule as high as it will go:
a rule a tool can check does not belong in prose.

| Tier | Enforced by                | Covers                                   |
| ---- | -------------------------- | ---------------------------------------- |
| 1    | rustfmt (`.rustfmt.toml`)  | whitespace, width, import grouping       |
| 2    | rustc + clippy (`[lints]`) | imports, dead code, idioms, docs         |
| 3    | this guide + code review   | module design, errors, visibility, YAGNI |

## 0. Precedence — read before applying anything below

This guide is the **default**. A repository's own written standard wins where it
says something different: its `AGENTS.md`/`CLAUDE.md`, a style guide it points
to, its `.rustfmt.toml`, its `[lints]` table, its pinned toolchain.

- Before editing, check for those files. Follow the repo where it speaks; apply
  this guide where it is silent.
- Never "fix" a repo toward this guide as a side effect of other work. A
  deviation the repo documents is a decision, not drift. To propose adopting
  part of this guide, raise it as its own change.
- A repo that agrees with this guide should not restate it. Repo docs record
  only deviations and repo-specific facts.

## 1. Tier 1 — formatting

Formatting is mechanical. Never hand-align whitespace or spend reasoning on
layout; run the formatter. Use whichever formatter the repo uses (a pre-commit
hook, `cargo fmt`, or a wrapper such as `fml fmt`).

Default `.rustfmt.toml` for a new project:

```toml
edition = "2024"
tab_spaces = 2
max_width = 80
newline_style = "Unix"
use_field_init_shorthand = true
# Nightly-only below. Only include if the repo already formats with nightly.
# imports_granularity = "Module"
# group_imports = "StdExternalCrate"
# wrap_comments = true
# comment_width = 80
# format_code_in_doc_comments = true
```

If the repo pins a stable toolchain (`rust-toolchain.toml`), do not introduce
nightly rustfmt. That changes CI, so it is the user's call.

## 2. Tier 2 — lints

Single crate: `[lints.rust]` / `[lints.clippy]` in `Cargo.toml`. Workspace:
`[workspace.lints.*]` at the root plus `[lints] workspace = true` in every
member. Prefer the manifest over crate-level `#![warn(...)]` attributes so all
targets (lib, bin, tests, examples) share one list.

```toml
[lints.rust]
missing_docs = "warn"
unsafe_op_in_unsafe_fn = "deny"
unused_qualifications = "warn"

[lints.clippy]
pedantic = { level = "warn", priority = -1 }
# Imports
wildcard_imports = "deny"
single_component_path_imports = "allow" # `use some_crate;` manifests (§3A)
# Hygiene
dbg_macro = "deny"
todo = "warn"
undocumented_unsafe_blocks = "deny"
# Nursery lint worth having; not part of pedantic
redundant_clone = "warn"
```

`pedantic` already includes `manual_let_else`, `match_same_arms`,
`semicolon_if_nothing_returned`, `cloned_instead_of_copied`,
`explicit_deref_methods`, `missing_errors_doc`, `missing_panics_doc`; list a
pedantic lint separately only to change its level. Silence a lint only at the
narrowest item, with a reason:
`#[expect(clippy::too_many_lines, reason = "...")]` — `expect`, not `allow`, so
the suppression fails once it stops being needed.

CI gate: `cargo clippy --all-targets -- -D warnings`.

## 3. Tier 3 — architecture

### A. File header manifest

Every file opens (after `//!` docs) with the crates and modules it uses.
External crates first, then `crate::` modules; one blank line between groups.

```rust
use std::collections;
use std::path;

use thiserror;
use web_sys;

use crate::web::canvas;
use crate::web::window;
```

- **Import modules, not items.** `use crate::web::canvas;` then
  `canvas::Canvas`, never `use crate::web::canvas::Canvas;`.
- **No globs** (`use foo::*`). Sole exception: `use super::*;` inside a
  `#[cfg(test)] mod tests`.
- **No anonymous imports** (`use foo::Trait as _;`).
- **Trait exception.** When method syntax needs a trait in scope and UCS would
  be unreadable, import the trait **by name**:
  - macros that expand to method calls: `use std::fmt::Write;` for `write!` into
    a `String`, `use std::io::Write;` for `writeln!` to a writer;
  - adaptor chains: `use rayon::iter::ParallelIterator;` rather than
    `rayon::prelude::*` or UCS on every `.map().filter().collect()`.

  Name exactly the traits used. This keeps every origin grepable, which is the
  point of the rule.

### B. Qualified paths

- Qualify types and functions by their module: `window::Window::new()?`,
  `path::PathBuf`, `collections::HashMap`.
- Prelude items stay bare: `Option`, `Result`, `String`, `Vec`, `Box`, `Clone`,
  `Default`, `Iterator`, `From`/`Into`, `ToString`.
- **UCS for one-off non-prelude trait calls:**
  `wasm_bindgen::JsCast::dyn_into::<web_sys::HtmlCanvasElement>(el)?`.
- Derives are qualified too: `#[derive(Debug, thiserror::Error)]`,
  `#[derive(serde::Deserialize)]`.

### C. Error hierarchy

Errors mirror the module tree. Leaves own their failures; parents aggregate.

```text
app::Error            (#[from] web::Error, ...)
  web::Error          (#[from] window::Error, #[from] canvas::Error)
    window::Error     (leaf: only what window can fail with)
    canvas::Error     (leaf)
```

```rust
#[derive(Debug, thiserror::Error)]
pub enum Error {
  #[error(transparent)]
  Window(#[from] window::Error),
  #[error("canvas element `{id}` not found")]
  MissingCanvas { id: String },
}
```

- One `pub enum Error` per module that can fail. Never import a sibling's error;
  the parent is the only module that knows both.
- Parents aggregate with `#[error(transparent)] X(#[from] x::Error)`. No hand
  written `impl From`.
- No stutter: `window::Error`, never `window::WindowError`.
- Each variant carries the data needed to act on it, not a pre-formatted
  `String`.
- If the repo forbids `thiserror` (see §0), keep the same shape and write
  `Display`/`Error`/`From` by hand.

### D. Visibility as gatekeeper

- Submodules are private (`mod parser;`). The parent `mod.rs`/`lib.rs` decides
  what escapes, via `pub mod` or `pub use`.
- Inside the tree, plain `pub` is fine; the gatekeeper caps it. Avoid sprinkling
  `pub(crate)`.
- Struct fields private unless a caller outside the module needs them now.
- Integration tests (`tests/*.rs`) only see the public API. Do not widen
  visibility for a test; test through the public surface or use an inline
  `#[cfg(test)]` module.

### E. YAGNI

- No derives, getters, constructors, features, or dependencies until code in the
  current change uses them. Exception: `Debug` on public types.
- Delete code a change makes unreachable in the same change.

### F. Documentation

- Every file starts with `//!`: one sentence on what the module owns, then what
  neighbouring modules own instead.
- `///` first line: one active-voice sentence ending in a period. Explain
  intent, units, invariants; never restate the signature.
- Sections only when they apply: `# Errors`, `# Panics`, `# Safety`,
  `# Side Effects` (I/O, mutation, spawned work).

### G. Resource efficiency

- Push over poll: block on events or channels; no sleep loops or busy waits.
- Borrow before you clone. Take `&str`/`&[T]`/`&Path` instead of owned values
  unless the function stores them.
- Hoist allocation and lookups out of hot loops; cache handles you reuse.
- Domain specifics: WebAssembly/DOM rules live in
  [references/wasm.md](references/wasm.md). Read it whenever the crate depends
  on `wasm-bindgen`, `web-sys`, or `js-sys`.

## 4. Cleanup workflow

Use this when asked to "clean up", "tidy", or bring a crate up to standard.

1. **Read the repo's standard first** (§0). Note every place it deviates from
   this guide and list them for the user. Do not resolve deviations yourself.
2. **Baseline.** Run clippy with this guide's lint set on the command line,
   without editing any config yet, and tally the results:
   `python3 <skill-dir>/scripts/lint_tally.py` (run from the crate root;
   `--help` for options). It prints the number of unique sites per lint.
3. **Plan by lint, not by file.** One commit (or PR) per lint or per mechanical
   transform. Order: machine-applicable first
   (`cargo clippy --fix -- -W clippy::<lint>`), then hand fixes, then structural
   changes (error hierarchy, imports, module splits).
4. **Turn the lint on in the same change that clears it**, so it can't come
   back.
5. **Never blanket-suppress.** A remaining site gets a narrowly scoped
   `#[expect(..., reason = "...")]` or a real fix.
6. **Verify** with the repo's full gate (tests, clippy `-D warnings`, the
   formatter's check mode). A unit-tests-only run is not the gate.

Mechanical sweeps are exempt from any small-commit size target. One lint across
the tree is one reviewable idea even if it touches 300 lines.

## 5. Review checklist

- [ ] Repo standard checked first; no unrequested drift "fixes".
- [ ] Modules imported, items qualified; traits named, never `as _` or glob.
- [ ] New failure modes live in the leaf `Error`; parents use `#[from]`.
- [ ] Nothing more visible than a current caller needs.
- [ ] No speculative derives, helpers, features, or dependencies.
- [ ] Every new file has `//!`; every public item has `///`.
- [ ] No polling, no needless clone/allocation in hot paths.
- [ ] Full gate passes: tests, `clippy --all-targets -D warnings`, fmt check.
