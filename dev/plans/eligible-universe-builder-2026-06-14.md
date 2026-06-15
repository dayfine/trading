# Eligibility-filter universe builder (live-universe track)

## Last updated: 2026-06-14

## Problem

The existing `Build_from_individuals` produces a universe by **dollar-volume
top-N rank** at an annual reconstitution date. For a *live* / current-dated
universe we want a different selection rule: **every** current common-stock-like
US listing that passes **absolute eligibility gates** — no size cap. The output
must be the same `Universe.Snapshot.t` on-disk shape the screener / scenario
runner already consume, so it drops straight into the backtest/live pipeline.

## Design

New sibling module `Build_eligible_universe` (lib) + a runner (bin). It reuses
the existing building blocks rather than duplicating them:

- `Composition_inputs.load_inventory` / `load_asset_type_lookup` / `load_sectors`
  — the same on-disk artifacts (`inventory.sexp`, `symbol_types.sexp`,
  `sectors.csv`).
- `Composition_bar_reader.read_bars` — per-symbol CSV bars.
- `Build_from_individuals.avg_dollar_volume_for_bars` /
  `latest_close_for_bars` — the *exact* trailing-window scoring + latest-close
  logic, exposed as pure helpers over a `bar list` so the eligibility builder
  reads each symbol's CSV once and shares the windowing. (Two new pure exports
  on the existing module; no behaviour change to `build`.)
- `Composition_policy.apply` — the junk / asset-type filters (REIT exclude,
  preferred exclude). Common + ADR + GDR survive.

### Pipeline (per date)

1. **Active filter** — inventory entries with
   `data_start_date <= date - trailing_window_days` and `data_end_date >= date`.
2. **Equity-like filter** — `load_equity_like_lookup` drops ETF / Mutual_fund /
   Fund / Bond / Index / Currency / Commodity; keeps Common / Preferred / ADR /
   GDR (`Eodhd.Asset_type.is_equity_like`).
3. **Eligibility gates** (all config fields, defaults = no-op keep-all):
   - `min_price` — latest close `< floor` ⇒ drop. Record default `0.0`; spec `5.0`.
   - `min_avg_dollar_volume` — trailing-30d avg(close×volume) `< floor` ⇒ drop.
     Record default `0.0`; spec `1_000_000.0`.
   - `min_window_bars` — reuse the existing `>= 30`-weeks history gate (the
     trailing-window-bar-count gate from `Build_from_individuals`). Default `30`.
4. **Composition policy** — `reit_policy = Exclude`, `exclude_preferred = true`
   (plus the always-on dual-class dedup). Drops Preferred + REIT; keeps Common +
   ADR + GDR.
5. **Emit** — equal weight `1.0 / K` for the `K` survivors. No top-N truncation.
   `method_ = Composition_from_individuals` (same consumer-facing shape);
   `size = K`; `aggregate_period_return = 0.0` (live build, forward window
   unknown — not the diagnostic the rank-builder computes).

### Eligibility config (experiment-flag-discipline R2)

Every gate is a config field. The record defaults reproduce a keep-all no-op
(`min_price = 0.0`, `min_avg_dollar_volume = 0.0`,
`reit_policy = Include`, `exclude_preferred = false`) so a caller passing
`default_config` is unaffected. The *live-universe spec* (a separate named
constructor `spec_config`) passes `min_price = 5.0`,
`min_avg_dollar_volume = 1_000_000.0`, `reit_policy = Exclude`,
`exclude_preferred = true`.

## Behavioral pins (fixture tests, no network)

- below `min_price` dropped; at/above kept (boundary).
- below `min_avg_dollar_volume` dropped; above kept.
- `< min_window_bars` dropped.
- preferred / REIT / ETF dropped; common-stock + ADR kept.
- no top-N truncation: K eligible inputs ⇒ exactly K entries.
- equal weight `1.0 / K`; total weight ≈ 1.0.

## Runner

`build_eligible_universe_runner` (bin) with single-dash Core flags:
`-inventory-path -csv-data-dir -date -min-price -min-adv -output-path`.
The dispatcher runs it later on freshly-fetched data; this PR is builder +
fixture-test only, no live fetch.

## Files

- `lib/build_eligible_universe.{ml,mli}` (new)
- `lib/build_from_individuals.{ml,mli}` (two pure-helper exports)
- `test/test_build_eligible_universe.ml` (new)
- `bin/build_eligible_universe_runner_lib.{ml,mli}` + `build_eligible_universe_runner.ml` (new)
- dune wiring in `lib/`, `bin/`, `test/`
- `dev/status/data-foundations.md`
