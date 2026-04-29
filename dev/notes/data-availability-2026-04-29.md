# Data availability audit for long-horizon backtests (2026-04-29)

Feasibility audit for two prospective experiments: **N=5,000 × 10y** and
**N=1,000 × 30y**. Both depend on (a) deep date coverage at depth, (b)
universe size at depth, and (c) memory budget at scale. This note
documents what's in the local trading-1-dev data root, what's feasible
without infrastructure changes, and where the current ceilings sit.

## 1. Data root layout

Canonical path inside the container: `/workspaces/trading-1/data/`
(host: `<repo-root>/data/`).

Layout: `data/<first_char>/<last_char>/<SYMBOL>/{data.csv,data.metadata.sexp}`.

Examples:
- `AAPL` → `data/A/L/AAPL/data.csv`
- `MSFT` → `data/M/T/MSFT/data.csv`
- `GE`   → `data/G/E/GE/data.csv`
- `C`    → `data/C/C/C/data.csv`

`data.csv` columns: `date,open,high,low,close,adjusted_close,volume`.
`data.metadata.sexp` carries `data_start_date`, `data_end_date`,
`verification_status`, and a few quality flags.

Inventory:
- **37,877** symbol directories total.
- **All 37,877** carry `verification_status Verified`.
- End-date distribution: 36,227 ending in 2025 (mostly 2025-05-16 — the
  bulk fetch); 1,650 ending in 2026 (2026-04-10 / 2026-04-14 — recent
  refresh of large-caps + ETFs). Every symbol has data through ≥2025.
- Universe sexps:
  - `trading/test_data/backtest_scenarios/universes/sp500.sexp` — 491
    symbols (S&P 500 minus 12 recent additions / delistings without
    bar history; 2026-04-26 snapshot).
  - `trading/test_data/backtest_scenarios/universes/broad.sexp` —
    sentinel that resolves to `data/sectors.csv` (10,472 symbols), of
    which 6,921 have bar files.

## 2. Per-symbol coverage table (20 large-caps)

| Symbol | Start       | End         | Rows  | Years | Expected | Coverage |
|--------|-------------|-------------|-------|-------|----------|----------|
| AAPL   | 1980-12-12  | 2026-04-10  | 11423 | 45.3  | ~11416   | 1.001    |
| MSFT   | 1986-03-13  | 2026-04-10  | 10097 | 40.1  | ~10105   | 0.999    |
| GE     | 1962-01-02  | 2026-04-10  | 16176 | 64.3  | ~16204   | 0.998    |
| NVDA   | 1999-01-22  | 2026-04-10  | 6846  | 27.2  | ~6854    | 0.999    |
| JPM    | 1980-03-17  | 2026-04-10  | 11611 | 46.1  | ~11617   | 0.999    |
| JNJ    | 1962-01-02  | 2026-04-10  | 16176 | 64.3  | ~16204   | 0.998    |
| KO     | 1962-01-02  | 2026-04-10  | 16176 | 64.3  | ~16204   | 0.998    |
| XOM    | 1962-01-02  | 2026-04-10  | 16176 | 64.3  | ~16204   | 0.998    |
| HD     | 1981-09-22  | 2026-04-10  | 11228 | 44.6  | ~11239   | 0.999    |
| NKE    | 1980-12-02  | 2026-04-10  | 11431 | 45.4  | ~11441   | 0.999    |
| MCD    | 1966-07-05  | 2026-04-10  | 15041 | 59.8  | ~15070   | 0.998    |
| WMT    | 1972-08-25  | 2026-04-10  | 13517 | 53.6  | ~13507   | 1.001    |
| BA     | 1962-01-02  | 2026-04-10  | 16176 | 64.3  | ~16204   | 0.998    |
| CAT    | 1980-03-17  | 2026-04-10  | 11610 | 46.1  | ~11617   | 0.999    |
| IBM    | 1962-01-02  | 2026-04-10  | 16177 | 64.3  | ~16204   | 0.998    |
| PG     | 1962-01-02  | 2026-04-10  | 16176 | 64.3  | ~16204   | 0.998    |
| VZ     | 1983-11-21  | 2026-04-10  | 10679 | 42.4  | ~10685   | 0.999    |
| T      | 1983-11-21  | 2026-04-10  | 10679 | 42.4  | ~10685   | 0.999    |
| C      | 1977-01-03  | 2026-04-10  | 12420 | 49.3  | ~12424   | 1.000    |
| BAC    | 1973-02-21  | 2026-04-10  | 13397 | 53.1  | ~13381   | 1.001    |

Coverage = rows / (years × 252). All twenty fall in 0.998–1.001 — no
material missing-day issues at scale. Pre-1990 holders dominate; 16
of 20 have ≥30y, 20 of 20 have ≥10y.

## 3. Universe coverage at depth

Counts of symbols with `start_date ≤ cutoff` (i.e. enough history to
fully cover a backtest of that horizon ending today):

| Horizon         | Cutoff       | Whole inventory (37,877) | SP500 (491)     | Broad / sectors.csv (6,921 of 10,472) |
|-----------------|--------------|--------------------------|------------------|----------------------------------------|
| 30y             | 1996-01-01   | 2,853 (7.5%)             | 305 (62.1%)      | 1,171 (16.9%)                          |
| 25y             | 2001-01-01   | n/m                      | 350 (71.3%)      | 1,592 (23.0%)                          |
| 20y             | 2006-01-01   | 10,085 (26.6%)           | 387 (78.8%)      | 1,962 (28.3%)                          |
| 15y             | 2011-01-01   | n/m                      | 423 (86.2%)      | 2,581 (37.3%)                          |
| 10y             | 2016-01-01   | 21,627 (57.1%)           | 457 (93.1%)      | 3,355 (48.5%)                          |
| 5y              | 2021-01-01   | 28,869 (76.2%)           | 480 (97.8%)      | 4,639 (67.0%)                          |

(Broad denominator is the 6,921 sectors.csv symbols with bar files, not
the 10,472 listed.)

Implications for the two prospective experiments:

- **N=5,000 × 10y**: feasible from a data-supply perspective.
  21,627 symbols across the whole inventory have ≥10y — pick any 5,000.
  If the 5,000 must be sector-classified (sectors.csv), you have 3,355
  candidates with start ≤ 2016. To get 5,000 with 10y, you need to
  either (a) relax to a 9y window (start ≤ 2017, count probably ~4,000+),
  or (b) include unclassified symbols (then 5,000 is comfortable).
- **N=1,000 × 30y**: feasible from a data-supply perspective only on
  inventory-wide selection. SP500 has 305 symbols with 30y; broad
  sectors.csv has 1,171. Take 1,000 from broad-30y or whole-inventory.

## 4. Split-event spot check

Detected via `adjusted_close / close` ratio jumps ≥ 50 % between
consecutive bars (forward 2:1+ or reverse 1:2+). Output uses the raw
ratio shift `rel = ratio_t / ratio_{t-1}`; e.g. `rel ≈ 2.0` for a 2:1
forward split, `rel ≈ 0.125` for a 1:8 reverse split.

| Symbol | Splits | Sample dates                                     |
|--------|--------|--------------------------------------------------|
| AAPL   | 5      | 1987-06-16 (2:1), 2000-06-21 (2:1), 2005-02-28 (2:1), 2014-06-09 (7:1), 2020-08-31 (4:1) |
| MSFT   | 9      | 1987-09-21, 1990-04-16, 1991-06-27 (3:2), 1992-06-15 (3:2), 1994-05-23, 1996-12-09, 1998-02-23, 1999-03-29, 2003-02-18 |
| NVDA   | 6      | 2000-06-27, 2001-09-17, 2006-04-07, 2007-09-11 (3:2), 2021-07-20 (4:1), 2024-06-10 (10:1) |
| GE     | 7      | 1971-06-08, 1983-06-02, 1987-05-26, 1994-05-16, 1997-05-12, 2000-05-08 (3:1), 2021-08-02 (1:8 **reverse**) |
| WMT    | 10     | 1975 / 1980 / 1982 / 1983 / 1985 / 1987 / 1990 / 1993 / 1999 / 2024 (3:1) |
| KO     | 6      | 1977 / 1986 (3:1) / 1990 / 1992 / 1996 / 2012   |

Density: long-history symbols carry **5–10 splits over 30+ years**
(roughly one per 4–6 years). Reverse splits (e.g. GE 2021-08-02 1:8) are
rare but real and the broker model handles them today
(`trading/analysis/data/types/lib/split_detector.ml`, recent #678/#680
fixes per `dev/notes/split-day-ohlc-redesign-2026-04-28.md`). At
N=1,000 × 30y, expected aggregate split events: ~1,000 × 6 = ~6,000
adjustments — within the engine's per-tick `_apply_splits_to_positions`
pathway already exercised by `goldens-broad/decade-2014-2023`.

## 5. Capacity feasibility for N=5,000×10y / N=1,000×30y

Cost model (post-engine-pool, GC-tuned, from
`dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`):

```
RSS ≈ 67 + 3.94·N + 0.19·N·(T − 1)   MB
```

Where N = universe size (loaded symbols incl. sector ETFs + index),
T = years of bar history.

| Cell           | Projected peak RSS | 8 GB ubuntu-latest? | Real-world reference |
|----------------|--------------------:|---------------------:|----------------------|
| N=1,000 × 10y  | 6,237 MB (~6.1 GB)  | ✓ tight             | Measured **2,945 MB** on `goldens-broad/decade-2014-2023` (2026-04-29, default GC). Cost-model is conservative. |
| N=1,000 × 30y  | 9,539 MB (~9.3 GB)  | ✗ over ceiling      | Extrapolation only — never run. |
| N=5,000 × 10y  | 28,857 MB (~28 GB)  | ✗ way over          | Extrapolation only. Confirms `dev/plans/daily-snapshot-streaming-2026-04-27.md` projection (30 GB at this cell). |
| N=5,000 × 30y  | 84,617 MB (~83 GB)  | ✗ way over          | Streaming-only territory. |

The measured N=1,000 × 10y peak (2,945 MB) is **52 %** of the
cost-model projection. Two possibilities for the 30y / 5,000 cells:

1. **Optimistic scaling** — if the same 0.5× factor holds:
   - N=1,000 × 30y → ~4.8 GB peak (fits 8 GB).
   - N=5,000 × 10y → ~14.4 GB peak (still does not fit 8 GB).
2. **Worst-case (cost-model holds)** — neither fits 8 GB.

Note: the 0.5× factor was measured on a single cell. β = 3.94 MB /
symbol is the calibration anchor; whether γ holds at 30y is untested
(no run beyond T=10 has been measured).

## 6. Recommendation

| Experiment        | Verdict                              |
|-------------------|--------------------------------------|
| N=5,000 × 10y     | **Blocked on infrastructure** — daily-snapshot streaming (`dev/plans/daily-snapshot-streaming-2026-04-27.md`). Data supply is fine; memory ceiling is the gate at ~14–30 GB projected vs 8 GB GHA limit. Local-only run is *possible* if a 32+ GB host is available, but won't fit the tier-4 release-gate without streaming. |
| N=1,000 × 30y     | **Feasible locally with caveats.** Data supply: 1,171 broad-30y symbols available; pick 1,000. Memory: cost-model projects 9.3 GB (over 8 GB GHA), but measured-vs-projected gap suggests ~4.8 GB realistic. Recommended: run **locally** (32 GB host) first to confirm, then decide whether to add to the GHA tier-4 release-gate. **Not feasible on ubuntu-latest** without streaming. |
| N=1,000 × 10y     | **Already proven** — 2,945 MB measured; runs in 4:27 wall on `goldens-broad/decade-2014-2023`. Re-pin canonical baseline after split-day broker model + #689/G3+G4 land. |
| N=500 × 30y       | **Untested but should fit** — projection ~4.9 GB (cost-model) / ~2.5 GB (measured-scaled); SP500-30y-deep symbols = 305, so 500 needs broad-universe. Suggested as a stepping-stone before committing to N=1,000 × 30y. |

**Immediate actions:**
1. **No data refresh needed** for either experiment. Inventory is
   verified, end-dates current through 2025/2026, and depth is sufficient.
2. **For N=1,000 × 30y**: pick a 1,000-symbol cohort from the 1,171
   broad-30y candidates. Run locally with `OCAMLRUNPARAM=o=60,s=512k`.
   Budget ~30–60 min wall (extrapolated from 4:27 at 10y).
3. **For N=5,000 × 10y**: gate on daily-snapshot streaming. No
   point in attempting on current infra.

## What this audit does NOT establish

- **Wall-clock at depth.** No N=1,000 × 30y run has been executed; wall
  time is extrapolated linearly from N=1,000 × 10y (4:27).
- **Strategy correctness at long horizons.** Stage classifier, stops,
  and screener cascade have not been exercised over a 30y window. The
  short-side issues currently in flight (G1–G4) plus split-day
  broker-model fixes (#678 / #680) are the active risks. Re-pin
  baselines after those land.
- **30y γ scaling.** Cost model fits T ∈ {1, 6} only. γ may degrade
  at T=30 due to per-symbol indicator continuity overhead; no
  measurement.
- **Survivorship bias in the cohort.** A 1,000-symbol broad-30y cohort
  is by construction survivors (or pre-delisting symbols whose data was
  retained). Backtests of long-horizon returns will overstate
  performance unless the cohort selection method explicitly accounts
  for delistings.
