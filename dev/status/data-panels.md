# Status: data-panels

## Last updated: 2026-04-25

## Status
IN_PROGRESS — Stage 0 spike MERGED as #555 (2026-04-25). Stages 1-5 blocked on human green-light per plan §Decision point.

## Interface stable
N/A — pre-implementation

## Goal

Refactor the backtester's in-memory data shape from per-symbol scalar
(Hashtbl of `Daily_price.t list`) to columnar (Bigarray panels of
shape N × T per OHLCV field, plus per-indicator panels of the same
shape). Collapses the entire `bar_loader/` tier system, the post-#519
Friday cycle, the parallel `Bar_history` structure, and the +95%
Tiered RSS gap — all structurally rather than incrementally. Unblocks
the tier-4 release-gate scenarios (5000 stocks × 10 years, ≤8 GB).

The strategy interface ALREADY has `get_indicator_fn` (per
`strategy_interface.mli:23-24`); panel reads back it with
`Bigarray.Array2.unsafe_get`. No new API surface.

## Plan

`dev/plans/columnar-data-shape-2026-04-25.md` (PR #554) — five-stage
phasing, Bigarray storage backend, parity-gate per stage, decisions
ratified inline.

Supersedes `dev/plans/incremental-summary-state-2026-04-25.md`
(SUPERSEDED, kept as historical record). Reusable pieces (functor
signature, parity-test functor, indicator porting order, Bar_history
reader audit) carry forward.

## Open work

- **PR #554** merged 2026-04-25 (plan ratified).
- **PR #555** (Stage 0 spike) merged 2026-04-25. Implements `Symbol_index`, `Ohlcv_panels`, `Ema_kernel`, `Panel_snapshot` under `trading/trading/data_panel/`. 20 tests pass; EMA parity bit-identical at N=100 T=252 P=50; snapshot round-trip bit-identical. QC structural + behavioral both APPROVED.

### Stage 1 pre-flags (from QC behavioral, non-blocking)

To address before / during Stage 1:
1. `Ohlcv_panels.load_from_csv` is not calendar-aware — must resolve before Stage 4 (weekly cadence) but Stage 1 can specify the contract.
2. `Panel_snapshot` dump-twice byte-equality is not tested — needed for reproducible golden fixtures; add the test in Stage 1.
3. Unrounded EMA values will flow into `stage.ml` once Stage 4 wires the kernel — add a boundary golden-parity check (current `Ema.calculate_ema` rounds output to 2 decimals via TA-Lib FFI; downstream callers (`stage.ml` slope/above-MA, `above_30w_ema`) appear insensitive but verify before Stage 4).

### RSS / memory gate

RSS gate (≤50% of scalar at N=300 T=6y on bull-crash goldens) is NOT measured at Stage 0 by design — that's a follow-up sweep run once Stages 1+ wire panels into the runner.

### Awaiting human

Per plan §Decision point: "if parity gate fails (FP drift > 1 ULP and end-to-end PV moves) or RSS gain < 30% or snapshot round-trip is lossy, abort the migration and revisit." Parity gate held bit-identical; snapshot round-trip is bit-exact; RSS gate deferred to post-Stage-1. **Recommendation: green-light Stage 1.**

## Five-stage phasing (from the plan)

| Stage | Owner | Scope | Branch | LOC |
|---|---|---|---|---|
| 0 | feat-backtest | Spike: `Symbol_index`, OHLCV panels, EMA kernel, parity test, snapshot serialization — **MERGED #555** | `feat/panels-stage00-spike` | ~700 (incl. tests) |
| 1 | feat-backtest | Panel-backed `get_indicator` for EMA/SMA/ATR/RSI; Bar_history kept alive | `feat/panels-stage01-get-indicator` | ~500 |
| 2 | feat-backtest | Replace 6 Bar_history reader sites with panel views; delete Bar_history | `feat/panels-stage02-no-bar-history` | ~400 |
| 3 | feat-backtest | Collapse Bar_loader tier system + Friday cycle | `feat/panels-stage03-tier-collapse` | ~400 |
| 4 | feat-backtest | Weekly cadence panels + remaining indicators (Stage, Volume, Resistance, RS) | `feat/panels-stage04-weekly` | ~300 |
| 5 | feat-backtest | Live-mode universe-rebalance handling (deferred until live mode lands) | `feat/panels-stage05-live` | ~150 |

Total: ~2200 LOC across 6 PRs over ~10 working days. Stage-by-stage
parity gate against existing scalar implementation. Each stage
mergeable independently (Stage 1 alone gives the indicator
abstraction; Stage 2 alone gives the memory win).

## Stage 0 gate criteria (decision point)

If Stage 0 spike fails any of these, abort migration and revisit:

- Byte-identical EMA values OR ≤ 1 ULP drift compounded over 1y with
  end-to-end PV unchanged
- RSS < 50% of current scalar implementation at N=300 T=6y on
  bull-crash goldens (target gain ≥ 30%)
- Snapshot serialization round-trip: bit-identical values, load wall
  < 100 ms at N=1000 T=3y

### Stage 0 result (2026-04-25, branch `feat/panels-stage00-spike`)

- **EMA parity: PASSED — bit-identical (max_ulp=0, max_abs=0.0)** at
  N=100 symbols × T=252 days × period=50 against a scalar reference
  using the same expression form (warmup = left-to-right `+.`
  accumulation; recurrence = bind `new_v` and `prev` to locals before
  the multiply-add).
  - Surprise observation: an earlier reference variant that inlined
    `data.(t)` and `out.(t-1)` directly into the multiply-add drifted
    by 1–6 ULP over compounded 1y. The OCaml compiler schedules
    instructions differently when reads aren't bound to named locals,
    and IEEE 754 multiplication isn't associative. **For Stage 1+
    indicator ports, ensure the kernel and any reference comparator
    use identical expression form** — specifically, named locals for
    each panel read before the arithmetic. Documented inline in
    `ema_kernel_test.ml` and the kernel's `.mli`.
- **Snapshot round-trip: PASSED — bit-identical** on single-panel
  (3×5 Float64) and multi-panel (2×4, three panels including NaN +
  inf cells) cases. Format is `[int64-LE header_len][sexp header][page-aligned float64 panels]`;
  load uses `Caml_unix.map_file` so it is mmap-backed and effectively
  O(milliseconds). Wall-clock measurement at N=1000 T=3y is deferred
  to Stage 1+ alongside the RSS sweep.
- **RSS gate: NOT measured at Stage 0**. The dispatch explicitly
  scoped this out — RSS measurement against the bull-crash N=300 T=6y
  goldens needs the perf-sweep harness wired in, which only happens
  when Stages 1+ start consuming panels in the runner. That sweep is
  the post-merge follow-up.
- **Verify**: `cd trading/trading && dune build data_panel/ &&
  for t in symbol_index ohlcv_panels ema_kernel panel_snapshot; do
  ../_build/default/trading/data_panel/test/${t}_test.exe; done`
  (20 tests, all OK).

## Memory targets (from plan §Memory expectations)

| Scale | Today (extrapolated) | Columnar projected |
|---|---:|---:|
| N=292 T=6y bull-crash | L 1.87 / T 3.74 GB | < 800 MB |
| N=1000 T=3y | L 1.83 / T 3.83 GB | < 1.0 GB |
| N=5000 T=10y (release-gate tier 4) | 12-22 GB | ~1.2 GB |

## Ownership

`feat-backtest` agent. All five stages owned by the same agent for
continuity (the indicator porting in stage 4 touches `weinstein/*`
modules but the work is panel-shaped, not strategy logic).

## Branch convention

`feat/panels-stage<NN>-<short-name>`, one per stage. Stages 1+ stack
on each prior stage's branch tip (per orchestrator fresh-stack rule)
since each stage needs the prior stage's types but not its merge.

## Blocked on

- Stage 0 must complete + parity-gate pass before any subsequent
  stage starts. No stages start until human reviews the spike result.

## Blocks

- `backtest-perf` tier-4 release-gate scenarios are blocked on
  Stage 3 (tier collapse) at minimum, ideally Stage 4 (weekly
  cadence). Until then the 5000×10y scenario doesn't fit in 8 GB.

## Decision items (need human or QC sign-off)

All ratified 2026-04-25; see plan §Decisions. None outstanding
pre-Stage 0.

Post-Stage 0 spike result will produce the next decision point: did
parity hold within tolerance, did RSS gain hit the gate, did
snapshot round-trip work? Stages 1+ proceed only on green.

## References

- Plan: `dev/plans/columnar-data-shape-2026-04-25.md` (PR #554)
- Superseded plan: `dev/plans/incremental-summary-state-2026-04-25.md`
  (PR #551 merged; kept as historical record)
- Sibling: `dev/status/backtest-perf.md` — tier 4 release-gate
  scenarios blocked here
- Predecessor: `dev/status/backtest-scale.md` (READY_FOR_REVIEW) —
  bull-crash hypothesis-test sequence that motivated this redesign
- Strategy interface (already exposes `get_indicator_fn`):
  `trading/trading/strategy/lib/strategy_interface.mli:23-24`
- Bar_history reader audit:
  `dev/notes/bar-history-readers-2026-04-24.md` (6 sites)
- Perf findings that motivated this: `dev/notes/bull-crash-sweep-2026-04-25.md`,
  `dev/notes/perf-sweep-2026-04-25.md`
