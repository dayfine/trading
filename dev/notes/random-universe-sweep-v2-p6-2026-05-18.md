# Random-universe sweep v2 — P6 result (2026-05-18)

Follow-up to PR #1180 + PR #1190. Re-ran the random-universe sweep
against the new delisted-aware `top-3000-2019.sexp` pool (#1190). The
result substantially revises the #1180 narrative.

## TL;DR — the #1180 "8σ outlier" claim was overstated

P6 sampled 5 random 500-symbol subsets from the new delisted-aware
pool (seeds 53-57) — DIFFERENT seeds than #1180 (43-47).

| Pool                                | Returns (sorted)               | Mean | σ    |
|-------------------------------------|--------------------------------|------|------|
| OLD live-only sectored (#1180)      | -10, -10, +24, +29, +30        | +13% | ~20pp|
| NEW delisted-aware sectored (P6)    | +19, +69, +106, +260, +273    | +145%| ~115pp|

**Top-500-by-volume baseline (#1179 → #1190): +175% → +78%**.

In the OLD distribution (mean +13%, σ ≈ 20), +175% was ~8σ — exotic.
In the NEW distribution (mean +145%, σ ≈ 115), +78% is **~0.6σ below
the mean — perfectly ordinary**.

But: the NEW sectored pool (1956 names) is ~96% identical to the OLD
sectored pool (2549 names) — only 6 net new sectored entries. So:

- **The +145% vs +13% gap is dominated by sample-size noise across
  different seeds, NOT by pool composition.**
- N=5 sampling × σ ≈ 100pp gives stderr ≈ 45pp — much larger than
  #1180 reported. #1180's "σ ≈ 20pp" was a lucky low-variance draw.
- Reliable distribution characterization needs N≥30.

## The #1180 conclusion was directionally right, magnitudinally wrong

The selection-bias finding from #1180 (composition cells are biased
upward vs random) IS true — the 5 random draws there were heavily
NEGATIVE-skewed (3 of 5 had returns ≤ +30%; mean +13%). The new draws
with delisted-aware pool are POSITIVE-skewed (mean +145%). The TRUE
random-mean is probably somewhere in between, with much wider
variance than either run estimated.

The +78% delisted-aware top-500 cell from #1190 sits within reasonable
bounds of EITHER distribution. The selection-bias narrative from
#1180/#1190 should be SOFTENED, not abandoned. Top-500-by-volume is
likely modestly above the true random mean (maybe ~1σ), not 8σ.

## P6 results (n=5)

| Sample | Return | Trades | WinRate | Sharpe | MaxDD | Sortino | Calmar |
|--------|--------|--------|---------|--------|-------|---------|--------|
| 1      | 260.24%| 144    | 36.81   | 0.68   | 61.87 | 0.98    | 0.47   |
| 2      | 105.85%| 273    | 29.67   | 0.70   | 41.75 | 1.00    | 0.37   |
| 3      |  68.88%| 274    | 33.94   | 0.56   | 36.33 | 0.68    | 0.30   |
| 4      | 273.30%| 271    | 31.00   | 0.88   | 46.34 | 1.92    | 0.65   |
| 5      |  18.76%| 278    | 29.86   | 0.27   | 40.92 | 0.24    | 0.09   |

Stats:
- Return mean ≈ +145%, range [+19, +273], σ ≈ 115pp
- Sharpe mean ≈ 0.62, range [0.27, 0.88], σ ≈ 0.23
- MaxDD mean ≈ 45.4%, range [36.3, 61.9]
- Win rate mean ≈ 32.3%, range [29.7, 36.8] — tight (strategy-mechanic invariant)
- Trade count mean ≈ 248 (sample 1 outlier at 144; others 271-278)

Sample 1 anomaly: 24 force-liquidations + 144 trades + open-positions=0
suggests a cascade event mid-window (likely a single big drawdown bar
that triggered mass exits). Worth investigating separately.

## What the sectored-pool diff shows

| Set                         | Count |
|-----------------------------|-------|
| OLD sectored pool (#1180)   | 2,549 |
| NEW sectored pool (P6)      | 1,956 |
| Common to both              | 1,950 |
| Net new in delisted-aware   |     6 |
| Net dropped                 |   599 |

The 599 dropped names are mostly low-volume small caps the
delisted-aware rebuild crowded out by dollar-volume rank. The 6 net
new are sectored small-cap rotations.

**The big delisted-aware additions (AABA, CELG, ANTM, AGN, ATVI, etc.)
all have empty sectors** in the new top-3000-2019 — they were
filtered out of the P6 sampling pool. So the P6 result is NOT a clean
test of "what happens when we include the famous 2019-2026
delistings" — it's a test of "what happens with new seeds on
essentially the same pool".

To do the FAIR test, we need P5 (sectors backfill for delisted
names). Then re-sample and re-run.

## Sample-size lesson

Both #1180 and P6 used N=5. The variance estimate is unstable at that
N. A reliable distribution characterization needs N ≥ 30. At N=30
× 3 min wall = ~90 min, doable in a single session.

Recommended P7 (next session):
1. Backfill sectors for the famous delistings (P5, deferred to P5 in
   #1190's note — Finviz / hardcoded historical mapping).
2. Re-run with N=30 seeds, including the delisted-aware additions
   that currently have empty sectors.
3. Report stable mean + σ + percentile bands. Then compare top-500-
   by-volume cell to that calibrated distribution.

## Why no PR-merge wave on top-500-2019 bands

The #1190 re-pin at +78.34% (±20%) still stands — that's a single-
point measurement of the cell, independent of the random-sample
narrative. Bands are correctly centered on the new measurement.
Tightness ±20% reflects measurement variance, not distribution
variance.

What's WRONG-ish about #1190's framing is the "selection-bias is now
borne out" claim — it's overstated. Should be "selection-bias is
plausibly modestly real but needs N≥30 to characterize".

## Reproducibility

Universes committed at `trading/test_data/backtest_scenarios/universes/random-2019-v2-delisted-aware/sample-{1..5}.sexp`
(seeds 53-57 from the new top-3000-2019 sectored pool).

Scenarios at `dev/experiments/random-universe-sweep-v2-2026-05-18/scenarios/random-2019-v2-sample-{1..5}.sexp`
(NOT committed — ad-hoc).

Run command:
```sh
docker exec trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) &&
  dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
    --dir /workspaces/trading-1/dev/experiments/random-universe-sweep-v2-2026-05-18/scenarios \
    --parallel 3 --fixtures-root /workspaces/trading-1/trading/test_data/backtest_scenarios \
    --no-emit-all-eligible'
```
