# Next-session priorities — 2026-10-04 (supersedes 2026-10-03)

The 10-03 doc's queue (anchor results → 2025 selection screen → shorts liveness → macro-suspend arm) is
**finished**. Every item has a merged or open results PR. Nothing is running. The next step is a user
decision (section 3).

## 0. Ground rules (unchanged from 10-03 §0 unless marked NEW)

1. Never commit, print, upload or quote the book file. Read it only locally, cite chapter + short quote.
2. No Python. POSIX `sh`, `awk`, `jq`, OCaml.
3. jj for every commit/branch/push; read-only `git` is fine. Agents use plain `git` in their own worktree.
4. QC outranks backtests: `sh dev/scripts/pr_gate_status.sh` first at every pause.
5. Never post a gate-format verdict (`## Results QC` / `## Structural QC` / `## Behavioral QC`) on your own PR.
6. sp500 is never evidence. The idle-cash SPY sleeve / barbell is user-declined.
7. **NEW (user, 10-04):** when disk is short, clean files *we* created without asking (the parent
   `trading/_build` ~11 GB, finished `.claude/worktrees/*`, container `/tmp` warehouses and test temp dirs,
   task outputs). **Never delete Time Machine snapshots.** If still short, say so in one status line.
8. **NEW (user, 10-04):** issues a cloud session can do end to end get the `env/cloud` label; cloud
   sessions pick them up from the label. Do not try to launch cloud agents (`isolation: "remote"` ran
   locally on 09-29 and OOM-killed a cell).
9. **NEW (10-04, PR #3112):** consequence-based routing — `.claude/rules/model-routing.md`. Direction-class
   analysis (a results read that sets the next step) goes through the `results-analyst` agent (opus, max
   effort) when it is available in the session; QC agents carry their own effort levels.
10. Times are PT. Say how long a wait will be. Compact at ~250k.

## 1. What this session settled (all on main except #3123)

| PR | result | memory |
|---|---|---|
| #3107 | 2025 selection screen: picks lagged the pool and SPY; no-build | `project_recovery_reentry_gap` |
| #3110 | Shorts liveness, investor + faithful shorts, 5d: **0 fills**; slow-grind gate shut 117/138 Bearish weeks; 2 tickets above market | `project_shorts_liveness_dead` |
| #3108 | #3075 fix: cancel a resting entry ticket on a split (default-off) | — |
| #3112 / #3113 | model + effort routing; token report gains per-model totals | — |
| **#3123** (open) | Macro-suspend on investor, 5d + 5r, 3 salts: **live but "dilutes" in both windows**, no phase 2 | `project_macro_suspend_investor_dilutes` |
| #3120 / #3121 / #3122 | cloud sessions (from `env/cloud`): catastrophic-exit reason (#3101), live broker-stop sync (#2984), pack short leg (#3111) | — |

**#3123 state at hand-off:** qc-results dispatched 18:50 PT. If APPROVED and CI green → merge
(`gh pr merge 3123 --squash --delete-branch`). If NEEDS_REWORK → rework in workspace
`.claude/worktrees/jjws-msusp` (bookmark `experiments/macro-suspend`), second commit, re-run qc-results.
Then `jj workspace forget` that workspace and remove the directory.

### The transferable why across this session's three experiments

All three hit the same wall: **a resting level that outlives the base that justified it.**
- Long recovery entries (10-02): far graded tops in every year, not just 2009 — no base-bounded anchor fix.
- Shorts (10-03): both tickets sat 21–34 % above market at a transition-week level and never traded.
- Macro-suspend (10-04): suspended tickets re-issue *unchanged*, so they fill months later at the old
  trigger (DLX +7 months, STN +11 months) and stop out within days. Removing bear-week fills is otherwise a
  coin-flip: those fills cluster at market turns (5d −$27k, 5r +$33k incl. AIT and STN at recovery starts),
  and the re-shuffled slots net only −$3k to −$5k at 5d — the stale re-issue is a per-trade defect, not the driver.

Forward: stop proposing levers that *move or time* a resting entry level (N-week anchors, suspend/resume,
re-time). The coherent remaining variant is "cancel and re-screen against the current base" — a different
mechanism; it is **not** proposed and needs its own pre-registration if the user wants it.

## 2. Open correctness items (local data needed — no `env/cloud`)

- **#3109 (P1)** split detector fires on adjusted-series steps with no raw gap (272 events ≥ 25 %);
  held positions rescaled on non-split days → phantom NAV jumps in records. First `[merge]` item is a
  count of split events applied to held positions in the 26y investor salts + the f2 record, with the NAV
  jump per event. That count decides how much of the record moves.
- **#3104** ADR dividends > 5 % read as splits (FUJIY, DHLGY) — same detector, smaller band.
- #3075 closed with `verify/pending`: its `[after-merge]` item is a 26y liveness read of the
  cancel-on-split flag; fold into the next 26y run rather than a dedicated chain.

## 3. Decision the user owes (default if unspecified: 3a)

- **(a) #3109 measurement** (read-only over the warehouse + committed records, no backtest). It is the only
  item that can change existing numbers, so it goes before new strategy work.
- (b) A selection-side read for the 2025 shape (picks lagged a narrow mega-cap tape): not designed yet;
  would start as a read-only screen.
- (c) SPY 30-week-MA strategy rerun on the current build (offered 10-04, not confirmed).
- (d) Shorts: open the gates one at a time, slow-grind gate first (user decision 10-03) — only on an
  explicit go.

## 4. Session-end chores

```sh
sh dev/scripts/export-memory.sh
sh dev/scripts/budget_local_record.sh   # --date <D> too if the session crossed UTC midnight
```

Docs-only PR (this file + exports + `dev/status/perf-long-cells.csv` + budget JSON): CI only, then
`gh pr merge --squash --delete-branch`. Print the time (PT).

## 5. Things that look right but are wrong

- Counting Bearish-week fills from `trades.csv` alone — open positions at the window end count too
  (the 5d macro-suspend count was 6 from trades, 9 with open positions).
- Reading the 5d macro-suspend realised P&L (+$22k–24k for the knob) as a win: the verdict includes the
  value of positions open at the end, and the pre-registered rule reads Calmar on NAV.
- Proposing a 26y phase for macro-suspend (rule 6 not met) or a default flip (rule 8).
- Deleting Time Machine snapshots to free disk.
- Everything in the 10-03 doc §7 still holds.
