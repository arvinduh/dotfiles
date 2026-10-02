---
name: orchestrate
description: >-
  Lead-orchestrator protocol for multi-agent software work — decompose into
  GitHub issues, dispatch workers into isolated git worktrees, run an
  independent QA review, merge, and clean up. Use this whenever the user asks
  you to orchestrate, dispatch, parallelize, fan out, "work through the
  backlog", run subagents or worktrees, act as lead, audit a repo for issues, or
  babysit several PRs — even if they never say "orchestrate". Not for planning
  or implementing a change yourself.
---

# Orchestrate

You are the **lead**. You decompose, dispatch, review, and merge. You do not
implement.

## 0. Precedence

This skill is the default process. The repository's `AGENTS.md`/`CLAUDE.md` (and
any process doc it points to) wins on **repo facts**: gate commands, required CI
checks, merge method, ask-first lists. Read it before dispatching anything. A
repo that agrees with this skill records only its facts and its deviations.

## 1. Roles

| Role   | Does                                            |
| ------ | ----------------------------------------------- |
| Lead   | decompose, dispatch, triage, merge, clean up    |
| Worker | implement one issue in its own worktree         |
| QA     | independently audit a finished PR, then debate  |
| Audit  | read-only sweep that turns findings into issues |

Where the harness exposes a model or effort knob per dispatch, set it higher for
QA than for workers.

**The lead writes no code.** It does bookkeeping (issues, labels, PRs, merges)
and resolves textual merge conflicts (§6). "This one is trivial too" is the
rationalization this rule exists to block.

## 2. State lives in the repository

GitHub is the only source of truth, and state is **derived, never stored**. No
status labels, no plan file, no summary issue: a snapshot that looks
authoritative goes stale. Native GitHub primitives carry all coordination:
milestones for batch boundaries, assignees for claiming, blockers for DAG
dependencies, and draft/ready PRs for execution state. The one exception is an
ownership label, `lead:<name>`: concurrent leads (`claude`, `agy`, ...) all act
as the same GitHub user, so the assignee alone cannot say whose claim it is.

| State   | Is                                                        |
| ------- | --------------------------------------------------------- |
| triage  | label `triage`: an unverified lead                        |
| design  | label `design`: needs a conversation with the user        |
| ready   | label `ready`, no assignee, no open blocker               |
| blocked | an open native blocker (`gh issue edit --add-blocked-by`) |
| doing   | assignee plus a draft PR                                  |
| review  | the PR is marked ready                                    |
| done    | closed by the merge (`Fixes #N`)                          |

Workers **push after every commit**, so the draft PR always shows real progress
and a stopped agent loses nothing. The price: a pushed commit is never amended
or force-pushed; a fix is a new commit. The squash merge hides that.

## 3. Issues

**The issue is the contract.** Every issue states:

```markdown
## Goal

<one sentence>

## Done

- [ ] <observable acceptance criterion>

## Files

<paths in scope>

## Not

<what this issue deliberately leaves out>
```

- **Size.** One issue is one squash commit on the default branch: one idea,
  independently mergeable, reviewable in one sitting. Split anything bigger into
  sub-issues (`gh issue create --parent N`), with order expressed as blockers
  (`--blocked-by N`), never as prose.
- **Titles** are the eventual commit subject: `<type>(<scope>): <summary>`.
- **Milestones.** Assign every issue to a GitHub Milestone
  (`gh issue edit N --milestone "<name>"`). Milestones define the batch
  container for releases and tracks without inventing custom `status:*` or
  `phase:*` labels. Multiple concurrent orchestrators filter by milestone
  (`gh issue list --milestone "<name>" --label ready`) to parallelize across
  distinct tracks without cross-talk.
- **Body escaping (PowerShell / Windows).** Never pass Markdown containing
  backticks or code spans inside double quotes (`--body "..."`) in PowerShell.
  PowerShell treats backticks as escape characters (e.g. `` `f `` becomes form
  feed `\x0c`, `` `r `` carriage return, mangling paths and code). Always write
  the body to a temporary file and pass `--body-file <path>`, or use a verbatim
  single-quoted here-string (`@'...'@`).
- **Spin-offs.** Anyone who finds something out of scope searches for a
  duplicate, then files it as `triage` with `Spun off from #N`. Nobody fixes it
  in place.
- **Triage.** Issue prose is a lead, not a fact: line numbers, "X is dead code",
  and file lists are true only as of filing, and comments override the body.
  Verify the premise, complete the template, then move `triage` to `ready` (or
  `design`, or close it with the reason).
- **Finding work.** When `ready` runs dry, or on request, dispatch Audit agents,
  one axis each: dead code, test gaps, doc drift, lint debt, `TODO`s. Recurring
  finding types become a lint or a test, not a recurring audit.

## 4. Dispatch

1. **Resume** first: `git worktree prune`, then
   `gh issue list --label lead:<self>`. Each claim with a draft PR goes back to
   a worker on that PR's branch. A claim with no PR is released: drop the
   assignee and the label.
2. List unblocked `ready` issues (optionally filtered by milestone:
   `gh issue list --milestone "<name>" --label ready`).
3. **Claim**: self-assign and add `lead:<self>`. If another lead already holds
   it, pick another. Never run two leads against one local clone; worktrees
   share one `.git/`.
4. **Stop rules**, before dispatching:
   - `design` issues go to the user. Do not reinterpret one to make it
     implementable.
   - New user-facing surface (command, flag, output format, config key): show
     the user an example invocation and output, and get a yes first.
   - Ask-first items in the repo's agent doc go to the user.
5. **Dispatch** with the template in
   [references/worker-prompt.md](references/worker-prompt.md).

- **Isolation.** Every worker gets its own worktree. In Claude Code, pass
  `isolation: "worktree"` to the Agent tool; it starts on a throwaway
  `worktree-agent-*` branch, which the worker replaces as its first command.
  Otherwise run
  `git worktree add .worktrees/<slug> -b <type>/<slug> origin/<default>` with
  `.worktrees/` git-ignored.
- **Branches** are `<type>/<slug>`: the Conventional Commit type, then the
  fewest words that identify the change, one where possible (`fix/spawn`,
  `feat/diagnostics`, `refactor/doctor`). Kebab-case only when one word is
  ambiguous. No issue number, no agent name; the PR body carries `Fixes #N`.
- **Parallelism.** Dispatch every unblocked, non-overlapping issue at once, up
  to **about four** agents: the limit is the shared account rate limit, and a
  429 kills the whole wave. Never run two workers whose diffs overlap, even
  without a blocker between them.

**Authority.** Starting a batch authorizes workers to commit and push their own
branch and open a PR, and authorizes the lead to merge PRs that meet §6. Nobody
pushes the default branch directly. Workers do not check in per commit; they
report once, when the PR is ready.

**Commits.** Every commit on a PR branch must strictly comply with `AGENTS.md`
§4. Target **<= 50 lines of net diff** per commit (excluding lockfiles and test
assets). Mandatory `<type>(<scope>): <summary>` format. Follow incremental
progression (types/errors -> private logic -> entry point -> caller / tests). A
fast check (build plus format) runs before each commit. The full gate runs once
before the PR is marked ready and again in QA.

## 5. QA

Required for anything touching shared code, refactoring architecture, or adding
behavior.

**Exemptions (skip §5):**

- One-line or typo fixes.
- **Mechanical lint and test-gate fixes:** Pure lint enablement (e.g. enabling a
  clippy lint in `Cargo.toml` and applying syntax/idiom fixes) or test-gate
  adjustments that introduce zero runtime behavior changes, provided that the
  compiler/clippy gate passes locally with zero warnings and required CI status
  checks are 100% green. The lead audits the diff against the issue's file list
  and merges directly.

QA is a **separate agent that did not write the code**, dispatched with the QA
template. It runs the full gate itself, checks the diff against the issue's
`Done` list, audits commits against `AGENTS.md` §4 (<= 50 net lines outside
mechanical sweeps, mandatory scopes, incremental progression), reverts the code
under each new test to see it fail, and independently verifies the one worker
claim that matters.

- **Debate, don't rubber-stamp.** Relay concrete objections to the worker and
  iterate until both converge on the best solution, not merely an acceptable
  one.
- **Encode new standards.** A violation no existing rule covers becomes a lint
  or test (preferred) or a line in the repo's style doc, in the same PR or a
  spin-off.

All agents share one GitHub identity, so a formal "Approve" is impossible. QA's
verdict is a PR comment.

## 6. Merge

The lead merges on its own when all of these hold:

- required checks are green on the PR's current head;
- QA's latest verdict is approve, or the change was trivial enough to skip §5;
- conversations are resolved.

Use the repo's merge method (default: squash via the PR, delete the branch). The
squash subject is the issue title.

**Conflicts.** Merge the default branch into the PR branch in its worktree:

- **Textual** (adjacent lines, no shared behavior): resolve it yourself.
- **Semantic** (both sides changed the same behavior or type): this is new
  implementation. Send it back to a worker, then through §5.

Re-run the full gate on the resolved tree before pushing.

## 7. Cleanup: every merge

The merge closes the issue, which ends the claim. Abandoning an issue instead
releases it: drop the assignee and `lead:<self>`, and comment with the branch
link. The user frees a dead lead's claim the same way.

1. `git worktree remove <path>`. Check `git status` first; use `--force` only
   for build residue.
2. `git branch -d <branch>`.
3. Delete local scratch tied to the closed issue.

If the repo allows it, share one build cache (`CARGO_TARGET_DIR`) across
worktrees. The cost is build-lock waits between concurrent workers.

## 8. Operating subagents

Read [references/operating-lessons.md](references/operating-lessons.md) before
the first dispatch of a session. When a session teaches something new, add it
there in the same session.

## 9. Report

At each pause, in this order: merged; in review; blocked, and on what; waiting
on the user (`design`, ask-first); next dispatch. Full links for issues and PRs.
End with the **Directives** line (`AGENTS.md` §11), merging what workers and QA
reported.
