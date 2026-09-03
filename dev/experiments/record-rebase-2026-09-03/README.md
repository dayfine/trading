# record-rebase-2026-09-03 — the record convention on the fixed exit basis

PR #2648 flipped `sim_exit_fill_next_open` and `stops_config.stop_skip_entry_bar`
on by default. The canonical record baseline (`record-baseline-2026-08-24`,
731.64% / 780 trades / Sharpe 0.666 / MaxDD 26.6 at build `c7660cac3`) was
measured on the old basis, whose first-order exposure was −$601k of Friday-open
fills on stop/laggard exits. This experiment re-bases the record: the same
spec, PAIRED (old = both knobs pinned false, new = the shipped default) at ONE
build, `e4984c5fe` (main after #2648 + #2652), pinned worktree
`sweep-record0903`.

## Cells (salt 0)

| cell | window | universe | arms |
|---|---|---|---|
| rec5y-2019 | 2019-01-02..2023-12-29 | top-3000-2019 (32% warehouse coverage — level survivor-tilted, A/B valid) | old, new (concurrent) |
| rec5y-2000 | 2000-01-03..2004-12-31 | top-3000-2000 (94%) | old, new (concurrent) |
| rec26y | 2000-01-01..2026-06-26 | top-3000-2000 | new, then old (sequential) |

Warehouse `/tmp/snap_top3000_dedup_v5thin_adj`, `SNAPSHOT_CACHE_MB=1024`,
`--no-emit-all-eligible --parallel 1`, `TRADING_PATH_SEED_SALT=0`. Specs staged
outside VCS during the run (`/tmp/rec0903-run/specs/`), committed copies under
`specs/`; raw per-arm artifacts (`actual`, `trades`, `params`, `summary`,
`trade_audit`, `open_positions`, runner log) under `results/`.

## What this answers

1. **The new canonical record level** (rec26y-new) — every writeup after this
   diffs against it; `record-baseline-2026-08-24` becomes the old-basis record.
2. **How much of the old record was the defect** — rec26y old→new at one
   build, decomposed per `feedback_dissect_before_proposing_a_mechanism`:
   shared-trade drift (`symbol|entry_date` join) vs cohort reshuffle vs
   monsters (`project_top500_composition_golden_is_gme`).
3. **A 5y null for the record-side exit levers** (laggard hysteresis, stage-3
   force-exit hysteresis, extension stop, stop anchor #2408) — measured on
   these same windows as the next chain.

Note that the old arm here is NOT bit-comparable to the 08-24 record (build
`c7660cac3` predates #2555's RS-trend fix and #2587's clock-52, which the
record spec pins to 0 anyway); the lineage delta 08-24 → rec26y-old is a
build delta, the old→new delta is the exit-basis delta.

## Results

All six cells landed 2026-09-03 10:51–17:31 PDT (`chain.log`). Raw per-arm
`actual` / `params` / `summary` / `trades` under `results/` (trade_audit and
open_positions dropped for size; regenerable from the committed specs).

| cell | old (both knobs false) | new (shipped default) | Δ return | wall |
|---|---|---|---:|---|
| rec5y-2019 | 13.81% / 174 / 0.234 / 33.91 | 3.02% / 184 / 0.118 / 30.33 | −10.8pp | 22 min ×2 concurrent |
| rec5y-2000 | 35.76% / 110 / 0.505 / 16.64 | 76.64% / 98 / 0.655 / 28.36 | +40.9pp | 22 min ×2 concurrent |
| **rec26y** | 312.74% / 799 / 0.430 / 38.78 | **302.65% / 723 / 0.397 / 36.26** | **−10.1pp** | 2h51m + 3h04m |

**The canonical record on the fixed basis is rec26y-new: 302.65% / 723 trades
/ Sharpe 0.397 / MaxDD 36.26** (`results/rec26y-new-s0-params.sexp`).

### Lineage cross-check

rec26y-old (312.74 / 0.430 / 38.78) is digit-for-digit the clock-surface
cell-A null of 2026-08-27 (`clockA-0`, build 90dfd6e97) — the record spec pins
the clock at 0, and nothing between that build and e4984c5fe moved the old-
basis default path. So the 08-24 record's 731.64% → 312.74% is the #2555
RS-trend build delta (already recorded as a correctness re-pin with no
return claim), and the exit basis costs a further −10.1pp on top.

### 26y dissection

Realised $2.95M → $2.21M (−$747k). Join on `symbol|entry_date`: 462 shared /
337 old-only / 261 new-only, first divergence 2000-03-07.

| component | $ | note |
|---|---:|---|
| shared: stop_loss price effect (306 trades) | −565k | −0.5pp per stop (vs −1.0…−1.2pp on the 5y cells) |
| shared: laggard_rotation price effect (144) | +814k | includes the D2-saved entries that lived to become laggard exits |
| shared total (all triggers, incl. sizing) | **−40k** | the mechanism is ≈ neutral at 26y |
| cohort: old-only 337 entries | +804k | AEIS 2025-06-24 +$548k (screened grade B in the new arm, book was 4 deep and never funded it), IONS 2013 +$246k, CLB 2005 +$231k |
| cohort: new-only 261 entries | +97k | BBWI 2020-08 +$414k, IPIXQ 2004 +$256k, GILT 2025 +$157k |

D2 saved 63 of the old arm's 108 entry-bar deaths (13.5% of its trades):
−$368k → +$283k, of which 39 re-stopped within 14 days and two became
monsters (WNC 2003 +160% / +$271k, UGP 2006 +69% / +$170k). The new arm has
one day-one stop (a genuine next-day stop, not an entry-bar artifact).

**Read.** On the record convention the fixed basis is a wash on shared
trades (stop tax ≈ D2 monster credit) and the −10pp is path: the book that
held UGP and WNC longer had different cash on the weeks AEIS, IONS and CLB
broke out. No mechanism claim attaches to the −10pp; the mechanism claims are
the per-trigger rows above and the 5y decomposition below.

### rec5y-2019 (top-3000-2019, 2019-01-02..2023-12-29), salt 0

| arm | return % | trades | win % | sharpe | maxDD % | realised $ |
|---|---:|---:|---:|---:|---:|---:|
| old (pre-flip basis) | 13.81 | 174 | 33.9 | 0.234 | 33.91 | +41,170 |
| new (fixed basis) | 3.02 | 184 | 33.7 | 0.118 | 30.33 | −68,074 |

Join on `symbol|entry_date`: 132 shared / 42 old-only / 52 new-only, first
divergence 2019-04-24 (SAP). **Shared-trade drift −$76k** (≈ −$580 per
trade; exit triggers 126 stop_loss + 46–53 laggard_rotation — the record
convention is stop/laggard-heavy, exactly the exits the Friday-open fill
flattered), **cohort reshuffle −$33k** (old-only +$24k, new-only −$9k), same
top trade in both arms (LOGI 2020-05-06, +$156k / +$149k). Unlike the golden
cells, the mechanism accounts for ~70% of this gap — the sign and shape the
26y record repricing predicted (−$601k first-order: stops −$337k, laggards
−$263k). maxDD improves 3.6pp (the entry-bar stop-outs were adding churn).

### rec5y-2000 (top-3000-2000, 2000-01-03..2004-12-31), salt 0

| arm | return % | trades | win % | sharpe | maxDD % | realised $ |
|---|---:|---:|---:|---:|---:|---:|
| old (pre-flip basis) | 35.76 | 110 | 37.3 | 0.505 | 16.64 | +256,230 |
| new (fixed basis) | 76.64 | 98 | 31.6 | 0.655 | 28.36 | +622,371 |

Join on `symbol|entry_date`: 74 shared / 36 old-only / 24 new-only, first
divergence 2000-03-07. Shared-trade drift **+$181k**, cohort +$185k (new-only
+$277k incl. IPIXQ 2004-04 +$256k; old-only +$92k). No splice-shaped rows
(|pnl%| > 100 with ≤5 days held) in either arm.

### Mechanism decomposition (shared trades, Δpnl% × old notional = price effect)

| window | trigger (new arm) | n | ΣΔpnl% | mean Δdays | price effect $ |
|---|---|---:|---:|---:|---:|
| 2000–04 | stop_loss | 58 | −70.5 | +3.5 | **−111,400** |
| 2000–04 | laggard_rotation | 12 | +183.2 | +36.1 | +322,022 (WNC alone ≈ +290k) |
| 2019–23 | stop_loss | 96 | −100.1 | +1.2 | **−134,025** |
| 2019–23 | laggard_rotation | 34 | +18.9 | +8.3 | +22,565 |

**D1 (honest Monday fill on stop exits) costs ≈ −1pp per stopped trade in
both windows** (−1.2pp/stop in 2000–04, −1.0pp/stop in 2019–23) — the
Friday-open fill was flattering exactly the record convention's dominant
exit. Laggard exits gain a little (+0.5pp each in 2019–23).

**D2 (no stop exit on the entry bar) removes every day-one death — 23 of 110
trades in 2000–04, 18 of 174 in 2019–23 — and most of them die anyway a few
days later at a worse price.** Fate of the old arm's entry-bar stop-outs in
the new arm (same `symbol|entry_date`):

| window | saved | old pnl $ | new pnl $ | stopped again ≤ 14d | winners | monsters |
|---|---:|---:|---:|---:|---:|---|
| 2000–04 | 18 of 23 | −8,791 | +225,316 (**−46k ex-WNC**) | 12 | 5 | WNC 2003-05-09 +160% (+$271k) |
| 2019–23 | 16 of 18 | −49,116 | −98,885 | 13 | 3 | none (best POOL +17%) |

So the artifact was, on average, a *lucky* exit: it sold breakouts that were
about to fail at a −2% day-one loss instead of the −4…−12% real stop. The
book-faithful basis holds them (§5.1: a stop cannot be hit by price the
position never held), pays that difference, and once in a while keeps a
monster. The 2000–04 +41pp is WNC; the 2019–23 −10.8pp is the D1 stop tax
plus the D2 hold cost with no monster to pay for it.

**Implication for the 26y record (pending):** first-order the repricing said
−$601k on stops + laggards; the 5y pairs say the D1 stop tax is ≈ −1pp × N
stops (N ≈ 500 at 26y → ≈ −$0.5M realised) and D2 is a small negative plus a
monster lottery. Expect the 26y record to drop unless a D2-saved monster
lands.
