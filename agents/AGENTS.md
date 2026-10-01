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

### A. Visibility

- Everything is private by default. Expose only the entry points an external
  caller requires in the current commit; the parent module decides what escapes.
- Fields stay private unless external access is strictly required.

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

## 4. Granular Commits

A clean git history enables effortless code review and robust `git bisect`.

### Rules

- **One idea per commit.** Target **<= 50 lines of net diff** (excluding
  lockfiles and test assets). A mechanical sweep (one lint, one rename,
  formatter output) is one commit however large: it is one reviewable idea.
  Where diff-size pre-commit hooks or automated checks are active, commits
  exceeding 50 lines fail by default; use the escape hatch (`[sweep]` in the
  commit message, `ALLOW_LARGE_COMMIT=1`, or `--no-verify`) only for legitimate
  mechanical sweeps.
- **Every commit on the default branch builds and passes the full gate.** Never
  commit a broken intermediate or "WIP" state. On a PR branch that will be
  squash-merged, each commit builds and is formatted; the full gate runs once
  before review.
- **Incremental Progression:** Break work into small, logically sequential
  commits. Tests and complex logic must take multiple commits rather than being
  bundled:
  1. _Commit 1 (Repro / Spec Test):_ Introduce a failing test or test fixture
     defining the expected behavior (if testable upfront), or declare localized
     error variants / private data structs.
  2. _Commit 2 (Helper Logic & Unit Tests):_ Implement private helper functions,
     constructors, and their corresponding unit tests.
  3. _Commit 3 (Gatekeeper / Public API):_ Expose the entry point and types
     through the module gatekeeper (`pub(crate)` / `pub use`).
  4. _Commit 4 (Caller Connection):_ Connect callers to consume the new entry
     point (turning the baseline test green).
  5. _Commit 5 (Integration & Edge-Case Tests):_ Add end-to-end integration
     tests, regression fixtures, or negative test cases.
- **Commit Message Standards (Conventional Commits):**
  - Format: `<type>(<scope>): <imperative summary>`
  - Scope is **mandatory** (e.g. `fix(markdown):`, `refactor(config):`). Only
    whole-repository mechanical sweeps may omit scope.
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
navigation. The language guide gives the syntax.

### A. Module-Level Documentation

- Every module file must begin with a doc comment providing:
  1. A one-sentence summary of the module's core responsibility.
  2. A concise paragraph explaining its architectural boundary (what it owns vs.
     what neighboring layers own).

### B. Item-Level Documentation

- **One-Sentence Summary:** The first line must be a concise, active-voice
  summary ending with a period.
- **High Signal, Zero Fluff:** Do not write tautological docstrings that merely
  restate type signatures. Explain _intent_, _units_, or non-obvious
  constraints.
- **Sections only when applicable:** side effects (mutation, I/O, listeners),
  errors (the conditions that produce each), panics (the violated invariant).

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
  commit and push their own feature branch, and the lead merges pull requests
  that pass the `orchestrate` skill's merge conditions); a cloud session whose
  task names a branch to develop and push on. None of these authorizes
  committing or pushing directly to the default branch; that always needs its
  own explicit go-ahead.

---

## 10. Mandatory Skill Dispatch Protocol

Before generating, modifying, or reviewing code in specialized domains, agents
MUST inspect and follow the corresponding skill (Claude Code: invoke it with the
Skill tool; other harnesses: read its `SKILL.md`):

- **Rust Projects:** Read and follow the `rust-guide` skill.
- **Python Projects:** Read and follow the `python-guide` skill.
- **Multi-Agent / Worktree Workflows:** Read and follow the `orchestrate` skill.

---

## 11. Feedback

These directives and skills are honed one lesson at a time. When work exposes a
gap, end your report with a **Directives** line, one sentence per item:

- a rule here or in a skill that was wrong, stale, or contradicted another;
- a correction the user had to give twice;
- a rule that a lint, test, or hook could enforce instead of prose;
- a repeated procedure with no skill yet.

Name the file and the proposed change. Propose only; never edit `AGENTS.md` or a
skill unasked, and say nothing when there is nothing to report.
