# Status: decline-character

## Last updated: 2026-06-22

## Status
IN_PROGRESS

## Interface stable
NO

A lookahead-free classifier of the current market decline
(`Slow_grind | Fast_v | Not_declining`) — the shared primitive that two later
consumers read. Full design + rationale:
`dev/notes/decline-character-exploration-2026-06-21-PM.md`.

The classifier is **regime INSURANCE**, not a winner-touching / fat-tail-taxing
lever (`memory/project_edge_is_the_fat_tail` endorses "winner-touching only as
explicit tail-RISK insurance", which the Fast_v-armed absolute stop is). It is
Weinstein-faithful: it encodes the book Ch. 8 A/D-lead breadth doctrine as a
read-only dial, not a spine change. All builds default-off.

## Build sequence

- **Build 0** — A/D data wiring (feat-data; replace `~ad_bars:[]` in the
  snapshot pipeline). Until it lands the A/D-lead leg is theory-only; the
  rate-of-decline + weeks-below-MA legs work today.
- **Build 1** — Decline-character classifier (THIS PR). New standalone
  `trading/analysis/weinstein/macro/lib/decline_character.{ml,mli}`. Pure
  `classify`; no consumer, changes no behaviour.
- **Build 2** — Fast-crash absolute long stop, arms on `Fast_v`
  (`stop_types` config `catastrophic_stop_pct`, default 0.0).
- **Build 3** — Faithful short (Bearish-only + `Slow_grind` gate) in screener.

## Completed

- **Build 1 — classifier** (MERGED, PR #1692).
  `Decline_character.classify ~config ~macro ~index_bars : t`. Reads the
  already-computed `Macro.result` (index stage MA value/direction + "A-D Line"
  indicator signal) plus weekly index bars (rate-of-decline drawdown,
  trailing-high drawdown, weeks-below-falling-MA). All thresholds in a
  `Decline_character.config` record with `default_config` (no magic numbers):
  `ad_lead_max_drawdown_pct=0.10`, `rate_lookback_weeks=4`,
  `slow_grind_max_rate_pct=0.04`, `fast_v_min_rate_pct=0.08`,
  `weeks_below_ma_slow_grind=8`, `trailing_high_lookback_weeks=52`. 6 unit
  tests. No core-module edits; no `Macro.result` / `Macro.analyze` change.

- **Build 2 — fast-crash absolute stop** (READY_FOR_REVIEW, PR
  feat/fast-crash-stop). Default-off `stops_config.catastrophic_stop_pct`
  (`[@sexp.default 0.0]`, exact no-op) in `stop_types.{ml,mli}`. New
  macro-AGNOSTIC `Catastrophic_stop.{ml,mli}` in the stops lib (re-exported as
  `Weinstein_stops.Catastrophic_stop`): `trailing_high_of_state` (reads the stop
  state's `last_trend_extreme`) + `check_hit ~armed ~pct ~trailing_high ~bar
  ~side`. OR'd into the trigger decision in `stops_runner.ml` via a new optional
  `?catastrophic_armed:bool` (default false → no-op) on `Stops_runner.update`.
  The `Fast_v → armed` decision is made in the strategy lib: a new
  `prior_decline_character` ref is classified at the macro step (via
  `Decline_character_wiring.{classify,update_ref}`, converting the weekly index
  view to bars) and read STRICTLY PRIOR by the next tick's stops pass —
  lookahead-free, mirroring the `prior_macro_result` pattern. Stops lib stays
  macro-agnostic (no `macro` dep added — A2). No core-module edits. To keep
  `weinstein_stops.ml` / `weinstein_strategy.ml` under the 500-line @large cap
  and `_process_market_day` under the 50-line fn cap (both were pre-maxed), the
  PR carries proportionate code-health extractions: the trigger lives in its own
  `Catastrophic_stop` module; the exit-audit-list helper moved to its natural
  home `Exit_audit_capture.emit_for_list`; the transition-assembly + exited-id
  helpers moved to a new pure `Transition_assembly` module; and the dials+entries
  tail of `_process_market_day` became `_run_dials_and_entries`.
  Tests: 8 in `test_weinstein_stops.ml` (helper both sides + no-op at
  armed=false / pct=0 + `trailing_high_of_state`), 3 in `test_stops_runner.ml`
  (armed+pct>0 → TriggerExit; armed=false → no exit; pct=0 → no exit). Threshold
  config for the classifier is `Decline_character.default_config` for now; the
  searchable mechanism axis is `catastrophic_stop_pct` (a real
  `Weinstein_strategy.config` `stops_config.*` float field →
  Variant_matrix-searchable per R2, same as `vol_scaled_stop_atr_mult`).

## In progress

- None (Build 1 awaiting QC + merge).

## Next steps

1. Merge Build 2 (fast-crash absolute stop, PR feat/fast-crash-stop).
2. **Build 0** — A/D data wiring (feat-data) `[non-blocking]` — makes the
   A/D-lead leg real (today the indicator is `Neutral` with `~ad_bars:[]`).
3. **Build 3** — faithful short (Bearish-only + `Slow_grind` gate in screener;
   depends on Build 1, on main).
4. Read-only screens (screen-rigor) on the `catastrophic_stop_pct` surface
   (and the 2020 fast-crash scenario specifically) → WF-CV if promising →
   promotion grid, before any default flip.

## Follow-ups

- None.
