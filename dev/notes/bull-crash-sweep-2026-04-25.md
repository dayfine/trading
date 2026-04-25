# Bull-crash sweep: data-source choice matters more than scenario shape (2026-04-25)

## Hypothesis (from `dev/notes/perf-sweep-2026-04-25.md` open question)

> The post-refactor verify A/B at N=292 T=6y on `/tmp/data-small-302`
> measured Tiered 3.74 GB / Legacy 1.87 GB. Synthetic 2018 sweep
> extrapolation predicted only ~720 MB / ~1.4 GB at the same N.
> 2.6× discrepancy. Hypothesis: bull-crash 2015-2020 specifically
> retains more memory than synthetic 2018 sweeps. Or: the
> /tmp/data-small-302 universe (curated liquid blue-chips with 40+
> years of CSVs) costs more per symbol than broad's first-N
> alphabetical mix (many short-history symbols).

## Setup

- Branch: `main` post-#548 (same code state as `dev/notes/perf-sweep-2026-04-25.md`).
- Tooling: ad-hoc bash loop wrapping `backtest_runner.exe` with
  `/usr/bin/time -f '%M'` per run.
- Data dir: `/workspaces/trading-1/data` (FULL broad sectors.csv,
  10K+ symbols, with `universe_cap` truncating to N).
- Scenario: `goldens-small/bull-crash-2015-2020.sexp` (T = 6 years).
- Override per cell: `((universe_cap (N)))` for N ∈ {100, 300, 1000}.
- 6 cells × 2 strategies = 6 runs. Sequential. ~30 min total.

## Result

### Bull-crash 6y on broad data/ (this run)

| N | Legacy | Tiered | Tiered/Legacy |
|---|---|---|---|
| 100 | 307 MB | 549 MB | 1.79× |
| 300 | 708 MB | 1306 MB | 1.84× |
| 1000 | 2109 MB | 3913 MB | 1.86× |

### Comparison: synthetic 2018 sweep (T = 1y) on broad data/

| N | Legacy | Tiered | Tiered/Legacy |
|---|---|---|---|
| 100 | 250 MB | 489 MB | 1.95× |
| 300 | 569 MB | 1145 MB | 2.01× |
| 1000 | 1629 MB | 3353 MB | 2.06× |

### Comparison: bull-crash 6y at N=292 on `/tmp/data-small-302`

| N | Legacy | Tiered | Tiered/Legacy |
|---|---|---|---|
| 292 | 1872 MB | 3744 MB | 2.00× |

## Hypothesis confirmed: data-source dominates

**Same scenario, same N, different data dir → 2.6× memory difference.**

- Bull-crash 6y N=300 on **broad data/**: Legacy 708 MB / Tiered 1306 MB
- Bull-crash 6y N=292 on **/tmp/data-small-302**: Legacy 1872 MB / Tiered 3744 MB
- Ratio: **2.64× Legacy, 2.87× Tiered**

The /tmp/data-small-302 universe (filtered to small.sexp's curated
~300 liquid US equities — AAPL, MSFT, JPM, etc., all going back to
the 1980s) costs ~3× more per symbol than broad's first-300
alphabetical mix.

Why? Likely the per-symbol bar density:
- AAPL CSV: 11,424 lines (1980-12-12 to 2026-04-10) — 670 KB on disk
- A "first 300 alphabetical" symbol from broad sectors.csv: many are
  small-cap or post-2020 IPOs with under 1500 lines / <100 KB CSVs

Each CSV's parsed `Daily_price.t` records add to the heap. Long-history
blue-chips amortize per-symbol fixed overhead but dominate per-symbol
variable overhead. With Tier 3 holding `Bar_history` + `Full.t.bars`
parallel for every universe symbol, the cost scales with the
historical depth of each chosen symbol.

## Within-broad-data linear scaling

Bull-crash on broad data/ alone:
- Legacy slope: (2109 − 307) / (1000 − 100) = **2.00 MB/symbol**
- Tiered slope: (3913 − 549) / (1000 − 100) = **3.74 MB/symbol**

vs synthetic 2018 sweep:
- Legacy: 1.57 MB/symbol
- Tiered: 3.26 MB/symbol

Bull-crash 6y costs ~30% more per symbol than synthetic 2018 1y on
the same broad data — explainable by the longer T (sub-linear T
scaling × 6) plus more position state (~600 round-trips vs few in
synthetic).

## Within-/tmp/data-small-302

We don't have a multi-N sweep on /tmp/data-small-302 (it's a fixed
292-symbol fixture). Single datapoint: 1872 MB Legacy / 3744 MB
Tiered. Per-symbol that's 6.4 MB Legacy / 12.8 MB Tiered.

vs broad data/ bull-crash slope (2.00 / 3.74 MB/symbol), the
small-302 universe costs **~3.2× more per symbol**. Direct
confirmation that the symbol mix drives the bulk of the variance.

## Implication for tier 4 release-gate scenarios

The release-gate scenarios in `dev/plans/perf-scenario-catalog-2026-04-25.md`
target N=5000, T=10y. Linear-extrapolating the bull-crash broad-data
slope (3.74 MB/symbol Tiered):

- 5000 stocks × broad-style symbol mix: ~3,740 MB Legacy / ~6,800 MB
  Tiered + scenario-specific extra. Likely fits in 8 GB.
- 5000 stocks × blue-chip symbol mix (long history per /tmp/data-small-302
  ratio): 3.2× the above = ~12 GB Legacy / ~22 GB Tiered. **Does NOT fit
  in 8 GB.**

So **WHICH 5000 stocks matters as much as the count.** If release-gate
scenarios are constructed to be production-realistic (all blue-chip,
all 25+ year histories), we'll need the incremental-indicators refactor
(`dev/status/incremental-indicators.md`) to fit. If release-gate is
satisfied with a representative sample weighted toward shorter-history
symbols, the current code might fit.

**Recommendation for tier 4:** include BOTH a blue-chip-heavy 5000-stock
scenario AND a representative-mix 5000-stock scenario. They're different
shapes of "production realistic" and the cost differential is huge.

## Hypothesis status update

| ID | Hypothesis | Status |
|---|---|---|
| H1 (Bar_history trim) | DISPROVED #531 |
| H2 (Full.t.bars cap) | DISPROVED #542 |
| H3 (skip_ad_breadth) | DISPROVED #539 |
| H7 (CSV stream-parse) | DISPROVED top, +130 MB Metadata only #544 |
| GC tuning | DISPROVED #546 |
| List.filter inline | DISPROVED on bull-crash, modest gains in synthetic 2018 #549 |
| **Data-source-dominates** | **CONFIRMED (this note)** |

## Implication for the +95% Tiered RSS gap framing

The "+95% Tiered RSS gap" measured in PR #524 was on the curated
blue-chip /tmp/data-small-302 universe — the most expensive symbol mix
we have. On a broad-data sample with the same scenario, the gap is
80-86% (still substantial, but less alarming).

The structural cause is the same (post-#519 promote-all-Friday +
parallel `Bar_history` and `Full.t.bars`). The absolute size depends
heavily on the symbol mix.

The incremental-indicators refactor (plan #551) addresses the
structural cause and will help BOTH symbol mixes proportionally.

## Artifacts

- Local-only: `dev/experiments/perf/bull-crash-sweep/` (gitignored)
  - 6 × `peak_rss_kb` files, 6 × log files
  - No memtrace .ctf this time (skipped to keep the sweep fast)
- This note: `dev/notes/bull-crash-sweep-2026-04-25.md`
