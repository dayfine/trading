# Armed resistance-history run — the false virgins were load-bearing (2026-07-14)

P1 close-out (next-session-priorities-2026-07-14): record convention +
`resistance_lookback_bars 520` (#1966) on the dedup-v2 warehouse, isolating
the honest-virgin vs false-virgin share of the resistance signal.
Run dir: `trading/dev/backtest/scenarios-2026-07-14-204544/top3000-2000-2026-resist520/`.

## Result (single path — screen-rigor caveats apply throughout)

| | Run D (record) | armed resist-520 | Run C (min-hist label floor) |
|---|---:|---:|---:|
| MTM | +7,914% | **+3,584%** | +1,720%* |
| realized | $70.9M | $28.5M | — |
| Sharpe | 0.83 | 0.719 | — |
| MaxDD | 32.3% | **49.1%** | 40.6%* |
| trades | 1,187 | 1,198 | 1,132* |

\* Run C vs the UNARMED baseline (+3,407%), from the 07-13 matrix.

## The why (transferable)

- **Same AXTI entry (2025-06-28), $25.8M vs $67.3M banked** — the armed path
  reached 2025 with ~1/3 of D's NAV, so the same monster paid a third.
- **The mid-tier monsters vanished**: D banked $12.1M realized on
  DDD/SKYW/BFX/BVN; the armed run entered DDD once (stopped out, −$0.03M),
  never entered SKYW/BFX, lost small on BVN.
- **Systematic, not lottery**: those are all CRASH-RECOVERY breakouts — names
  with years of real trapped sellers overhead. Starved windows graded them
  fake Virgin A+ (top rank); honest 520-bar history grades them B/C and they
  lose the Friday ranking race at the cap. The false-virgin defect was
  systematically promoting recovery breakouts — exactly the class where this
  strategy's mid-tier fat tail lives.
- **Honest virgin ≈ no signal**: armed lands at −55% vs D; Run C (signal
  deleted) landed at −50% vs its baseline. The resistance signal's apparent
  contribution to the record path was MOSTLY its false positives. The book's
  virgin-preference rule, fed honest data on this universe, is
  winner-adjacent — another entry in the fat-tail-law ledger, with the twist
  that it is a FAITHFUL rule doing the taxing.

## Decisions

1. **Backtest record convention: `resistance_lookback_bars` stays OFF**
   (never was armed there). Run D remains the record of record.
2. **Live weekly-review arming (merged in #1966's overrides file): KEEP for
   text honesty, but flagged** — honest grades in live RANKING steer picks
   away from the recovery-breakout class. The proper resolution is
   resistance-v2's score/display split (below), not a flip-flop of the live
   override; a human reads the live report and can see both.
3. **Resistance-v2 becomes the arbitration path** (next session): continuous
   overhead-supply score — Σ over zones above breakout of
   bars × age_decay × proximity — on PRECOMPUTED point-in-time top-sketches
   (rolling 520w max-high column + ~20-bucket trailing price histogram per
   symbol-week, built at warehouse time). Gives (a) the honest data without
   the 5h wall (this run took ~5h vs D's ~1.5h — the per-survivor 520-bar
   walk), (b) a WF-CV-able score-weight axis instead of the all-or-nothing
   grade flip, (c) the 10y/5y/2.5y virgin gradient + magnitude discounting.

## Perf note

~5h wall vs ~1.5h unarmed — the survivors-only deep fetch still pays a
520-bar walk per survivor-week. Precomputed sketches (v2) reduce the query to
O(1) column reads. Do not put this knob in a WF-CV sweep before v2.

## Progress-counter gotcha (for future sessions)

`progress.sexp`'s `trades_so_far` counts trade LEGS (~2× round trips) — the
mid-run "2,207 trades vs D's 1,187" read was wrong; final round trips 1,198.
