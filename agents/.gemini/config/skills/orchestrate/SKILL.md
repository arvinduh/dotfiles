---
name: orchestrate
description: >-
  Master coordination workflow for multi-agent loop engineering, Git worktree
  isolation, issue tracking synchronization, and Maker-Checker QA verification.
  Use this skill when the user requests multi-agent execution, background task
  parallelization, worktree orchestration, or when acting as a Lead Orchestrator
  delegating implementation to subagents.
---

# Multi-Agent Loop Engineering & Worktree Orchestration

This skill defines the operational protocol for autonomous multi-agent task
execution, branch isolation via Git worktrees, and Maker-Checker QA
verification.

---

## 1. The Separation of Roles

To prevent confusion, regressions, and workspace locking, agents operate in
three distinct roles:

```text
┌────────────────────────────────────────────────────────┐
│             Lead Orchestrator (Primary Agent)          │
│ • Decomposes goals into minimal issues (<= 50 lines)   │
│ • Manages issue state machine (TODO -> CLAIMED -> QA)  │
│ • Does NOT write code; spawns and directs subagents     │
└───────────┬────────────────────────────────┬───────────┘
            │ 1. Spawn Worker                │ 2. Spawn QA Reviewer
            ▼                                ▼
┌────────────────────────┐      ┌────────────────────────┐
│    Worker Subagent     │      │  QA Reviewer Subagent  │
│ • Works in .worktrees/ │      │ • Independent review   │
│ • Atomic <= 50L diffs  │      │ • Runs test/clippy/fmt │
│ • Validates build      │      │ • Approves/Rejects PR  │
└────────────────────────┘      └────────────────────────┘
```

---

## 2. Lead Orchestrator Invariants

1. **Zero Direct Implementation:** The Orchestrator plans, coordinates, and
   reviews. It delegates implementation to subagents (`invoke_subagent`).
2. **Issue Tracker Synchronization:** The Orchestrator maintains task states in
   a central manifest (`.agents/tasks.md` or session issue state):
   - `[TODO]`: Unassigned, ready for pickup.
   - `[CLAIMED]`: Assigned to a worker subagent in a dedicated worktree.
   - `[QA_REVIEW]`: Implementation complete; awaiting QA pass.
   - `[DONE]`: Verified by QA, approved by user, merged to main.
3. **No Unbounded Parallelism:** Limit concurrent active worker worktrees to 2–3
   maximum to prevent host resource starvation and cognitive overhead.

---

## 3. Git Worktree Lifecycle Protocol

### Step 1: Worktree Initialization

Workers never work in the main workspace. Each task gets a dedicated worktree:

```bash
# Ensure .worktrees/ is git-ignored
git worktree add .worktrees/feat-<name> -b feat/<name> origin/main
```

### Step 2: Worker Execution

The worker subagent operates strictly inside `.worktrees/feat-<name>`:

- Implements changes in **<= 50-line granular commits**.
- Verifies compilation (`cargo check`), tests (`cargo test`), and formatting
  (`cargo +nightly fmt --check`) before signaling completion.

### Step 3: The Commit Gate & User Authorization

- **Branch Commits:** When the user directs the orchestrator to execute a task,
  worker subagents have authorization to make granular commits on their
  **isolated feature branch** (`feat/<name>`).
- **Main Branch Gate:** Subagents are **strictly forbidden from committing to or
  merging into `main`**. The Orchestrator presents the final branch diff to the
  user for explicit approval before merging.

### Step 4: Maker-Checker QA Review Pass

Before merging, the Orchestrator spawns an independent **QA Reviewer Subagent**
into the worktree:

1. QA runs presubmit: `cargo check`, `cargo test`, `cargo clippy`, `cargo fmt`.
2. QA audits the diff for YAGNI violations, speculative code, or missing docs.
3. If QA fails, the worker is messaged with the exact failure. If QA passes, the
   task transitions to `[QA_REVIEW] -> Approved`.

### Step 5: Merge & Clean Tear-down

Upon user authorization, the Orchestrator integrates the branch and destroys the
worktree:

```bash
# Fast-forward or rebase merge
git merge --ff-only feat/<name>

# Tear down worktree and branch
git worktree remove .worktrees/feat-<name>
git branch -d feat/<name>
```
