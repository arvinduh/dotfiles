---
name: rust-guide
description: >-
  Personal Rust engineering standard — 2-space/80-col rustfmt, module-only
  imports with qualified paths, UCS trait calls, minimal errors (reuse before
  defining), thin clap CLIs over a granular library, gatekeeper visibility, clippy lint baseline, and
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

### C. Errors

Each module fails with the narrowest type that says what went wrong. A custom
error is the exception, not the default.

- **Reuse an existing error when it is the only failure.** A module that can
  only fail with `io::Error` returns `io::Result<T>`; no wrapper enum.
- **Define an `Error` enum only when it adds information:** a genuinely new
  failure (a variant carrying the data needed to act on it, never a
  pre-formatted `String`), or a module that raises several error types and
  needs one return type. Aggregate those with
  `#[error(transparent)] Io(#[from] io::Error)`; no hand-written `impl From`.
- **One definition per error.** When sibling modules raise the same custom
  error, define it once in the parent's `error.rs` (`module/error.rs`, declared
  by `module.rs`) and have the siblings import it. No `error.rs` otherwise, and
  no crate-wide catch-all enum unless a real caller needs to match across
  subsystems.
- No stutter: `parser::Error`, never `parser::ParserError`.
- If the repo forbids `thiserror` (see §0), keep the same shape and write
  `Display`/`Error`/`From` by hand.

```rust
#[derive(Debug, thiserror::Error)]
pub enum Error {
  #[error(transparent)]
  Io(#[from] io::Error),
  #[error("manifest `{path}` has no `[package]` table")]
  MissingPackage { path: path::PathBuf },
}
```

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

### H. Binary & CLI architecture

- **Layering.** `main.rs` → `cli` → (`ui` when needed, and the library). The
  library never depends on `cli` or `ui`, never prints, and never exits.

  ```text
  main.rs (mod cli;)  ──►  src/cli/  ──►  src/cli/ui/ (optional)
                               │
                               └──────►  <crate> library
  ```

- **The library exposes granular, meaningful functions and types; `cli`
  orchestrates.** Pipelines (find, validate, transform, write), progress, and
  output live in the command's `run`. `cli` owns the lifetime of every object a
  run creates. Library functions return data; they do not decide what the user
  sees.
- **`cli` belongs to the binary.** Declare `mod cli;` in `src/main.rs`, never
  in `src/lib.rs`; the library has zero dependency on `clap`.
- **One file per subcommand.** `src/cli/<cmd>.rs` holds its `#[derive(clap::Args)]`
  struct and an inherent `run(self)`. Commands are `cmd::Args::run`, not free
  `run(args)` functions.
- **No wrapper struct without global flags.** When the base command has no
  flags of its own, the `clap::Parser` is the subcommand enum itself:

  ```rust
  // src/cli.rs: command routing only
  mod ingest;

  #[derive(clap::Parser)]
  #[command(name = "grade", version, about = "...")]
  pub enum Args {
    Ingest(ingest::IngestArgs),
  }

  impl Args {
    pub fn run(self) -> Result<(), grader::Error> {
      match self {
        Self::Ingest(args) => args.run(),
      }
    }
  }

  // src/main.rs: process host
  mod cli;

  use std::process::ExitCode;

  use clap::Parser;

  fn main() -> ExitCode {
    match cli::Args::parse().run() {
      Ok(()) => ExitCode::SUCCESS,
      Err(err) => {
        eprintln!("[ERROR] {err}");
        ExitCode::FAILURE
      }
    }
  }
  ```

  Add a `struct Cli { #[command(subcommand)] .. }` wrapper only once a global
  flag exists. A multi-code tool (clean / violations / error) returns its
  status enum from `run` and `main` matches it exhaustively onto `ExitCode`.
- **Process host (`main.rs`).** Owns process-level side effects: argument
  parsing, terminal capability detection (`NO_COLOR`, `CLICOLOR_FORCE`), the
  log subscriber, panic hooks, and signal handling. `main` returns
  `ExitCode`; `std::process::exit` is banned outside `main` because it skips
  destructors.
- **Help styling.** Give the parser cargo-style colored help with
  `#[command(styles = STYLES)]` and a `clap::builder::Styles` constant; clap
  disables it for non-TTY output and `NO_COLOR` on its own.
- **Logging, not printing, for internals.** The library emits diagnostics
  through the `log` facade (`log::debug!`, `log::info!`); the binary installs
  the subscriber in `main` and keeps it quiet by default (`-v` or `RUST_LOG`
  turns it up). User-facing output is printed only by `cli`.
- **Test the library, not the binary.** Behaviour is tested through library
  functions; integration tests in `tests/` call the public API. Spawning the
  binary is reserved for the few things only the process shows (exit codes,
  argument parsing).

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
   changes (errors, imports, module splits).
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
- [ ] Errors reuse existing types; a custom `Error` only adds information.
- [ ] Nothing more visible than a current caller needs.
- [ ] No speculative derives, helpers, features, or dependencies.
- [ ] Every new file has `//!`; every public item has `///`.
- [ ] No polling, no needless clone/allocation in hot paths.
- [ ] Full gate passes: tests, `clippy --all-targets -D warnings`, fmt check.
