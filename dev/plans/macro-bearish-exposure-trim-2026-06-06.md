# Experiment plan — macro-bearish held-exposure trim

**Date:** 2026-06-06
**Status:** SCOPED (not built). Strategy-core change → TDD + 3-gate QC; dispatch to `feat-weinstein`.
**Origin:** the late-Stage2 stop-tighten dial REJECT (`dev/experiments/_ledger/2026-06-06-late-stage2-stop-tighten-grid.sexp`) + the fast-crash diagnosis below.

## Motivation — the real drawdown lever

The late-Stage2 stop-tighten dial (#1446) was REJECTED: it keys on the *per-stock*
`late` flag, which **fast crashes reset before the top**, so it never engages on the
DD-defining episodes. Diagnosing *why* the deep drawdowns happen surfaced a different,
better-supported lever.

**Two findings from the 2026-06-06 crash autopsy:**

1. **Reaction speed is NOT the problem.** Production runs `stop_update_cadence = Daily`:
   stops re-evaluate daily and trigger every day against the bar's intraday low (fill at
   the low). The Friday/weekly cadence governs only entries, macro re-eval, and stage
   reclassification — never stops. We already react at daily granularity. The drawdown is
   structural: Weinstein stops sit *below the base by design*, so a position rides down to
   its stop before exiting; on a vertical day you fill at the gapped-down low.

2. **For slow distribution tops, the macro gate gives early, objective signal — but we
   only use it to block entries, never to reduce held exposure.** Empirical macro-gate
   (breadth/AD) timing from the deep production run
   (`dev/backtest/scenarios-2026-06-02-145506/production-deep/macro_trend.sexp`):

   | crash | type | macro gate | callable? |
   |---|---|---|---|
   | 2000 dot-com | slow distribution | Bearish around/before the Mar-2000 top; decisively Bearish from Sep-2000 | yes (early, whippy) |
   | 2008 GFC | slow distribution | **Bearish from Jan-2008 — ~10 months before** the Sep-Oct waterfall | yes (early, whippy) |
   | 2020 COVID | vertical shock | Bullish through −13%, never Bearish, Neutral only 3wks in | **no — uncallable** |

   `weinstein_strategy_macro.ml`: under Bearish macro, "longs blocked" — that is an
   **entry** gate. Held longs exit only via their own stops / Stage-4 / drawdown-based
   force-liquidation. So in 2008 the gate was Bearish from January and we *stopped buying*
   but **kept riding existing longs down all year** until each hit its individual stop.
   That lag IS the deep-window drawdown.

**The gap:** a *bearish-macro-driven held-exposure reduction*. It keys on the index/breadth
level (fires early + persists through 2000/2008), not the per-stock `late` flag (reset by
fast crashes). It cannot help 2020 — but nothing can except the daily stop, which already
runs. 2000 + 2008 are the bulk of the deep-window MaxDD, so this is where the lever lives.

## Weinstein-faithfulness (W1/W2)

**Spine intact.** The macro gate is spine item #6 ("bearish macro is an unconditional
filter"). Extending it from "block buys" to "also raise cash" is faithful to the book's
intent — Weinstein explicitly says to *raise cash / get defensive when the major trend
turns down* and to *be in cash in Stage-4 markets* (weinstein-book-reference.md §Macro
Analysis, §Stage 4). Holding longs through a confirmed bearish tape is the un-Weinstein
behavior; this mechanism corrects toward the book. It is a **dial** (exit-aggressiveness),
config-expressed, default-off — not a graft.

## Mechanism design

- **Trigger:** on a Friday screening day, when `macro_result.trend = Bearish`.
- **Action:** cap total held long exposure at `macro_bearish_max_long_exposure_pct`
  (tighter than the normal `max_long_exposure_pct`, e.g. 0.35 vs 0.70). Trim the excess
  by exiting **weakest-RS positions first** (reuse the laggard-rotation RS ranking), until
  held long exposure ≤ the bearish cap. `0.0` = full flat (most aggressive, "all cash in a
  bear tape").
- **Re-entry is naturally damped (anti-whipsaw):** the mechanism only *trims*; it never
  force-buys. Coming back requires the normal Stage-2 breakout + volume screen, so a
  Bearish→Bullish whipsaw does not auto-rebuy — re-entry is gated by entry criteria.
- **Model it on `force_liquidation`** (`weinstein/portfolio_risk/`): same shape
  (portfolio-wide, threshold-triggered, emits exit events + integrates with the
  single-exit collision rules), but the trigger is the *predictive* macro gate rather than
  the *reactive* 60%-drawdown portfolio floor.

## Config (experiment-flag-discipline)

```
enable_macro_bearish_exposure_trim : bool   [@sexp.default false]   (* R1: default-off *)
macro_bearish_max_long_exposure_pct : float [@sexp.default 0.70]    (* no-op = normal cap *)
```

- **R1 default-off:** flag false → zero behavior change; backward-compatible on merge.
- **R2 searchable:** real `Weinstein_strategy.config` fields → `Overlay_validator` resolves
  them → expressible as a `Variant_matrix` axis.
- **R3 no default-on without an ACCEPT + confirmation grid.**

## Experiment plan (same harness as the late-dial grid)

- **Axis:** `Flag enable_macro_bearish_exposure_trim (true)` ×
  `Key macro_bearish_max_long_exposure_pct ({0.0, 0.175, 0.35, 0.525})`
  (full-flat → 1/4 → 1/2 → 3/4 of the normal 0.70 cap).
- **Grid cells** (≥3, one deep macro-diverse — per `.claude/rules/promotion-confirmation.md`):
  1. **deep** — PIT-2000 SP500, 2000-2026 (dot-com + GFC — where the mechanism should act).
  2. **bull** — PIT-2010 SP500, 2010-2026 (generalization: fewer/shorter bear-macro
     episodes — 2011, 2015-16, 2018, 2022 — a real whipsaw-cost test).
  3. **third universe cell** (if promising) — e.g. top-1000 broad or a different PIT snapshot.
- Each cell → `Variant_ranking` (Pareto) + `Deflated_sharpe`.
- **Decision rule:** PROMOTE a value only if it **cuts deep MaxDD (37%) materially without
  killing the 918% return AND is not badly dominated on bull**, robust across the grid.
  Never the single-window winner.

## Honest prediction + risk

This *should* reduce deep-window DD (the gate was Bearish months before 2000/2008), **but
at a return cost**: trimming on the Bearish gate means (a) selling into the bear-rally
whipsaws (spring-2008, late-2000 false all-clears), and (b) missing part of the rebound if
re-entry lags. **It could still REJECT** if the whipsaw + missed-rebound cost exceeds the
DD benefit — that is precisely the uncertainty the grid prices. Unlike the late-dial (which
provably did *nothing* to DD), this mechanism *will* move DD; the question is the
DD-vs-return trade, which is a real, fundable question.

## Implementation plan (TDD, strategy-core → feat-weinstein)

1. New module `Macro_bearish_trim_runner` (`weinstein/strategy/lib/`), modeled on
   `force_liquidation` + `laggard_rotation_runner` (RS ranking for weakest-first).
   - `update ~config ~macro_result ~positions ~get_price ~rs_ranking ~current_date`
     → exit transitions trimming held long exposure to the bearish cap.
2. Wire into `weinstein_strategy.ml` `_process_market_day` as a new pass after
   `_run_special_exits`, gated on `config.enable_macro_bearish_exposure_trim`
   && `macro_result.trend = Bearish` && screening day.
3. Two config fields above (default-off no-op).
4. Tests (`test_macro_bearish_trim_runner.ml`): trims to cap on Bearish; no-op when flag
   off / macro not Bearish / already under cap; weakest-RS-first ordering; never force-buys;
   collision with stop/stage3/laggard exits (single-exit rule).
5. Default-off + `Variant_matrix` axis registration. **No default flip without grid ACCEPT.**

## Sequence

1. Build the mechanism (feat-weinstein, TDD + 3-gate QC). ~1 PR, default-off.
2. Run the deep+bull grid (dispatcher, same as the late-dial grid — output to `/tmp`, no
   concurrent jj agents).
3. Pareto/DSR → ledger entry → promotion decision via the confirmation grid.

## Related
- `dev/experiments/_ledger/2026-06-06-late-stage2-stop-tighten-grid.sexp` (the REJECT this supersedes as the lever).
- `.claude/rules/promotion-confirmation.md`, `.claude/rules/experiment-flag-discipline.md`, `.claude/rules/weinstein-faithful-core.md`.
- `memory/project_stage_late_flag_discarded`, `memory/project_cell_e_2020_stall_regime`.
