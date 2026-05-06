# All-eligible fixed-dollar trade-grading diagnostic (issue #870)

## Context

Issue #870 calls for a diagnostic tool that — for every Stage-2 entry signal
that fires across a backtest period — allocates a fixed dollar amount per
signal, bypasses every portfolio-level rejection, and tracks each position
independently to its natural exit.

Why now:
- #871 15y diagnostic showed cascade is at no-look-ahead ceiling; capital
  recycling is the leverage gap.
- #856 grid sweep showed `max_position_pct_long` alone can't hit acceptance
  gates. Suspected mechanisms: `Insufficient_cash` skips + stop-distance gates.

The diagnostic separates **signal quality** from **portfolio mechanism**:

| Tool                          | Measures                                                 |
|-------------------------------|----------------------------------------------------------|
| `optimal-strategy`            | Counterfactual "perfect picking" within universe scope   |
| `all-eligible` (this PR)      | Raw signal alpha — what would each Stage-2 signal return |
| `actual` (live backtest)      | Strategy + portfolio mechanism interaction               |

Combining all three:
- High signal alpha + many portfolio rejections → portfolio surface needs loosening
- Low signal alpha + few rejections → screener cascade needs tightening
- High alpha + few rejections + low actual return → optimal-strategy picking gap

## Approach

The `optimal-strategy` track already has the two pure functions needed:

1. `Stage_transition_scanner.scan_panel` — per-Friday Stage-2 breakout
   enumeration. Drops cascade gates (top-N, grade, macro), keeps the
   per-candidate breakout predicate + price helpers. Macro pass is recorded
   on each candidate, not gated.
2. `Outcome_scorer.score` — forward-walks the panel applying the trailing
   stop walker + Stage-3 detector. Returns the realised exit week / price /
   R-multiple per candidate.

The all-eligible diagnostic is the same pipeline minus the greedy filler.
Instead of resolving sizing / cash / sector caps, every scored candidate
becomes one trade record sized at `entry_dollars / entry_price` shares.

**Key design decisions:**

- **Reuse, don't duplicate.** The lib lives at
  `trading/trading/backtest/all_eligible/lib/all_eligible.{ml,mli}` and depends
  on `backtest_optimal` for `Optimal_types`, `Stage_transition_scanner`, and
  `Outcome_scorer`. No new pure functions for entry/exit logic — same
  byte-for-byte semantics as the optimal-strategy track.
- **Pure function entry point.** `grade` takes the already-scored candidates
  (the caller is responsible for scanning + scoring) and produces the trade
  records + aggregate. This keeps the lib portable: the same surface can be
  driven from a CLI binary (PR-2) or from in-process tests with hand-built
  scored candidates (this PR's tests).
- **Allocate fixed dollars per signal.** Default `entry_dollars = 10_000.0`
  (configurable). Shares = `entry_dollars / entry_price` as float (no
  rounding — these are diagnostic positions, not real fills).
- **No portfolio interaction.** Every signal is taken regardless of cash,
  exposure, sector concentration, or any other portfolio-level limit. Each
  position evolves independently.
- **PR-1 scope: lib + tests only.** ≤ 500 LOC. CLI exe + integration with a
  real run's artefacts is PR-2.

## Files to change

New:

- `trading/trading/backtest/all_eligible/lib/dune` — library declaration.
- `trading/trading/backtest/all_eligible/lib/all_eligible.mli` — public
  surface: `config`, `trade_record`, `aggregate`, `result`, `default_config`,
  `grade`. Aggregate metric helpers exposed for unit testing.
- `trading/trading/backtest/all_eligible/lib/all_eligible.ml` —
  implementation. Pure function. Walks scored candidates, projects each into
  a `trade_record`, computes aggregate.
- `trading/trading/backtest/all_eligible/test/dune` — test runner.
- `trading/trading/backtest/all_eligible/test/test_all_eligible.ml` —
  OUnit2 + Matchers tests covering the three required cases plus edge cases.

No modifications to existing modules.

## Public surface (sketch)

```ocaml
type config = {
  entry_dollars : float;
  return_buckets : float list;
}

type trade_record = {
  signal_date : Core.Date.t;
  symbol : string;
  side : Trading_base.Types.position_side;
  entry_price : float;
  exit_date : Core.Date.t;
  exit_reason : Optimal_types.exit_trigger;
  return_pct : float;
  hold_days : int;
  entry_dollars : float;
  shares : float;
  pnl_dollars : float;
  cascade_score : int;
  passes_macro : bool;
}

type aggregate = {
  trade_count : int;
  winners : int;
  losers : int;
  win_rate_pct : float;
  mean_return_pct : float;
  median_return_pct : float;
  total_pnl_dollars : float;
  return_buckets : (float * float * int) list;
}

type result = {
  trades : trade_record list;
  aggregate : aggregate;
}

val default_config : config
val grade :
  config:config ->
  scored:Optimal_types.scored_candidate list ->
  result
```

## Risks / unknowns

- **Hold days vs hold weeks.** `Optimal_types.scored_candidate.hold_weeks` is
  in weeks; the issue calls for `hold_days`. Convert via
  `Date.diff exit_date signal_date` directly — preserves day granularity.
- **Return buckets.** Issue says "return distribution histogram". I'll use
  fixed default boundaries: `[-0.5; -0.2; 0.0; 0.2; 0.5; 1.0]` yielding seven
  buckets. Configurable via `config.return_buckets`.
- **CSV / Markdown emit.** Out of scope for PR-1 — the lib returns records,
  PR-2 (CLI exe) handles I/O.

## Acceptance criteria

- `grade` returns `trade_count = scored.length` (every signal taken — no gates).
- Per-trade `pnl_dollars = (exit_price - entry_price) * shares` for longs,
  reflected for shorts.
- Aggregate `total_pnl_dollars = sum(per-trade pnl_dollars)` (alpha additive).
- `win_rate_pct = winners / trade_count`, where winner = `return_pct > 0`.
- Tests: synthetic 3-signal scenario (all 3 taken); per-trade exit-reason +
  return matches hand-calc; aggregate matches sum.
- `dune build && dune runtest` green; `dune build @fmt` clean.
- Linters (function length, magic numbers, mli coverage) all pass.

## Out of scope

- CLI exe wrapper (PR-2).
- Reading a real run's `summary.sexp` / `actual.sexp` (PR-2 — uses
  `Optimal_run_artefacts.load`).
- Snapshot construction + per-Friday scan loop (PR-2 — reuses
  `Optimal_strategy_runner._build_world` / `_scan_and_score`).
- Output emission to disk (`csv`, `summary.md`) — PR-2.
- Distributional metrics (Sharpe, Sortino, etc.) — separate M5.2c/d track.

## Reference

- Issue: https://github.com/dayfine/trading/issues/870
- Optimal-strategy track: `trading/trading/backtest/optimal/lib/`
- 15y diagnostic: `dev/notes/15y-sp500-zero-trades-diagnosis-2026-05-03.md`
