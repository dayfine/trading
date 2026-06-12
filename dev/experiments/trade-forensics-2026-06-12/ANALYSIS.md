# Trade-level forensics — broad universe, both regimes (2026-06-12)

User request: deep trade-level analysis across the broad universe — good trades
vs bad trades, impactful decisions, what works and what doesn't. Substrate: two
single full-window Cell-E audit runs (652-trade bull ledger 2011-2026 on
top-3000-2011; bear-decade ledger 2000-2011 on top-3000-2000), each with
`trades.csv` + `trade_audit.sexp` (decision trail incl. MFE/MAE) + equity curve.

Run artifacts: `dev/backtest/scenarios-2026-06-12-064232/cell-e-top3000-2011-15y/`
and `dev/backtest/scenarios-2026-06-12-074543/cell-e-top3000-2000-regime/`
(in-container/local; key tables reproduced here).

## Part 1 — Bull ledger (2011-2026, 652 round-trips)

Summary: win rate 33.1%, profit factor 1.43, realized P&L +$4.21M on $1M
initial; terminal MTM $19.9M of which **AXTI alone ≈ $19.7M** (249,089 sh ×
$79.22 — one ticket ≈ 100% of terminal NAV; position sized 14% at entry, never
trimmed, ran 36×).

### 1. Exit-channel decomposition (where money is made/lost)

| exit channel | n | total realized | avg/trade | avg days |
|---|---|---|---|---|
| laggard_rotation | 192 | **+$10.98M** | +21.3% | 85 |
| stop_loss | 450 | **−$7.01M** | −2.72% | 26 |
| stage3_force_exit | 8 | +$0.24M | +1.3% | 62 |

The P&L engine is: stops eat many small losses; the laggard-rotation channel
(which exits relative-strength laggards to fund new entries) is the de-facto
**profit-taking channel** — by the time a position fades enough to trigger
`rs_13w_neg_weeks=2` it has usually banked a gain (median +2.7%, p90 +25%,
mean +21% — right-tail dominated; 30% of rotations exit at a loss).

### 2. Concentration (Bessembinder at trade level)

Top 5 realized trades = **165%** of total realized P&L; top 10 = 203%; top 20
= 242%. The other ~630 trades are NET NEGATIVE in aggregate. Add the
unrealized side (AXTI = the entire terminal MTM) and the 15-year outcome is:
a handful of right-tail rides pay for everything else.

### 3. Win/loss anatomy — the machine works as designed

Winners: n=216, avg +23.3%, held 87d. Losers: n=436, avg −4.9%, held 23d.
Payoff ratio 4.7 at 33% win rate. Cut-losses-fast/let-winners-run is
mechanically intact; there is no execution rot here.

### 4. Entry-type decomposition — the realized edge is ~all in ONE entry type

Audit rationale → score mapping: score 75/85 = **Stage1→2 breakout** entries;
score 60/70 = **Early Stage2** entries.

| entry type | n (share) | realized P&L (share) | avg/trade | win rate |
|---|---|---|---|---|
| Stage1→2 breakout (75/85) | 525 (80%) | ~+$0.30M (**7%**) | +1.9% | 33% |
| Early Stage2 (60/70) | 86 (13%) | ~+$4.10M (**98%**) | +21.7% | 36% |
| Other (shorts, low grades) | 41 | −$0.2M | — | — |

Score=70 Early-Stage2 alone: n=57, avg **+34.6%**, +$4.75M (>100% of total).
This is `project_cascade_selection_inversion` confirmed with realized dollars:
the screener's highest-scored entry type (the textbook breakout, 80% of all
capital deployments) is net-noise; the lower-scored early-Stage2 continuation
entry is essentially the entire realized edge. The score=85 cohort stops out at
73% rate (225/311 exits via stop) vs 56% for score-70.

### 5. Give-back — first measurement (MFE/MAE fields now live)

| cohort | n | avg MFE | avg realized | give-back |
|---|---|---|---|---|
| laggard_rotation exits | 188 | +51.8% | +21.6% | **30.1pp** |
| stop_loss exits | 441 | +6.7% | −2.6% | 9.3pp |
| MFE>20% cohort | 72 | +142% | +59.8% | **82pp** |

Even stopped trades were up +6.7% on average at their peak. The big-winner
cohort gives back over half its peak — that is the *designed* cost of holding
for 36× tails (every exit-tightening variant has failed WF-CV; treat any
"capture more MFE" proposal as winner-touching with the standing skeptical
prior). The one candidate axis: laggard-rotation trigger latency
(`rs_13w_neg_weeks`) — it fires ~30pp after the local peak; a faster RS
trigger is *laggard*-touching rather than winner-touching, so it is at least
eligible for a default-off surface test.

### 6. Stop channel anatomy

- 69% of all round-trips end at a stop; median stop-out dies **11 days** after
  entry (p25=5d). Half the stop book is dead inside two weeks — entry timing
  on breakouts is the weak link, consistent with §4.
- **Gap-down stops** (313 of 450) cost −4.19% avg vs −1.79% for intraday stops:
  ~2.4pp × 313 trades of unavoidable overnight-gap slippage. Structural cost of
  weekly cadence + gaps; stop placement cannot remove it.
- Whipsaw is minor: 444 symbols traded once; only 14 symbols traded 3+ times
  (net −$51k). Re-entry churn is not a leak.

### 7. By entry year (regime fingerprint)

2020 (+$3.9M) and 2023 (+$2.8M) carry the ledger; 2022 (−$1.55M), 2024
(−$0.80M), 2025 (−$1.80M, 6.7% win rate) bleed. CAVEAT: recent years are
right-censored — their winners are still open (unrealized), so realized
year-P&L overstates recent weakness. (The matrix's realized-vs-MTM columns
showed the same censoring from the other side.)

## Artifacts / process gaps found by this analysis (task 2 input)

- **G1 — `open_positions.csv` writes the run date as `entry_date`** for every
  open position (all rows say the run's end date). Writer bug; trivial.
- **G2 — trades.csv ↔ audit reconciliation gap:** THM's 2022 short closed per
  the audit (stop at 0.55, position THM-wein-8427) but has NO row in
  trades.csv, while an OPEN 1.1M-share THM short (entry 0.69) sits in
  open_positions with no audit entry record. At least one position's
  round-trip accounting is inconsistent between the two artifacts.
- **G3 — stale-hold zombies pollute the open book:** 23 of 24 open positions
  are `stale_held_symbols` (e.g. CPKI held since 2011-07 at its delisting
  close for 15 simulated years; THM short bleeding −240% unstopped because no
  bars → no stop evaluation). Their NET value contribution here is small
  (AXTI dominates), but audit runs should set the #1487 stale-exit flag ON so
  the trade ledger closes these honestly.
- **G4 — MFE/MAE memory was stale:** fields ARE populated now (fixed upstream,
  likely #1525/#1528). Memory corrected; give-back analysis unlocked (§5).
- **G5 — shorts present in a "long" baseline:** the Cell-E config trades
  short-side entries (Stage3→4 breakdowns, score 65/55 cohort, n≈15, net
  negative incl. the THM open disaster). Worth an explicit
  `enable_short_entries` review — at minimum the per-share margin floors from
  `dev/notes/long-short-margin-mechanics-2026-06-12.md` say sub-$17 shorts
  (THM at $0.69!) are uneconomic to carry at 100%+ margin in reality.

## Part 2 — Bear-decade ledger (2000-2011, 321 round-trips)

Summary: +44.9% total over 11.5y, win rate 34.0%, MaxDD 31.2%. **Realized P&L
is only +$61k** — final value $1.449M is ~all open-position value (unrealized
+$486k on the 2009-2011 recovery winners still open at window end; censoring).

### Exit channels NET TO ZERO in the bear decade

| exit channel | n | total realized | avg/trade | avg days |
|---|---|---|---|---|
| laggard_rotation | 67 | +$1.38M | +13.3% | 106 |
| stop_loss | 246 | −$1.26M | −2.9% | 33 |
| stage3_force_exit | 6 | −$0.05M | −5.1% | 67 |

Same machine as the bull ledger, but the profit channel only just covers the
stop channel. Payoff ratio collapses to 2.2 (vs 4.7) at the same ~34% win
rate — chop makes winners half as big. All net return is terminal unrealized
carry from the post-2009 leg.

### Give-back is WORSE in chop

| cohort | n | avg MFE | avg realized | give-back |
|---|---|---|---|---|
| stop_loss exits | 226 | **+12.7%** | −3.4% | **16.1pp** |
| laggard_rotation exits | 64 | +37.5% | +13.3% | 24.1pp |

Bear-decade stopped trades averaged +12.7% at peak before dying to −3.4%
(bull: +6.7%→−2.6%). The wide trailing stop converts mid-size paper gains into
losses when trends don't extend — this, not entry quality, is the bear-decade
realized-P&L killer.

### Entry-type edge INVERTS BACK across regimes

| entry bucket | bull 2011-26 avg/trade | bear 2000-11 avg/trade |
|---|---|---|
| score 85 (Stage1→2 breakout) | +1.6% | +0.8% |
| score 75 (Stage1→2 breakout) | +2.4% | −0.1% |
| score 70 (Early Stage2) | **+34.6%** | **−1.9%** |

The early-Stage2 dominance is a post-2011 phenomenon; in 2000-2011 it is mildly
NEGATIVE. The cascade-inversion finding (`project_cascade_selection_inversion`)
is regime-conditional — reweighting the cascade toward early-Stage2 on the
post-2011 evidence would have been a regime bet, not a structural fix. (The
inversion memory's "return edge non-stationary" caveat, now seen from the
other side.)

### Macro-gate protection = entry SUPPRESSION, not better entries

2002: n=8 entries; 2008: n=11 (win rate 9%). The gate's value in crashes is
keeping the strategy OUT (the matrix's halved drawdowns), not improving picks —
the few entries it does allow in declining tape are awful. 2003-2005 recovery
entries: +$0.53M realized, 40-47% win rates — the post-bear sweet spot in
realized form (mirrors the matrix's 2003-04 start-date alpha).

## Cross-regime synthesis — what works, what doesn't

1. **What pays, everywhere:** a small number of long right-tail rides
   (concentration: top-5 trades = 165% of bull realized P&L; AXTI = ~100% of
   terminal bull NAV), entered disproportionately in post-bear recovery
   windows (2003-05, 2011-13, 2020, 2023), held 80-110 days through the
   laggard-rotation channel.
2. **What loses, everywhere:** the stop channel (~70-77% of all trades), with
   half of stop-outs dead within ~2 weeks of entry — breakout entries that
   fail immediately. Gap-down slippage adds ~2.4pp per stop on 70% of stops.
3. **What is regime-dependent (don't tune on it):** entry-type ranking
   (early-Stage2 vs breakout flips sign across decades); per-trade payoff
   (4.7 bull / 2.2 chop); the realized-vs-unrealized split.
4. **What the machine does as designed (leave alone):** loss-cutting (avg
   loser −5% in 23-31 days), winner-holding (the give-back is the price of
   the 36× tail), low whipsaw.
5. **Newly actionable candidates (default-off axes, skeptical priors):**
   (a) laggard-rotation trigger latency (30/24pp give-back at exit;
   laggard-touching, not winner-touching); (b) breakout-entry quality in
   mid-bull regimes (the 2013-2018 / 2006-2007 entry cohorts are the bleed);
   (c) short-side entries: disable or margin-model them (G5 — currently
   unrealistic and net-negative).
