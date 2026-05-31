# SPY-only Weinstein strategy — status

Last updated: 2026-06-01

Status: IN_PROGRESS (PR open: `feat/spy-trader-preset`)

## Scope

Single-instrument Weinstein stage-timing reference strategy on SPY
(`trading/trading/weinstein/strategy/lib/spy_only_weinstein_strategy.ml`),
long/flat only. Direction-finding + headroom diagnostic vs BAH-SPY; not a
production strategy.

## Completed

- Base SPY-only strategy (Stage-2 entry, Stage 3→4 / stop exit) — PR #1397.
- Trader/investor docs + Weinstein-faithful-core rule — PR #1398.
- **`ma_period_weeks` config dial** (`feat/spy-trader-preset`): the one
  Weinstein-faithful dial that distinguishes the investor preset (30-week MA,
  the `[@sexp.default 30]`) from the trader preset (10-week MA). Per
  `.claude/rules/weinstein-faithful-core.md` only the MA period changes; the
  spine (Stage-2-only entry, Stage 3/4 exit, stop below base) is untouched.
  - `Strategy_choice.Spy_only_weinstein` gained `ma_period_weeks : int
    [@sexp.default 30]` — existing `spy-only-stage2.sexp` parses bit-identically
    as the investor preset.
  - `Spy_only_weinstein_strategy.config_with ~ma_period_weeks` constructor; the
    weekly-bar lookback now scales as `2 * ma_period` (floored at 12) instead of
    a fixed 60, so a shorter trader MA does not over-read history.
  - Scenarios `spy-investor.sexp` (30wk) + `spy-trader.sexp` (10wk),
    2009-06-01→2025-12-31, universe `universes/spy-only.sexp`, research tier.
  - Unit test: a decline-then-rally tape that the 10-week preset classifies
    Stage 2 (enters) while the 30-week preset classifies Stage 3 (no entry).

## In progress

- PR `feat/spy-trader-preset` review/merge.

## Next steps

- Run both presets on cached SPY 2009-2026 data and record the
  investor-vs-trader return / trades / win-rate / MaxDD comparison (the
  preset-comparison diagnostic the scenarios exist for).

## Follow-ups

- None.
