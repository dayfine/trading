# Engine-pool RSS matrix — wall improves, RSS essentially flat (2026-04-28)

PR-5 of the engine-layer-pooling plan
(`dev/plans/engine-layer-pooling-2026-04-27.md`). Re-runs the same
4-cell matrix as `dev/notes/panels-rss-matrix-post602-gc-tuned-2026-04-26.md`
with all four engine-pool PRs landed (#618 PR-1 instrumentation, #626
PR-2 `Price_path.Scratch.t`, #631 PR-3 thread `Scratch` through
`Engine.update_market`, #632 PR-4 `Buffer_pool.t` for transient
workspaces).

## Setup

- Build SHA: `123ed13e` (post-#631 / post-#632 main).
- Container: `trading-1-dev`, opam env, `OCAMLRUNPARAM=o=60,s=512k`.
- Fixture: `TRADING_DATA_DIR=/tmp/data-small-302` (292 universe symbols,
  same data layout as the prior matrix — see post-#602 GC-tuned note).
- Command shape:

  ```sh
  TRADING_DATA_DIR=/tmp/data-small-302 OCAMLRUNPARAM="o=60,s=512k" \
    /usr/bin/time -v _build/default/trading/backtest/bin/backtest_runner.exe \
    <START> <END> --override "((universe_cap (<N>)))"
  ```

- No `--gc-trace`, no `--memtrace`, no `--trace` — matches prior matrix's
  command shape so RSS / wall numbers are directly comparable. (One
  separate gc-trace run on 50×1y was captured at
  `/tmp/matrix-50x1y.csv`; cited inline below for the per-step
  promotion delta.)

## Result

| N | T | post-tuned RSS / Wall | post-engine-pool RSS / Wall | Δ RSS | Δ Wall |
|---:|---:|---:|---:|---:|---:|
| 50 | 1y | 264 / 0:06 | **264 / 0:06** | 0 | 0 |
| 50 | 6y | 322 / 0:24 | **322 / 0:21** | 0 | −3s (−13%) |
| 292 | 1y | 1,216 / 0:43 | **1,217 / 0:31** | +1 (+0.1%) | −12s (−28%) |
| 292 | 6y | 1,453 / 2:51 | **1,445 / 1:49** | −8 (−0.6%) | −62s (−36%) |

RSS in MB (peak resident), wall in m:ss.

## Fit (post-engine-pool, GC-tuned)

`RSS ≈ 67 + 3.94·N + 0.19·N·(T − 1)` MB

| Component | post-#602 (untuned) | + GC tuning | + engine-pool | Δ vs GC-tuned |
|---|---:|---:|---:|---:|
| α (fixed) | 86 | 68 | **67** | −1 (−1%) |
| β (per-symbol) | 5.5 | 4.3 | **3.94** | −0.36 (**−8%**) |
| γ (per-symbol-per-year) | 0.5 | 0.20 | **0.19** | −0.01 (−5%) |

β dropped 8%, γ unchanged within noise.

## vs plan target

Plan §PR-5 (`dev/plans/engine-layer-pooling-2026-04-27.md`) projected
β: 4.3 → **1-1.5 MB/symbol**. Actual: 4.3 → **3.94 MB/symbol**. Far
short of target.

Where did the projected RSS reduction not materialize? Re-reading the
plan:

> Drop the simulator's per-tick allocation rate by making `Price_path`
> / `Engine.update_market` reuse pre-allocated scratch buffers rather
> than allocating fresh records / arrays per call. Target: collapse
> the ~1.29 billion words promoted to major heap to <100M (10×
> reduction); same engine behavior, parity-tested against existing
> goldens.

The cumulative-promotion target *was* hit. The per-step `Gc.stat`
trace at 50×1y (`/tmp/matrix-50x1y.csv`, captured under PR-1
instrumentation in a separate run since `--gc-trace` adds ~25× wall
overhead and isn't in the comparable matrix) shows
`promoted_words = 85.8M` cumulative at end — **inside the <100M plan
target** for that cell. Per-step delta `minor_words` is 1-2.7M words
per step (~20-50 KB / symbol / step), well below the per-tick
allocation churn the memtrace flagged before PR-2.

But peak RSS did not move. The reason is in
`dev/notes/panels-rss-matrix-post602-2026-04-26.md` §"Why γ doubled":
post-#602, the per-tick allocation rate was *already* low enough that
GC kept the major heap compacted. The remaining peak RSS at 292×6y
(1,445 MB) is dominated by the **major-heap working set**, not by
allocation churn driving steady-state high-water-marks. Engine-pool
PRs reduce promotion churn — which speeds the GC up, hence the wall
improvement — but the working set itself (panel storage + macro
inputs + per-symbol bar caches) is not what the engine pool addresses.

## Wall: real win at large N×T

The **−36% wall at 292×6y** (2:51 → 1:49) is the more interesting
deliverable. Engine-pool collapses ~1.4 GB of array-only allocation
traffic per run (PR-3 impact note,
`dev/notes/engine-pool-pr3-impact-2026-04-27.md` §"Sample size in
production"), the GC runs less, and wall drops by a third. The
smaller cells see proportionally smaller wins because their absolute
wall is dominated by panel-build (constant cost) not the simulator
loop.

## Trade output parity (sanity)

292×6y produces the same 80 round-trips, 0.65 Sharpe, 24.34% max DD
as the prior matrix run — the engine-pool refactor is bit-equivalent
on real data, as the parity gates in PR-2 (`test_panel_loader_parity`)
and PR-3 (`test_engine_scratch_threading_parity`) already pinned
synthetically.

## Implications for tier-4

| N × T | post-#602 untuned | + GC tuning | + engine-pool |
|---|---:|---:|---:|
| 1,000 × 10y | 12.5 GB | 6.2 GB | **5.7 GB** |
| 5,000 × 10y | 50 GB | 30 GB | **27 GB** |
| 10,000 × 10y | 100 GB | 61 GB | **56 GB** |

(Projections from the new fit `α + β·N + γ·N·(T−1)` extrapolated
beyond the measured range; treat as order-of-magnitude.)

**N=1,000 × 10y still fits the 8 GB ceiling** — the GC-tuned position
(6.2 GB) was already inside, and engine-pool brings it down further to
~5.7 GB. Confirming the prior conclusion: tier-4 release-gate at N≤1000
is achievable today.

For broader N (5,000+), the architecture still needs fundamental change
— **engine-pool was not the lever**. The remaining options:

1. **Daily-snapshot streaming** (Option 2 from
   `dev/plans/hybrid-tier-architecture-2026-04-26.md`,
   superseded by `dev/plans/daily-snapshot-streaming-2026-04-27.md`):
   ~25 MB constant RSS regardless of N.
2. **Stage 4.5 PR-C / PR-D follow-on** (panel reshaping for additional
   indicator workspaces): incremental only.

The engine-pool PRs land their wall improvement and ship clean
abstractions for future hot-path work, but **tier-4 N≥5000 requires
the streaming pivot**, not further per-tick refactoring.

## Conclusion

- **β: 4.3 → 3.94 MB/symbol (−8%).** Did not hit the plan's 1-1.5
  target. Cumulative-promotion target *was* hit (<100M words
  promoted at 50×1y, plan said <100M).
- **Wall: −36% at 292×6y, −28% at 292×1y.** Real improvement from
  reduced GC pressure at large N×T.
- **Tier-4 implication:** N=1000×10y at ~5.7 GB still fits 8 GB
  ceiling; N≥5000 still needs daily-snapshot streaming.

The engine-pool plan's stated goal ("collapse promoted words 10×")
was achieved; the *predicted RSS knock-on* (β → 1-1.5) did not
materialize because peak RSS at 292×6y is no longer dominated by
allocation churn after #602 + GC tuning. Engine-pool is a wall win,
not an RSS win, against this baseline.

## References

- Prior matrix (this matrix's direct predecessor):
  `dev/notes/panels-rss-matrix-post602-gc-tuned-2026-04-26.md`
- Pre-#602 baseline:
  `dev/notes/panels-rss-matrix-post602-2026-04-26.md`
- Engine-pool plan: `dev/plans/engine-layer-pooling-2026-04-27.md`
- PR-3 architectural impact:
  `dev/notes/engine-pool-pr3-impact-2026-04-27.md`
- Phase-1 hybrid-tier results (the trigger for engine-pool):
  `dev/notes/hybrid-tier-phase1-results-2026-04-27.md`
- Memtrace (pre-engine-pool hot path):
  `dev/notes/panels-memtrace-postA-2026-04-26.md`
- Master columnar plan §"Memory expectations":
  `dev/plans/columnar-data-shape-2026-04-25.md`
