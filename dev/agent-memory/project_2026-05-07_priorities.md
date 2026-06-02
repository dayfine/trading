---
name: 2026-05-07 next-session priorities (post-overnight Cell E success)
description: Capital-recycling thesis confirmed end-to-end — Cell E (Stage3 K=1 + Laggard h=2) hit Sharpe 0.94 on 16y SP500. Forward-looking priorities P1-P9 live in dev/notes/next-session-priorities-2026-05-07.md. P1 (equity_curve writer fix) blocks P2/P3.
type: project
originSessionId: 80b44010-4cb3-4caf-add1-0cab1e3628ce
---
## State as of 2026-05-07 morning

The overnight session 2026-05-06 → 2026-05-07 landed 22 PRs (#892–#913).
Headline result: **Cell E (Stage3 K=1 + Laggard h=2) on 16y SP500 = Sharpe
0.94 / +162.78% return / 2,090 trades / 15.22% MaxDD**. 5y Cell E was Sharpe
0.93. Risk-adjusted alpha is regime-invariant. Laggard rotation (#887) is the
dominant lever; Stage-3 force-exit (#872) is complementary. Average hold
collapses 130d → 39d; trade count scales 20×.

## Forward-looking priorities

Full priority list at `dev/notes/next-session-priorities-2026-05-07.md`.

Headline ordering:

1. **P1 — Fix `equity_curve.csv` writer truncation** (blocks P2/P3). The 16y
   Cell E run produced an equity curve that ends 2018-09-28 (8.7 of 16
   years); headline Sharpe / return / MaxDD computed off the truncated window.
   Reconciled NAV +166.7% confirms direction within ~4 pp but full numbers
   not pinnable until the writer fix lands. Trace via
   `trading/trading/backtest/lib/result_writer.ml`.
2. **P2 — Laggard h-sweep on 15y** (h=1, h=2, h=3, h=4, h=6 with Stage3 K=1
   fixed). Confirms whether h=2 is 15y-optimum or just inherited from 5y.
   ~16-20h wall total — overnight cron territory.
3. **P3 — Pin 15y Cell E as second goldens baseline** (after P1 + P2).
4. **P4 — Cost-model overlay** (orthogonal, high-value): Cell E's 131
   trades/yr would carry significant slippage/commission drag in real
   trading; current measurement is no-friction. Add `commission_per_trade`
   + `slippage_bps` knobs, re-run to get the real-Sharpe number.
5. **P5 — Tier4-broad-1y local run** (user-supervised; mechanic validation
   for the 10k-symbol path; PR #897 already landed the scenario file).
6. **P6 — Patch `cleanup_merged_worktrees.sh`** (harness; 3 agents lost
   tonight to mid-run worktree reap; default `--stale-hours 1` minimum or
   distinguish "never on origin" from "deleted from origin").

Lower priority: P7 doc-precision on `StrategySignal`, P8 `#889` continuation
buys, P9 cascade-weight tuning.

## How to apply

When this file is read in a fresh session (post-context-reset), use it to
prime the orchestrator. The forward-looking priorities ordering — `P1
blocks P2 → P3` — should drive the dispatch order. P4 is parallel-safe.
P5 is user-supervised. P6 is a quick harness fix.

## Decision-tree (if outcomes diverge)

- If P2 confirms h=2 on 15y: flip defaults after P4's cost gate clears.
- If P2 finds different 15y-optimum: re-run 5y at that h; if parity, pin
  the consistent h; if divergent, keep feature opt-in and document
  regime-dependence.
- If P4 shows real Sharpe ≪ 0.94: capital-recycling thesis still holds
  directionally but bar moves up; likely tune Laggard hysteresis longer
  to reduce churn at cost of some alpha (measurable trade-off).

## Reference docs (all on main)

- `dev/notes/next-session-priorities-2026-05-07.md` — this file's authoritative source.
- `dev/notes/15y-cell-e-headline-2026-05-07.md` — PR #913 headline writeup.
- `dev/notes/capital-recycling-combined-impact-2026-05-07.md` — PR #910 5y sweep.
- `dev/notes/capital-recycling-framing-2026-05-06.md` — PR #896 pre-empirical framing.
- `dev/notes/all-eligible-opportunity-cost-2026-05-07.md` — PR #908 opportunity-cost.
- `dev/notes/15y-crash-investigation-2026-05-07.md` — PR #911 crash fix.
- `dev/notes/session-summary-2026-05-06-overnight.md` — session ledger
  (superseded for forward-looking items but useful as the merge tally).
