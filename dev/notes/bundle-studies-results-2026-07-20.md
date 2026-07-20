# Bundle promotion studies — results (2026-07-20)

The three studies green-lit 2026-07-19 (promotion memo option B) completed
overnight. Candidate = the BUNDLE: `w_overhead_supply=30` +
`virgin_crossing_readmission=true` + floors `0/0/0`
(recent_far/stale_mid/stale_old). Reports:
`/tmp/sweeps/bundle-{sp500,2011,rolling}/` (chain
`/tmp/sweeps/bundle-studies-chain.sh`); 07-18 baseline/w30 rolling-start
comparators in `.sweep-output/rolling-start-promo/`.

## Cell 1 — sp500 grid (26×1y, 2000-2026, catstop-golden base): CONFIRM

| variant | Sharpe μ±σ | Return μ | MaxDD μ | Sharpe wins |
|---|---:|---:|---:|---:|
| baseline | 0.396 ± 0.99 | 6.3% | 10.6% | — |
| bundle w15 | **0.737 ± 1.09** | 13.9% | 10.0% | **19/26** |
| bundle w30 | 0.570 ± 1.00 | 9.7% | **9.7%** | 16/26 |

Both weights beat the 07-17 w-only cell (w15 .623, w30 .552 vs same .396
baseline): vc + floors-zero ADD value on the narrow universe. (Formal gate
FAIL via the zero-tolerance worst-fold rule only — same technical-FAIL
shape as every accepted surface.)

## Cell 2 — broad 2011-2026 (7×2y, record-convention base): REGRESS (wash)

| variant | Sharpe μ±σ | Return μ | MaxDD μ | Sharpe wins |
|---|---:|---:|---:|---:|
| baseline | 0.619 ± 0.57 | 23.7% | 16.6% | — |
| bundle w15 | 0.525 ± 0.46 | 18.6% | 19.3% | 3/7 |
| bundle w30 | 0.599 ± 0.67 | 20.9% | 18.0% | 4/7 |

Sharp contrast with the 07-17 w-only 2011 cell (w30 **.825**, fold-σ
collapse to .223): adding vc + floors-zero destroyed that cell's alpha
and its stability (σ .223 → .674). Reading: on a bull-era broad window
the floor staircase WAS the value — it suppresses the re-admitted stale
cohort; across 2000-2026 the same staircase is the redeemed-cohort tax.
The floors are regime-dependent.

## Cell 3 — bundle rolling-start (14 starts, stride-730, top-3000
2000→2026, n=12 counted): THE RECOVERY WINDOWS REPAIR

Paired per-start CAGR (pp/yr), three configs on identical start grids:

| start | baseline | w30 | bundle | Δ(bundle−base) | Δ(w30−base) |
|---|---:|---:|---:|---:|---:|
| 2000 | 18.00 | 12.16 | 18.41 | **+0.41** | −5.84 |
| 2002 | 16.86 | 18.24 | 18.59 | +1.73 | +1.38 |
| 2004 | 17.49 | 19.20 | 17.83 | +0.34 | +1.71 |
| 2006 | 15.60 | 19.20 | 20.07 | +4.47 | +3.60 |
| 2008 | 19.45 | 12.77 | 19.61 | **+0.16** | −6.68 |
| 2010 | 23.18 | 14.64 | 21.26 | **−1.92** | −8.54 |
| 2012 | 24.95 | 25.23 | 24.81 | −0.14 | +0.28 |
| 2014 | 24.14 | 25.56 | 26.94 | +2.80 | +1.42 |
| 2016 | 26.11 | 32.38 | 29.47 | +3.36 | +6.27 |
| 2018 | 27.90 | 28.37 | 30.32 | +2.42 | +0.47 |
| 2020 | 40.44 | 41.36 | 46.75 | +6.31 | +0.92 |
| 2022 | 37.29 | 47.21 | 44.68 | +7.39 | +9.92 |

- **The motivating question is answered YES**: the three recovery-window
  starts that cost bare w30 −5.8..−8.5 pp/yr are repaired to
  +0.41 / +0.16 / −1.92 — the vc + floors-zero levers do exactly what
  they were designed for.
- **Bundle vs baseline: 9/12 wins, median +2.08 pp/yr, worst loss
  −1.92** (vs w30's three 6-9pp forfeits).
- **Edge floor**: worst-start realized edge vs index — baseline +6.35%,
  w30 **−1.27%** (loses to index on the 2010 start), bundle **+7.79%**
  (beats index on all 12; floor better than baseline's).
- **Risk kept**: MaxDD median 28.76 / worst 30.99 vs baseline 32.2 /
  40.5 — the w30 DD compression survives the bundle, worst-path even
  better than bare w30 (33.9).
- Cost vs bare w30: a few mid-bull starts give back some of w30's
  upside (2016 −2.91, 2022 −2.53 vs w30) — the same effect as the 2011
  cell, seen path-wise.

## Verdict synthesis

Per `promotion-confirmation.md` the grid is SPLIT (sp500 CONFIRM, 2011
wash-to-regress, rolling-start REPAIR): no unanimous cell sweep, so the
promotable-value call is a judgment weighing which lens is decisive.

The rolling-start distribution is the lens closest to the estimand
(terminal wealth over realistic deployment paths), and there the bundle
dominates baseline (9/12, +2.08 median, worst −1.92, DD compressed,
index-beat on every start) and strictly repairs bare-w30's known left
tail. The 2011-cell regression is the honest cost: in a pure bull-era
broad window the bundle is a wash vs baseline and clearly worse than
bare w30.

Options for the human gate (R3 — no default flip without user):

- **A. Promote the BUNDLE** (three defaults flip together as one unit).
  Case: best worst-path floor of all three configs, repairs the
  recovery tail, keeps DD compression; accepts the bull-era wash.
- **B. Promote nothing; keep axes** (status quo). Case: grid split =
  evidence standard not met; wait for lever (f) age-banded surfaces
  (v4 rebuild) to resolve the floors' regime-dependence directly.
- **C. Promote bare w30.** Not recommended: its −1.27% edge floor and
  6-9pp recovery forfeits are exactly what the studies flagged.

Recommendation: **A**, on the rolling-start dominance + edge-floor
argument; with the explicit caveat recorded that 2011-era-style
bull-broad windows give back ~0.2 Sharpe vs bare w30, and lever (f)
remains the designed refinement for the floors' regime-dependence.

## Ledger

`2026-07-20-bundle-promotion-studies.sexp` (verdict recorded as
Inconclusive-pending-human-gate; the decisive-lens argument above in
notes).
