# short_min_price short-entry gate — 2026-06-12

## Context

Margin Phase 3 found shorts net-negative in 3 of 4 bear windows; the
2026-06-12 long-short margin research
(`dev/notes/long-short-margin-mechanics-2026-06-12.md`) established that
**sub-$17 shorts are uneconomic** (83–362% maintenance margin). The
2026-06-13 priorities doc (P1 "short-side hygiene") asks for a configurable
minimum-price gate on short entries so that economic floor becomes an
expressible experiment axis.

Per `.claude/rules/experiment-flag-discipline.md` this lands **default-off
as a no-op** (threshold `0.0` = no gating = current behaviour, all goldens
bit-equal), becomes a searchable axis the day it lands, and is NOT wired
into any default config.

Current code: short candidates join the entry candidate list at
`weinstein_strategy_screening.ml` ~line 399–404:

```ocaml
let combined_candidates =
  if config.enable_short_side then
    screen_result.Screener.buy_candidates
    @ screen_result.Screener.short_candidates
  else screen_result.Screener.buy_candidates
```

`Screener.scored_candidate` carries `suggested_entry : float` (the suggested
buy/sell-stop entry price) and `side : position_side`.

## Approach

1. **Config field** `short_min_price : float; [@sexp.default 0.0]` on
   `Weinstein_strategy.config` (`weinstein_strategy_config.{ml,mli}`),
   defaulted to `0.0` in `default_config`. `0.0` = no gating.

2. **Gate** — a pure helper
   `filter_short_candidates_by_min_price ~short_min_price candidates` in
   `weinstein_strategy_screening.ml`. When `short_min_price <= 0.0` it is the
   identity; otherwise it drops candidates whose `suggested_entry <
   short_min_price`. Applied to `screen_result.Screener.short_candidates`
   before concatenation. Purely additive: with `0.0` the candidate list is
   identical to today.

   The module has no `.mli`, so the helper is exported automatically and is
   unit-testable via `Weinstein_strategy.S.filter_short_candidates_by_min_price`.

3. **Unit tests** (`test_short_min_price_gate.ml`, new): synthetic
   `scored_candidate`s — (a) `0.0` → all retained (no-op); (b) `15.0` drops a
   $10 short, retains a $20 short; (c) the gate does not touch Long candidates
   (it only filters the short list).

4. **Axis test** (cheap — done): mirror `test_single_component_override_shape`
   in `test_variant_matrix.ml`, asserting `((short_min_price 0.0))` /
   `((short_min_price 17.0))` resolve as a top-level float axis through
   `Overlay_validator` (same path as `stage3_exit_margin_pct`).

## Files to change

- `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml` — add field + default.
- `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli` — add field + doc.
- `trading/trading/weinstein/strategy/lib/weinstein_strategy_screening.ml` — helper + wire at seam.
- `trading/trading/weinstein/strategy/test/test_short_min_price_gate.ml` — new test (+ dune names entry).
- `trading/trading/backtest/walk_forward/test/test_variant_matrix.ml` — add axis test.
- `dev/status/short-side-strategy.md` — status note.

## No-op-default argument

`short_min_price` defaults to `0.0`. The helper short-circuits to the identity
when `short_min_price <= 0.0`, so `combined_candidates` is byte-for-byte the
same list as before. No golden/baseline decodes differently (`[@sexp.default
0.0]` means existing sexps that omit the field decode to `0.0`), and no
emitted transition changes. `enable_short_side` default stays `true` —
untouched.

## Axis-ability note (R2)

`short_min_price` is a top-level `float` field with `[@sexp.default 0.0]`, so
`Variant_matrix` resolves it by sexp name with no `Overlay_validator` change
(identical mechanism to `stage3_exit_margin_pct`). Axis test added.

## Risks / unknowns

- Correct entry-price field: confirmed `suggested_entry` on
  `Screener.scored_candidate` (screener.mli line 214).
- Helper must be a no-op at `0.0` to preserve goldens — guarded by the
  `<= 0.0` short-circuit + a dedicated no-op test.

## Acceptance

- `dune build @fmt`, `dune build && dune runtest` exit 0.
- New unit tests pass; goldens unchanged (no-op at `0.0`).
- `short_min_price` resolves as a variant axis.

## Out of scope

- Building the margin model / touching the margin runner.
- Flipping `enable_short_side` (forbidden without a ledger ACCEPT).
- Wiring `short_min_price` into any default config or preset (stays default-off).
- Core stop-machine / simulator changes.
