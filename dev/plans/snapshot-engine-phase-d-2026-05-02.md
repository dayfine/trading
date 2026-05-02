# Plan: snapshot streaming Phase D — engine + simulator integration (2026-05-02)

## Status

PROPOSED. Re-attempt of the Phase D dispatch from earlier today (the
prior attempt STOP-AND-REPORTED because Phase A schema lacked OHLCV
columns; Phase A.1 #786 fixed that). Plan budget: ~400 LOC; cap ~600.

Parent plan: `dev/plans/daily-snapshot-streaming-2026-04-27.md` §Phasing
Phase D ("Replace `Bar_panels.t` references in `simulator.ml` /
`panel_runner.ml` with `Daily_panels.t`. Engine's per-tick price reads
via `Daily_panels.read_today`; `Stops_runner` via `read_history`.").

## Context

Phase A landed the snapshot schema + file format (#779). Phase A.1
extended the schema with OHLCV columns (#786) so the simulator's
per-tick reads can pull raw OHLCV out of snapshots without re-introducing
a parallel bar-shaped data path. Phase B landed the offline pipeline
that writes per-symbol `.snap` files (#781). Phase C landed the runtime
layer with `Daily_panels.t` (lazy LRU cache) and `Snapshot_callbacks.t`
(thin field-accessor shim) (#782).

Phase D wires Phase C's runtime into the simulator's hot path so that
backtests can read OHLCV from snapshots instead of CSV files.

## What Phase D actually wires (vs. what the parent plan said literally)

The parent plan's literal statement — "Replace `Bar_panels.t`
references in `simulator.ml` / `panel_runner.ml` with `Daily_panels.t`"
— is **not implementable as a literal swap**, for two reasons:

1. **The simulator does not directly use `Bar_panels.t`.** It reads
   prices via `Trading_simulation_data.Market_data_adapter`. The
   `Bar_panels.t` reference in `panel_runner.ml` is consumed by the
   inner Weinstein strategy (`Weinstein_strategy.make ~bar_panels`),
   not the simulator itself.

2. **`Daily_panels.t` cannot replace `Bar_panels.t` at the strategy
   level under Phase D's budget.** `Bar_panels.t` exposes a much richer
   API (weekly_view_for, daily_view_for, low_window, weekly_bars_for)
   that the strategy uses for stage classification, RS analysis, ATR,
   support-floor stops, etc. Replacing those reads with `Daily_panels`
   reads would require either (a) precomputing all weekly aggregates
   into the snapshot schema (multi-PR effort), or (b) building a
   bar-shaped reconstruction layer over snapshots (defeats the
   architecture). Phase F retires `Bar_panels.t` only after parity
   plays out across the whole strategy — not Phase D.

What Phase D **can** do under budget: wire `Daily_panels.t` into the
**simulator's per-tick OHLCV reads** (the Engine's `update_market`
input, MtM portfolio_value, split detection, benchmark return). The
strategy's bar reads keep going through `Bar_panels.t` until Phase F.
This delivers the stated benefit ("Engine's per-tick price reads via
`Daily_panels.read_today`") and unblocks Phase E (validation +
tier-4 spike at N=10K), where the simulator's CSV-side residency is
the dominant component once the strategy's panels are also off-CSV.

## Approach: feature-flagged dispatch in the backtest runner

**Default mode (no flag):** existing CSV path through
`Market_data_adapter.create ~data_dir`. Bit-equal to pre-PR behaviour.

**Snapshot mode (`--snapshot-mode --snapshot-dir <path>`):** the
backtest runner loads the manifest from `<path>/manifest.sexp`, builds
a `Daily_panels.t`, and constructs an alternate `Market_data_adapter`
backed by closures that read OHLCV from snapshots via
`Snapshot_callbacks.t`. The simulator's hot path is unchanged — it
still calls `Market_data_adapter.get_price` etc.

This pattern gives parity by construction: only the `get_price` source
changes; every other simulator code path runs identically.

### Module shape

```
trading.simulation.data.market_data_adapter
  + create_with_callbacks  (* alternate constructor *)

trading.backtest.lib.bar_data_source            (* NEW *)
  type t = Csv | Snapshot of { snapshot_dir : string;
                                manifest : Snapshot_manifest.t }
  val make_adapter : t -> data_dir:Fpath.t -> Market_data_adapter.t

trading.backtest.lib.snapshot_bar_source        (* NEW *)
  val make_callbacks :
    panels:Daily_panels.t ->
    snapshot_to_daily_price callbacks bundle

trading.backtest.lib.panel_runner
  + ?bar_data_source:Bar_data_source.t = Csv

trading.backtest.lib.runner
  + ?bar_data_source:Bar_data_source.t = Csv

trading.backtest.runner_args
  + snapshot_dir : string option

trading.backtest.bin.backtest_runner
  + --snapshot-mode --snapshot-dir <path> wiring
```

### Why this respects A1 + A2

- **A1 (CORE module modification):** `Market_data_adapter` is in
  `trading.simulation.data`, NOT in the canonical CORE list
  (`portfolio`, `orders`, `position`, `strategy`, `engine`). Adding an
  alternate constructor is a generalization of an existing data-source
  abstraction; existing callers of `create` are unaffected. No CORE A1
  fields.
- **A2 (no analysis/ imports into trading/trading/ outside backtest
  exception surface):** `weinstein.snapshot_runtime` is in
  `analysis/weinstein/`. The Phase D wiring imports it ONLY in
  `trading/trading/backtest/lib/{bar_data_source,snapshot_bar_source}.ml`
  — well within the established backtest exception surface.
  `Market_data_adapter`'s callback-mode does NOT import `weinstein.*`;
  it only takes plain closures. The closures are constructed in
  `snapshot_bar_source.ml` (in backtest/), which is allowed.

## Files to touch (LOC budget)

| File | LOC | Kind |
|---|---:|---|
| `dev/plans/snapshot-engine-phase-d-2026-05-02.md` | ~120 | NEW (this plan) |
| `trading/trading/simulation/lib/data/market_data_adapter.{ml,mli}` | +50 | MODIFIED (add `create_with_callbacks`) |
| `trading/trading/backtest/lib/bar_data_source.{ml,mli}` | ~80 | NEW |
| `trading/trading/backtest/lib/snapshot_bar_source.{ml,mli}` | ~120 | NEW |
| `trading/trading/backtest/lib/panel_runner.{ml,mli}` | +25 | MODIFIED (thread `?bar_data_source`) |
| `trading/trading/backtest/lib/runner.{ml,mli}` | +20 | MODIFIED (thread `?bar_data_source`) |
| `trading/trading/backtest/runner_args/backtest_runner_args.{ml,mli}` | +30 | MODIFIED (add `snapshot_dir` field + flag parsing) |
| `trading/trading/backtest/bin/backtest_runner.ml` | +40 | MODIFIED (manifest load + bar_data_source build + thread to runner) |
| `trading/trading/backtest/test/test_snapshot_mode_parity.ml` | ~150 | NEW (parity test) |
| `trading/trading/backtest/lib/dune` | +2 | MODIFIED (add deps) |

Total: ~520 LOC (incl. plan); cushion above 400 plan + below 600 cap.

## Acceptance criteria

1. Default mode (no `--snapshot-mode`): existing tests + `panel-golden`
   parity still bit-equal (no behaviour shift).
2. `--snapshot-mode --snapshot-dir <path>`: simulator reads OHLCV via
   `Daily_panels.read_today` + `Snapshot_callbacks.read_field`.
3. Parity test (small fixture: 3 symbols × ~60 days): trade lists +
   final PV byte-identical between modes.
4. `dune build && dune runtest` clean.
5. `dune build @fmt` clean.
6. PR diff < 600 LOC.
7. Pre-existing baselines still pass unchanged.

## Risks

- **R1 — float precision.** Snapshots write `Daily_price.volume` as
  `float` (cast `int → float` per Phase A.1 schema). The CSV path
  stores volume as `int` and casts at consumption. Should be exact for
  any realistic equity volume (counts up to ~2^53). Mitigation: parity
  test asserts equality.
- **R2 — `volume : int` vs `float`.** `Daily_price.t.volume` is `int`.
  The snapshot reader has to round-trip via float. We use
  `Float.to_int` (truncation) on the read side; for clean integer
  volumes this is exact. If a future schema stores fractional volume,
  this assumption breaks loudly via parity divergence.
- **R3 — `get_indicator` in callback mode.** The simulator never calls
  `get_indicator` through the adapter under panel_runner (the strategy
  goes through `Get_indicator_adapter` over `Indicator_panels`). In
  callback mode we return `None` for `get_indicator`. Verified by
  inspection of `panel_strategy_wrapper.ml`.
- **R4 — `finalize_period` in callback mode.** The simulator does not
  call `finalize_period`. In callback mode it is a no-op. Verified by
  grep on `simulator.ml`.
- **R5 — snapshot directory bootstrap.** `--snapshot-mode` requires a
  pre-built snapshot directory. We accept `--snapshot-dir <path>`; the
  runner reads `<path>/manifest.sexp` at startup. Build-first
  requirement is documented in the CLI help text.

## Out of scope (for this PR)

- **Strategy-side `Bar_panels` retirement** — Phase F.
- **Stops_runner via `read_history`** — the strategy's stop machinery
  reads through `Bar_panels` callbacks; rewiring those to
  `Snapshot_callbacks.read_field_history` is a Phase F job alongside
  the broader bar-source retirement.
- **Multi-symbol snapshot per-tick parity at scale** — Phase E
  validation (S&P 500 5y golden + tier-4 spike at N=10K).
- **`bin/build_snapshots.exe` runs as part of the CLI** — out of
  scope; user runs `build_snapshots.exe` separately.

## References

- Parent plan: `dev/plans/daily-snapshot-streaming-2026-04-27.md`
- Phase A.1 (precursor): PR #786
- Phase B (offline pipeline): PR #781
- Phase C (runtime layer): PR #782
- A2 enforcement: `.claude/rules/qc-structural-authority.md` §A2
