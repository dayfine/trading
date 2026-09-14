# Cross-agent review — Codex as an advisory reviewer, Claude as the gate

Two agents review PRs in this repo. Their roles are not symmetric, and the
asymmetry is expressed in automation vocabulary (headings, labels, a script
column) so the gate loop enforces it, not the chat.

## The rule

1. **Every PR merges on the three gates, whoever wrote it:** CI green +
   qc-structural APPROVED + qc-behavioral APPROVED at the current tip
   (`pr-merge-gates.md`). Both QC verdicts are **Claude Code** reviews
   (dispatched subagents or the local session). A Codex review is never a
   substitute for either.
2. **Codex reviews are advisory.** They post under the heading
   `## Codex review — <title>` and show in the **CODEX** column of
   `sh dev/scripts/pr_gate_status.sh`. They must never use the headings
   `## Structural QC`, `## Behavioral QC` or `## qc-…` — those attribute the
   review to a Claude gate (`pr_gate_status.sh` reads the FIRST heading only;
   the #2620 false-green mode). `dev/scripts/codex_review.sh` validates the
   shape before posting and refuses otherwise.
3. **Codex-authored PRs** carry `author/codex` (Codex sets it on creation) and
   go through the same loop: structural → behavioral → merge by the dispatcher.
   Codex cannot merge or approve (`.codex/rules/trading.rules` forbids both).
4. **Opt-in per PR, with a fallback:**

   | label | effect in `pr_gate_status.sh` |
   |---|---|
   | (none) | CODEX column shown; NEXT-ACTION unchanged. Today's behaviour. |
   | `review/codex-requested` | a missing/stale Codex review is appended to NEXT-ACTION as a hint; the action itself is unchanged. |
   | `review/codex-required` | a would-be `MERGE` becomes `HOLD` until a Codex verdict is `ok` at the tip. **Soft gate with a timeout:** after 3 h without a verdict the dispatcher swaps the label to `review/codex-timeout`, comments why, and merges on the Claude gates. It never overrides a rework, a red CI or a `do-not-merge` hold. |
   | `review/codex-timeout` | record that the soft gate expired; informational. |

   `CODEX_REVIEW=off` in the loop's environment makes `codex_review.sh` a
   no-op (exit 0). Removing the label or setting that variable is the whole
   fallback — nothing else changes.

## How a Codex review runs

Dispatcher-driven, never a standing terminal:

```sh
sh dev/scripts/codex_review.sh <PR>            # checkout → codex exec review → validate → post
sh dev/scripts/codex_review.sh <PR> --no-post  # validate only; report path printed
sh dev/scripts/codex_review.sh <PR> --dry-run  # print the prompt
```

It checks the PR head out into a detached worktree under `.claude/worktrees/`,
runs `codex exec review --base origin/main --ephemeral` (read-only sandbox,
**no dune** — it consumes no container slot, so it may run beside a backtest),
validates the report (`Reviewed SHA:` line 1, `## Codex review` first heading,
`## Verdict` → `APPROVED|NEEDS_REWORK`, no gate headings), posts it with the
full head SHA as `commit_id`, and removes the worktree. Docs-only PRs are
skipped (CI is their only gate).

`docs/howtos/codex_pr_reviews.md` (#2785) describes the **promotion path** —
Codex playing the qc-structural / qc-behavioral roles under the gate headings.
That is not enabled: it becomes an option only after the advisory column has
agreed with the Claude gates across enough PRs to trust it, and it would need
its own rule change here.

## Container discipline (unchanged)

Claude QC reviewers build in their own worktree and take a dune slot
(`container-capacity-scheduling.md`: cap 3 agents, one dune in flight,
none beside a multi-hour backtest). The advisory Codex review does not build.
If a future Codex role does, it takes the same slot rules as a Claude reviewer.

## When this fires

- A PR shows `[+ codex review (advisory) at <sha>]` in NEXT-ACTION → run
  `codex_review.sh`.
- A PR shows `HOLD -- review/codex-required` → run it, or after 3 h swap the
  label to `review/codex-timeout` and merge on the Claude gates.
- A review appears under a gate heading from Codex → it is a defect in the
  poster, not a verdict: remove or re-post under `## Codex review`, and file it.
