# Read-only screens run 2026-09-13 PM (after the item-3 REJECT and the item-4 26y ACCEPT)

All screens are counterfactuals over committed trade lists (`trades.csv`) and the CSV store's `adjusted_close`
(basis-independent ratios), on the 26y `_v10dedup` cells: **null** = `a0-breadth-on-null-s{0,1,2}-v10` (4% daily
stop), **wide** = `a4-cadence-12w-s{0,1,2}-v10` (12% initial, weekly trail update). They ignore cash redeployment
and trail ratchets; what is trusted is the SIGN at three salts and the mechanism, not the dollar size
(`mechanism-validation-rigor.md`). Scripts are throwaway Perl (`*.pl` here; port to OCaml/sh if reused).
Weekly states come from the salt-1 audit (`weekly_states_s1.txt`: date, breadth_state, macro_trend — path-independent).

## 1. Exit-at-next-close for positions already OPEN when a signal fires (`cf_exit.pl`)

gain-from-exit = (pnl if sold at the first close after the signal week) − (actual final pnl); positive = exiting helps.

| signal | weeks | null s0 / s1 / s2 | wide s0 / s1 / s2 |
|---|---:|---|---|
| index speed (4wk ≤ −12% or ≥15% off 8wk high; `speed_trigger_weeks.txt`) | 28 | −$447k / −$289k / −$407k | — |
| breadth `Deteriorating` | 52 | **+$776k / +$794k / +$336k** | **−$707k / −$162k / −$103k** |
| macro trend → Bearish (onset; book's Stage-4 market) | 43 | −$744k / −$723k / −$737k | −$1.23M / −$1.00M / −$1.15M |
| macro trend leaves Bullish | 48 | −$800k / −$346k / −$908k | −$2.92M / −$1.82M / −$1.87M |

Timing sensitivity (null s1, Deteriorating): lag 0 / 7 / 14 / 28 d = +$794k / +$674k / +$500k / +$951k — noisy.
Per-position (null s1, Deteriorating): n=120, 63% positive, p10 −$21.8k, p50 +$9.7k, p90 +$39k.
Read: under a 4% trail, positions are ahead when `Deteriorating` fires and give it back to whipsaw stops; under the
wide trail they are held and go on to gain. Speed fires after the 4% stop has already done the cutting.

## 2. Same, selective: exit only poor-RS holdings at Bearish onsets (`cf_exit_rs.pl`)

RS = stock minus GSPC return over 13 or 26 weeks at the signal week. Poor-RS subsets are 1–17 positions (the trail
has already culled them); leaders (130–247) lose $0.5–1.3M if exited at every salt and definition; the poor subset is
−$275k…+$82k with no consistent sign. **No-build:** the book's "sell the poor-RS holdings" is already done by the stop.

## 3. Entries grouped by the breadth state of the screen that produced them (`by_state.pl`)

| state | null s0/s1/s2 | wide s0/s1/s2 | stop-out rate null → wide |
|---|---|---|---|
| Bullish | +2.06 / +1.78 / +1.15 M | +3.06 / +2.29 / +2.97 M | 60% → 32% |
| Neutral | +0.83 / +0.76 / +0.79 M | +1.11 / +1.00 / +0.90 M | 68% → 41% |
| Recovering | +0.50 / +0.45 / +0.51 M | +1.87 / +1.21 / +1.09 M (mean/trade $25k → $60k) | 74% → 41% |
| **Deteriorating** | −0.27 / −0.27 / +0.06 M | −0.10 / **+0.30 / +0.41 M** | 81% → 59% |
| **Bearish** (resting tickets that filled after the flip) | +0.12 / +0.22 / +0.19 M | −0.12 / +0.11 / −0.19 M | 74% → 57% |

Four of five states gain from wide at 3/3 salts, Deteriorating included (its record loss was whipsaw, not picks).
Bearish-week FILLS are the one cohort wide hurts (3/3) — the per-state map cannot touch them (it sizes at placement,
and the gate never places Bearish tickets); the instrument is cancelling resting tickets on the Bearish flip.
Reference: the item-3 map's Deteriorating=4% cohort (daily) was −$139k…+$119k — worse than wide at 2 of 3 salts.

## 4. Width curve — narrower INITIAL stops replayed on the wide arm's own trades (`width_curve.pl`)

Stopped trades booked at −w; survivors keep actual pnl; full-life MAE (first-60-day column in the script output is the same shape).

| width | s0 | s1 | s2 |
|---|---|---|---|
| 4% | −1.23M | +0.11M | −0.36M |
| 6% | +0.23M | +0.17M | −0.26M |
| 7% | +0.97M | +0.91M | +0.73M |
| 8% | +1.60M | +2.46M | +2.42M |
| 9% | +3.79M | +3.52M | +3.57M |
| 10% | +3.69M | +3.83M | +3.39M |
| 12% | +3.69M | +3.28M | +3.49M |

**Not linear: flat through 6%, a knee from 7% to 9%, a plateau 9–12% (±$0.4M).** Absolute levels are conservative
(every 12% touch is booked at −12%; the real arm's ratcheted stops exit higher). Consequence: the promotable value
should be read off the plateau → add a **10%-weekly neighbour arm** to the confirmation grid.

## 5. Tightening the RESTING stops of open positions on a signal (`tighten_replay.pl`)

Trailing w% from the signal week forward, wide arm, gain vs actual:

| signal | w | s0 / s1 / s2 | hit rate |
|---|---|---|---|
| Deteriorating | 4% | −$903k / −$365k / −$421k | 93% |
| Deteriorating | 8% | −$1.23M / −$741k / −$700k | 79% |
| Bearish onset | 4% | −$1.17M / −$951k / −$1.17M | 93% |
| Bearish onset | 8% | −$1.02M / −$655k / −$730k | 80% |

Nine in ten open positions get hit inside a Deteriorating/Bearish stretch by construction. **No-build** for regime
tightening of resting stops at any width; the ratchet's own level beats moving it on either label, every salt.

## Book (Ch. 6, Ch. 8; `book-as-authority.md` tier 2, local session)

Ch. 6 keys tightening to the STOCK's structure (raise under each completed correction and the rising 30-week MA; pull in
when the stock's MA flattens). Ch. 8 keys the defensive posture to the INDEX's 30-week MA break into Stage 4: suspend
buying, sell poor-RS holdings, pull protective stops up tightly; 1987 gave days of warning. Screens 1–2 and 5 are a
direct test of that rule on 2000–2026 and it loses at every salt; the reconciliation is his own caveat about a faster,
wilder market — our 43 Bearish onsets are mostly V-shaped (only 2000–02 was long). The spine (macro gate on entries,
Stage-4 sell at the stock level) is untouched; the dial that adapts is width.
