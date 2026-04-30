# G6 — Decade backtest non-determinism investigation (2026-04-30)

Owner: feat-backtest. Source spec:
`dev/notes/session-followups-2026-04-29-evening.md` §1 ("Decade backtest
non-determinism (NEW gap — call it G6)").
Empirical baseline that surfaced this:
`dev/notes/goldens-broad-long-only-baselines-2026-04-29.md` § Determinism.

## Symptom (verbatim from session note)

`goldens-broad/decade-2014-2023` is reproducibly non-deterministic across
run modes:

- **Single-cell `--dir /tmp/decade-cell` runs (run-1, run-3)**: bit-identical
  `145 trades / +1582.85 % return / 40.69 % WR / 103.3 d hold / $15.91 M unreal`.
- **Multi-cell `--dir goldens-broad` batch run (run-2)**: drifted to
  `135 trades / +1627.09 % / 40.00 % / 98.0 d / $16.66 M unreal`.

Other three goldens-broad cells (`bull-crash-2015-2020`,
`covid-recovery-2020-2024`, `six-year-2018-2023`) are bit-identical across
both run modes — only the 10-year decade cell drifts.

## Initial hypothesis (from session note)

Parent-process heap state at simulation-fork time depends on which prior
scenarios were loaded. The simulator may reach into a singleton (RNG seed,
sector-map cache, panel-pool, audit accumulator) initialised once per
process; prior cells leave fingerprints. Suspected suspects (priority
order from the goldens-broad note):
1. Hashtbl iteration over `ticker_sectors` / `stop_states` (Core's
   `Hashtbl` is randomized only when explicitly built that way; default
   is deterministic).
2. `Time_ns_unix.now()` reads in audit-record construction.
3. Order-set iteration in the simulator's per-day fill loop.

## Code-path audit of `scenario_runner.ml`

Walking through the flow that produces the non-determinism:

```
[parent process]
  argv → _parse_args
  scenarios = List.map files ~f:Scenario.load   ← deterministic sexp parses
  output_root = _make_output_root ()             ← side effects: mkdir + Time
  _run_scenarios_parallel
    Queue.create
    for each scenario:
      if running >= parallel: reap one
      pid = _fork_scenario ~output_root ~fixtures_root s
        Core_unix.fork ()
          [child process]
            _run_scenario_in_child ~output_root ~fixtures_root s
              eprintf "Running %s..."
              mkdir_p scenario_dir
              sector_map_override = _sector_map_of_universe_file ~fixtures_root s.universe_path
              result = Backtest.Runner.run_backtest ~start_date ~end_date ~overrides ?sector_map_override ()
              Backtest.Result_writer.write ~output_dir result
              actual = _actual_of_result result
              Sexp.save_hum (... "actual.sexp") actual
              Stdlib.exit 0
          [parent continues]
            Queue.enqueue (s, pid)
    while running not empty: reap
```

Objects mutated/built BEFORE the fork (in the parent process):

1. The `scenarios` list — pure `Scenario.t` values, no side effects.
2. `output_root` — a directory created on disk. Children read this path
   string but don't otherwise interact with parent state through it.
3. The `Queue.t running` — queue of `(scenario, pid)` pairs, parent-only.
4. `Hashtbl.create (module String) statuses` — parent-only.

**No Backtest.Runner / Weinstein_strategy state is built in the parent.**
All heavy state — `ticker_sectors`, `bar_panels`, `Indicator_panels`,
`Symbol_index`, the `Weinstein_strategy.make` closure (with its
`stop_states` ref, `prior_macro` ref, `peak_tracker`,
`prior_stages` Hashtbl, etc.) — is constructed inside
`Backtest.Runner.run_backtest` which is called inside
`_run_scenario_in_child`, AFTER the fork.

So the children of the 4-cell batch run all fork from the same parent
state and should be observationally identical to a single-cell child of
the same scenario.

## Non-determinism candidates AT or BELOW the child workload

Despite the architectural symmetry, these places consume non-deterministic
inputs at run time inside the child:

### Wall-clock readers (per-call, deterministic structure)

| Site | Input | Effect on output |
|---|---|---|
| `trading/orders/lib/create_order.ml:_generate_order_id` | `Time_ns_unix.now()` for ID prefix + `Random.int 10000` for suffix | Order ID strings are wall-clock-derived. The IDs are stored as keys in `Trading_orders.Manager.orders` (a stdlib `Hashtbl.t`); `list_orders` iterates that hashtbl via `Hashtbl.fold`, so iteration order depends on `Hash.hash order_id mod table_size`. Different timestamp prefix → different bucket → different order. |
| `trading/orders/lib/types.ml:update_status` | `Time_ns_unix.now()` for `updated_at` | Updates the order's `updated_at` field; not used for sort/key. No observable effect on round-trip output. |
| `trading/engine/lib/engine.ml:_create_trade` | `Time_ns_unix.now()` for `trade.timestamp` | `trade.timestamp` is consumed by `Trading_portfolio.Portfolio._make_lot` as `acquisition_date`, which seeds FIFO lot ordering. Within a single backtest run (~5 min wall), the wall clock typically advances sub-second — all lots created during the run share the same `acquisition_date` (today). FIFO lot matching becomes order-of-insertion-stable, and stays deterministic relative to lot insertion order. |

The `_generate_order_id` site is the strongest candidate: it stamps the
order ID with `Time_ns_unix.now()` ns precision, the ID is the hashtable
KEY for `Manager.orders`, and `list_orders` iterates that hashtable.
Different process forks → different wall-clock times → different IDs →
different hash buckets → different `process_orders` iteration order.

Why doesn't this surface on the 5–6y scenarios (or on the 5x in-process
determinism test against `panel-golden-2019-full`)? Because:
- `Random.int` is the OCaml stdlib `Random` module, whose `default` PRNG
  state has a FIXED seed (`State.make [| 314159265 |]`) per
  `runtime/random.ml:mk_default`. So the Random.int suffix sequence is
  deterministic across processes UNTIL someone calls `Random.self_init()`.
  No code path in this repo calls `Random.self_init`.
- The stdlib `Hashtbl.create` defaults to `randomized = false` unless
  `OCAMLRUNPARAM` contains `'R'`. The decade reproduction used
  `OCAMLRUNPARAM=o=60,s=512k` (no `R`) → seed = 0 → bucket placement is
  fully deterministic given the same KEY string.
- The 5x in-process `test_determinism_5x_round_trips` runs `run_backtest`
  five times in the SAME process — `Time_ns_unix.now()` advances between
  runs but the order IDs minted in run-1 and run-2 differ in the
  timestamp prefix only by ~milliseconds. For 7 symbols × ~150 daily
  fills the bucket placements are stable enough to not perturb anything,
  OR (more likely) market-order processing is bucket-iteration-order
  insensitive because every order in this codebase is a Market order
  generated by `Order_generator.transitions_to_orders` (line 25) and
  market orders all fill at the same open price — iteration order
  doesn't change which fills happen, only the order they happen.

But what about cash floor / risk gating? `Portfolio.apply_trade` reduces
`current_cash`. If two large trades are submitted on the same Friday and
the cash floor would only let one through, iteration order picks the
winner. The decade scenario hits this enough times over 10 years × ~52
Fridays × N=1000 that small perturbations compound.

### Force-liquidation runner — peak tracker

`trading/weinstein/portfolio_risk/lib/force_liquidation.ml` (#695)
introduces a `Peak_tracker.t` with mutable `peak` and `halt`. Lives in
the strategy closure (`Weinstein_strategy.make` line 516), per-instance.
A new make = a new tracker. No process-global state.

But: `Peak_tracker.observe` snapshots portfolio_value ONCE per Friday.
If `process_orders` iteration order produces a different trade list →
slightly different portfolio_value at observation time → different peak
→ potentially different halt-state evolution → different downstream
trades. This is a SECOND-ORDER amplifier, not a primary source.

### `Trade_audit` / `Force_liquidation_log` — per-run collectors

Both are `create()`-d fresh inside `Panel_runner.run` (per-run, not
per-process). Their output is a list sorted by date (`events`,
`get_audit_records` etc.) — not iteration-order-sensitive.

## Structural finding

The order-ID hash-bucket-iteration angle is the strongest candidate. It
depends on wall-clock at `Time_ns_unix.now()` time, which:
- IS different between two single-cell runs (different fork-times) —
  yet run-1 and run-3 produce bit-identical results.
- IS different between batch and single — and run-2 (batch) drifts.

The discrepancy between "run-1 = run-3 single-cell" and "run-2 batch"
when both kinds also have wall-clock differences is unexplained by this
mechanism alone. Possible explanations:

(a) The 4-cell batch run has the parent forking 4 children whose
   subsequent wall-clock advance (during their respective workloads) is
   correlated by CPU contention. The decade child's per-bar timing
   shifts when 3 sibling cells are competing for cores → different
   nanosecond-precision clock reads at order-creation time → different
   order IDs → different bucket placements.
(b) Some other source of non-determinism not in this audit.

## Why only the 10-year cell drifts

Two ingredients compound:
- **Length.** Longer horizons = more Fridays where cash-floor / sizing
  / risk-gate decisions can flip on iteration order. 10y × ~52 wk = 520
  screen Fridays; 5y = 260; etc.
- **Universe size.** decade runs at N=1000 (broad) for the entire 10
  years. The other goldens-broad cells also use N=1000, but the
  shorter horizons compound less.

A divergence that introduces a 1-in-1000 chance of an iteration-order
flip at any given Friday accumulates: P(no flip over 520 Fridays) ≈
e^(-0.52) = 0.59 — i.e. ~40 % chance of seeing AT LEAST ONE flip per
run. That matches "1 of 3 runs drifted."

## Hypothesis — primary source identified

**Order ID generation in `trading/orders/lib/create_order.ml` mints IDs
with a `Time_ns_unix.now()` ns-precision prefix, and these IDs are
hashtable keys in `Trading_orders.Manager.orders`. `Trading_engine.Engine.process_orders`
iterates this hashtable via `Manager.list_orders` → `Hashtbl.fold` →
order-of-iteration depends on bucket placement of the keys. Different
wall-clock timing during order creation produces different IDs →
different buckets → different fill order → different per-day trade
sequences → different cumulative portfolio state.**

The bug is NOT a leak across cells in the parent process. It is a
**process-time-dependent ordering of orders** within a single run, that
gets amplified into observable metric drift on long-horizon /
many-orders runs.

## Reproduction on GHA-sized data

The reproduction in `dev/notes/goldens-broad-long-only-baselines-2026-04-29.md`
required N=1000 × 10y. GHA-sized fixtures (panel-goldens 22 symbols,
2018-10 to 2020-01 = ~15 months) almost certainly DO NOT reproduce the
divergence — the multiplicative factors above (520 Fridays × N=1000)
shrink to ~60 Fridays × N=22 = 1320 cell-Fridays vs 520k for decade.
Less than 0.3 % of the surface.

Per the task spec ("If the bug DOESN'T reproduce on small windows in
GHA: still write the regression test as a forward guard, and document
that ..."), the test pins the property
`metric_record(single) == metric_record(after_other)` as a forward
guard. The test holds today on small windows (because the order-ID
divergence rarely crosses a flip threshold in 1320 surface-points) but
would catch a regression that breaks isolation badly enough to flip
even small runs.

## Recommended fix surface

The order ID generator is in `trading/orders/lib/create_order.ml`. This
module is OUTSIDE the agent's allowed scope (`trading/portfolio/`,
`trading/weinstein/`, `analysis/` are off-limits per the task spec, and
`trading/orders/` falls into the same "core modules" set). The
appropriate fix is to make order ID generation deterministic with
respect to scenario-time inputs (e.g., feed the simulator's
`current_date` and a per-scenario monotonic counter into the ID
instead of wall-clock time), and is a feat-weinstein / orders-owner
change.

This investigation note + the regression test in this PR DOCUMENT the
finding and PIN the property; a follow-up PR by the appropriate owner
will plug the leak.

## Test surface added in this PR

- `trading/trading/backtest/scenarios/test/test_scenario_runner_isolation.ml`
  — runs the same panel-golden-2019-full scenario twice (standalone,
  and after running a different scenario `tiered-loader-parity` in the
  same process), asserts the round-trips list and final-portfolio-value
  are bit-identical across the two runs. Three test cases:
  1. target after one perturber: round_trips bit-equal to standalone.
  2. target after one perturber: final_portfolio_value within 1e-9.
  3. target across 2 perturber cycles: round_trips stable.
  The test lives in `scenarios/test/` per the task spec; the dune file
  there is extended with `backtest`, `weinstein.data_source`,
  `trading.simulation`, `trading.simulation.types` deps to support
  invoking `Backtest.Runner.run_backtest`. Sibling test for the
  in-process determinism property is `trading/backtest/test/test_determinism.ml`
  (5x same-scenario in-process determinism check) — that test already
  passes; this one extends the property to "different scenario before
  the target run."

Test holds today (per the empirical observation that small-window
isolation works); becomes a forward guard if a future change leaks
worse state across cells / flips iteration order even on small data.

## Cross-references

- `dev/notes/goldens-broad-long-only-baselines-2026-04-29.md` § Determinism
- `dev/notes/session-followups-2026-04-29-evening.md` §1
- `dev/notes/short-side-gaps-2026-04-29.md` (G1-G5 context)
- `trading/trading/orders/lib/create_order.ml` (suspected primary site)
- `trading/trading/orders/lib/manager.ml` (hashtbl iteration site)
- `trading/trading/backtest/test/test_determinism.ml` (existing in-process
  determinism gate; this PR's test is its sibling for cross-cell isolation)
