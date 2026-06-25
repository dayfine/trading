# Status: decline-character

## Last updated: 2026-06-25

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

- **Build 3 — faithful short** (READY_FOR_REVIEW, PR feat/faithful-short).
  Two default-off screener knobs that tighten short admission toward Weinstein's
  confirmed-bear short rule, both bit-identical to baseline when off:
  - `screener.config.neutral_blocks_shorts` (`[@sexp.default false]`) — short
    mirror of `neutral_blocks_longs`: new `_shorts_admitted_by_macro`
    (`Bullish->false | Neutral->not neutral_blocks_shorts | Bearish->true`)
    rewrites `_evaluate_shorts`. When `true`, a `Neutral` chop tape (the 2020 V,
    where shorts get squeezed) no longer admits shorts.
  - `screener.config.enable_slow_grind_short_gate` (`[@sexp.default false]`) —
    when `true`, shorts are admitted only when the current index decline is a
    `Decline_character.Slow_grind`. The screener lib stays MACRO-AGNOSTIC (no
    `macro` dep, A2): it receives a plain `~decline_is_slow_grind:bool` (new
    optional on `screen_with_cooldown`, default `true` = no-op) and `&&`s it into
    short admission. The `Slow_grind` bool is classified in the STRATEGY lib
    (`weinstein_strategy_screening._decline_is_slow_grind`) via
    `Decline_character_wiring.classify` from the CURRENT cycle's `macro_result` +
    `index_view` — lookahead-free for an ENTRY gate (entries already gate on the
    current `macro_trend`; the prior-cycle decline ref is the stops seam).
  Both knobs are real `Weinstein_strategy.config` fields
  (`neutral_blocks_shorts`, `enable_slow_grind_short_gate`, both
  `[@sexp.default false]`) threaded through the `_run_screener` with-override
  seam into `Screener.config` → Variant_matrix-searchable (R2). No core-module
  edits. Tests: 6 in `test_screener.ml` (`neutral_blocks_shorts` default-admits /
  Neutral→0 / Bearish-unaffected; slow-grind gate off-ignores-flag /
  on-blocks-fast-v / on-admits-slow-grind), all `List.count + equal_to N`.

- **Build 2b — fast-V arming-speed dial** (READY_FOR_REVIEW, PR
  feat/decline-character/fast-v-arm-speed). Closes the arming-LATENCY gap the
  Build-2 fast-crash screen found: the `catastrophic_stop_pct` absolute stop
  NEVER FIRED in 2020 because `Decline_character.Fast_v` cannot arm until the
  index is below a *falling* MA (~mid-March 2020) — by then the structural
  gap-down stop has already exited every long. The binding constraint is arming
  speed, not stop width. New default-off classifier knob
  `Decline_character.config.fast_v_ignores_ma_filter` (`[@sexp.default false]`):
  when `true`, `classify` evaluates the fast-V-on-rate path even when no decline
  is in progress by the MA test — returning `Fast_v` iff the trailing
  rate-of-decline drawdown over `rate_lookback_weeks` exceeds
  `fast_v_min_rate_pct` (and A-D not leading); else `Not_declining`. The
  slow-grind path is never reached this way (it presupposes weeks-below-a-falling
  -MA). Threaded from a new strategy flag
  `Weinstein_strategy.config.fast_v_arm_on_rate_alone` (`[@sexp.default false]`,
  mirrored in `weinstein_strategy_config.{ml,mli}` + `weinstein_strategy.mli`)
  through a single `Decline_character_wiring.classifier_config
  ~fast_v_arm_on_rate_alone` into BOTH classify sites
  (`Decline_character_wiring.update_ref` — the load-bearing stop-arming seam —
  and `weinstein_strategy_screening._decline_is_slow_grind`, inert for this flag
  since it maps `Fast_v`→not-slow-grind). Variant_matrix-searchable per R2
  (real `Weinstein_strategy.config` field → sexp-resolved by
  `Overlay_validator`). Default `false` = bit-identical (no golden re-pin). 4 new
  classifier unit tests (flag-off steep+rising-MA→Not_declining; flag-on
  steep+rising-MA→Fast_v; flag-on shallow+rising-MA→Not_declining; flag-on
  preserves already-declining Slow_grind / Fast_v). No core-module edits.

## In progress

- None.

## Next steps

**WORKSTREAM EXHAUSTED (2026-06-25, #1739).** All builds merged; A-D-default flip
merged (#1725, confirmation-grid 3/3 ACCEPT); the A-D-lead leg is now live (the deep
`data/breadth/` store is populated). The final open empirical question — whether the
now-live A-D-lead basis makes `fast_v_arm_on_rate_alone=true` promotable — was
answered **NO** by the arming-speed A-D-live WF-CV (ledger
`dev/experiments/_ledger/2026-06-24-arming-speed-adlive-wfcv.sexp`, verdict Reject;
DSR 0.9999, go/no-go FAIL at 1/26 Sharpe wins; the A-D-live basis narrowed the knob
to 2/26 folds — a marginal selectivity refinement, not the catch-vs-whipsaw
separator the 06-22 `fast_v_min_rate` REJECT hoped for). Same meta-pattern as every
decline-character mechanism: faithful narrow-niche tail-RISK insurance →
**stays a default-off axis** (`catastrophic_stop_pct` armed on `Fast_v`;
`neutral_blocks_shorts`; `enable_slow_grind_short_gate`; `fast_v_arm_on_rate_alone`),
never default-on. See `memory/project_decline_character_builds` +
`project_edge_is_the_fat_tail`.

Remaining (all LOCAL/data-gated, none orchestrator-dispatchable):

1. Heavy-tier golden re-pin — sub-task 1 (runnable broad/custom cells) DONE
   (#1734/#1737, re-pinned to the complete-universe warehouse). Remaining
   OOM/snapshot-mode cells (`sp500-30y-capacity-1996`, etc.) deferred — need
   snapshots built first (EODHD-gated). Tracked in the 06-24 plan
   `dev/plans/broad-golden-complete-data-2026-06-24.md`.
2. No further mechanism search planned; the single-dial decline-character surface is
   exhausted. Any revival would be a new hypothesis with its own ledger entry.

## Follow-ups

- None.
