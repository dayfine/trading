# Next-session priorities — 2026-05-30

**Supersedes:** `dev/notes/next-session-priorities-2026-05-29-PM.md`. That doc's
P0 (stage3 hysteresis) is **dead** — rejected first as a point (31-fold WF-CV,
#1366) then as an entire surface (#1375). Do not revive it.

## What shipped (2026-05-29 PM → 2026-05-30 overnight)

1. **Hysteresis closed out** — single point rejected (#1364–#1367: panel note,
   WF spec + parser tests, WF-CV verdict, gate-n fix).
2. **Systematic experiment platform built (Gaps A–F, all merged):**
   - #1368 program plan (`dev/plans/experiment-platform-2026-05-29.md`)
   - #1369 `Walk_forward.Variant_matrix` (axes → surface) + flag-discipline rule
   - #1371 `Experiment_ledger` (append-only history + config-hash dedup) + seed
   - #1372 `Backtest_stats.Deflated_sharpe` + `Walk_forward.Variant_ranking`
   - #1374 `experiment-gap-closing` invocable skill
3. **Platform's first real use (#1375):** swept the autopsy exit-timing knobs as
   a **surface** (hysteresis_weeks {1,2,3} × stage3_exit_margin_pct
   {0.0,0.02,0.05}, 31 folds). **REJECTED** — monotonic degradation toward
   baseline; no cell beats baseline; exit-timing missed gain is NOT recoverable
   by these knobs. Recorded in the ledger. Writeup:
   `dev/notes/exit-timing-surface-2026-05-30.md`.

Net: the exit-timing failure mode (autopsy modes 1+2, ~75% of measured missed
gain) is **exhausted** — definitively not capturable by exit-timing knobs.

## The loop is now the default workflow

Use the `experiment-gap-closing` skill. Every strategy-change idea goes:
gap → hypothesis → **axes (surface, not a point)** → check ledger → matrix
(`Variant_matrix`) → WF-CV → rank (`Variant_ranking` Pareto + `Deflated_sharpe`)
→ verdict → ledger append → promote only on a DSR-surviving ACCEPT. New
mechanisms land behind a **default-off flag first**
(`.claude/rules/experiment-flag-discipline.md`).

## P0 — next gap-closing target: a DIFFERENT mechanism class

Exit-timing is done. The remaining autopsy failure mode is
**`late_stage2_admission`** (entry-timing, mode #3: +505% / 100 trades) — the
30-week MA signals Stage 2 months late off bear bottoms (Mar 2009, Mar 2020).
Entry-timing is the sanctioned-explorative axis (per
`memory/feedback_strategy_mechanic_changes_too_explorative`: "entry-timing
okay").

Candidate mechanisms to land behind a default-off flag, then sweep as a surface:
- Dual-MA confirmation (enter on 13-week, hold on 30-week — Weinstein "early
  admission").
- Volatility-adjusted MA period (faster MA in low-vol regimes).
- Volume/breadth confirmation as a trend-establishment proxy before the MA
  recovers.

Step 1 is a small code PR (one mechanism behind one default-off flag). Step 2 is
a `Variant_matrix` surface sweep through the loop. **Expectation, honestly: also
likely a rejection** — but a systematic one that closes the question, and the
loop makes each attempt cheap. If a cell survives DSR, that's the first
real fix found.

## P1 — wire `Deflated_sharpe` into the BO tuner

The `backtest_stats` lib is shared. The continuous-surface BO program can adopt
DSR for its own best-of-N correction (its M3 design named it but never built
it). Deferred to that program; low urgency.

## Still on the roadmap (unchanged priority)

- **Broader-universe** (Russell 3000 / 1998-2026 top-3000) — the BO program's
  M4 fixture exists. Orthogonal to the gap-closing loop; both are valid.
- **Cross-sectional rotation** (`french_weinstein_rotation`) — a different
  alpha source entirely; reopen if entry-timing also exhausts.

## DEFER (unchanged)

Score-formula tuning, v8 BO surrogate swaps, short-side feature work — dead per
prior sessions. Off-Weinstein mechanisms — premature.

## Session state on return

- **Main CI:** check `gh run list --branch main --workflow CI --limit 1` per
  `session-rampup.md` (a fresh CI run is in flight on the #1375 merge as of this
  writing — pure-data PR, expected green).
- **No active agents, no active sweeps, no locked worktrees.** The exit-timing
  sweep finished and was harvested; outputs are in `.sweep-output/` (host).
