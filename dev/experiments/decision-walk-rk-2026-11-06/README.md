# Decision-tree walkthrough on the record, seed k0 (draft, 2026-11-06)

**What this is.** A descriptive walk over every recorded decision of one record cell: the weekly screens, the
placements, the fills, the weekly stop decisions and the exits. It re-runs the 2026-09-26 walk
(`dev/experiments/obvious-fixes-2026-09-25/salt0-analysis.md`, f2 s0) on the current record and adds the stop-decision
record that run did not have. There is no pre-registered rule and no verdict on any mechanism. The replays in §2.7 are
first-order, within-run screens, not tests. They price a lever; they do not accept or reject it.

## 0. Inputs and reproduction

- **Run.** `record-kseed-2026-10-27` seed k0, the default-config draw (run tree `fc78391dd`; top-3000 PIT v12 schedule,
  27 yearly lists, broad, so U1 holds; 2000-01-01 → 2026-06-26). The artifacts are at `.sweep-output/record-kseed/rk-k0-s0-*`.
  `trades.csv` and `equity_curve.csv` are byte-identical to the committed `results/`.
- **What the audit holds.**
  - 670 placement records: 566 closed trades, 5 positions still open at the end, and 99 tickets that never filled.
  - 1,335 weekly cascade summaries with 21,450 top-N decisions.
  - 10,074 stop decisions over 571 positions.
- **Script.** `.sweep-output/walk-rk-k0/walk-rk.sh` plus `lib/`, in POSIX sh, awk and jq. It runs on the host only, in
  about 3 minutes, and needs the CSV bar store at `./data`.
  ```sh
  sh dev/scripts/review_pack.sh --out .sweep-output/walk-rk-k0/pack --no-container k0=.sweep-output/record-kseed/rk-k0-s0-   # ~12 min, host only
  sh .sweep-output/walk-rk-k0/walk-rk.sh .sweep-output/record-kseed/rk-k0-s0- .sweep-output/walk-rk-k0/pack/site/data:k0 \
     .sweep-output/walk-rk-k0/out 2018 2021 2022 2023 2024 2025
  sh .sweep-output/walk-rk-k0/lib/seeds.sh .sweep-output/record-kseed .sweep-output/walk-rk-k0/seeds > .sweep-output/walk-rk-k0/out/seeds.txt
  ```
- **Outputs.** Every number below cites one of these files:
  - `out/tables.txt`: the 09-26 tables, §A–G;
  - `out/stops.txt`: the stop decisions, §S0–S8;
  - `out/extras.txt`: §X1–X5;
  - `out/seeds.txt`: the replays on all five seeds;
  - `out/walk-YEAR.txt`: week-by-week walks;
  - the committed `dev/experiments/record-kseed-2026-10-27/results/read/regime-split.txt`, for RV2.
- **Basis.**
  - SPY is total return, from the pack's `spy.json`.
  - Forward and post-exit returns use adjusted closes from the CSV store, which runs to 2026-08-17. The v12wk
    warehouse was built from the same store.
  - The "basis factor" of a date is raw close / adjusted close in that store.
- **Review pack.** The pack I rebuilt with `--no-container` is used only as a data source, for the NAV and exposure
  series and the per-trade MFE and 13-week post-exit fields. It was not rendered. The k0 pack was rendered and looked at
  in the record read (that README's §Review-pack look).
- **V6.** It does not apply. Nothing here pairs two runs. The replays are counterfactuals inside one run.

## 1. The 09-26 findings, re-checked on the record

The 09-26 run (f2 s0) was the hybrid config. The record differs in the ways that matter here:

- `require_structural_stop` is on, so there are no 4 % fallback stops.
- The ticket clock is the default 52 weeks; 09-26 pinned it to 0.
- There is no Stage-3 force exit and no extension stop.
- The breadth-fixed macro inputs are in use.
- Laggard rotation is kept.

| # | 09-26 finding (f2 s0) | record k0 | status |
|---|---|---|---|
| 1 | Fallback-stop shakeouts: 78 % of trades on a 4.7 % automatic stop; 72 % stopped, 38 % quick-fail; stopped names +8.7 %/13 w after | 0 fallback stops; 566 `Support_floor` trades, mean stop 12.2 % from the fill; 49 % stopped, **16 % quick-fail** (93 trades, −$7.49M); the quick-fails' hold-through proxy median **−7.4 %** (tables §C) | **No longer holds as a shakeout.** The quick-fails are mostly real breakdowns. They still cost money |
| 2 | Stops inside 2 ATR on 58 % of trades; quick-fail 48 % / 41 % / 27 % / 6 % by ATR band | 126 of 566 (22 %) inside 2 ATR20 (median ATR20 3.2 %); quick-fail 38 % / 20 % / 13 % / 7 % / 3 % for <2 / 2–3 / 3–4 / 4–6 / 6+ ATR (§C) | **Holds as a gradient, on far fewer trades** |
| 3 | Tickets rest for years (max 885 w; 202 fills ≥ 26 w) | max age at fill **48 w**; 20 fills from 26–52 w, +$0.60M (§D) | **Gone** (the 52-week clock) |
| 4 | Tickets fill in Bearish weeks: 103 fills (14 %), stale ones −$264k | **17 fills (3 %)**: 4 fresh, +$114k; 13 stale, −$80k; net +$34k (§D) | **Holds, small and net flat** |
| 5 | Macro gate is not the loss; 2020–26 Bullish weeks NAV +2 % vs SPY +83 % at 77 % invested | Bullish weeks overall NAV +911 % vs SPY +576 %. 2020–22 Bullish NAV +54 % vs SPY +9 %. **2016–19 Bullish +20 % vs +57 %** and **2023–26 Bullish +7 % vs +65 %**, both at 65–66 % invested. Bearish weeks 2009–19: 49 w, +9 % vs +39 % (§A) | **Refined.** The Bullish-week shortfall moved to 2016–19 and 2023–26. It is holdings, not exposure (RV2 below) |
| 6 | Picks ≈ alternatives (paired weekly win 48 % in every era) | Placed beat the rest of the top-N in **54 / 49 / 44 %** of weeks at 26 w (2000–08 / 2009–19 / 2020–26) and 56 / 53 / 40 % at 13 w. 26-w medians: placed +6.8 %, `No_structural_stop` skips +4.2 %, cash-rejected +8.1 % (§B) | **Holds** |
| 7 | Installed stop ≈ half `suggested_stop` (4 % vs 8 %) | Installed median **11.6 %** below E, against the screener proxy's fixed 8 %. The audit field is now `screener_proxy_stop` (#2975's resolution) (§E) | **Reversed**, and the field is renamed |
| 8 | Trailing stops rarely rise (675/724 on the old, off-by-one count) | **365 / 571 positions never raised** (64 %). `n_stop_raises` now equals the audit count on 566 / 566 trades (§S0, §S1) | **Holds, and the count is now trustworthy.** The cause is §2.3–2.4 |
| 9 | Laggard rotation sells names that keep going: 148 / 234 higher 13 w later, mean +4.1 % | 168 / 279 higher (60 %), mean +3.3 %, median +3.1 % (§F) | **Holds, unchanged** |
| 10 | Neutral macro admits bear-rally buys | Neutral weeks NAV +21 % vs SPY +3 %; Neutral fills: 63 fresh, +$2.30M; 19 stale, +$0.18M (§A, §D) | **Not a cost on the record** |
| 11 | Record config is a hybrid | Now investor-shaped: structural stops, no Stage-3 force exit or extension stop, 52-week clock, rotation kept | **Resolved** |
| 12 | Weekly stop decisions not recorded | 10,074 rows (#2986) | **Fixed**; read in §2 |

**RV2: exposure by SPY regime and period, k0** (`regime-split.txt`, k0 rows; strategy vs SPY, invested %):

| period | UP days | MIXED | DOWN | all |
|---|---|---|---|---|
| 2000–08 | +137.1 vs +8.9 % (67.5 %) | +3.4 vs +8.7 % (47.0 %) | +8.1 vs −39.0 % (19.9 %) | +165.0 vs −27.8 % (47.8 %) |
| 2009–11 | +28.1 vs +29.2 % (62.2 %) | −15.7 vs −10.0 % (55.9 %) | +5.1 vs +27.4 % (36.8 %) | +13.5 vs +48.1 % (55.1 %) |
| 2012–15 | +73.5 vs +38.9 % (76.5 %) | +14.3 vs +14.4 % (48.6 %) | +3.1 vs +11.0 % (30.9 %) | +104.6 vs +76.3 % (72.6 %) |
| 2016–19 | **+17.6 vs +37.1 % (65.3 %)** | +3.0 vs +11.3 % (44.6 %) | −0.3 vs +11.9 % (11.6 %) | +20.7 vs +70.7 % (58.8 %) |
| 2020–22 | +59.5 vs +25.7 % (67.9 %) | −12.9 vs −30.5 % (54.5 %) | +14.5 vs +42.6 % (44.6 %) | +59.0 vs +24.6 % (59.7 %) |
| 2023–26 | **+5.3 vs +68.9 % (67.6 %)** | +10.7 vs −1.8 % (36.0 %) | +2.5 vs +21.1 % (17.9 %) | +19.6 vs +100.8 % (62.5 %) |

The two eroded periods lose inside UP regimes at about two-thirds invested, so the cause is holdings, not cash. Cash
costs only in the DOWN-labelled rebounds: 2009–11, and 2020–22, where it is offset. This agrees with the macro-state
view in row 5 and with `project_2025_anatomy` ("2025 = picks").

**Two more facts from the walk** (`out/extras.txt` §X1, §X5):

- **2023 realised no winner.** Its best exit was ARCO, +3 %. MMYT (+155 %) and CVNA (+80 %) were bought in 2023–24
  and realised in 2025.
- **Low exposure in Bullish weeks costs only in 2009–15.** There were 28 Bullish weeks below 40 % invested, with SPY
  +27 % against NAV +7 %: the post-2009 re-entry gap (`project_recovery_reentry_gap`). In every era, 90–97 % of the
  top-N slots went to `No_structural_stop` skips.

## 2. The weekly stop decisions (new since 09-26)

### 2.1 How often stops rise (`out/stops.txt` §S1)

- **Rows.** The 10,074 rows break down as:
  - waiting for a cycle: `No_correction_yet` 4,107, `Correction_not_recovered` 3,676, `Anchor_not_fresh` 59;
  - completed cycles: `Raised` 335, `Cycle_stalled` 550;
  - tightening: `Entered_tightening` 80, `Tightened_ratchet` 45, `Tightened_hold` 386;
  - `Stop_hit` 291, 11 of which are entry-bar hits that `stop_skip_entry_bar` withheld.
- **Stop increases per position:**

  | increases | positions |
  |---:|---:|
  | 0 | 365 |
  | 1 | 88 |
  | 2 | 64 |
  | 3 | 26 |
  | 4 or more | 28 (max 14, MMYT) |

- **By holding length** (closed trades), the share ever raised rises with the hold:

  | held | raised |
  |---|---:|
  | ≤ 20 days | 11 % |
  | 21–64 days | 21 % |
  | 65–129 days | 45 % |
  | 130–259 days | 64 % |
  | 260+ days | 68 % |

- **Integrity** (§S0):
  - No stop ever moved down inside the state machine.
  - The only moves outside it are the 14 split rescales, which match `splits.csv` one for one.

### 2.2 By how much (§S2)

| | n | raise, % of the old stop (median, p10–p90) | new stop below that day's close (median, p10–p90) |
|---|---:|---|---|
| first cycle, anchored on the entry-seeded extreme | 89 | +4.3 % (+0.7 to +9.0) | 14.9 % (11.3 to 20.2) |
| later cycles | 246 | +6.0 % (+2.4 to +12.6) | 20.1 % (13.3 to 35.2) |

The first stop increase comes a median **43 days** after the fill (p25 14, p75 76, p90 154; n = 203). A raised stop
still sits 15–20 % under the price, below the MA, as book §5.2 puts it.

### 2.3 Which rule decides: the MA term, read on a mixed basis (§S3)

A completed cycle's candidate is `0.99 × min(correction low, 30-week MA)`. The correction low is a raw price. The MA is
built from adjusted closes (#2982, closed; `stop_ma_same_basis` default-off).

| completed cycles | rows (positions) | binding term | basis factor ≥ 1.05 |
|---|---:|---|---|
| `Cycle_stalled` | 461 (162) | MA | yes. **390 of these rows would raise the stop on a same-basis MA, by a mean +22 %** |
| `Cycle_stalled` | 84 (58) | MA | no: the stock sits far above its MA, faithful |
| `Cycle_stalled` | 5 | correction low | — |
| `Raised` | 266 / 69 | MA / correction low | 67 of the 266 MA-bound ones have a gap |

- **The basis gap decides most stalls.** It accounts for 84 % of all stalled cycles (461 of 550).
- **Raise rate by the factor at entry:** 46 % below 1.05 (n = 244), 36 % at 1.05–1.5 (n = 165) and 21 % at ≥ 1.5
  (n = 162).
- **The gradient holds inside every era:**

  | era | factor < 1.05 | 1.05–1.5 | ≥ 1.5 |
  |---|---:|---:|---:|
  | 2000–08 | 63 % | 35 % | 25 % |
  | 2009–19 | 46 % | 40 % | 17 % |
  | 2020–26 | 39 % | 31 % | 21 % |

  So this is not only "old trades carry big dividend factors" (the confound `project_stop_raise_basis_mix_defect` flagged).

### 2.4 Stops that never rise (§S4)

Of the 281 closed trades held 65 days or more, 125 were never raised:

| why | trades | P&L | mean realised | mean MFE |
|---|---:|---:|---:|---:|
| a completed cycle stalled only because of the basis gap | **91** | **+$6.66M** | +19.1 % | +34.5 % |
| no completed cycle (no 8 % correction plus recovery: faithful) | 17 | −$0.65M | −3.2 % | +3.8 % |
| cycles stalled with the MA below the stop on one basis (extended: faithful) | 16 | −$0.37M | −2.7 % | +12.7 % |
| stale anchor only | 1 | +$0.08M | +18.4 % | +45.7 % |

**The stale anchor** is a second lock, in the state machine itself:

- **The mechanism.** After a completed cycle, both extremes reset to that bar's close. The correction extreme then
  only moves down, and the phantom guard needs a bar to touch it. A stock that never trades back to the reset close
  logs `Correction_not_recovered` or `Anchor_not_fresh` on every row. Every later pullback that holds above the reset
  close is invisible.
- **Footprint.** 545 of 7,842 trailing hold rows. 37 positions have a stale stretch, and 12 of them last 13 weeks or
  more.
- **Who.** All 12 long stretches belong to winners, and all 12 exited by laggard rotation (+$5.51M):
  - APPS, 40 weeks, the trend extreme reaching +583 % above the anchor;
  - LGND, 51 weeks;
  - FOSL, 50 weeks;
  - NOAH, 39 weeks;
  - CVNA, 23 weeks.
- **The flag.** `correction_must_follow_peak` (default-off, #2996) addresses it.

### 2.5 Exits right after a raise vs never raised (§S5)

| stop exits | n | P&L | mean realised | 13 w after the exit: mean, share higher |
|---|---:|---:|---:|---|
| never raised (initial stop) | 185 | **−$14.72M** | −10.0 % | +6.2 %, 98 / 185 (53 %) |
| last raise ≤ 10 days before the exit | 44 | +$2.53M | +6.4 % | **+8.9 %, 34 / 44 (77 %)** |
| last raise 11–60 days before | 42 | −$0.01M | +0.1 % | +1.9 %, 24 / 42 |
| last raise > 60 days before | 9 | −$0.02M | −0.6 % | +12.7 %, 8 / 9 |

- **Ordinary raises rarely cause a quick exit.** A plain `Raised` move is followed by a stop exit within 10 days only
  6 times.
- **The tightening transition does.**
  - `Entered_tightening` (Stage 3/4, or a flat or falling MA) jumps the stop a mean +13.0 % (61 transitions from
    Trailing) and is followed by a stop
    exit within 10 days 24 times: +$1.97M, after which the stocks rise +10.7 % over 13 weeks (18 / 24 higher).
  - `Tightened_ratchet` adds 14 more such exits.
- **The record does not say which trigger fired.** `Stop_decision.t` drops the `Tightened` state's reason, so the 24
  cannot be split into Stage 3/4 and MA-flat.
- n = 24 is far below the ~230 trades a tail statistic needs (`feedback_perturb_before_believing_a_cohort_split`).

### 2.6 Winners' give-back (§S6)

Across the 102 trades whose MFE reached +30 % or more:

- **The typical give-back.** The exit came a median **17.2 % below the peak price** (p10 −31.3 %, p90 −5.2 %).
- **By exit:**

  | exit | give-back from the peak, median |
  |---|---:|
  | rotation, never raised | 14.1 % |
  | rotation, raised | 13.5 % |
  | raised stop | 23.0 % |
  | stale anchor ≥ 13 weeks | 22.7 % |

- **Rotation is the binding exit for winners:** it took 71 of the 102. The stops took 29, and delisting 2.
- **The largest dollar give-backs:**

  | trade | MFE → realised | give-back |
  |---|---|---:|
  | APPS 2020–21 | +858 % → +526 % | $1.68M |
  | BBWI 2020–21 | +320 % → +138 % | $1.45M; includes the uncredited VSCO spin-off, #3215 |
  | SATL 2026 | +88 % → −12 % | $1.37M |
  | MMYT 2023–25 | +222 % → +155 % | $1.08M |
  | CVNA 2024–25 | +133 % → +80 % | $0.72M |

### 2.7 First-order replays: what a working trail would have done (§S7, §S8, `out/seeds.txt`)

**What the replay can isolate.** With `reset_anchor_on_stalled_cycle` on, a stalled cycle resets the anchor exactly as
a raise does. So the dates of completed cycles do not depend on the stop level, and restating the MA on the raw basis
changes only each cycle's candidate.

**The method.** The replay applies `0.99 × min(correction low, MA × factor)` at every completed cycle and keeps the
running maximum. It then walks the daily raw bars to the first low that reaches that stop, filling at
`min(open, stop)` (the trigger-bar rule).

**What it ignores:**

- the round-number nudge;
- redeploying the freed cash;
- path changes elsewhere in the book;
- dividends;
- the 14 split-rescaled positions;
- open positions.

| seed | `stop_ma_same_basis` | of realised P&L | earlier exits (of which > +50 % winners) | `correction_must_follow_peak` alone |
|---|---:|---:|---|---:|
| k0 | −$2.06M | −21.5 % | 54 (7, −$2.34M) | −$0.27M |
| k1 | −$2.67M | −15.6 % | 54 (9, −$2.60M) | −$0.33M |
| k2 | −$1.76M | −16.3 % | 50 (6, −$1.50M) | −$0.26M |
| k3 | −$1.77M | −20.4 % | 52 (7, −$2.04M) | −$0.24M |
| k4 | −$2.48M | −20.3 % | 48 (8, −$2.45M) | −$0.26M |

- **The same shared winners carry it in every seed.** DXCM 2019 costs −$0.82M to −$1.00M in all five; AVGO 2013,
  GLNG 2022, BWA 2010, SSTK 2020, R 2023 and NOAH 2017 make up most of the rest.
- **The rest of the earlier exits are mixed.** On k0 the other 47 earlier exits net +$0.14M, and the per-trade delta's
  median is +0.35 % of the exit price (p10 −19.9 %).
- **The anchor fix alone barely binds.** On k0 it moves one position, APPS, which exits 4 days before the rotation at
  53.20 against 57.86: −$0.26M. Rotation pre-empts the trail on the other stale winners.
- **Inside the stale stretches alone, the two fixes together come to −$0.63M on k0** (§S8). The basis fix's full
  effect is the −$2.06M above.
- **Economic scale, a crude bound.** If the lost dollars had compounded at each run's own NAV growth, ln(1 + R) would
  fall by 0.37–0.54. That is larger than the seed SD of 0.225.
- **Path effects can swamp it.** At 26 years they reversed the sign between salts on the hybrid in lane M (−69 pp /
  +98 pp). Only a paired run measures the portfolio effect.

## 3. Why: the exit stack as it actually runs

The record's money, by decision (§F, §S1, §S5):

- **The entry decision** produces 566 trades. Placed names are a coin flip against the skipped names at the same
  screen (row 6). The structural-stop gate turns away 94 % of the top-N, at about the same median forward return as
  the placed names.
- **The initial structural stop** cuts a third of the trades (185 never-raised stop exits) at a mean −10 %: **−$14.72M**.
  84 of them are quick-fails (93 quick-fails in all; 9 had a tightening move first). For the quick-fails, holding
  through would not have helped the median (−7.4 %, §C), so the stop is mostly right. That is the cost of entry.
- **Laggard rotation is the profit-taking exit.** It realises **+$20.75M** over 279 trades and takes 71 of the 102
  winners that reached +30 %.
- **The trailing stop is mostly a passenger.**
  - It rises in 206 of 571 positions.
  - Raised stops sit 15–20 % under the price.
  - Raised-stop exits net +$2.50M over 95 trades, half of them set by tightening moves.
  - For winners it rarely binds before rotation does.

**Why the trail is mostly inert.** Two locks keep it low.

1. **The adjusted-MA basis gap** (§2.3). It is decided by the vintage of the adjusted series: a corporate action years
   later rescales the MA for every earlier date.
2. **The stale anchor** (§2.4).

**Why fixing the locks costs money** (§2.7).

- **Big winners dip below their 30-week MA mid-advance and resume.** On the raw basis, examples:
  - DXCM, 2019-09-10;
  - GLNG, 2022-07-06;
  - AVGO, 2014-10;
  - NOAH, 2017-09;
  - BWA, 2010-05.
- **What the book's rule does with that.** §5.2 puts the stop "below the MA even if the correction low held above it".
  A working trail sells those dips; the locked trail lets rotation sell later and higher.
- **This repeats a known result on the structural-stop record.** It re-derives `project_edge_is_the_fat_tail` and lane
  M's per-trade finding (`project_stop_raise_basis_mix_defect`: "every worse trade a winner cut short") on the record's
  structural-stop config, at first order in 5 of 5 seeds.

**Why the give-back is structural.** A parabolic name runs 50–100 % above its MA, and the book's trail stays under the
MA, so it gives the run back whatever the anchors do:

- SATL 2026 went to +88 % and came back to −12 %. Every completed cycle's candidate was `0.99 × MA`, which stayed
  below the stop until the MA caught up in late May; the run's basis factor was 1.00.
- FOSL 2011 peaked at 134. The anchor fix would have raised its stop only to about 69, and the 2011-08-09 low of 69.57
  missed it. The real exit was rotation at 80.12.

Only rotation, and the Stage-3/4 tightening, protect a parabolic gain.

### Traced end to end (`out/extras.txt` §X4, `out/stopdec_bars.tsv`)

1. **APPS 2020–21: rotation does the work.**
   - **The screen, 2020-06-12** (macro Bullish, breadth Recovering). 225 names passed grade into a binding top-20.
     Two were placed (DECK, APPS) and 17 skipped `No_structural_stop`, among them PENN (+199 % over the next 26 weeks),
     YETI (+106 %) and RH (+86 %).
   - **The ticket and fill.** The decision close, 9.38, sat 51 % above the 30-week MA (6.21); E was 9.17. It filled on 2020-06-15 at 9.25 with a
     `Support_floor` stop at 7.88, sized to $0.50M.
   - **Four stalled cycles.** The genuine MA term, 6.4–7.2 against the 7.88 stop at a factor of 1.00, blocked them.
   - **One raise,** to 8.63 on 2020-07-31, which reset the anchor to that day's close, 13.88.
   - **A stale anchor for 40 weeks** while the price ran to 94.74.
   - **The exit.** Laggard rotation sold it on 2021-05-17 at 57.86: +526 %, +$2.65M. The stop was still 8.63. The
     peak give-back was $1.68M.
2. **DXCM 2019–20: a vintage-frozen trail that protected the tail.**
   - **The basis gap.** The 4:1 split of 2022 makes the factor 4.00 in 2019, so the stop machine read an MA of 34 under
     a price of 155.
   - **Every cycle stalled.** That is 13 completed cycles (2019-08-13 through 2020-08-03), with the stop frozen at
     133.66 for 13 months.
   - **The exit.** Rotation sold it on 2020-08-17 at +173 % (+$0.81M).
   - **On a same-basis MA,** the 2019-08-21 cycle would have raised the stop to 140.50, just under the raw MA of 141.9.
     The 2019-09-10 low of 138.28 hits it, for an exit at −10.5 %: −$0.85M first-order.
3. **CVNA 2024–25: behaviour decided by a corporate action 14 months after the exit.**
   - **The basis gap.** `data/C/A/CVNA/splits.csv` has a 5:1 split on 2026-05-08. So in 2024 the factor is 5.00 and
     the MA reads 19.6 under a price of 122–285.
   - **The stop never moved.** Every cycle stalled; the stale anchor then held from 2024-09-20 to 2025-02-28. The stop
     stayed 116.17 for the whole hold.
   - **The exit.** Rotation on 2025-03-03 at +80 % (+$1.10M).
   - **What that means.** A warehouse built before May 2026 would have run this 2024 trade differently.
4. **SATL 2026: the faithful parabolic give-back.**
   - At the decision of 2026-03-27 the close sat 88 % above the MA.
   - The stop stayed 5.34–5.38 while the price went 6.07 → 10.74 → 5.04. Every candidate was `0.99 × MA`, and the MA
     ran 3.3–6.2, so only the 2026-05-22 cycle cleared the stop (5.34 → 5.38).
   - Stopped on 2026-06-24 at −12.0 %, after an MFE of +88 %.
5. **GME 2020: a born-broken entry.**
   - The decision of 2020-09-04 had a close of 7.65 and an E of 6.95, under the post-breakout correction low of 7.17.
     That made the installed stop `7.17 × 0.96 = 6.88`, 1.0 % under E.
   - The 2020-09-10 bar opened at 6.65, already under the stop. It rose to the fill at 6.95, the bar's high, and closed
     at 6.23. The entry-bar skip withheld the exit.
   - The exit came on 2020-09-11 at the 6.26 open: −9.9 %. The stock then squeezed.
6. **SDA 2023: a deep-pullback fill.**
   - The decision of 2023-06-16 had a close of 21.97 and an E of 11.56: E/close 0.53. The trigger was already met, so
     the stop-limit acted as a limit buy at 11.79.
   - It filled on 2023-07-12, inside a −47 % collapse.
   - Stopped on 2023-07-13 at 10.44: −11.4 %, −$148k.
   - `force_liquidations.sexp` also lists a `Per_position` event that day, at the close of 8.18 (defect D8).
7. **AAON 2023–24: a ticket that crossed a split.**
   - Placed on 2023-03-17 at E 83.42, on the pre-split basis.
   - AAON split 3:2 on 2023-08-17. The ticket was not rescaled.
   - It filled on 2024-02-15 at 83.43, which is 125 on the decision's basis, against a decision close of 89.33.
   - The stop machine started at 55.48, 34 % under the fill. Exit −5.2 %.
   - It is the only split-crossing fill in k0 (§X3).

### Cohort splits poked before believing them

Each cohort was perturbed by moving its cutoff (`feedback_perturb_before_believing_a_cohort_split`). Each one fails:

| cohort | at the original cutoff | after the cutoff moves |
|---|---|---|
| initial stop < 2 % of E (all have E under the decision close, §G, §X3) | 18 trades, −$474k, 11 stopped within 5 days | +$685k at < 4 % (ADSK +292 % enters) |
| E/close < 0.90 | 7 fills, all losers, −$679k | +$1.55M at < 0.92 (MMYT +155 % enters) |
| extension above the MA (§G) | ≥ 35 %: 32 trades; stop-out and quick-fail rates climb monotonically with extension (37 → 88 %, 9 → 65 %) | the ≥ 50 % band nets +$1.61M on APPS |
| fill at the top of the stop-limit band (§G) | 108 fills, quick-fail 31 % vs 12 %, median −4.7 %; net +$0.54M with MMYT | — |

All four cohorts have n below the ~230 a tail statistic needs. These are observations and detector candidates, not
levers.

## 4. How it fits what we know

- **Re-derived on the record:**
  - `project_edge_is_the_fat_tail`. A working trail sells the record's shared monsters on their dips below the MA.
    Rotation, the exit that lets them run, carries the P&L.
  - `project_stop_raise_basis_mix_defect` (lane M) finds the same fix cutting the same kind of winner, on a different
    config (structural stops plus rotation) and across 5 seeds at first order.
- **Refined:**
  - `project_stop_raise_basis_mix_defect` / #2982. The defect is the main reason trails do not rise: 84 % of stalled
    cycles and 91 of the 125 never-raised long holds. It also makes behaviour depend on the vintage of the adjusted
    series (CVNA). The era confound is checked: the gradient holds inside each era.
  - `project_decision_walkthrough_next` (09-26):
    - the shakeouts disappear with the fallback stop;
    - picks ≈ alternatives holds;
    - the Bullish-week shortfall moved from 2020–26 to 2016–19 and 2023–26.
  - `project_2025_anatomy` and `project_recovery_reentry_gap` are consistent: 2023–26 is holdings at two-thirds
    invested; low-exposure Bullish weeks cost in 2009–15.
- **Confirmed:**
  - `project_envelope_knobs_dead`. The book is above 70 % invested on 45.7 % of days and reached 101.0 % on 2024-10-18,
    and 250 of the 566 filled tickets were placed while it was above 70 %. The spec's `max_long_exposure_pct 0.70` and
    `min_cash_pct 0.30` are inert.
  - `project_floor_and_refresh_screens`. Skips have no median edge, and the binding gates are the top-20 cut and the
    structural-stop gate.
  - `project_base_broken_is_age`, whose breach depth matches the deep-pullback fills.
  - `project_exit_stack_survives_fixed_basis`. Rotation is the profit engine.
- **Contradicted (a record defect, not a finding).**
  - `dev/experiments/concentration-deploy-2026-09-13/README.md` explains c2's bit-identical result as "the book never
    reaches the 70 % exposure ceiling or the 30 % cash floor". On the record the book exceeds 70 % on almost half of
    all days.
  - The real reason is that both knobs are inert. Its conclusion ("deploy more does not exist at this per-position
    size") stands.

## 5. What it implies next (options; the choice is the user's)

1. **Decide what the trailing stop is meant to be on the record, then cost it.**
   - **What the walk shows.** The record's effective exit rule is the initial structural stop plus laggard rotation
     plus tightening. The trail mostly does not bind, and when it would, the vintage of the adjusted prices decides.
   - **The cheaper option, (a): keep the de-facto rule.** Treat the warehouse's adjusted-price vintage as part of the
     record's identity: keep v12wk, record its build date, and expect a data refresh that adds splits to move old
     trades.
   - **The other option, (b): make the trail basis-clean** for reproducibility (`stop_ma_same_basis`). That is a K = 5
     paired 26-year run, about 22 hours of cell wall per arm. The first-order prediction is −16 to −22 % of realised
     P&L in every seed, carried by DXCM, AVGO, GLNG, BWA, SSTK, R and NOAH. Pre-register it as a correctness change
     with its measured cost, not as a return lever.
   - **Not worth a run on its own:** `correction_must_follow_peak`, at −$0.24M to −$0.33M per seed.
2. **Record the tightening reason, then decide whether the tightening exits are worth a screen.**
   - **The build.** Add the `Tightened` reason (Stage 3 / Stage 4 / MA flat / MA falling in Stage 2) to `Stop_decision.t`.
     It is a small harness change.
   - **The screen.** Then screen the 38 stop exits that came within 10 days of a tightening move (24 after
     `Entered_tightening`, 14 after `Tightened_ratchet`) by trigger.
   - **The priors.** Tightening is book §5.2 (STAGE3_TIGHTENING), and the threshold `ma_flat_threshold 0.002` is a
     dial. The prior on holding longer is mildly positive (tail-preserving). Rotation would still pre-empt many of them.
3. **Pack detectors, no lever:**
   - "initial stop < 2 % of E";
   - "E ≥ 10 % below the decision close";
   - "trail never raised with factor ≥ 1.05", which flags a vintage-frozen trail.

   These surface the §3 specimen classes without anyone having to look for them (`backtest-result-review.md`, "what
   the eye catches becomes a detector").
4. **Spec and record hygiene.**
   - Drop or label the two inert envelope overrides in the record specs.
   - Correct the concentration-deploy README's mechanism sentence.
   - Neither moves any result.
5. **For entries and selection: nothing. Stop here.** The walk re-derives the known closures:
   - picks are a coin flip;
   - structural-stop skips have no median edge;
   - the macro gate is not the loss;
   - the 2023–26 lag is holdings.

   No new entry lever is indicated.

## 6. Defects and opportunities found, with specimens

| # | kind | finding | specimen and decision record | issue |
|---|---|---|---|---|
| D1 | strategy defect, load-bearing | The trailing-stop candidate mixes an adjusted MA with raw prices. It decides 461 of 550 stalled cycles (162 positions) and 91 of 125 never-raised long holds. Behaviour depends on the vintage of the adjusted series. The first-order fix costs −$1.8M to −$2.7M per seed | DXCM-wein-953: 13 `Cycle_stalled` rows, 2019-08-13 → 2020-08-03, MA 34–93 vs stop 133.66, factor 4.00. CVNA-wein-1247: factor 5.00 from the 2026-05-08 split (`out/stopdec_bars.tsv`) | #2982 (closed, defect + flag). The basis-consumer test belongs to **#2973** (open). The vintage dependency is **new** |
| D2 | strategy defect, small | Stale anchor after a cycle reset: pullbacks above the reset close are invisible and the phantom guard rejects every recovery. 37 positions; 12 stretches ≥ 13 weeks, all rotation-exited winners. First-order −$0.24M to −$0.33M per seed | APPS-wein-1018: `Anchor_not_fresh` / `Correction_not_recovered` with `last_correction_extreme` 13.88 from 2020-08-07 to 2021-05-14 while the trend extreme ran to 94.74 | **new** (flag `correction_must_follow_peak` exists, #2996) |
| D3 | recording gap | `Stop_decision.t` does not carry the tightening trigger. 80 positions tightened; 24 were stopped within 10 days of `Entered_tightening` (+10.7 % over 13 weeks after) | MMYT-wein-1184: `Entered_tightening` 2025-02-24 (stop +0.5 %), stopped 2025-02-25 at 95.86 (+155 %), +8.9 % over 13 weeks after. ON-wein-268: jump +39.5 %, then −32 % (the tighten was right) | **new** (harness) |
| D4 | entry geometry | E under the post-breakout correction low gives a 0.1–1.9 % stop: 18 trades, −$474k, 11 stopped within 5 days. Fails the cutoff shift | GME-wein-1025: decision 2020-09-04, E 6.95, close 7.65, floor 7.17 → stop 6.88; filled 2020-09-10 at the bar's high, open 6.65 already under the stop | **new** (detector, not lever) |
| D5 | entry geometry | Deep-pullback fills: a triggered stop-limit with E ≥ 10 % under the close becomes a limit buy that fills in a collapse. 7 fills, all losers, −$679k. Fails the cutoff shift (MMYT) | SDA-wein-1168: E/close 0.53, filled 2023-07-12 inside a −47 % fall | none: consistent with #2407's breach depth (closed, no-build). Observation |
| D6 | split basis | A resting ticket is not rescaled at a split. It fills about 40 % above its decision price, with a stop 34 % under the fill. 1 of 566 fills, −$85.6k | AAON-wein-1156: placed 2023-03-17, split 2023-08-17 ×1.5, filled 2024-02-15 | #3075 (closed): flag `cancel_resting_entry_on_split` (#3108); its [after-merge] 26y liveness run never ran |
| D7 | spec / record | `min_cash_pct 0.30` and `max_long_exposure_pct 0.70` in the record spec are inert. The book reaches 100 %. The concentration-deploy README states a false mechanism for c2 | 2025-01-02: 8 positions, $16.09M of $16.15M NAV; SKYT-wein-1318 placed 2024-12-27 at 92.8 % invested (`out/extras.txt` §X2) | known (`project_envelope_knobs_dead`). The README correction is **new** (docs) |
| D8 | artifact | `force_liquidations.sexp` records long `Per_position` events on days when the trigger-bar stop already filled, so `force_liquidations_count 2` overstates it. P&L is unaffected | SDA 2023-07-13 (event at the close, 8.18; stop exit 10.44) and SIRI 2023-07-25 (event at 5.13; exit 5.96) | **#3206** (open, verify/pending): the long-side specimens of the same-day collision |
| D9 | data, proxy only | Vendor-series errors produce absurd forward returns in the screen proxy (none traded in k0). They are why §B reports medians and quantiles, not means | NDN 2011-10 (+57,881 % over 26 weeks), BELM 2005, LAF 2006, NTO 2007, KRTX 2023-12 (`out/fwd.tsv`) | **#3239** (open) |
| D10 | accounting | BBWI's give-back includes the uncredited VSCO spin-off. The basis replay's only sizeable gain (+$110k) is that day | BBWI-wein-1021: replay exit 2021-08-03 | **#3215** (open) |
| — | not a defect | 11 entry-bar `Stop_hit` rows withheld by `stop_skip_entry_bar` (#2642); 7 were stopped out the next trading day, the other 4 later | GME, CRON, CENX, ISPH, … (§S1) | — |

**Opportunities.** None for return, on the evidence here. Each stop-side change that would make stops rise more often
prices negative at first order in every seed, which is the fat-tail law again. The only open questions this walk adds
are D3 (decompose the tightening exits once the reason is recorded) and the reproducibility choice in §5 item 1.

## Files

Committed: this README, `walk-rk.sh` + `lib/` (host-only, ~3 min), and the text outputs under `out/` (`tables.txt`, `stops.txt`, `extras.txt`, `seeds.txt`, `walk-YEAR.txt`). Not committed: `out/records.txt` (8 MB audit dump) and the `.tsv` intermediates (some carry bar prices); `walk-rk.sh` regenerates them. Paths above under `.sweep-output/walk-rk-k0/` are the local run; `out/` here is a copy of the same files.
