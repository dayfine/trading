# path-stability-2026-10-23: #3404 Step 2, pre-registered

Status: **RUN 2026-10-23/24; read below (§Results).** The text down to §Results is the pre-registration as committed at
`a8ba322fc` (then: "PRE-REGISTERED, NOT RUN"). The chain is launched by the dispatcher when the container is free (no agents, no other backtest), after #3406
(Step 1, `Seeded` tiebreak) merges: `launch` aborts otherwise.

The read rule is `dev/plans/path-stability-fixes-2026-10-23.md` at commit `b5ce359b7` (#3407, the amended plan), §"Step 2",
§"Metrics" and §"Decision rule". Those three sections are copied verbatim below. Where the plan left a detail open, the
choice made before any run is listed under "Implementation choices"; nothing there changes an arm, K, the window or a
threshold.

## How to run

```sh
sh dev/experiments/path-stability-2026-10-23/chain.sh launch    # pins .claude/worktrees/sweep-ps at origin/main, starts `run`
tail -f /tmp/ps-run/chain.log
# afterwards (run does these itself at the end; rerunnable):
sh dev/experiments/path-stability-2026-10-23/chain.sh collect dev/experiments/path-stability-2026-10-23/results
sh dev/experiments/path-stability-2026-10-23/chain.sh summary dev/experiments/path-stability-2026-10-23/results
sh dev/scripts/perf_long_cells.sh update /tmp/ps-run/chain.log
```

`sh chain.sh validate` (parse + override check of the four p0 specs and a negative control) needs a built run tree and
the warehouse in the container; it was not run by the author.

## Pre-registered design (verbatim from the plan at `b5ce359b7`)

#### Step 2: the stability experiment (one chain, after Step 1 merges)

**Arms.** Four, on one pinned build:

| arm | tie order | `entry_fill_size_to_available` | `max_position_pct_long` | role |
|---|---|---|---|---|
| A | Alphabetical | false | 0.14 (record) | reference: today's yardstick |
| S | Seeded | false | 0.14 | **null**: honest noise |
| SR | Seeded | true (min fraction 0.5) | 0.14 | candidate stabiliser: resize |
| SC | Seeded | false | **0.07** | candidate stabiliser: capacity, about twice the names at half the size |

**Perturbations.** K = 6 per arm:
- p0: unperturbed;
- p1–p5: each deletes **one traded, minor name** from the lists.
  - The five names are fixed by rule before any run: from arm A p0's trade list on the window, the five traded symbols
    with the smallest |total-return P&L|, ties broken by ticker.
  - The same five deletions are used in every arm.
- In S, SR and SC, each perturbation pk also sets `tiebreak_seed = k`, so the tie draw varies along with the list.
  In A the seed is inert.

**Window and universe.** Top-3000 PIT v12 schedule, 2019-01-01 → 2024-12-31 (6y), record spec (`rb1-26.sexp` body)
with the window changed.

**Cost.** 24 cells at about 1.7 h each (1,031 s per simulated year, #3381) ≈ **41 h**, sequential, alone in the
container.

**Validity.** Each perturbed cell is gated on `validator_diff -check V6` against its arm's p0. Each arm's p0 is gated
on V6 against A p0. A mismatch excludes the cell and names the specimen.

#### Metrics (pre-registered)

Per arm, over its K = 6 cells:

- **spread** = SD of ln(1 + total return) (primary), with the max − min range as secondary;
- the median ln(1 + R), Sharpe and max DD (secondary, read only for do-no-harm);
- **divergence onset:** for each p1–p5, the first date its NAV differs from the arm's p0 (descriptive).

#### Decision rule (written before any run)

- **Yardstick (A vs S).** Report spread(S) / spread(A). If it is ≥ 1.5, the alphabetical yardstick is recorded as
  understating path noise. From then on, chains measure noise with seeded perturbations (seeds plus list deletions)
  in place of path salts.
- **Seeded order as the default.** Seeded removes an arbitrary A→Z bias. It is recommended as the new default **on
  user approval as a correctness fix**, whatever its spread or return. This is an explicit exception to
  `experiment-flag-discipline.md` R3, recorded here.
- **Stabiliser (SR, SC vs S).** An arm **stabilises** if:
  - spread(arm) ≤ 0.6 × spread(S); **and**
  - its median ln(1 + R) is not below S's median by more than spread(S).

  A ratio between 0.6 and 0.85 is "inconclusive", never a win.
- **Promotion.** A stabilising arm is recommended for default on user approval, the same R3 exception.
  - If both stabilise, the recommendation is the one with the smaller spread. A combined SRC cell set is a follow-up
    only if both pass.
  - SC changes sizing, which the June capacity surface showed trades return for drawdown. So its do-no-harm read also
    reports max DD and Calmar against S. A stabiliser that deepens the median max DD by more than spread(S) in
    percentage points is reported "stabilises with a DD cost": a user decision, not an automatic recommendation.
  - Promotion moves the record, so it is followed by the record re-baseline (with #3388 if decided by then).
- **Small n.** K = 6 gives a wide CI on an SD. The thresholds are set so that only a large effect counts.


## Implementation (what the chain does)

- **Specs.** `specs/ps-<arm>-p0.sexp` = the `rb1-26.sexp` body (`../breadth-fix-rb1-2026-10-11/specs/`, the record N),
  name and description changed, window `2019-01-01 → 2024-12-31`, the full 1999–2025 top-3000 pit-v12 schedule kept
  (main's #3391-deduped lists), plus the arm's overrides:
  - A: `((screening_config ((candidate_ranking Alphabetical))))` (the default, stated explicitly);
  - S: `((screening_config ((candidate_ranking Seeded) (tiebreak_seed 0))))`;
  - SR: S plus `((entry_fill_size_to_available true))` and `((entry_fill_min_size_fraction 0.5))`;
  - SC: S with `max_position_pct_long` 0.14 → 0.07 (`max_long_exposure_pct` 0.70 and `min_cash_pct` 0.30 unchanged).

  Knob paths are #3406's (`Screener_ranking.Seeded`, `screening_config.tiebreak_seed`, pinned in its
  `test_seeded_tiebreak_overlays.ml`). No A-D fixture swap: every cell reads the run tree's test_data (main's fixture).
- **Order.** Sequential, one cell at a time: preflight of the four p0 specs (2024-10-01 → 2024-12-31), A-p0, the
  perturbation names, A p1–p5, then S, SR, SC each p0–p5. 24 cells, tag `ps-<arm>-p<k>-s0`, path salt 0 everywhere.
- **Perturbation names, by rule, after A-p0.** From `ps-A-p0-s0-trades.csv`: per symbol, total-return P&L = sum over its
  rows of `pnl_dollars + dividends_received`; the five with the smallest |total-return P&L| (rounded to cents), ties
  by ticker. Written to `results/perturb-names.txt` (k, symbol, P&L, trades, lists holding it) with the whole ranking
  in `results/perturb-ranking.csv`. pk deletes the k-th name from all 27 scheduled lists; each cut list is checked to
  differ from the original by exactly that symbol's entries. In S/SR/SC, pk sets `tiebreak_seed k`; A sets no seed.
- **Warehouse.** `/tmp/snap_top3000_pit_v12wk` (the #3266 rerun's build) reused: its manifest must hold 9,236 symbols
  and equal the set derived from the run tree's lists; every cell's cache line must read `n_symbols_absent=1` (MEL),
  else the cell is VOID.
- **V6 gates.** `validator_diff -check V6`: each pk vs its arm's p0, each S/SR/SC p0 vs A-p0. Exit 1 (mismatch) or 2
  (a report missing or unreadable) logs `EXCLUDED <tag>` with the specimen; the chain continues. `summary` drops
  EXCLUDED, VOID and failed cells.
- **Cell guard.** `CELL_TIMEOUT=14400 s`: the slowest same-spec cell ran 39,142 s over 26 y (#3381) ≈ 1,505 s/yr, so
  6 y ≈ 9,030 s, ×1.5 ≈ 13,545 s, rounded up to 4 h. The #3266 rerun cell measured 1,031 s/yr
  (`dev/status/perf-long-cells.csv`, row `v3266-Mpre3339-s0`), so a cell should take about 1.7 h and the chain about 41 h.
- **Review packs.** One per arm, from its p0, under `.sweep-output/review-ps-<arm>-p0/` (site + rendered PNGs), to be
  looked at before the read (`backtest-result-review.md`).

## Implementation choices (plan details left open, fixed here before any run)

1. **"|total-return P&L|"** is the trades.csv sum `pnl_dollars + dividends_received` per symbol (the review pack's
   `tradeTR`, #3175: `pnl_dollars` is price-only). Cash interest is in no trade row.
2. **Names held at the window end are not eligible.** A symbol in A-p0's `open_positions.csv` has part of its P&L
   unrealised and outside trades.csv, so its |total-return P&L| is not known from the trade list. A traded symbol in
   no scheduled list (impossible in practice) is also skipped. Both are marked in `perturb-ranking.csv`.
3. **Spread** is the sample SD (n − 1) of ln(1 + R), R = `total_return_pct` / 100, over the arm's included cells.
4. **"Deepens the median max DD by more than spread(S) in percentage points"** is read as median max DD(arm) −
   median max DD(S) > 100 × spread(S) pp (spread is in log units, about a fraction).
5. **Divergence onset** is the first equity-curve date at which a pk's portfolio value differs from its arm's p0 at
   all (the written cents differ), or "never".
6. **How a perturbed cell sees its lists.** Universe paths resolve under `--fixtures-root`, so a perturbed cell runs with
   a container fixtures root (`/tmp/ps-fix`) that symlinks every entry of the run tree's and adds `ps-lists/p<k>/`;
   its spec's universe paths point at `ps-lists/p<k>/`. p0 cells use the run tree's fixtures root unchanged.
7. **V6 exit 2** (a partner report missing or unreadable) excludes the cell like a mismatch: the gate could not pass.
8. The 20 generated specs are not preflighted (they differ from a preflighted p0 spec only by name, list paths and
   seed); a parse error fails in seconds and is logged as GUARD-KILLED/FAILED.

## Results

Read by results-analyst; numbers spot-checked by the dispatcher against the committed artifacts. Raw `trade_audit.sexp`
files are reduced by `collect` (`*-audit_entries.csv`, `*-cash_rejections.csv`); the extracts that read the raw audits
and the packs are in `results/read/` with the scripts that regenerate them (`ps-analysis.sh`, `regime.awk`).

**Run.** Pre-registration `a8ba322fc`, rule = plan at `b5ce359b7`, run tree HEAD `3db869d32`, 2026-10-23 20:55 →
10-24 19:49 PT. All 24 cells RESULT, 0 excluded, 0 void (`results/chain.log`). Every cell reads `n_symbols_absent=1`.
All 23 `validator_diff -check V6` gates exit 0 and V6 = 0 in all 24 reports, so every pair below is V6-clean. Cell
wall 2,360–4,794 s, 21.8 h in all (plan estimate 41 h). Deleted names (`results/perturb-names.txt`): p1 SHEN, p2 ODFL,
p3 SLAB, p4 DECK, p5 DIOD.

### 1. The rule, as written

ln(1+R) per cell (`results/summary.txt`):

| arm | p0 | p1 | p2 | p3 | p4 | p5 | spread (SD) | range | median | med. Sharpe | med. maxDD % | med. Calmar |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A | 0.985 | 0.978 | 0.940 | 0.983 | 0.970 | 0.975 | 0.0167 | 0.046 | 0.9764 | 0.787 | 27.44 | 0.643 |
| S | 0.673 | 1.177 | 0.945 | 0.837 | 1.118 | 1.203 | 0.2108 | 0.530 | 1.0313 | 0.838 | 23.29 | 0.674 |
| SR | 0.619 | 0.967 | 0.984 | 0.620 | 1.082 | 1.031 | 0.2088 | 0.463 | 0.9755 | 0.797 | 25.36 | 0.634 |
| SC | 0.535 | 0.688 | 0.579 | 0.650 | 0.601 | 0.875 | 0.1205 | 0.340 | 0.6256 | 0.600 | 20.36 | 0.521 |

Scale: SPY total return on the window is +158.4 % (ln 0.949, 17.1 %/yr). S's median is 18.8 %/yr, its seeds span
11.9–22.2 %/yr; A's six cells span 17.0–17.8 %/yr; SC's median is 11.0 %/yr.

- **Yardstick.** spread(S)/spread(A) = **12.6** ≥ 1.5: the alphabetical yardstick understates path noise. From now on,
  chains measure noise with seeded perturbations in place of path salts.
- **Seeded as the default.** Recommended for user approval as a correctness fix (the rule's R3 exception). The A→Z
  bias is measurable (`results/read/letter-mix.txt`): A-tickers are 17.4 % of A-p0's 138 trades vs 10.0–14.3 % in the
  six S cells and 9.5 % of the 1999–2025 list union (10.4 % on the 2018–24 lists in force; reproduced by qc-results from the lists, not in a committed extract); A–F tickers 43.5 % vs 34.6–37.9 %.
- **SR.** Ratio **0.99** > 0.85: **does not stabilise.** (Do-no-harm would have passed: median 0.976 vs 1.031.)
- **SC.** Ratio **0.57** ≤ 0.6, but its median 0.626 is **0.406 below** S's, more than spread(S) = 0.211: do-no-harm
  **fails**, **does not stabilise.** No DD cost (median max DD 20.4 % vs 23.3 %); median Calmar 0.52 vs 0.67.
- **Promotion.** No arm stabilises; nothing to promote; the SRC follow-up does not trigger.
- **Small n.** 90 % intervals on the SD ratios (F(5,5)): S/A 5.6–28; SR/S 0.44–2.2; SC/S 0.25–1.28.

Divergence onsets: in A, each pk diverges on A-p0's entry date for its deleted name (2019-07 → 2024-02). In the
seeded arms, p1/p4 diverge 2019-02-26, p3/p5 2019-02-28, p2 2019-05-09, identical in S, SR and SC.

### 2. Verdict, calibrated

- **Yardstick: robust.** Every leave-one-out ratio stays in 9.2–39.3. Within S the seed is confounded with the list
  deletion, but every seeded onset precedes the first deleted name's first entry (2019-07-24), so the seed is the
  first-order term.
- **Seeded default.** A rule recommendation, not a return claim: A-p0 (0.985) sits inside S's six draws (0.673–1.203).
  Alphabetical order freezes one draw; it does not shift the level.
- **SR.** Resizing at min fraction 0.5 does not reduce seeded spread on this window. Its paired level gap (−0.108 log,
  5 of 6 seeds) is two displacement events (§3.3), not a return verdict.
- **SC.** Its return cut is robust in this design (6 of 6 seeds, mean −0.338 log, about −7.8 pp/yr at the medians). Its
  spread pass is not: 3 of 6 leave-one-out drops land in the inconclusive band, and it is proportional to its level.
- **Cannot say:** anything outside 2019–2024 or top-3000 PIT v12, or the seeded spread at 26 y (unmeasured).

### 3. Why

**3.1 The window's return is three trades plus one open position.** In A-p0, ADMA ($526k), APPS ($397k) and GLNG
($153k) carry $1.08M of total-return P&L; the other 135 trades net +$3k. End unrealised P&L is $521k, mostly MMYT,
open since 2023-10-26 in all 24 cells (`results/read/tail-decomposition.txt`). A cell's level is set by which of the
three it catches.

**3.2 Two gates decide which tails a cell catches** (`results/read/tie-cut-traces.txt`):

| seed | S | SR | SC | ADMA top-20, 2023-08-18 | GLNG top-20, 2022-02-04 | APPS 2020-06-12 (S / SR / SC) |
|---|---|---|---|---|---|---|
| 0 | 0.673 | 0.619 | 0.535 | **cut** | in | no cash / no cash / no cash |
| 1 | 1.177 | 0.967 | 0.688 | in | in | placed / placed / no cash |
| 2 | 0.945 | 0.984 | 0.579 | in | **cut** | placed / placed / no cash |
| 3 | 0.837 | 0.620 | 0.650 | **cut** | in | placed / no cash / placed |
| 4 | 1.118 | 1.082 | 0.601 | in | in | placed / placed / no cash |
| 5 | 1.203 | 1.031 | 0.875 | in | in | placed / no cash / placed |
| A, all six | 0.940–0.985 | | | in ×6 | in ×6 | placed ×6 |

- **Gate 1: the top-20 cut lands inside a tie group.** `max_buy_candidates` = 20 binds in all 277 decision weeks of
  every cell, and 91–92 % of admitted slots are then skipped as `No_structural_stop`. ADMA, 2023-08-18: 11 names score
  97–110; the last 9 slots go to a score-95 tie group of at least 12. Seeds 0 and 3 cut ADMA; only R, ADMA and PKG of the
  20 have a structural stop. GLNG, 2022-02-04, is the only placeable name of its 20, and seed 2 cuts it. The cuts are
  identical in S, SR and SC at each seed.
- **Gate 2: cash at placement.** APPS is top-20 in all 24 cells and placed in 16; in the other 8 the entry walk skips
  it as `Insufficient_cash`, a state built by the cell's earlier draws.
- **Alphabetical is frozen, not stable.** It settles every boundary the same way, so all six A cells catch all three
  tails; a deleted minor name moves the path only from its own entry date (worst: ODFL, −0.046 log in ten months). A
  seed re-draws every boundary, so each seed is a different draw of the same tail lottery.

**3.3 Why SR does not stabilise.** The resize acts only on at-fill refusals (9–14 per S cell, 72 in all; after SR 6–10,
1 at least half funded). It touches neither gate 1 nor gate 2 (128–156 placement-time `Insufficient_cash` skips per S
cell). Each saved ticket commits cash a later candidate needs: at seed 3, SR fills DKS (2019-11-07) and LACO
(2020-05-27), then cannot place APPS (2020-06-12): +$22.4k saved (total return; $21.9k price-only), −$389k displaced. Seed 5 repeats it (−$387k).

**3.4 Why SC cuts return.** Same seeds, same gate-1 results, smaller stake (trades joined on symbol and entry date):

| seed | shared trades | S on shared | SC on shared | SC/S quantity | S-only | SC-only (n) | Δ end unrealised |
|---|---|---|---|---|---|---|---|
| 0 | 140 | $356k | $217k | 0.73 | −$3k | +$52k (52) | −$176k |
| 1 | 125 | $1,061k | $586k | 0.61 | +$389k | +$33k (54) | −$411k |
| 2 | 127 | $660k | $377k | 0.63 | +$295k | +$93k (60) | −$300k |
| 3 | 135 | $563k | $460k | 0.70 | +$62k | −$1k (50) | −$235k |
| 4 | 127 | $812k | $447k | 0.59 | +$474k | +$21k (56) | −$407k |
| 5 | 131 | $1,417k | $937k | 0.68 | +$40k | −$12k (49) | −$399k |

- The tails pay about half (ADMA $267–350k vs $518–624k; MMYT held at about half size). APPS is lost in three more
  seeds. The names do not double: SC averages 6.7 positions vs 5.3 at p0, and its 49–60 extra trades net about zero.
- Exposure by SPY regime and period, p0 cells (`results/read/regime-split.txt`):

| p0 cell | 2019–21 UP (SPY +49.4 %) | 2019–21 DOWN (SPY +47.5 %) | 2022–24 UP (SPY +27.2 %) | 2022–24 DOWN (SPY +10.4 %) | invested |
|---|---|---|---|---|---|
| A | +72.6 % @ 60 % | +10.4 % @ 46 % | +45.9 % @ 71 % | +4.9 % @ 37 % | 58 % |
| S | +49.3 % @ 66 % | +10.9 % @ 44 % | +20.5 % @ 68 % | +3.0 % @ 34 % | 59 % |
| SR | +45.6 % @ 66 % | +11.1 % @ 44 % | +18.2 % @ 69 % | +3.0 % @ 34 % | 60 % |
| SC | +46.9 % @ 61 % | +11.9 % @ 38 % | +14.0 % @ 62 % | +0.6 % @ 24 % | 53 % |

  SC is less invested in every regime and both periods; its shortfall sits in 2022–24 UP days, more than the exposure
  gap explains (the half-size open book does the rest). A-p0 vs S-p0 is UP-day holdings (APPS, ADMA), not cash.
- SC's lower spread is the same draw at smaller stakes: its seeds rank like S's (correlation 0.69), spread/median 0.19
  vs 0.20, paired SC − S mean −0.338 log, 6 of 6 negative.

**3.5 Perturbation checks.** Leave one out: S/A 9.2–39.3; SR/S 0.83–1.15; SC/S 0.29–0.74.

### 4. How it fits what we know

- `project_26y_path_noise_floor`: confirmed and refined. One cell is one draw; the 6-year seeded SD alone is 0.21; the
  26-year seeded spread is unmeasured.
- Ledger `2026-06-30-tiebreak-noise-floor`: confirmed (tie order is a large selection variance that grows with
  breadth). Its forward directive, capacity as the variance reducer, is refined: at a 7 % cap the tails halve.
- `project_record_gap_is_concentration`, capacity-concentration BROAD: confirmed; P&L tracks quantity on shared trades.
- `project_funding_grid_monster_lottery`, chain V (#3383): re-derived; saved tickets are median-sized, displacement is
  monster-sized.
- `project_monster_funnel_top_of_funnel`, `project_top_n_capacity_verdict`: extended; the cap binds every week and
  91 % of its slots go to names that are then unplaceable. ADMA is the boundary specimen in both.
- `project_screener_alphabetical_tiebreak`: **contradicted** — on top-3000 the bias over-selects A-tickers and boundary
  ties decide two of its three tail trades (ADMA, GLNG).
- `project_edge_is_the_fat_tail`: confirmed.

### 5. What it implies next (options; the choice is the user's)

1. **Measure noise as the rule now says:** K ≥ 5 seeds per arm, paired by seed (arms share each seed's draws:
   correlation 0.87 SR, 0.69 SC; paired SD 0.11–0.15 vs 0.21 unpaired). At K = 6 a 6-year lever read resolves about
   ±0.09–0.13 log at 2 SE.
2. **Seeded default** (correctness; user approval), then re-baseline the record as K seeds. On this window 3 of 6 seeds
   beat SPY. `config-default-blast-radius` applies.
3. **Act on gate 1:** a top-N cap counted in placeable names (no such dial exists), or the existing
   `support_floor_anchor_scope Nearest` dial (pre-registered as `../floor-nearest-2026-10-25/`, #3418, running).
4. **Accept the noise** as intrinsic to a ~5-slot book on a fat-tailed edge, and measure it (option 1).
5. **Before the next 26-year verdict,** run a 26-year seeded null on the record config.

### 6. Defects found

1. **V12 and `stop_fill_distance_pct` mix split bases** (left over from #3127/#3256). `results/ps-SC-p0-s0-validator.sexp.sexp`:
   NVDA 2021-05-24 installed_stop 567.69 vs fill 154.55 (4:1 split 2021-07-20); SNX in the p1 cells (factor 2.0,
   2020-12-01). P&L unaffected; false V12 FAIL rows.
2. **V13 counts delisting exits as fills on a day with no bar** (`_v13_leg`, no waiver). S-p0: MIME-wein-200 (exit
   2022-05-20, last bar 05-19), LACO-wein-168 (exit 2020-10-09, last bar 10-08). Reporting only.
3. **Cash-rejection `available` is gross cash** (`cancel_handler.ml:272`, `current_cash`), while the G2b clamp budgets
   cash plus paper losses minus commission. `results/ps-SR-p1-s0-cash_rejections.csv` ADNT-wein-122 shows 0.79 funded
   yet was refused under a 0.5 minimum. Funding-fraction counts overstate spendable cash.
4. Known, #3215: BBWI held across the 2021-08-03 VSCO spin-off in all 24 cells; uncredited.
5. To check (#3239 class): SNX's 2020-12-01 split factor 2.0 falls on the Concentrix spin-off date.

### Review-pack look

`.sweep-output/review-ps-{A,S,SR,SC}-p0/`, 61 images (`top.png`, `part-1…14.png` each, plus SC `part-15.png`), pack SHA `3db869d32`.

- Every chart spans 2019-01-02 → 2024-12-30. KPI strips match `actual.sexp` (A +168 % / −27.4 % / 0.79 / 138 trades;
  S +96 % / −17.1 % / 0.63 / 150; SR +86 % / −17.1 % / 0.58 / 153; SC +71 % / −16.3 % / 0.54 / 192). No mojibake, NaN
  or empty panels.
- Config-implied zeros are zero: 0 fallback stops, 0 stop exits on a later open, 0 Saturday fills. "Filled against the
  macro" (A 2, S 1) are Bullish-week tickets filled after the screen turned, allowed with `entry_ticket_macro_suspend`
  off.
- Odd rows traced: SC's V12 NVDA row (defect 1); V13 counts vs the pack's 0 (defect 2); S-p0's flat NAV in late
  2022–2023 is two zero-exposure stretches earning T-bill interest, not a marking stall.
- Signals (RV3): **Eras vs SPY** (A 1.04×, S 0.76×, SR 0.72×, SC 0.66×; seeded packs blame 2019–21 cash through the
  rebound) — **refined**: that is seed 0's draw; A-p0 leads on UP days because it holds APPS. **Return rests on open
  positions** — **confirmed** (MMYT in all 24 cells, CVNA). **Ten trades made $1.73M** (A) — **confirmed**, three carry
  it. **Entries cancelled at the fill for cash** — **refined** by defect 3. **Gate reopens** — none flagged.
- Limit: the packs are single-run and cannot show the seed spread; a pack with an arm's p0–p5 as runs would.

**Published packs (RV1):** [A](https://claude.ai/artifact/FiprVgeUujbVRmN8rjj6r9) ·
[S](https://claude.ai/artifact/Vm8SLjNXLGQ8y2nqMVdSZX) · [SR](https://claude.ai/artifact/CYr3dRhjUDJRNPbgLQTden) ·
[SC](https://claude.ai/artifact/THzJ9tVfVexzAtWGk9ThSz) (private to the owner until shared).

### Record

- **User decision, 2026-10-25:** Seeded tie order (seed 0) approved as the default, the rule's correctness exception
  (#3404 comment). The flip PR and a K-seed record re-baseline follow.
- **G2b (`entry_fill_size_to_available`):** not a stabiliser at min fraction 0.5. It stays a default-off axis
  (REJECT-as-stabiliser, keep-as-axis; not retirement-eligible).
- **§5.1 note:** "K ≥ 5 seeds" leaves open whether the list deletions are kept; this design cannot separate deletion
  noise from seed noise (seeds act first), so the next chain should state its choice.
- `results/lists.md5` is committed as `results/lists-md5.txt` (same content; the extension kept the PR in the
  results-only lane). `chain.sh` still writes `lists.md5` and is left as pre-registered.
- Memory: `project_path_stability_seeded_noise`. Defects §6 items 1–3 are filed as #3420.
