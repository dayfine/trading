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

### The transferable why (corrected by the results-analyst second read of #3123)

- Long recovery entries (10-02): far graded tops in every year — no base-bounded anchor fix.
- Shorts (10-03): both tickets sat 21–34 % above market and never traded.
- Macro-suspend (10-04): Bearish-week fills are timed near market turns but are ordinary in quality; removing
  them is negative expected value on a fat-tailed book, and the dollar result is a tail lottery (5d = ONXX
  alone). Re-issued tickets fill from above as dip-buys with stale stops (#3126) — a correctness defect of the
  axis, not a lever. Keep the knob default-off as a book-faithful axis.

Forward: do not propose cancel-and-re-screen as an improvement (it shares the dominant term). Levers that add
or remove a handful of fills cannot be measured by a 5y × 3-salt Calmar test (one draw per window); they need
a paired per-event estimand or the 26y window plus a truncation check.

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
- Calling the 5d macro-suspend result a window-end artefact: it is decided by ONXX, a Bearish-week breakout
  that msB could never have bought.
- Proposing a 26y phase for macro-suspend (rule 6 not met) or a default flip (rule 8).
- Deleting Time Machine snapshots to free disk.
- Everything in the 10-03 doc §7 still holds.

## Addendum — 2026-10-05 01:30 PT (late-session work; supersedes §2–§3 where they differ)

Merged since the handoff: #3128 (macro-suspend second read), #3129 (margin-realism + experiment-platform
COMPLETED; resistance-v2 bundle verified ACTIVE on `_v11pit`), #3130 (SPY 26y benchmark: SPY-30w 326.8 % /
Calmar 0.219; BAH 400.8 % / 0.112 — price-only), #3135 (short-only Phase A). Cloud PRs from `env/cloud`:
#3120, #3121, #3122, #3142 (macro-suspend re-arm, #3126).

**Findings that change how the record reads**
- **The sim is price-only** (`project_sim_price_only_accounting`): no cash interest, no dividends. With T-bill
  interest on the ~49 % cash and dividends, the 26y investor is ≈ 9.3 % CAGR (s0/s2) vs SPY TR 8.1–8.2 %. #3137.
- s1's gap to s0 is one at-fill cash cancellation (ADMA, 96 % funded) — #3138.
- Dollar-volume look-ahead in PIT ranking / liquidity gates (split-adjusted volume × raw close) — #3136 (P1).
- #3109 measured: no unconfirmed splits on held positions, but five dividend-type misfires pass the raw-confirm
  rule; phantom +$36k–109k realised per run (−4 to −11 pp total return). Needs an adjusted-series tightness test.
- Worst years vs SPY (2019, 2023, 2025; also 2009, 2016) = re-entry lag after V-bottoms: 12–17 Bullish weeks
  with zero tickets because ~97 % of candidates skip `No_structural_stop`; plus a narrow mega-cap tape.
- 26y deep-dive (user's six questions): capture of ≥ +100 % breakout episodes ≈ 1 % in every forward bucket;
  faithfulness career grade B− (volume at fill and laggard exits of healthy leaders are the gaps); P&L is
  tail-carried (top 20 trades ≈ 100 % of net; winner α 1.3–1.8, loser α 6–7) — do not optimise whipsaws.
  Report features filed: #3139 (weekly decision record), #3140 (missed winners / faithfulness / P&L anatomy),
  #3141 (pack defects).
- **Short-only Phase A** (#3135): live, but the clean book ≈ −22 % / −17 % (2007–12, salt 0); NAV rose in 2008,
  gains given back 2009–12. Defects: #3131 (ticket at base top AND the $17 gate reads the base-top price →
  sub-$17 margin churn), #3145 (short Tightened stop never lowered), #3146–#3149.

**Decisions owed by the user (as of 01:30 PT)**
1. #3137 cash interest + dividends — recommended next (changes every SPY comparison).
2. #3136 — measure membership change per vintage before any rebuild.
3. Shorts — fix #3131 and run #3145 as its own stop study before any money read, or stop (record P0a + Phase A).
