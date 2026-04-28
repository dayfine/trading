# PR #642 trade-audit — regression investigation (2026-04-28)

## Brief

PR #644 reported a sharp drop in sp500-2019-2023 trade count after PR #642
landed (134 → 30). The hypothesis dispatched to me: PR #642's "pure
observer" trade-audit capture sites are not actually pure observers, and
they're displacing strategy decisions on the 491-symbol universe even
though they're bit-equivalent on the 7-symbol parity goldens.

Branch dispatched: `fix/trade-audit-pure-observer`, off main@origin.
Expected outcome: identify the side effect and either narrow the capture
or revert #642 entirely.

## TL;DR

**No regression attributable to PR #642.** The 30-trade sp500 result
reproduces at every commit I tested — including 565365fb (the SHA the
PR-#639 baseline note declares it ran on, where the note claims 134
trades). The "134 trades" baseline does not reproduce against the current
data + scenario file, so there is nothing for #642 to have regressed
*from*.

No fix or revert PR is appropriate.

## What I ran

All runs: `scenario_runner.exe --dir
trading/test_data/backtest_scenarios/goldens-sp500` (1453 trading days,
491-symbol universe), unmodified scenario file, default config. Container
`trading-1-dev`. Universe sp500.sexp generated 2026-04-26.

| Commit | Description | Trades | Return | MaxDD |
|---|---|---:|---:|---:|
| 7fa21571 (main) | post-#645 (current main) | **30** | +4.2% | 5.0% |
| 6f9a66d9 | post-#642, pre-#645 | **30** | +4.2% | 5.0% |
| c43e4f44 | pre-#642 (post-#640) | **30** | +4.2% | 5.0% |
| 565365fb | "baseline note" SHA | **30** | +4.2% | 5.0% |

Identical outputs — same 30 round_trips, same return, same drawdown —
across `pre-#642`, `post-#642`, and `post-#645`. PR #642's parity gate
(`test_panel_loader_parity` against `panel-golden-2019-full.sexp`,
7-symbol/8-month) also still passes bit-for-bit on current main.

Steps to reproduce my pre-#642 run (for the next reviewer):

```bash
git checkout c43e4f44 -- trading/
rm -f \
  trading/trading/weinstein/strategy/lib/{audit_recorder,entry_audit_capture,exit_audit_capture}.{ml,mli} \
  trading/trading/backtest/lib/{trade_audit,trade_audit_recorder}.{ml,mli} \
  trading/trading/backtest/test/test_trade_audit_capture.ml
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && dune build'
docker exec trading-1-dev bash -c \
  'TRADING_DATA_DIR=/workspaces/trading-1/trading/test_data \
   /workspaces/trading-1/trading/_build/default/trading/backtest/scenarios/scenario_runner.exe \
   --dir /workspaces/trading-1/trading/test_data/backtest_scenarios/goldens-sp500'
```

## Why the dispatched hypothesis is not correct

The brief's evidence rests on three numbers — 478 (pre-#642 baseline,
brief), 298 (post-#645, brief), 30 (PR #644's measurement of post-#642).
If the regression were really 478→298 between pre-#642 and post-#645, my
pre-#642 run on the same SHA would have shown 478 trades. It shows 30.

The PR #639 baseline note (`dev/notes/goldens-performance-baselines-2026-
04-28.md`) does claim 134 sp500 trades over 5y at SHA 565365fb. That note
was written today, but the run dir it cites
(`dev/backtest/scenarios-2026-04-28-034706/sp500-2019-2023/`) contains
only `equity_curve.csv` — no `trades.csv`, no `summary.sexp`, no
`actual.sexp`. The 134 number can't be cross-checked against artifacts.
Re-running 565365fb today gives 30 trades on the same scenario file +
universe.

Possible explanations for the published-but-not-reproducible 134:
- Data drift. `data/A/L/AAPL/data.csv` was last modified 2026-04-12; no
  obvious refresh between then and now, but I can't rule out whether the
  baseline used a different snapshot.
- Different config_overrides at run time that the note didn't capture.
- A data subset issue (e.g. universe file regenerated since the baseline
  run; `universes/sp500.sexp` says generated 2026-04-26 — matches my run).

This finding is consistent across the small goldens too:
`bull-crash-2015-2020` baseline 83 → my run 21; `covid-recovery` 118 →
30; `six-year-2018-2023` 122 → 37. The discrepancy is uniform, not
specific to sp500. So whatever shifted, it shifted strategy-wide and
before the pre-#642 commit I tested.

## Diff inspection — no obvious side-effect anyway

Independent of the empirical bisect, I read PR #642's diff carefully for
side effects. The factored-out `make_entry_transition` /
`classify_candidate` / `emit_entries` chain in
`entry_audit_capture.ml` preserves the order of effects on `stop_states`
and `remaining_cash` line-for-line vs the pre-#642
`_make_entry_transition` / `_check_cash_and_deduct` /
`_candidate_to_transition`:

- `make_entry` is called before the cash check in both versions; both
  versions write `stop_states` before knowing if the cash check passes.
- `List.map` (NEW) and `List.fold ~init:[] |> List.rev` (OLD) both walk
  candidates left-to-right. The decision-list shape used to compute
  `alternatives_considered` is built post-walk; it doesn't feed back into
  the kept set.
- `find_recent_level_with_callbacks` is now called twice per candidate
  (once for the stop level, once for the floor-kind classification). Both
  calls are pure on the same callbacks bundle.
- The exit-side `_distance_from_ma_pct` calls `Stage.classify_with_
  callbacks` per `TriggerExit` — observation only, populates the shared
  `Weekly_ma_cache` via `Hashtbl.find_or_add` but the cache is keyed only
  on `(symbol, ma_type, period)` and the stored value is a function of
  the panels (which are immutable post-load).

The capture sites are pure observers as advertised.

## What I did NOT do

- Did not open a `fix/` PR. There is no behavioral change to fix; opening
  one would assert a regression that doesn't exist.
- Did not revert PR #642. Same reason. Reverting would lose the
  `Trade_audit` capture infrastructure that PR-3 (renderer) depends on,
  for no observed benefit.
- Did not investigate why the 134-baseline doesn't reproduce. That's a
  separate question — likely data drift, config drift, or the baseline
  measurement was taken with parameters not reflected in
  `goldens-performance-baselines-2026-04-28.md`. Re-pinning the
  `expected` block in `sp500-2019-2023.sexp` should be done off the
  *current* run, not the baseline note.

## Recommended follow-ups

1. **Repin the `expected` block** in
   `trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp`
   off the current 30-trade run, OR if the 134-trade run was correct,
   identify what changed (data, config) and roll it forward. Do not
   merge changes that target the 134 number on the assumption that it
   was the recent baseline; it isn't reproducible.

2. **Update PR #644's note** to clarify the 134 → 30 delta is not
   attributable to PR #642; the 30-trade result reproduces at 565365fb.
   The note's "follow-up #1: diagnose the trade-count collapse since
   #642" should be redirected to "diagnose what made the 2026-04-28
   baseline measurement diverge from current reproduction."

3. **The 4 short-side audit entries on Jan 2019** (PR #644, "All 4 shorts
   are missing from trades.csv") and **inverted CVX/JNJ short stops** are
   real, separate findings. Worth investigating independently — they
   have nothing to do with the 478/134/298/30 trade-count question.

## References

- PR #642: 6f9a66d9, "feat(backtest-perf): trade-audit capture sites in
  strategy + runner".
- PR #644 (open): docs note claiming 134 → 30 collapse, attributes it to
  #642's strategy refactor.
- Baseline note (PR #639, 13edf52f): 134 sp500 trades at 565365fb.
- Parity gate: `trading/trading/backtest/test/test_panel_loader_parity.ml`
  against `panel-golden-2019-full.sexp` (7 symbols, 2018-10..2020-01) —
  passes bit-for-bit on every commit I tested.
