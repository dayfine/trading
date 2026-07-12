# Status: extension-stop

## Last updated: 2026-07-12

## Status
IN_PROGRESS

## Interface stable
NO

A default-off **extension stop** — a wide tail-INSURANCE trail for a held long
that has run far above its 30-week WMA (a blow-off / parabolic advance). Once the
weekly close reaches `trigger_ratio ×` the WMA30 it arms a wide trail; thereafter
it exits on the first weekly close that is `trail_pct` below the post-trigger
running peak weekly close. Weekly-close semantics (L3), tighten-only (L2).

Catastrophic-stop-class tail-INSURANCE dial (same class as
`stops_config.catastrophic_stop_pct`, #1695) — NOT a performance axis. Extension
events are rare (~0.6-1% of episodes reach 2.0× WMA30 over a quarter-century), so
a WF-CV is structurally powerless; acceptance basis is the left-tail / event-level
audit, never fold Sharpe. User-directed insurance build (2026-07-11 PM): "no way
we actually sit through 140→70, even if that would take a manual intervention" —
an encoded, tested rule beats an untested panic exit.

W2 authority: a faithful trader exit-aggressiveness dial (book §5.3 "Trailing
Stop — Trader Method"; §Stage 3 detail Ch. 2 "Traders: exit with profits"). Spine
untouched.

Design / evidence: `dev/notes/next-session-priorities-2026-07-12.md` §P0a;
`dev/backtest/extension-screen-2026-07-11/FINDINGS.md` §"What survives".

## Completed
- **Build (PR `feat/extension-stop`, 2026-07-12)** — default-off mechanism:
  - `trading/trading/weinstein/stops/lib/extension_stop.{ml,mli}` — pure trigger
    + trail logic (`config { trigger_ratio; trail_pct }`, both default `0.0` =
    disabled; `fired config ~closes ~wmas`). Mirrors the merged extension screen's
    trigger/peak/fire logic exactly. Registered as `Weinstein_stops.Extension_stop`.
  - `trading/trading/weinstein/strategy/lib/extension_stop_runner.{ml,mli}` —
    Friday-gated, LONG-only special-exit runner: replays each held long's holding
    window on the WMA30 basis (`Sma.calculate_weighted_ma`), emits a `TriggerExit`
    (`StrategySignal "extension_stop"`) at the current weekly close when the trail
    fires; skips positions already exiting (tighten-only).
  - Wired into `special_exits.ml` after the liquidity exit, sharing the full
    same-tick skip-set union (stop / force-liq / Stage-3 / laggard / liquidity).
  - Config: `extension_stop_config : Weinstein_stops.Extension_stop.config`
    (default no-op) in `Weinstein_strategy.config` — a nested `Variant_matrix`
    axis resolvable through `Overlay_validator.apply_overrides`.
  - Tests: `test_extension_stop.ml` (pure mechanism), `test_extension_stop_runner.ml`
    (wiring/gating/fire/shakeout/skip-set/side/cadence), + Overlay_validator
    round-trip cases in `test_runner_hypothesis_overrides.ml`.

## In Progress
- **Build MERGED (#1934, 2026-07-12)** via the GHA orchestrator on full-green:
  qc-structural APPROVED + qc-behavioral APPROVED (quality 5) + CI
  (build-and-test + perf-tier1-smoke) success. Default-off primitive is now on
  main; behavior unchanged (experiment-flag-discipline R1). Review:
  `dev/reviews/extension-stop.md`; audit: `dev/audit/2026-07-12-extension-stop.json`.
- Remaining track work is the acceptance audit below (LOCAL / deep-warehouse,
  `[non-blocking]`) — the code build itself is complete.

## Next Steps
- **Acceptance audit (post-merge, insurance basis).** Run armed-vs-off record
  runs on the current-basis deep runs + re-run the `analysis/scripts/extension_screen`
  counterfactual; judge on left-tail / dispersion / event-level (NOT fold Sharpe).
  Screen pins the width: `trail_pct 0.25` survives on-ramp shakeouts; `0.10-0.20`
  are on-ramp killers. `[non-blocking]`.
- Only after an insurance-basis ACCEPT would a default flip be considered
  (experiment-flag-discipline R3) — default stays off until then.

## Follow-ups
- None.
