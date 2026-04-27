# Plan: Stage 4.5 PR-B — sector pre-filter as third early-exit gate (2026-04-26)

## Status

IMPLEMENTING. Companion to
`dev/plans/panels-stage045-lazy-tier-cascade-2026-04-26.md` §"PR-B".
Branch: `feat/panels-stage045-pr-b-sector-prefilter`. Builds on PR-A (#599)
which split `_screen_universe` into Phase 1 (cheap stage classify) +
Phase 2 (full Stock_analysis on survivors).

## Wedge (recap)

PR-A landed the two-phase cascade but the post-PR-A RSS matrix
(`dev/notes/panels-rss-matrix-postA-2026-04-26.md`) showed `β` unchanged
at ~5.12 MB/symbol. Memtrace
(`dev/notes/panels-memtrace-postA-2026-04-26.md`) located the wedge in
simulation/engine, not strategy. **PR-B's expected RSS impact at the
small-302 scale is therefore minimal**; main value is cleaner laziness
(the cascade is more honest about what it skips), not memory. RSS gains
should compound at larger universes / weaker macro regimes where Stage 4
+ Strong-sector stocks are abundant.

## Cascade after PR-B

```
1. Stage classify (cheap, all N).
2. Stage filter (drop Stage 1 / Stage 3) — PR-A.
3. Sector pre-filter (drop Stage2-in-Weak / Stage4-in-Strong) — PR-B.
4. Full Stock_analysis for symbols that survive both — PR-A.
```

The `sector_map` is already computed in `_run_screen` before
`_screen_universe`; PR-B threads it into the cascade rather than letting
the screener-internal sector check do the rejection downstream.

## Filter predicate

Mirrors the screener exactly. Reading
`trading/analysis/weinstein/screener/lib/screener.ml`:

- `_long_candidate` (line 320): `if equal_sector_rating sector.rating
  Weak then None` — drops Weak sectors.
- `_short_candidate` (line 341): `if equal_sector_rating sector.rating
  Strong then None` — drops Strong sectors.

So the side-aware predicate is:

```ocaml
match (stage_result.stage, sector_ctx.rating) with
| Stage2 _, Weak -> false   (* would-be long candidate; drop *)
| Stage4 _, Strong -> false (* would-be short candidate; drop *)
| _ -> true
```

A ticker absent from `sector_map` defaults to PASS, matching
`Screener._resolve_sector` which falls through to a `Neutral` context for
unknown tickers.

The dispatch's "Strong/Neutral pass; Weak drop" rule is asymmetric
(applies to longs only) and would accidentally drop Stage4 shorts that
the screener would accept. The side-aware version above is correct.

## Pragmatic deviations from dispatch

1. **Survivors-list shape**, not `(loaded, stage_pass, sector_pass)`
   triple. The dispatch suggested changing `survivors_for_screening`'s
   return type to a counts triple. I instead added a public
   `?sector_map` argument: when omitted, returns Phase-1-only survivors
   (preserves the PR-A test contract); when supplied, also applies the
   sector pre-filter. The PR-B counter test invokes
   `survivors_for_screening` twice on the same fixture (once without
   `sector_map` → `stage_pass`, once with → `sector_pass`) and computes
   `loaded` from `cfg.universe`. This avoids breaking PR-A's existing
   tests and keeps the production call site (`_screen_universe`) using
   the value directly.

2. **No `Macro` early-exit in this PR.** Dispatch explicitly said skip;
   confirmed.

## Files

- `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml` —
  - New `_survives_sector_filter ~sector_map (ticker, view, sr)` private
    helper.
  - `survivors_for_screening` gains optional `?sector_map` and trailing
    `()`.
  - `_screen_universe` threads the sector_map through the cascade
    (chained `|>` style; preserves the `(ticker, view, prior, sr)`
    four-tuple shape so `prior_stage` stays threaded into Phase 2).
- `trading/trading/weinstein/strategy/lib/weinstein_strategy.mli` —
  signature change on `survivors_for_screening`.
- `trading/trading/weinstein/strategy/test/test_weinstein_strategy.ml` —
  4 new tests:
  - PR-B sector filter drops Weak-sector longs.
  - PR-B sector filter drops Strong-sector shorts.
  - PR-B sector filter: ticker absent from sector_map passes.
  - PR-B counter test: `(loaded, stage_pass, sector_pass) = (6, 6, 3)`
    on a six-symbol fixture; surviving tickers match the expected set.
- 3 existing PR-A tests updated for the new `unit` trailing argument.

## Parity gates

- `test_panel_loader_parity` round_trips golden — bit-equal trades
  (load-bearing). The two scenarios under
  `test_data/backtest_scenarios/smoke/{tiered-loader-parity,panel-golden-2019-full}.sexp`
  both pass — sector pre-filter only drops symbols the screener would
  have rejected anyway, so trade output is bit-identical.
- All `weinstein/strategy/test` suites: 22 tests, all OK (was 18 pre-PR-B).
- `test_weinstein_backtest`, `test_macro_inputs`, `test_stops_runner`,
  `test_panel_callbacks`, `test_weekly_ma_cache` — green.
- File length linter: `weinstein_strategy.ml` exactly 500 lines (at the
  declared-large hard limit). PR-B added the sector predicate +
  cascade-extension but trimmed PR-A's docstrings to compensate; the
  filter logic is captured in the .mli's `survivors_for_screening` doc.
- Magic number, nesting, `dune fmt`, `dune build @fmt` linters all
  silent.

## LOC

~+30 production (sector predicate + cascade pipe), ~+170 tests (4 new
tests + helper for building synthetic sector_maps). Net minor change to
`_screen_universe`.

## Risk

### Parity drift on the round_trips golden

The sector pre-filter could in principle drop a symbol the screener
would have accepted via some non-obvious code path. Mitigation: the
filter mirrors `Screener._long_candidate` / `_short_candidate`'s sector
gate exactly (those are the only screener call sites that read
`sector.rating`). The round_trips golden test catches any divergence —
it's bit-equal post-PR-B.

### Production sector_map behaviour vs tests

The production cascade always passes the real `sector_map` (which may be
empty when `sector_etfs = []` is configured). Empty `sector_map` → all
tickers default to PASS, equivalent to PR-A behaviour. This matches the
behaviour of the two parity-test scenarios (which provide their own
sector maps).

## Recommendation

Skip the post-PR-B matrix re-run. PR-A's matrix already pinned that the
wedge is in simulation/engine (`dev/notes/panels-memtrace-postA-2026-04-26.md`).
PR-B's expected impact at small-302 is minimal; the value is correctness
of the lazy cascade. Pick up the simulation/engine wedge as the next
dispatch (the memtrace document already names the call sites).
