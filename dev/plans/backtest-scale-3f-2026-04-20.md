# Plan: backtest-scale-3f — Tiered runner path + shadow screener (2026-04-20)

Track: [backtest-scale](../status/backtest-scale.md)
Branch: `feat/backtest-scale-3f`
Parent plan: `dev/plans/backtest-tiered-loader-2026-04-19.md` §3f

## Context

3a–3e landed on main. 3e (#459) added the `Loader_strategy.Legacy | Tiered`
flag to `Backtest.Runner.run_backtest` but the `Tiered` branch currently
raises `Failure`. This increment implements the actual Tiered execution
path behind that flag.

## Approach

Split 3f into two logical commits under one PR:

### Commit 1 — Shadow screener adapter (`shadow_screener.ml{,i}`)

Pure, testable module that synthesizes `Stock_analysis.t` stubs from
`Bar_loader.Summary.t` values and feeds them to the existing
`Screener.screen`. The adapter approach is preferred over changing
`Screener.screen`'s signature (plan §Open questions, decision: adapter).

**Synthesis rules** (documented on the .mli so the divergence with the
Legacy path is explicit):
- `Stage.result` — reconstructed from `Summary.stage` and `Summary.ma_30w`.
  `ma_direction` / `ma_slope_pct` use a conservative proxy (Rising when
  stage is Stage2; Declining when Stage4; Flat otherwise). Prior stage
  tracked in a caller-supplied `(string, stage) Hashtbl.t` — same mechanism
  as `_screen_universe` in `weinstein_strategy.ml`.
- `Rs.result` — synthesized from `Summary.rs_line` (Mansfield-normalized).
  Trend classified by comparing `rs_line` to the threshold 1.0: > 1.0 →
  `Positive_rising`; < 1.0 → `Negative_declining`. `Positive_flat` /
  `Negative_improving` / crossovers are unreachable without an RS history
  series (captured as a known divergence).
- `Volume.result` — always `None`. The Summary tier does not retain
  breakout-volume information.
- `Resistance.result` — always `None`.
- `breakout_price` — `None`. Screener's `_build_candidate` falls back to
  `ma_value * (1 + breakout_fallback_pct)`.

**Expected divergence from Legacy** — documented in the .mli:
- Missing volume signal → every candidate scores ~20-30 points lower (no
  Strong/Adequate volume contribution). This means `min_grade = C` becomes
  the functional floor for most candidates.
- Missing resistance signal → no Virgin/Clean bonus.
- RS trend can never produce `Bullish_crossover` / `Bearish_crossover` →
  no A+ crossover bonus.
- `prior_stage` tracking is caller-managed; if the caller forgets to pass
  in a prior-stage table, every candidate looks like a non-transition.

The parity test in 3g is the ultimate gate; if the divergence is too wide
on the smoke scenario, the parity test will fail and we iterate.

**Public surface:**

```ocaml
val screen :
  loader:Bar_loader.t ->
  config:Screener.config ->
  macro_trend:Weinstein_types.market_trend ->
  sector_map:(string, Screener.sector_context) Core.Hashtbl.t ->
  universe:string list ->
  prior_stages:(string, Weinstein_types.stage) Core.Hashtbl.t ->
  held_tickers:string list ->
  as_of:Core.Date.t ->
  Screener.result
```

`universe` is the subset of symbols currently at Summary+ tier. Symbols
below Summary are silently skipped — the caller is responsible for having
promoted them via `Bar_loader.promote`.

Prior-stage table is mutated in place (matches `_screen_universe`'s
contract).

### Commit 2 — `_run_tiered_backtest` in runner.ml

Tiered runner path. Orchestrates:

1. Build `Bar_loader` with the full universe + sector map.
2. Promote every universe symbol to Metadata up front (inside `Load_bars`
   phase).
3. Create the simulator with **only** the "always full" symbols — the
   primary index + sector ETFs + global indices. These get full OHLCV
   because the strategy's macro / sector analysis needs them. The universe
   symbols do NOT get bars in the simulator's Price_cache until they are
   promoted to Full tier by the tiered path.
4. Build a custom strategy module inline (bypasses `Weinstein_strategy.make`'s
   `_on_market_close`). On each daily call:
   - Run `Stops_runner.update` for held positions (reuses
     `Weinstein_strategy.Stops_runner`).
   - On Fridays only: promote universe to Summary, compute macro + sector
     map via existing helpers, run shadow_screener, promote candidate
     tickers to Full, and emit `entries_from_candidates` transitions.
   - On position-open (CreateEntering) emit a Bar_loader.promote call to
     Full for the candidate.
   - On position-close (Closed state transitions visible in next step's
     portfolio) demote back to Metadata.
5. Trace hooks wire through Bar_loader — Summary/Full/Demote phases.

**Scope boundary**: this increment wires Tiered but does NOT flip the
default. The parity test in 3g is the merge gate.

**Line budget ceiling**: If commit 2 balloons past ~300 lines, defer the
position-open/close promotion logic to a follow-up and land a simpler
version that just runs the Legacy simulator with Bar_loader running
alongside as an observability instrument (still promotes to Metadata on
boot, to Summary on Fridays — tracks memory/timing for the A/B harness
in 3h). This is still useful — the shadow screener is tested in isolation,
and the `Tiered` flag starts emitting trace phases for the scale/A/B team.

## Out of scope

- 3g parity acceptance test — separate PR.
- Flipping default to Tiered — separate PR.
- Modifying `Bar_history`, `Weinstein_strategy` internals, `Simulator`,
  `Price_cache`, `Screener.screen` signature (plan §Out of scope).
- Perfect parity with Legacy — known divergences on volume/resistance/RS
  crossover signals documented in shadow_screener.mli. 3g will tell us
  whether the divergence is small enough for the flag ramp.

## Risks

- **Shadow screener synthesis loses signal.** The three missing signals
  (volume, resistance, RS crossover) lower candidate scores and may
  change the top-N ranking. 3g will catch this if the diff exceeds the
  agreed parity ε.
- **Simulator's Price_cache not fed by Bar_loader.** In this increment
  the simulator still owns its own Price_cache for the "always full"
  symbols (index, sector ETFs, global indices). Universe-symbol bars
  live only in Bar_loader's Full-tier storage. If the strategy's
  `get_price` path is called for a universe symbol, the simulator will
  try to load via its own Price_cache and miss. Mitigation: drive the
  Tiered path through a custom strategy wrapper that routes
  universe-symbol `get_price` calls through Bar_loader's Full-tier bars
  when available, and returns `None` otherwise.
- **CSV-per-promote cost.** Each Summary promote on Friday reads 250-day
  tails from CSV for every universe symbol. With 10k symbols that's 10k
  CSV reads per Friday, once per week for the backtest horizon. 3d
  trace phases will expose whether this is the bottleneck; if so,
  incremental indicators (parent plan §Out of scope) become a real
  follow-up.

## Verify

Per commit:

```
dev/lib/run-in-env.sh dune build
dev/lib/run-in-env.sh dune runtest trading/backtest
```

Session end:

```
dev/lib/run-in-env.sh dune build && dev/lib/run-in-env.sh dune runtest
```
