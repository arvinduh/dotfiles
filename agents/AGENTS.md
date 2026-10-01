# AGENTS.md — Global Engineering Directives & Architecture Principles

All AI agents and contributors working across projects on this machine must
strictly adhere to the following principles.

**Precedence:** a repository's own `AGENTS.md`/`CLAUDE.md` and the docs it
points to override this file on repo facts (commands, CI checks, merge method,
compatibility policy). This file and the skills in §10 are the defaults; repos
record only their facts and deliberate deviations.

---

## 1. Anti-Sycophancy & Technical Pushback Mandate

AI agents must act as uncompromising, rigorous technical partners—not polite
sycophants. Never blindly validate a user suggestion or adopt a suboptimal
pattern just because the user asked "why not X?".

### Operating Principles

- **First-Principles Evaluation:** Before proposing or writing code, evaluate
  suggestions against this strict priority hierarchy: 0. **Correctness:**
  Behavior matches the spec and tests prove it. Nothing below justifies a wrong
  answer.
  1. **Absolute Computational Efficiency:** Zero wasted CPU when idle, zero
     unnecessary heap allocations, push over poll.
  2. **Ergonomic, Composable Architecture:** Orthogonal primitives, decoupled
     subsystems.
  3. **Clean Code Style:** Minimal boilerplate, strict naming.
- **Immediate Pushback:** If a suggestion introduces performance drawbacks (e.g.
  polling loops, unnecessary heap clones), memory leaks, or architectural
  coupling, **explicitly push back and state the trade-offs immediately** before
  writing code.
- **No False Consensus:** Do not append empty flattery ("Great idea!", "You're
  totally right!"). Focus purely on technical merits, benchmarks, and
  invariants.

---

## 2. Anti-Overthinking & Targeted Information Retrieval

Agents must avoid unbounded discovery loops, speculative reasoning essays, and
context pollution.

### A. Bounded File Reading

- **Never dump whole files:** For files longer than 100 lines, do not view the
  entire file at once. Read a line range (your file tool's range parameters,
  e.g. `offset`/`limit`, or `sed -n 'A,Bp'`).
- **Grep Before Read:** Always use `rg` (ripgrep), your grep tool, or targeted
  symbol search to locate the exact function, struct, or diagnostic site
  _before_ reading lines.
- **Delegate broad sweeps:** When an answer needs many files read and only the
  conclusion matters, hand the sweep to a read-only search subagent so the file
  dumps stay out of the main context.
- **Index & Header First:** Inspect module-level documentation (`//!`), struct
  definitions, and public entry points first. Do not inspect private
  implementation bodies unless active logic changes are required.

### B. Single-Hypothesis Verification

- Formulate **one concrete hypothesis** at a time.
- Perform the smallest verifiable check (e.g., `cargo check -p <crate>`) rather
  than speculating on five hypothetical scenarios.
- When fixing compiler or linter diagnostics, read the exact lines flagged in
  the error message—do not read unrelated caller chains.

### C. 3-Step Early Halt

- If **three consecutive attempts at the same hypothesis** fail (three fixes for
  one error, three probes for one root cause), pause immediately. This counts
  failed attempts, not tool calls; a survey or an orchestration batch
  legitimately takes many calls.
- State the exact technical blocker and compiler output concisely, and ask the
  user for clarification rather than speculating across lateral subsystems.

---

## 3. Strict YAGNI (You Aren't Gonna Need It)

**Do not add anything until it is immediately needed.**

### A. Visibility (Module Files as Gatekeepers)

- Avoid noisy, repetitive `pub(crate)` annotations throughout internal code.
- Items inside submodules can use standard `pub` where access within the module
  tree is needed.
- The parent module file (`mod_name.rs`) and the crate root (`lib.rs`) act as
  the **gatekeepers to visibility**: an item is only accessible to the rest of
  the application if `mod_name.rs` explicitly exposes it.
- Submodules remain private by default (`mod submodule;`). Only expose public
  entry points that external callers actively require in the current commit.
- Struct fields must remain private unless external access is strictly required.

### B. Derives & Traits

- **Do not blindly derive traits.** No automatic
  `#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]`.
- Only add a derive when the compiler actively requires it for the code being
  written in the current commit to compile, or when an immediate caller actively
  calls a trait method.

### C. Dependencies & Features

- **Zero speculative dependencies in package manifests.**
- Do not add any crate/dependency until the specific component being written in
  the current commit directly imports and uses it.
- **Strict feature gating:** Do not enable default or extra crate features
  unless the code actively references types from those specific features.

### D. Functions, Getters, and Setters

- **No unused code.** Do not write getters, setters, helper functions,
  constructors, or fields "just in case."
- If data is not consumed by an active caller right now, do not write code to
  expose or manipulate it.
- **No stray scratch files.** Write throwaway files (drafts, repro cases, logs,
  generated scripts) to a temporary directory, never to `$HOME` or a repo root,
  and delete them when the task ends.

---

## 4. Granular Commits (<= 50 Lines Net Diff)

A clean git history enables effortless code review and robust `git bisect`.

### Rules

- **50-Line Soft Ceiling:** Each commit should target **<= 50 lines of net
  diff** (excluding auto-generated lockfiles or test assets). A mechanical sweep
  (one lint, one rename, formatter output) is one commit however large: it is
  one reviewable idea.
- **Every Commit Must Build and Pass Gates:**
  - Never commit a broken intermediate or "WIP" state.
  - Every single commit must leave the repository in a fully compiling, tested,
    and formatted state.
- **Incremental Progression:**
  1. _Commit 1:_ Introduce the localized error variant or private data struct.
  2. _Commit 2:_ Implement the constructor or private helper logic.
  3. _Commit 3:_ Expose the entry point through the module gatekeeper.
  4. _Commit 4:_ Connect the caller to consume it.
- **Commit Message Standards (Conventional Commits):**
  - Format: `<type>(<scope>): <imperative summary>`
  - Types: `feat`, `fix`, `refactor`, `style`, `docs`, `test`, `chore`.
  - The summary must be lowercase, imperative mood, without a trailing period
    (e.g., `feat(canvas): add dpr scaling support`).
  - The body (if required) must focus on _why_ the change was made and
    non-obvious invariants, separated by a blank line.

---

## 5. Worktree Isolation for Multi-Agent Workflows

When multiple subagents operate concurrently, never execute work in the same
working directory to avoid git lock contention, dirty tree collisions, and build
artifact clashes. Every worker gets its own git worktree, removed immediately
after merge. The full protocol (dispatch, QA, merge, cleanup) lives in the
`orchestrate` skill.

---

## 6. Composition Over Monolithic Bundling

- **Keep primitives orthogonal:** Standalone concepts must remain separate,
  decoupled structs.
- **Never bundle unrelated primitives into monolithic "god" structs.**
- **Principle of Least Privilege:** Functions/constructors must only accept the
  exact interface they consume.
- **Higher layers compose:** Coordinators/App own and coordinate independent
  primitives.

---

## 7. Documentation & Spec Standards

Every item must be documented for clean generation and effortless IDE hover
navigation (`rust-analyzer`, `clangd`, language servers).

### A. Module-Level Documentation (`//!`)

- Every module file must begin with an inner doc comment providing:
  1. A one-sentence summary of the module's core responsibility.
  2. A concise paragraph explaining its architectural boundary (what it owns vs.
     what neighboring layers own).

### B. Item-Level Documentation (`///`)

- **One-Sentence Summary:** The first line must be a concise, active-voice
  summary ending with a period.
- **High Signal, Zero Fluff:** Do not write tautological docstrings that merely
  restate type signatures. Explain _intent_, _units_, or non-obvious
  constraints.
- **Standard Doc Sections (Use only when applicable):**
  - `# Side Effects`: Explicitly state mutations, I/O, or event listeners.
  - `# Errors`: Explain specific conditions that return `Result::Err`.
  - `# Panics`: Document any invariant violations that cause a panic.

---

## 8. Zero Compatibility Overhead

- This environment does not maintain public API stability, legacy aliases,
  deprecation warnings, or backwards-compatibility layers.
- If an existing interface needs to change, refactor or replace it directly to
  keep the codebase as clean, optimal, and minimal as possible.
- **Exception:** a project that ships a versioned interface to users (CLI flags,
  a config schema, a published crate or package) follows its own compatibility
  policy for that interface. Internal code stays exempt.

---

## 9. Explicit Commit Authorization

- **NEVER execute a git commit without explicit user instruction.**
- Agents may stage changes (`git add`), verify compilation, and propose commit
  messages, but MUST NOT run `git commit` until the user explicitly directs them
  to do so.
- **What counts as explicit instruction:** the user asking for the change to be
  committed or pushed; the user starting an orchestrated batch (workers then
  commit and push their own feature branch); a cloud session whose task names a
  branch to develop and push on. None of these authorizes committing to, pushing
  to, or merging into the default branch; that always needs its own explicit
  go-ahead.

---

## 10. Mandatory Skill Dispatch Protocol

Before generating, modifying, or reviewing code in specialized domains, agents
MUST inspect and follow the corresponding skill (Claude Code: invoke it with the
Skill tool; other harnesses: read its `SKILL.md`):

- **Rust Projects:** Read and follow the `rust-guide` skill.
- **Python Projects:** Read and follow the `python-guide` skill.
- **Multi-Agent / Worktree Workflows:** Read and follow the `orchestrate` skill.
