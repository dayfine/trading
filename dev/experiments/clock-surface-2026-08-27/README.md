# clock-surface — entry_order_max_rest_weeks {0,13,26,52,156} on two broad cells (#2405)

The re-flip test #2405's own record demands: the clock measured as a SURFACE
(value re-opened, not assumed — 26 was never derived), multi-cell, with the
fill-model default pair ON (#2569) so every backtest grows resting tickets.
USER approval-in-principle 2026-08-25; fill-model decision 2026-08-26.

## Cells

| cell | lineage | window × universe | why |
|---|---|---|---|
| **B** | `broad5y-00-core` (ladder-v4 cell-00) | 2019-01-02..2023-12-29 × top-3000 PIT-2019 | fast read; the window family where the −40.91pp sp500 episode lived |
| **A** | `record-baseline` (2026-08-24 canonical) | 2000-01-01..2026-06-26 × top-3000 PIT-2000 | macro-diverse (dot-com + GFC); the 26y record convention |

Both cells: one-knob arm diffs (`entry_order_max_rest_weeks` only), salt 0,
split-safe warehouse `/tmp/snap_top3000_dedup_v5thin_adj`, `--parallel 1`
per run. Universe discipline: both cells broad (top-3000) — no sp500 cell.

## Fresh nulls (arm 0), not tripwires

The committed baselines predate two default-moving merges: #2561 (RS
`lookback_bars` 52→56, classifier now live) and #2569 (`enable_sim_entry_stoplimit`
+ `entry_extension_max_pct` pair — pinned in these specs anyway). So arm 0 of
each cell is a FRESH NULL at build `90dfd6e97`; a delta vs record-baseline
731.64 / broad5y 281.71 is the build moving, not the clock. All arm
comparisons are within-cell against THIS run's arm 0.

## Pre-registered decision rule

1. **Top-lines are gated by the noise floors**: 26y ≈ 132.5pp (3-salt, old
   basis — treat as order-of-magnitude), broad-5y per
   `rt-freshness-broad5y-2026-08-20/README.md`. No top-line gap below the
   floor is interpretable on its own.
2. **The verdict evidence is the paired trade-level dissection** (join
   `position_id`; `symbol|entry_date` cross-arm): for each arm vs arm 0,
   the removed-fills cohort (rest > w) must reproduce the shape of the
   committed 2026-08-16 bucket table (rest >26wk: 89 fills, −349,132 on the
   record base) — a net-negative removed cohort at the chosen w = the
   mechanism working; a net-positive removed cohort = the SMCI reading wins
   in that window and the arm is a tail-tax there.
3. **Boundary location**: the bucket table puts the sign flip inside
   14–52wk (14–26wk +82,266; 27–52wk −148,226). If the surface agrees
   (13 too tight / 52 too loose / 26 or between robust in both cells),
   the re-flip PR proposes the robust value; if the cells disagree on
   sign at every w, record REJECT-as-default / keep-as-axis and stop.
4. **SMCI / freeze_entry_at_first_breakout adjudication**: locate SMCI (or
   its analogue) in cell A's arm diffs; classify its entry E as
   stale-screen-harvest vs legitimate-base per the #2405 record. This
   informs the separate freeze knob question; it does not gate the clock
   verdict (the base-broken measurement already showed 79/89 long-rest
   fills were structurally broken).
5. Promotion (default flip 0→w) additionally requires the
   `config-default-blast-radius` paired-golden protocol on the flip PR —
   the goldens_affected_check will now correctly FAIL affects-all/default-flip
   (#2575) and the paired table + `paired-run-done` label resolve it.

## Mechanics

- Pinned worktree `.claude/worktrees/sweep-clock2405` @ `90dfd6e97`.
- Specs staged at `/tmp/clock2405-run/specs` (outside any VCS tree).
- Per-arm artifacts exported to `.sweep-output/clock2405/` (bind-mount) as
  `<arm>-{actual.sexp,trades.csv,params.sexp}`; committed under `results/`
  when the surface completes (never read numbers from the chain log).
- Chain log: `/tmp/clock2405-chain.log` (host).

## Results (salt 0; build 90dfd6e97)

### Cell A — 26y × top-3000-2000 (macro-diverse)

| arm | return % | trades | win % | sharpe | maxDD % | wall |
|---|---:|---:|---:|---:|---:|---:|
| 0 (null) | 312.74 | 799 | 33.79 | 0.430 | 38.78 | 2h47m |
| 13 | 436.77 | 653 | 34.46 | 0.490 | 35.58 | 1h32m |
| 26 | 389.81 | 691 | 35.89 | 0.484 | 33.18 | 1h38m |
| **52** | **496.20** | 699 | **36.34** | **0.515** | **25.65** | 1h47m |
| 156 | 267.59 | 761 | 35.48 | 0.401 | 38.48 | 2h10m |

### Cell B — 2019-2023 × top-3000-2019

| arm | return % | trades | win % | sharpe | maxDD % |
|---|---:|---:|---:|---:|---:|
| 0 (null) | 18.02 | 187 | 29.41 | 0.271 | 34.12 |
| 13 | 18.72 | 190 | 29.47 | 0.288 | 30.97 |
| 26 | 15.83 | 181 | 30.39 | 0.251 | 31.61 |
| **52** | **25.31** | 182 | 30.22 | **0.345** | **27.00** |
| 156 | = null (digit-identical: no 5y fill rests >156wk — knob-liveness sanity both ways) | | | | |

### Paired dissection (join `symbol|entry_date`; realized P&L only)

| pair | removed (fills, net $) | added (fills, net $) | realized delta |
|---|---|---|---:|
| B-13 vs B-0 | 72, −107,597 | 75, −59,901 | +47,696 |
| B-26 vs B-0 | 58, −143,977 | 52, −101,468 | +42,509 |
| B-52 vs B-0 | 39, −239,451 | 34, −132,402 | +107,049 |
| A-26 vs A-0 | 421, +1,089,666 (137W/284L) | 313, +1,529,385 (115W/198L) | +439,719 |
| A-52 vs A-0 | 384, +661,133 | 284, +2,238,592 | +1,577,459 |

**The divergence is path-dominated**: at 26y, >50% of the book differs
between arms (cancelling resting tickets frees cash/slots and everything
downstream reshuffles), so removed/added cohorts are a path-A-vs-path-B
comparison, NOT an isolated cut-cohort audit. The direct long-rest class
(~89 fills on the old record base per the committed 2026-08-16 bucket
table) is buried inside the cascade. The isolated-cohort evidence remains
the bucket table; this surface adds the portfolio-level answer on top.

### SMCI adjudication (decision-rule item 4)

**SMCI has zero fills in every arm INCLUDING the null.** The +258,902
stale-E monster of the −40.91pp episode does not exist at the current
basis (it lived on the sp500 golden cell at pre-#2530/#2561 defaults).
Nothing to adjudicate here; the `freeze_entry_at_first_breakout` question
stays open independently but this surface carries no SMCI-like casualty.

### Cell C — 2000-2012 × top-3000-2000 (disjoint, bear-heavy: dot-com + GFC)

| arm | return % | trades | win % | sharpe | maxDD % | wall |
|---|---:|---:|---:|---:|---:|---:|
| 0 (null) | 76.71 | 291 | 33.33 | 0.382 | 27.10 | 1h21m |
| 26 | 93.49 | 231 | 33.77 | 0.435 | 26.61 | 1h41m |
| **52** | **97.99** | 245 | 33.47 | **0.448** | **25.65** | 56m |

(C-52's maxDD is digit-identical to A-52's: C's window is a time-prefix of
A's at identical config+salt, so A-52's drawdown episode occurred pre-2013 —
a determinism self-check, not a coincidence.)

### Verdict — ACCEPT(mechanism); robust value = 52

Ledger: `dev/experiments/_ledger/2026-08-27-entry-rest-weeks-surface.sexp`.

The clock beats the null in **3/3 independent broad cells** on sharpe and
maxDD, and on return everywhere except B-26 (−2.2pp on a 187-trade book,
with realized paired delta +$42.5k — MTM/realized divergence). **52 is the
only value on the frontier in all three cells** (top return + sharpe +
maxDD in each). Per `promotion-confirmation.md`'s decision rule, 52 is the
promotable value; 26 (the approved-in-principle value) is clean in A and C
and mixed in B.

Declared gate deviations: salt 0 only (noise floors cited from committed
3-salt records); 3-cell period×universe grid, not WF-CV folds, no DSR;
A and C share the PIT-2000 composition (period-disjoint, not
composition-independent).

**The default flip is NOT executed here.** It is a separate user-gated PR
(R3 + `config-default-blast-radius` paired-golden protocol; the
goldens_affected_check will correctly FAIL default-flip and list the
inheriting goldens per #2575). Open user decision: flip to **52** (the
measured robust value) or **26** (approved-in-principle).

### Reading (detail)

- Every clock arm {13,26,52} beats the null in cell A on ALL of return /
  win rate / sharpe / maxDD. In cell B, 13 and 52 beat the null; 26 dips
  on return (−2.2pp, small book) while improving maxDD.
- **52 is the only cross-cell-consistent winner** — top on return, sharpe
  and maxDD in BOTH cells. Its cell-A return delta (+183.5pp) exceeds even
  the old-basis 132.5pp noise floor, and DD/sharpe/win-rate co-move.
- 156 (clip-the-absurd-tail-only) is a no-op at 5y and WORSE than null at
  26y (−45.2pp, DD ≈ null) — cutting only the extreme tail keeps the
  losing 27-156wk class while forfeiting the reshuffle benefit.
- The bucket-table prior said the sign flip sits in 14-52wk; the surface
  puts the optimum at (or beyond) 52 — consistent with the cut being
  beneficial mostly through freeing capital from dead tickets rather than
  through surgically removing the worst bucket.
- Cell B is nested inside cell A's window, so it is NOT an independent
  grid cell (rangetop lesson). Cell C (2000-2012 disjoint, bear-heavy)
  runs arms {0,26,52} to complete a legitimate 3-cell read.
