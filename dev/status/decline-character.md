# Status: decline-character

## Last updated: 2026-06-21

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

- **Build 1 — classifier** (READY_FOR_REVIEW, PR feat/decline-character).
  `Decline_character.classify ~config ~macro ~index_bars : t`. Reads the
  already-computed `Macro.result` (index stage MA value/direction + "A-D Line"
  indicator signal) plus weekly index bars (rate-of-decline drawdown,
  trailing-high drawdown, weeks-below-falling-MA). All thresholds in a
  `Decline_character.config` record with `default_config` (no magic numbers):
  `ad_lead_max_drawdown_pct=0.10`, `rate_lookback_weeks=4`,
  `slow_grind_max_rate_pct=0.04`, `fast_v_min_rate_pct=0.08`,
  `weeks_below_ma_slow_grind=8`, `trailing_high_lookback_weeks=52`. 6 unit
  tests (fast-V, slow-grind, rising-MA, close-above-declining-MA, empty bars,
  ambiguous shallow dip). No core-module edits; no `Macro.result` /
  `Macro.analyze` change (goldens untouched).

## In progress

- None (Build 1 awaiting QC + merge).

## Next steps

1. Merge Build 1 (classifier).
2. **Build 0** — A/D data wiring (feat-data) `[non-blocking]` — makes the
   A/D-lead leg real (today the indicator is `Neutral` with `~ad_bars:[]`).
3. **Build 2** — fast-crash absolute stop (depends on Build 1).
4. **Build 3** — faithful short (depends on Build 1).
5. Read-only screens (screen-rigor) on wired data → WF-CV if promising →
   promotion grid, before any default flip.

## Follow-ups

- None.
