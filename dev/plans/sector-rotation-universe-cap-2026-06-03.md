# Sector-rotation: scenario universe + per-sector cap — 2026-06-03

Build half of P0 from `dev/notes/next-session-priorities-2026-06-03-PM.md`
(§"Few-feature carrier comparison on stocks"). Plumbing + a default-off dial +
unit tests, landing default-off so every existing golden is bit-identical.

## Context

`Sector_rotation_weinstein_strategy` is the multi-symbol generalization of the
SPY-only reference strategy: each Friday it stage-classifies every tradable
symbol, keeps the Stage-2 names, ranks by RS vs the benchmark, and holds the
top-`k`. Today it **hardcodes the 11 SPDR sector ETFs** as its tradable
universe (`default_symbols`), regardless of the scenario universe. To compare a
"few-feature carrier" against the production Cell-E engine on PIT S&P 500, the
maintainer needs the strategy to trade the *scenario's* universe.

Two relevant facts already true on `main`:
- `config.symbols` and `config.k` are already config fields; `config_with`
  already accepts `?symbols`. So piece (1) is pure plumbing in the backtest
  builder, not a strategy-config change.
- The panel builder already has `~ticker_sectors : (string,string) Hashtbl.t`
  in scope — symbol→GICS-sector for the whole universe (its keys ARE the
  universe). This is the symbol set for piece (1) and the sector lookup for
  piece (2).

## Approach

### Piece 1 — consume the scenario universe (default-off opt-in)

- Add `use_scenario_universe : bool [@sexp.default false]` to the
  `Sector_rotation_weinstein` variant in `strategy_choice.ml`/`.mli`.
- In `panel_strategy_builder.ml`, when `use_scenario_universe = true`, derive
  the tradable list from `Hashtbl.keys ticker_sectors`, **excluding the
  benchmark symbol** (preserve the never-trade-the-benchmark invariant), sorted
  for determinism, and pass it as `~symbols`. When `false` (default), pass no
  `~symbols` so `config_with` keeps the 11-SPDR default → bit-identical.
- Rejected alt: a `symbols` sexp list literal on the variant. The scenario
  universe is already loaded into `ticker_sectors`; re-listing symbols in the
  scenario would duplicate + risk drift. The boolean opt-in reuses the loaded
  universe.

### Piece 2 — per-sector concentration cap (default-off dial)

- Add `sector_cap : int option` to the strategy `config` (default `None`) and
  `sector_of : string -> string option` to `config` (the symbol→sector lookup;
  default `fun _ -> None` = every symbol its own singleton sector, so the cap
  is a no-op even when set if no map is wired). `config` is a plain record (no
  `[@@deriving sexp]`), so a function field is fine.
- Add a matching `sector_cap : int option [@sexp.default None]` to the scenario
  variant; thread it through `config_with` (`?sector_cap`).
- In `panel_strategy_builder.ml`, build `sector_of` from `ticker_sectors`
  (`Hashtbl.find ticker_sectors`) and pass it into the config so the cap can
  resolve sectors. Always wire `sector_of` (cheap); the cap only engages when
  `sector_cap = Some n`.
- Selection logic: extend `Sector_rotation_signals` with
  `rank_top_k_capped ~candidates ~k ~sector_cap ~sector_of`. After sorting by
  RS descending (existing `_compare_candidate`), fold left taking a candidate
  only if (a) fewer than `k` picked total AND (b) its sector currently has
  `< n` picks. A symbol with `sector_of sym = None` is treated as its own
  singleton sector keyed by the symbol itself, so it is never capped away
  (distinct sector per unmapped symbol). When `sector_cap = None`, delegate to
  the existing `rank_top_k` (bit-identical path).
- `_target_set` in the strategy calls the capped variant, threading
  `config.sector_cap` and `config.sector_of`.

This stays Weinstein-faithful (`weinstein-faithful-core.md`): spine items 2
(buy Stage 2), 4 (exit Stage 3/4), 7 (RS for selection) are untouched. The cap
is only a diversification constraint on which already-qualified, RS-ranked
Stage-2 names get filled — exactly the kind of risk-surface dial allowed by the
flag-discipline rule (R1 default-off, R2 searchable config field, R3 no
default-on without a ledger ACCEPT).

## Files to change

- `trading/trading/backtest/lib/strategy_choice.ml` + `.mli` — add
  `use_scenario_universe` + `sector_cap` to the variant; extend `name`.
- `trading/trading/backtest/lib/panel_strategy_builder.ml` — derive symbols
  from `ticker_sectors` when opted-in; build + pass `sector_of`; pass
  `sector_cap`.
- `trading/trading/weinstein/strategy/lib/sector_rotation_weinstein_strategy.ml`
  + `.mli` — add `sector_cap` + `sector_of` config fields; thread into
  `default_config`, `config_with` (`?sector_cap ?sector_of`); call the capped
  ranking in `_target_set`.
- `trading/trading/weinstein/strategy/lib/sector_rotation_signals.ml` + `.mli`
  — add `rank_top_k_capped`.
- `trading/trading/weinstein/strategy/test/test_sector_rotation_weinstein_strategy.ml`
  — (a) universe-override test; (b) `sector_cap = Some 1` test.

## Risks / unknowns

- Function field in `config` breaks any future `[@@deriving sexp/eq/show]` on
  it. Mitigated: the record has no deriving today; if one is needed later the
  lookup can move to a `make` parameter. Documented in the `.mli`.
- Golden churn if defaults aren't truly no-op. Mitigated: `use_scenario_universe
  = false` passes no `~symbols`; `sector_cap = None` delegates to the existing
  `rank_top_k`; `sector_of` default is `fun _ -> None`. Verify `dune runtest`
  bit-identical.

## Acceptance criteria

- `dune build && dune runtest` green; goldens bit-identical at defaults.
- New tests assert domain outcomes (which symbols held), per
  `.claude/rules/test-patterns.md`.
- `.mli` docs cite `weinstein-faithful-core.md` + `experiment-flag-discipline.md`
  for the new dial, matching the `enable_macro_gate` style.
- Default-off on both new fields; no production `Weinstein_strategy` / core
  module change; no default flipped on.

## Out of scope

- K sweep, any backtest runs, PIT-S&P-500 510-symbol runs, comparison to the
  Cell-E production engine (maintainer's separate local experiment).
- Changes to the production `Weinstein_strategy` or any core module.
- Wiring any default on / ledger ACCEPT.
