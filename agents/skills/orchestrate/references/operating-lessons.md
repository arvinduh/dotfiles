# Operating subagents: lessons that cost real work

These are harness and account realities, not preferences.

- **A quiet agent may still be working.** Subagents often end a turn while a
  build runs in the background and wake when it finishes. "Waiting on cargo
  test" means still working. Never dispatch a second agent into the same
  worktree to "finish" it; that puts two agents on one branch.
- **To replace an agent, stop it first.** Stopping loses its context, not its
  files. Before re-dispatching, inventory the worktree: `git status` and commits
  not yet pushed (workers push every commit, so the draft PR is the rest).
  Unreported results (measurements, review findings) are gone; re-derive them.
- **A quiet CI monitor is not a green build.** Poll loops exit silently. Check
  the PR's checks directly before trusting a monitor that hasn't reported. In
  Claude Code cloud sessions, prefer PR activity subscriptions (events wake the
  session) over polling, and use the GitHub MCP tools (there is no `gh` CLI
  there).
- **An audit's claims are leads, not facts.** Spot-check a finding's premise
  before filing or dispatching on it. "This function is dead" has been wrong
  when it had production callers.
- **Verify the one claim that matters.** "Byte-identical on Linux": read the
  `#[cfg]`. "No golden output moved": confirm the golden diff removes no lines.
  "The hook passed": check `git status` after the commit, since a pre-commit
  formatter can leave the commit and the working tree diverged.
- **Flaky is not a root cause.** A test that fails under load gets a real
  diagnosis or an issue, never an invented explanation and never a skip.
- **Rate limits are shared.** Every agent, cloud session, and chat on the
  account draws from one limit. Five-agent waves have died together on 429s;
  about four is the ceiling. Queue the rest.
