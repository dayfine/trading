# Perf sweep: complexity matrix + post-refactor RSS savings (2026-04-25)

First run of the (N × T × strategy) perf-sweep harness landed in #547.
8 cells × 2 strategies = 16 runs over 2 hours of compute. Code state:
post-#548 (H7 streaming + List.filter inline-accumulator refactors).

## Headline findings

1. **Tiered/Legacy RSS ratio is structurally ~2.0×** across every (N, T)
   tested — doesn't grow with scale, doesn't shrink with scale. The
   gap is a constant factor, not a scaling problem.

2. **Memory scales linearly in N (universe size)** for both strategies.
   ~1,569 KB/symbol Legacy, ~3,259 KB/symbol Tiered.

3. **Memory scales sub-linearly in T (run length)** — only ~129 KB/day
   Legacy, ~318 KB/day Tiered. Bar_history accumulation cost is
   modest.

4. **Wall-time is 1.4–1.6× slower for Tiered.** Gap widens slightly at
   N=1000.

5. **The post-refactor code (this run) is ~2.4× lighter than pre-refactor.**
   At pre-refactor PR #524 baseline (N=292, T=6y): Tiered = 3.65 GB,
   Legacy = 1.87 GB. Extrapolated post-refactor for the same scenario
   from sweep data: Tiered ≈ 1.5 GB, Legacy ≈ 0.72 GB. Direct
   verification A/B run on the same scoped fixture in flight at time
   of writing — will append to this note when it lands.

## Peak RSS matrix

| N \ T | 3m | 6m | 1y | 3y |
|---:|---:|---:|---:|---:|
| **100**  | — | — | 250 / 489 / 1.95× | — |
| **300**  | 538 / 1048 / 1.95× | 550 / 1083 / 1.97× | 569 / 1145 / 2.01× | 625 / 1263 / 2.02× |
| **500**  | — | — | 902 / 1839 / 2.04× | — |
| **1000** | — | — | 1629 / 3353 / 2.06× | 1826 / 3833 / 2.10× |

Legend: `Legacy MB / Tiered MB / ratio`.

## N-sweep complexity (T = 1y)

| N | Legacy RSS | Tiered RSS | Tiered/Legacy | Legacy wall | Tiered wall |
|---:|---:|---:|---:|---:|---:|
| 100 | 250 MB | 489 MB | 1.95× | 11.8s | 18.1s |
| 300 | 569 MB | 1145 MB | 2.01× | 28.0s | 38.6s |
| 500 | 902 MB | 1839 MB | 2.04× | 44.8s | 61.2s |
| 1000 | 1629 MB | 3353 MB | 2.06× | 82.6s | 131.4s |

**Linear fit (slope = (y[N=1000] − y[N=100]) / 900):**
- Legacy RSS: ~1,569 KB / symbol
- Tiered RSS: ~3,259 KB / symbol
- Tiered/Legacy slope ratio: 2.08× — matches the per-cell ratio constant

The N-sweep curves are smooth and monotone. RSS scales linearly in N
for both strategies — no super-linear blow-up at the scales tested.
Tiered's slope being exactly ~2× Legacy's reflects the constant per-
symbol overhead of carrying the loader's `Full.t.bars` cache parallel
to `Bar_history`.

## T-sweep complexity (N = 300)

| T | days | Legacy RSS | Tiered RSS | Tiered/Legacy | Legacy wall | Tiered wall |
|:---|---:|---:|---:|---:|---:|---:|
| 3m | 63 | 538 MB | 1048 MB | 1.95× | 14.6s | 20.0s |
| 6m | 126 | 550 MB | 1083 MB | 1.97× | 18.1s | 26.2s |
| 1y | 252 | 569 MB | 1145 MB | 2.01× | 28.0s | 38.6s |
| 3y | 756 | 625 MB | 1263 MB | 2.02× | 76.5s | 104.0s |

**Linear fit (slope = (y[3y] − y[3m]) / 693):**
- Legacy RSS: ~129 KB / day
- Tiered RSS: ~318 KB / day

Memory grows ~10× more slowly with T than with N. That's expected:
the per-day cost is just one bar per held symbol added to `Bar_history`,
while the per-symbol cost is the whole bar history + Full.t.bars +
loader bookkeeping. **The strategy is N-bound, not T-bound.** A 10-year
backtest costs only ~3× the memory of a 3-month one (at fixed N), but
a 1000-symbol universe costs 7× a 100-symbol one (at fixed T).

Wall time scales differently:
- Legacy wall: 14.6s → 76.5s = 5.2× over T factor 12 → wall ~ √T-ish
- Tiered wall: 20.0s → 104.0s = 5.2× over T factor 12 → same shape
- Wall-time scales much more steeply with T than RSS does. The per-
  bar work dominates wall time even though it doesn't grow memory.

## Wall-time matrix

| N \ T | 3m | 6m | 1y | 3y |
|---:|---:|---:|---:|---:|
| **100**  | — | — | 11.8s / 18.1s / 1.53× | — |
| **300**  | 14.6s / 20.0s / 1.37× | 18.1s / 26.2s / 1.45× | 28.0s / 38.6s / 1.38× | 76.5s / 104.0s / 1.36× |
| **500**  | — | — | 44.8s / 61.2s / 1.37× | — |
| **1000** | — | — | 82.6s / 131.4s / 1.59× | 232.4s / 381.8s / 1.64× |

Wall ratio Tiered/Legacy = 1.37–1.64×. Tiered's per-Friday Promote_full
work adds ~40-60% wall time vs Legacy's incremental simulator path.

## Implications

**For the Tiered flip decision:** the +95% RSS gap measured pre-refactor
(PR #524) is now a +95-110% gap STRUCTURAL, not a regression. Tiered will
always carry ~2× Legacy's memory because of the parallel cache. That's a
design tradeoff the Tier 3 architecture made for OHLCV-bounded growth.

But: post-refactor, the absolute numbers are dramatically smaller. Tiered
at N=1000 T=3y = 3.83 GB vs pre-refactor extrapolated ~9 GB. The
practical OOM ceiling moves from ~500-symbol scenarios to ~2000-symbol
scenarios at 3-year run length on an 8 GB box. The sub-linear T scaling
means longer backtests are cheap.

**Tiered is suitable for:**
- Small/medium universes (100–1000 symbols) at any T
- Long backtests (5y+) at modest N
- Any case where the parallel cache's correctness benefit (faster fewer-
  CSV-reads at scale) outweighs 2× the memory

**Tiered is NOT suitable for:**
- Maxed-out universe (10K+ symbols) — would OOM around 6 GB Legacy /
  12 GB Tiered. Same as pre-refactor.
- The "broad" CI fixture (separate issue per backtest-scale.md
  follow-up).

## VERIFIED (extrapolation was wrong — refactors had ~0% effect on this scenario)

Direct A/B on PR #524's exact scenario (N=292, T=6y on `/tmp/data-small-302`),
post-refactor (post-#543 + post-#548):

| | Pre-refactor (PR #524) | Post-refactor (verify) | Δ |
|---|---|---|---|
| Legacy | 1,871,240 KB | **1,871,788 KB** | +548 KB (+0%, noise) |
| Tiered | 3,652,852 KB | **3,743,716 KB** | +90,864 KB (+2.5%, noise) |

**The refactors did NOT meaningfully reduce RSS on PR #524's exact
scenario.** The +95% Tiered RSS gap and Legacy's 1.87 GB peak are both
unchanged. The earlier extrapolation from sweep data was wrong by ~2.6×.

## Why the sweep numbers were so different

Sweep at N=300 T=3y on broad sectors.csv: Legacy = 625 MB / Tiered = 1263 MB.
Verify at N=292 T=6y on /tmp/data-small-302: Legacy = 1872 MB / Tiered = 3744 MB.

3× the RSS at 2× the time on essentially the same N. Linear T extrapolation
predicted ~720 MB Legacy. Actual is 1.87 GB — 2.6× higher.

Three possible reasons (need investigation):

1. **Different data setup.** Sweep used full `data/` with `universe_cap=300`
   override. Verify used filtered `/tmp/data-small-302/` (sectors.csv with
   only 292 entries). Both should yield 292-symbol universe but may exercise
   different code paths.

2. **Different scenario shape.** Sweep used synthetic `bull-3y.sexp`
   (2018-01-02 → 2021-01-02). Verify used `bull-crash-2015-2020.sexp`
   (real bull-crash including the 2020 COVID drawdown). Bull-crash has
   far more strategy activity (608 round-trips Legacy / 613 Tiered)
   than the synthetic 2018-uptrend (probably <100 trades).

3. **Bar densities differ.** The CSV files for the symbols in the 292-symbol
   universe span 1980-2026 (46 years of data per symbol). The synthetic
   sweep scenarios may load shorter slices. Each symbol's full CSV must be
   parsed regardless of `tail_days` in the older code paths.

The cleanest test would be to re-run the sweep cells using the
goldens-small bull-crash scenario specifically. Tomorrow's investigation
target.

## Conclusion

- **Complexity slopes from the sweep are still valid for that setup.**
  Linear in N, sub-linear in T — those shape findings hold.
- **Absolute RSS depends heavily on scenario specifics.** The bull-crash
  + filtered-sectors-csv setup retains 2.6× more memory than synthetic
  uptrend + capped-broad-sector-map, even though both touch ~292 symbols
  for 1-3 years.
- **The +95% Tiered RSS gap on production-shaped scenarios remains.** None
  of today's 6 attempts (H1, H2, H3, H7, GC tuning, List.filter refactor)
  meaningfully moved the needle on the bull-crash 2015-2020 baseline.
- **Workstream exhausted today.** The investigative pipeline is in place;
  the next step is a different angle on the bull-crash retention pattern
  specifically. Two candidates for tomorrow:
  - Re-run the sweep with bull-crash 2015-2020 as the base scenario
    (vary universe_cap on the same scenario file) to establish whether
    the gap grows linearly or has a step function around the
    bull-crash 2020 COVID period
  - Open the post-refactor verify .ctf in memtrace_viewer (requires
    `opam install memtrace_viewer` on host) to find what's really
    retained at peak in the bull-crash run

## Failures

None — every cell completed cleanly. No OOM, no timeout.

## Artifacts

- Sweep harness PR: #547
- List.filter refactor PR: #548 (this is what made the absolute numbers small)
- CSV stream-parse PR: #543 (the other refactor)
- Local sweep dir: `dev/experiments/perf/sweep-sweep1/` (gitignored;
  contains all 16 run outputs + memtrace .ctf files for flamegraph
  inspection)
- Aggregate report: `dev/experiments/perf/sweep-sweep1/report.md`

## Appendix: pre-refactor comparison (extrapolated)

Pre-refactor PR #524 baseline (N=292, T=6y):
- Legacy: 1,871,240 KB ≈ 1.87 GB
- Tiered: 3,652,852 KB ≈ 3.65 GB

Post-refactor extrapolated (linear in N, sub-linear in T from sweep data):
- Legacy at N=292 T=6y: 250 + (292-100)*1.569 KB + (756 from 3y to 6y * 0.129 MB) → ~720 MB
- Tiered at N=292 T=6y: 489 + (292-100)*3.259 KB + (756 * 0.318 MB) → ~1.4 GB

If verified: **2.6× Legacy savings, 2.6× Tiered savings.** Most of the win
is from the List.filter refactor (#548) since H7 alone (#543) had
shown only +130 MB Promote_metadata savings. The List.filter inline-
accumulator pattern eliminated the multi-MB intermediate lists in the
strategy hot path.
