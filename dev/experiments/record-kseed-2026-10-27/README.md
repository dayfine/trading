# record-kseed-2026-10-27: the record as K = 5 tie-order seeds on the Seeded default

**Pre-registration.** Nothing has run. Everything below is fixed before the first cell launches.

## Why

The path-stability read (`../path-stability-2026-10-23/`, #3419) found the 26y record path chaotic in our own
mechanics: the alphabetical tiebreak picked among equal-score candidates, and one draw moved the 6y end NAV by up to
0.2 log. The user approved `candidate_ranking Seeded` (seed 0) as the default on 2026-10-25, and #3425 (`cae75ca2a`)
flipped it. The remaining `[after-merge]` item of #3404 is this run: re-baseline the record as K seeds, at least 5,
on the Seeded build, so that every later 26y lever read is paired per seed against a measured band rather than one
draw (`project_path_stability_seeded_noise`). It is also the 26y seeded null that `../path-stability-2026-10-23/`
§"What next" item 5 asks for before the next 26-year verdict.

This is a re-baseline, not a lever test: no accept or reject.

## Design

- **Spec.** The record N (`../breadth-fix-rb1-2026-10-11/specs/rb1-26.sexp`), byte for byte, with name, description
  and one added override `((screening_config ((tiebreak_seed k))))`. `candidate_ranking` is main's default (Seeded).
  `specs/rk-k0.sexp` .. `specs/rk-k4.sexp`; `launch` checks each body equals rb1-26's up to the seed line.
- **Cells.** k = 0, 1, 2, 3, 4. Window 2000-01-01 → 2026-06-26, top-3000 PIT v12 schedule (27 yearly lists, broad,
  U1 passes), path salt 0 everywhere. Tags `rk-k<k>-s0`. k0 is what the default config produces.
- **Build.** A pinned worktree at origin/main when launched (must contain #3425 and the template's fixes, #3391
  dedupe included). The 27 lists are main's (md5 `51fba79e…`, the same as `../path-stability-2026-10-23/`); they
  differ from the old record's (`deca56c7…`) by #3391's CMN/CMD twin drop, one more reason item 3 below is
  descriptive only. #3388 (the full rename-twin dedupe) is still open and is not applied.
- **Warehouse.** `/tmp/snap_top3000_pit_v12wk` (the #3266 rerun's build, 9,236 symbols), reused and checked against
  the run tree's lists.
- **Order.** Preflight k0 and k1 on the last half-year (a non-zero seed must reach `params.sexp`), then k0 .. k4,
  one cell at a time, alone in the container.
- **Cost.** About 35–45 h: the latest same-spec 26y cell took 27,309 s (#3266 rerun, 10-23), the slowest 39,142 s.
  `CELL_TIMEOUT` 60,000 s = 1.5 × the slowest.

## What is read

1. **V6 gate.** Each k1..k4 runs `validator_diff -check V6` against k0 and must exit 0 (seeds change which
   candidates win ties, never the instrument set). A mismatch excludes the cell and names the specimen.
2. **The record band** over the included seeds: per seed total return, ln(1 + R), Sharpe, max DD, Calmar, trades;
   then median, sample SD and min–max of ln(1 + R), and the medians of Sharpe, max DD and Calmar
   (`sh chain.sh summary`).
3. **Reference, descriptive only.** The old record N (Alphabetical, path salts 0–2, `../breadth-fix-rb1-2026-10-11/results/`):
   where its median ln(1 + R) falls against the seed range. Salts and seeds re-draw different things and the
   arms are not paired, so this states a level shift, not an effect.
4. **Divergence onset:** the first date each seed's NAV leaves k0's.
5. **Review pack** (all five seeds), rendered and looked at per `backtest-result-review.md`; each signal bullet is
   confirmed, refined or rejected in the writeup.

## What it decides

- **≥ 4 seeds included:** the K-seed set replaces the single-run record. The headline is the median ln(1 + R) with
  its range and SD; k0 is the default-config run. Every later 26y lever read on the record config runs the same
  seeds and is read paired per seed. The record memory, the #3404 issue and the ledger take the band.
- **Fewer than 4 included:** the record is not replaced; an issue names the failing cells.
- **The band's width is the finding,** whatever it is. A 26y SD of ln(1 + R) near the 6y one (0.21) would mean a
  single 26y cell cannot resolve a lever smaller than about 0.4 log, and every 26y verdict needs K ≥ 5.

Out of scope: re-pinning the tier-4 local goldens (`goldens-sp500-historical`, `goldens-broad/`), which still hold
Alphabetical-era bands. That is a separate run after this one, on the same build.

## How to run

```sh
PREREG=<this commit> sh dev/experiments/record-kseed-2026-10-27/chain.sh launch   # host; detaches `run`
tail -f /tmp/rk-run/chain.log
```

`run` copies results into `/tmp/rk-run/results` and writes `summary.txt`; the pack goes to
`.sweep-output/review-record-kseed-build/`.


## Results

Read by results-analyst against the pre-registration at `57eedc3e8` (§"What is read", §"What it decides", unchanged).
Dispatcher spot-checks against the artifacts: ADMA's three rows in `results/rk-k{1,2,4}-s0-trades.csv` (+$5,182,494 /
+$3,574,721 / +$3,921,682, +300.00 %); SPY's window total return +705.8 % = ln 2.0866 (`read/regime-split.txt`); the
five composition files that differ between `524bc2df0` and `fc78391dd` (defect 1); each seed's `RESULT` line against
its `actual.sexp`.

- **Per-cell artifacts:** `results/`.
- **Derived tables:** `results/read/rk-analysis.sh` and `results/read/rk-specimens.sh` (POSIX sh, awk, jq; `regime.awk`
  beside them), with their outputs as `read/*.txt`.
- **What the scripts read:** `results/`, the uncommitted raw `trade_audit.sexp` files (`.sweep-output/record-kseed/`,
  14 MB each), and the pack's `site/data`.

**Run.**

- **Provenance.**
  - Pre-registration `57eedc3e8`, merged as `fe388039a` (#3456).
  - Run tree `fc78391dd` (`results/chain.log` line 1). It holds #3425 (`cae75ca2a`, the Seeded default) and #3391.
  - Lists md5 `51fba79e…` (`results/lists-md5.txt`).
  - Warehouse `/tmp/snap_top3000_pit_v12wk`, reused: 9,236 symbols, equal to the run tree's derived set.
- **Timeline.** 2026-10-27 12:18 → 10-28 10:22 PT.
  - Preflights passed: k0 in 533 s, k1 in 394 s.
  - Cells: 5 RESULT, 0 EXCLUDED, 0 failed or void.
  - Cell wall 12,336–23,162 s; 78,373 s (21.8 h) in all, against the 35–45 h estimate. k2 and k3 ran slow overnight
    (#3381).
  - Every cache line reads `n_symbols_absent=1`, 20,659 misses and 0 evictions.
- **Configuration.**
  - The five `params.sexp` differ only in `tiebreak_seed` 0–4.
  - Against N s0's `params.sexp` they differ only in that line, in `code_version` (`unknown`, defect 10) and in
    `data_dir`.
  - The spec bodies equal `rb1-26.sexp` up to the seed line (launch check).
- **Macro gate.** The five `macro_trend.sexp` are byte-identical (md5 `c78c8ae2…`). The seed never touches the macro
  gate.
- **Integrity.**
  - The metric-glob tripwire on `chain.log` and `summary.txt` is clean.
  - Each `RESULT` line equals its `actual.sexp` to the last digit.
- **Universe.** Top-3000 PIT v12 schedule (27 yearly lists), broad. No sp500 cell.

### 1. The rule, as written

**1. V6 gate.**

- Every cell reads `V6 INVARIANT PASS`.
- `validator_diff -check V6` of k1, k2, k3 and k4 against k0 prints `V6 | 0 | 0 | agree` and exits 0
  (`results/rk-k{1,2,3,4}-s0.v6diff-k0.log`).
- No cell is excluded.
- The bare-form audit (check 8) moves with the trade lists, as expected (`read/validator-counts.txt`; Review-pack
  look, item 5):
  - V7: 15–22.
  - V12: 24–34.
  - V13: 19–24, with 6–9 skipped.
  - V16 (an expectation): 1–2. That is the NLC stale force-exit in all five seeds, plus NTO 2007 in k1.

**2. The record band.** Per-seed values come from `results/rk-k<k>-s0-actual.sexp`, CAGR from `-summary.sexp`, and
the band from `results/summary.txt`.

| seed | total return | ln(1+R) | CAGR | Sharpe | max DD | Calmar | trades |
|---|---:|---:|---:|---:|---:|---:|---:|
| k0 (default config) | +1,312.8 % | 2.6482 | 10.51 % | 0.606 | 26.23 % | 0.401 | 566 |
| k1 | +2,218.8 % | 3.1436 | 12.60 % | 0.726 | 24.16 % | 0.522 | 555 |
| k2 | +1,515.0 % | 2.7819 | 11.07 % | 0.632 | 32.08 % | 0.345 | 552 |
| k3 | +1,192.7 % | 2.5593 | 10.14 % | 0.602 | 23.87 % | 0.425 | 564 |
| k4 | +1,648.7 % | 2.8614 | 11.41 % | 0.653 | 26.11 % | 0.437 | 552 |

- **ln(1 + R):** median 2.7819, sample SD 0.2254, min–max 2.5593–3.1436 (a range of 0.584).
- **Medians:** Sharpe 0.6317, max DD 26.11 %, Calmar 0.4249.
- **Against SPY.** SPY's total return over the same window is +705.8 % (ln 2.0866, CAGR 8.20 %;
  `read/regime-split.txt`, row 2000–2026 ALL).
  - Every seed is ahead of it by 0.47–1.06 log, which is 1.9–4.4 pp of CAGR a year.
  - The seeds end at 1.60–2.88× SPY's NAV.

**3. Reference, descriptive only.**

- **The old record N** (Alphabetical, path salts 0–2; `../breadth-fix-rb1-2026-10-11/results/N-rb1-26-s{0,1,2}-v12-actual.sexp`):
  - Total return 849.28 / 835.99 / 878.27 %.
  - ln(1+R) 2.2505 / 2.2364 / 2.2806: median 2.2505, SD 0.0226.
- **Where it falls.** N's median lies outside the seed range:
  - 0.309 log below the lowest seed (k3);
  - 0.531 log below the seed median;
  - CAGR 8.87 % against 11.07 %.
- **What this is.** As pre-registered, this states a level shift, not an effect:
  - seeds and salts re-draw different things;
  - the cells are not paired;
  - the build and the lists also changed under N (§3.5, defect 1).

**4. Divergence onset.** The first date each seed's NAV leaves k0's (`results/summary.txt`):

- k3: 2000-01-11;
- k1: 2000-01-25;
- k4: 2000-01-25;
- k2: 2000-02-28.

Every pair of seeds has diverged by 2000-02-28 (`read/tie-cut-traces.txt`). The first two screens of the window
decide it (§3.1).

**5. Review pack.** Built, rendered, looked at and published at https://claude.ai/artifact/TN5LbsLKaMVwhNj4rQJjJX.
See "Review-pack look" below; the appendix answers each signal bullet.

**What it decides, applied.**

- **5 of 5 seeds are included (≥ 4), so the K-seed set replaces the single-run record.**
  - Headline: median ln(1 + R) **2.7819** (+1,515 %, CAGR 11.07 %).
  - Range **2.5593–3.1436** (+1,193 % to +2,219 %, CAGR 10.14–12.60 %).
  - SD **0.2254**.
  - k0, the default-config run, reads +1,312.8 %, ln 2.6482.
- **Later lever reads.** Every later 26y lever read on the record config runs seeds k0–k4 and is read paired per seed.
  The record memory, #3404 and the ledger take the band (see Record).
- **The band's width is the finding.** The 26y SD (0.2254) is near the 6y one (0.2108, arm S of
  `../path-stability-2026-10-23/`); the ratio is 1.07. So the rule's sentence applies as written:
  - one 26y cell cannot resolve a lever smaller than about 0.45 log (2 SD; about 1.9 pp of CAGR a year at this level);
  - every 26y verdict needs K ≥ 5.

### 2. The verdict, calibrated

**Verdict.** A re-baseline, with no accept or reject. The record is the K = 5 band.

**What this design can say.**

- **It is a band.** On this build, these 27 lists and this warehouse, the record config's 26y outcome over tie-order
  draws spans 2.56–3.14 log (CAGR 10.1–12.6 %). It is not a point.
- **Every draw beats SPY's total return**, by 0.47–1.06 log, with a max DD of 23.9–32.1 % against SPY's 55.2 % (ledger
  `2026-10-12-breadth-fix-rb1-record-baseline`).
- **The seed changes which names enter, not how much is invested.** Whole-window exposure is 56.1–57.3 % in every
  seed; §3.3 gives it by regime and period.

**What it cannot say.**

- **The SD itself, closely.** With n = 5:
  - the 90 % interval on the SD is 0.146–0.535 (χ², 4 df);
  - leave-one-out estimates run from 0.135 to 0.260;
  - the 90 % interval on the 26y/6y ratio is 0.47–2.7 (F(4,5)).

  "Near the 6y SD" is the point estimate. A √T-scaled value of 0.44 is not excluded.
- **Anything about tie order's effect on the level.** The one Alphabetical draw on nearly this build is M of the
  #3266 rerun, at 2.7860, and it sits inside the band (§3.5). The +0.53 log over N is the build change that #3266
  measured, not Seeded.
- **The 26y resolution of a paired read.** No lever arm ran. The 6y paired SD (0.11–0.15) is a projection here, not a
  measurement.
- **Noise sources other than the tie order.** List changes are not varied here (#3388: one name moved the path by
  0.204 log in #3266 §3.4), and the intraday path salt is fixed at 0.

### 3. Why

**3.1 The seed re-draws the top-20 cut from the first screen.**

- **The first screen.** On 2000-01-07 (macro Neutral), 537 names pass the grade gate into a cap of 20 that binds.
  Most of the admitted names are skipped `No_structural_stop`, and the seeds admit different members of the tie
  groups:
  - k3 admits FR, which is placed and fills 2000-01-11: the first NAV divergence.
  - k2 admits DXC, which fills 2000-02-28.
  - The other three seeds admit neither.
- **The second screen, 2000-01-14** (from the raw `rk-k<k>-s0-trade_audit.sexp`, not committed; `read/tie-cut-traces.txt`
  has no block for this date):
  - k0 places TWX1, FR and DIS;
  - k1 places TWX1 and VION;
  - k2 places TWX1 and DIS;
  - k3 places TWX1;
  - k4 places TWX1 and FR.
- **The Alphabetical M** also admits FR on 2000-01-07.
- **Over the whole window** (`read/gates.txt`), in every seed:
  - the cap binds in all 1,099 screens that have a long top-N;
  - of the admitted decisions recorded, 93.8–94.0 % are `No_structural_stop`, 3.1–3.2 % are placed and 2.1–2.3 % are
    `Insufficient_cash`.
- **Two gates decide which tails a seed catches, as at 6y.** Gate 1 is the tie cut at the top 20; gate 2 is cash at
  placement.

**3.2 A handful of tie cuts, each one a tail trade, carry the spread.**

**The common core** (`read/overlap.txt`, `read/tail-weights.txt`):

- 274 trades are in every seed, 404 in two to four seeds, and 257 in one.
- The four largest of the 274 trades in all five seeds, by weight (each trade's P&L as a share of entry NAV):

  | trade | weight |
  |---|---:|
  | ADSK 2003-09-15 | 0.42 |
  | APPS 2020-06-15 | 0.37 |
  | MMYT 2023-10-26 | 0.22 |
  | BBWI 2020-08-05 | 0.14 |

- **How weights are computed.** A weight is the trade's total-return P&L over its own seed's NAV at entry. So a shared
  trade weighs the same in every seed, and only its dollars scale with NAV.

**The pack's "From the rest" column.**

- k1's $10.78M is price-only P&L from k1's 281 trades that are not in every seed: 224 in two to four seeds and 57 in
  k1 alone.
- The trades only k1 took make $1.68M.

**The traced events:**

| traced event | gate | who catches it | weight (ln) |
|---|---|---|---:|
| ADMA, screen 2023-08-18 | 1 | k1, k2, k4 | 0.30 (0.26) |
| GLNG, screen 2022-02-04 | 1 | all but k2 | 0.097 (0.092) |
| CVNA, screen 2024-07-05 | 1 | k0 only | 0.077 (0.075) |
| CMG, screen 2010-02-05 | 2 | k1, k4 | 0.16 (0.15) |

1. **ADMA (gate 1), traced end to end.**
   - **The screen.** On 2023-08-18 (macro Bullish), 261 names pass the grade gate.
     - 11 names score 97–110: DHT 110, IMAX 106, R/CDW/CORT/TEN/SCHL/PRGO/INSW 105, TXT 101, DTCB 97.
     - The last nine of the 20 slots go to a score-95 tie group of at least 12: PKG, CRGY, DINO, HDSN, MTDR, ROST, SUN,
       TEVA, TFSL, AMGN, IMO, ADMA.
   - **Who admits it.** Only R, PKG and ADMA of the 20 have a structural stop.
     - Seeds 1, 2 and 4 admit ADMA.
     - Seeds 0 and 3 do not. k0 had ADMA in its top 20 a week earlier (2023-08-11), but skipped it
       `No_structural_stop`.
   - **The ticket** (`read/specimens.txt`): close 4.10, suggested entry 4.32, installed stop 3.93 on its support floor.
     - It rests 17 weeks.
     - It fills on 2023-12-19 at 4.35, for 10 % of NAV.
     - It exits by laggard rotation on 2024-12-23 at 17.40: +300 %.
   - **The money** (`results/rk-k{1,2,4}-s0-trades.csv`): +$5.18M (k1), +$3.57M (k2), +$3.92M (k4). Each is 0.30 of
     entry NAV, about +0.26 log.
   - **The year** (`read/yearly.txt`). In 2024 the three ADMA seeds made +48.4 % to +53.2 %, against +21.5 % for k0
     and +26.3 % for k3. That 31.7 pp spread is the widest of the 27 years.
2. **GLNG (gate 1).**
   - **The screen.** On 2022-02-04, nine names score 105–120. The last 11 slots go to a score-95 group of at least 14.
   - **The cut.** GLNG is the only placeable name of k0's 20, and seed 2 cuts it.
   - **The trade.** GLNG runs 2022-02-07 → 2022-11-28 for +70.1 % (0.097 of entry NAV) in the four seeds that hold it.
   - **What k2 missed.** k2's 2022 is −16.7 %, against −5.9 % to −7.9 % for the others. k2's max DD (32.1 %,
     2021-04-12 → 2023-10-27) is the APPS give-back with no GLNG to offset it.
3. **CVNA (gate 1).**
   - **The screen.** On 2024-07-05, 18 names score 82–105. The last two slots go to a score-80 group of at least ten,
     which each seed fills differently:
     - k0: CVNA and AVGO;
     - k1: MOD and CRTO;
     - k2: TYL and CAVA;
     - k3: ARGX and ALTR;
     - k4: INST and MNDY.
   - **The trade.** CVNA, placed only in k0, fills on 2024-07-08 and makes +80.4 % by 2025-03-03: +$1.10M, or 0.077 of
     entry NAV.
   - **Its role.** It is k0's partial offset for missing ADMA.
4. **CMG (gate 2).**
   - **The screen.** On 2010-02-05, CMG is in all five top-20s.
   - **Who places it.** k1 and k4 do, making +$0.40M each (0.16 of entry NAV).
   - **Who doesn't.** k0, k2 and k3 skip it `Insufficient_cash`, a cash state their earlier draws built.
   - **The same shape elsewhere:**
     - LAD on 2012-08-10: k1 placed it, k0 was out of cash.
     - CRM on 2009-11-27: k2 placed it, k3 was out of cash.

**APPS.** Cash decided APPS on 2020-06-12 in 8 of the 24 cells at 6y; here all five seeds place it. Gate 2 depends on
the book; gate 1 does not (§4).

**The fat tail turns a few draws into the level** (`read/tail-weights.txt`).

- In every seed, the top ten trades make 110–128 % of realised price P&L.
- The other 542–556 trades net −$1.7M to −$2.8M.
- Each seed's summed entry-NAV weights (2.79–3.47) rank the seeds exactly as ln(1 + R) does.

**3.3 Exposure is the same in every seed (RV2).**

The table gives the seeds' range of return and of exposure, by SPY regime and period, using the pack's rule: the
weekly close against the 30-week MA and its slope, lagged a week. It comes from `read/regime-split.txt`, and its k0
rows reproduce the pack's era table.

| period | SPY UP / DOWN days | seeds, UP days (invested) | seeds, DOWN days (invested) | seeds, all days (invested) |
|---|---|---|---|---|
| 2000–08 | +8.9 / −39.0 % | +125.9 to +147.3 % (63.2–67.5 %) | +8.1 to +18.6 % (13.2–19.9 %) | +145.4 to +173.9 % (43.9–47.8 %) |
| 2009–11 | +29.2 / +27.4 % | +11.5 to +37.3 % (62.2–66.7 %) | +5.1 to +16.2 % (36.8–44.1 %) | +13.5 to +30.9 % (55.1–59.8 %) |
| 2012–15 | +38.9 / +11.0 % | +45.5 to +83.4 % (72.1–77.8 %) | +3.1 to +7.0 % (30.9–49.2 %) | +62.8 to +120.0 % (69.4–75.4 %) |
| 2016–19 | +37.1 / +11.9 % | +16.4 to +31.9 % (62.0–65.3 %) | −3.6 to −0.3 % (9.9–13.1 %) | +18.8 to +34.2 % (55.2–58.8 %) |
| 2020–22 | +25.7 / +42.6 % | +51.8 to +75.4 % (67.9–74.2 %) | +7.2 to +15.3 % (31.4–46.7 %) | +48.0 to +78.1 % (56.5–62.9 %) |
| 2023–26 | +68.9 / +21.1 % | +1.5 to +35.6 % (67.3–70.3 %) | +0.7 to +3.2 % (15.0–21.8 %) | +13.5 to +44.6 % (61.7–65.0 %) |
| 2000–26 | +468.7 / +66.7 % | +692.8 to +1,598.6 % (67.5–68.4 %) | +37.1 to +65.6 % (23.1–25.8 %) | +1,192.1 to +2,217.8 % (56.1–57.3 %) |

- **Exposure explains none of the seed spread.**
  - Over the whole window, every seed is 67.5–68.4 % invested on UP days and 23.1–25.8 % on DOWN days.
  - Yet UP-day returns run from +692.8 % (k3) to +1,598.6 % (k1).
  - For comparison, M makes +1,011.3 % on UP days at 68.9 %, and N s0 +566.7 % at 67.0 %.
  - The spread is which names ride the advances.
- **The regime pattern is common to all seeds.**
  - Cash on DOWN days protects in 2000–08 and costs in every later rebound.
  - Every seed lags SPY's UP days in 2016–19 and in 2023–26.
- **The depth of 2023–26 is ADMA.** On UP days, k3 makes +1.5 % and k0 +5.3 %, against +28.8 % to +35.6 % for the
  ADMA seeds, at 67.3–70.3 % invested in all five.

**3.4 Why the 26y SD is about the 6y one, not √T larger.**

- **The spread builds late** (`read/yearly.txt`).
  - Through end-2013 the five seeds are within 0.13 log of each other (SD 0.053).
  - The end spread is built after 2014: the 2014–26 SD is 0.183.
- **Yearly deviations add up, but they are concentrated.**
  - The summed yearly variance (0.0520) matches the total (0.0508). The lag-1 correlation of seed deviations is
    −0.06, so on average they neither compound nor cancel.
  - But 2004, 2006, 2010 and 2024 carry 53 % of the summed variance, and 2024 alone 24 %.
- **The mechanism.** A window's seed SD is set by how many large tie-cut tails fall inside it, not by its length. The
  6y window 2019–24 holds ADMA, GLNG and APPS's cash draw, which makes it unusually noisy per year.
- **The economic scale.**
  - One SD at 26y is 0.225 log over 26.5 years: about 0.9 pp of CAGR.
  - One SD at 6y is 0.21 log over 6 years: about 4 pp a year.
  - So a lever that acts every year is resolved about 4.5× more finely per year at 26y. A lever that acts in a single
    episode is not.

**3.5 Why every seed sits above every old salt.**

1. **N's three salts are one draw** (`read/overlap.txt`).
   - They share 553–562 of their 568–575 trades (96–99 %).
   - The seeds share 386–407 of their 552–566 trades (about 70 %).
   - A salt re-draws intraday paths, not tie cuts: SD 0.023 against 0.225.
2. **The build changed under N.**
   - N ran at `524bc2df0`. This chain's `fc78391dd` adds:
     - #3283: ISO week-year bucketing;
     - #3391: CMN dropped from five lists, so the lists are not N's (defect 1);
     - #3339: the A-D fixture;
     - #3425: the Seeded default.
   - The #3266 rerun measured the first two of these on one Alphabetical cell, M (`../verify-3266-rerun-2026-10-22/`):
     +1,521.64 %, ln 2.7860, +0.5355 over N s0.
   - M sits inside this band, 0.004 above its median, between k2 and k4.
   - M shares 395–412 trades with each seed, as many as the seeds share with each other. It shares 464–473 with N's
     salts.
3. **What moved in the path.**
   - ADSK 2003-09-15 (0.42 of entry NAV) and APPS 2020-06-15 (0.37) are held by M and by all five seeds, and by none
     of N's salts (`N-rb1-26-s*-v12-trades.csv`).
   - Together they are worth about 0.67 log. #3266 traced both (§1, item 3).
4. **What Seeded changed: it removed the A→Z bias** (`read/letter-mix.txt`).
   - A-tickers are 9.7–11.1 % of seed trades, and A–F tickers 36.3–39.9 %.
   - Under Alphabetical (M, N s0–s2) they are 13.7–15.4 % and 46.4–47.0 %.
   - Under Alphabetical, ADMA wins its 2023-08-18 tie every time: M and all three N salts hold it. Under Seeded it is
     a 3-in-5 draw.
   - The level did not move. M is mid-band, as A-p0 was mid-band at 6y (#3419 §2).
5. **Checkable, but it decides nothing.**
   - One Alphabetical cell on `fc78391dd` would pair with k0 on tie order alone.
   - M also differs from the seeds by #3339's 11 weekly macro readings in 2004–09 (`macro_trend.sexp` diff).
   - Either way, one Alphabetical cell is one draw.

**3.6 Perturbation checks** (`feedback_perturb_before_believing_a_cohort_split`; `read/yearly.txt`,
`read/tail-weights.txt`).

- **Leave one seed out.** The SD runs from 0.135 (without k1) to 0.260 (without k2).
- **Remove each seed's largest seed-specific trade**, without redeploying its cash. The SD falls only to 0.180, so the
  band does not rest on one trade per seed.
- **The ADMA split.**
  - The ADMA seeds average 2.929 and the others 2.604: a gap of 0.325 log, of which ADMA's own weight is about 0.26.
  - Without ADMA, k1 still ranks first (2.882), while k4 (2.602) and k2 (2.519) fall to the level of k0 (2.648) and k3
    (2.559).
  - k1's lead is spread over smaller draws: LAD 2012, CMG 2010, CCJ 2021, WSM 2020, SGEN 2019 and MIME 2021
    (`read/overlap.txt`).

### 4. How it fits what we know

- **`project_path_stability_seeded_noise` and ledger `2026-10-24-path-stability`: confirmed, and extended to 26y.**
  - The 6y read's open item, "the 26-year seeded spread is unmeasured", now reads 0.225.
  - The same gate-1 specimens recur at the same seeds, in a 2019 window and in a 2000 window with entirely different
    books:
    - seeds 0 and 3 cut ADMA on 2023-08-18;
    - seed 2 cuts GLNG on 2022-02-04.
  - The reason: the seeded order hashes `seed|date|ticker` (`screener_ranking.ml` lines 126–135), and the screen sets
    the tie group (less any held names), not the book.
  - **So a seed's gate-1 draws are book-independent. Gate 2 is not:** APPS needed cash in 8 of the 24 cells at 6y and
    in none of these five.
- **`project_26y_path_noise_floor` ("below about 0.2 log, untraced deltas are noise"): refined.**
  - One 26y cell's seed SD is 0.225, so 2 SD is 0.45 log.
  - The 0.2 rule of thumb was set from one list perturbation. It understates the single-cell floor by about 2×.
- **Ledger `2026-10-12-breadth-fix-rb1-record-baseline` (N): superseded as the record.** Its salt SD of 0.023 measured
  near-replicate paths.
- **`project_screener_alphabetical_tiebreak`: contradicted again.** The A→Z bias reproduces at 26y.
- **Confirmed:**
  - `project_edge_is_the_fat_tail`: the top ten trades are 110–128 % of realised P&L.
  - `project_funding_grid_monster_lottery` and `project_record_gap_is_concentration`: gate 2 decides CMG, LAD and CRM,
    and shared trades weigh the same in every seed.
  - `project_monster_funnel_top_of_funnel`, `project_top_n_capacity_verdict` and `project_floor_and_refresh_screens`
    ("the binding gates are the top-20 cut and the structural-stop gate"): the cap binds in every screen, and 94 % of
    admitted names are unplaceable.
  - Ledger `2026-06-30-tiebreak-noise-floor`: tie order is a large selection variance at this breadth.
- **The record's standing diagnoses hold in every seed** (`project_investor_preset_broad`; `read/pack-checks.txt`):
  - **The 2009 sit-out:** 0 entries in the 13 weeks after the 2009-05-01 reopen, and −2.8 % to +0.1 % against SPY's
    +19.1 %.
  - **"2025–26 is picks":**
    - 2023–26 UP days make +1.5 % to +35.6 % against SPY's +68.9 %, at 67–70 % invested.
    - The 2025-05-30 reopen is "invested and lagged" in every seed: 13–17 entries, and −1.6 % to +0.1 % against
      +16.6 %.
  - **Bear defence in 2000–08.**
- **Contradictions:** none in the results. The chain's list comment and its unchecked md5 are wrong (defect 1); the
  merged §Design is right.

### 5. What it implies next (options; the choice is the user's)

1. **Adopt the band, as the rule says.**
   - Update the record memory and the ledger.
   - #3404 stays open for its remaining [after-merge] item, the tier-4 golden re-pin on this build.
2. **Run 26y lever reads at K = 5, paired per seed.**
   - **Cost:** about 22 h of cell wall per arm, at this chain's 12.3k–23.2k s per cell.
   - **The first such read should report its paired SD and correlation.**
   - **The gate-1 mechanism makes a prediction.**
     - Pairing should be strong for levers that leave the screen and its tie groups alone (stops, exits, sizing):
       those arms inherit the ADMA, GLNG and CVNA cuts.
     - It should be weak for levers that change scores, ranks or the candidate set.
   - **Until that is measured**, if 26y pairs as well as 6y did (paired SD 0.11–0.15), a paired read at K = 5
     resolves about 0.10–0.13 log (2 SE). Unpaired, it resolves 0.29 log.
3. **Decide #3388 before investing in 26y lever reads.** Any twin dedupe re-draws the path (#3266 §3.4), so this band
   would have to be re-measured afterwards: five cells, about 22 h.
4. **Accept the noise as intrinsic, and measure it.** For stabilisers, the honest answer is "nothing — stop here".
   - The why points at gate 1: on 2023-08-18, 17 of the 20 admitted names were unplaceable.
   - But the three funnel-widening reads (top-N 40, Nearest, monthly refresh) all moved the draw to cash order in
     this cash-bound book (`project_floor_and_refresh_screens`). A cap counted in placeable names would probably do
     the same.
   - Nothing here argues for a stabiliser lever.
5. **Optional, and it decides nothing:** one Alphabetical cell on `fc78391dd`, only if the user wants the level
   question closed on an identical build.
6. **This run adds no evidence for or against any strategy lever.**

### 6. Defects found

| # | kind | defect | specimen |
|---|---|---|---|
| 1 | chain comment / check | `chain.sh` line 93's comment says "Same scheduled lists as the old record", and the md5 it writes is compared with nothing. The run's lists (md5 `51fba79e…`) are #3391's, the same as the #3266 rerun's; N's are md5 `deca56c7…`, and the two differ by CMN in five lists. §Design states this correctly: the pre-registration commit `57eedc3e8` had the wrong sentence, and #3456's second commit (`534561c53`) fixed it before merge, 16 s after the chain launched. So item 3's reference also spans a list change, which #3266 labels. The band is unaffected, since all seeds share the lists | `git diff 524bc2df0 fc78391dd -- trading/test_data/backtest_scenarios/pit-v12/composition/top-3000-{2005,2009,2013,2014,2015}.sexp`: one `(symbol CMN)` row each; `chain.sh` lines 93–97 |
| 2 | chain | The chain's PACK step failed because its `--out` was outside the run tree, which container steps require. So the chain built no pack; it was rebuilt by hand at `.claude/worktrees/sweep-rk/.review-record-kseed/`. The README's line "the pack goes to `.sweep-output/review-record-kseed-build/`" is wrong | `chain.log` "PACK build failed"; `/tmp/rk-run/pack.log` line 1; `chain.sh` line 169 (`out=$H/review-record-kseed-build`) |
| 3 | review pack | The stage replay runs only for the charts run (k0), so checks 1 and 13 are measured for k0 and n/a for k1–k4. The "Faithfulness grades by run" table therefore compares different evidence sets. Regraded without checks 1 and 13, k0 reads A 427 / B 20 / C 107 / D 2 / F 10, the same shape as k1–k4 (A 414–432, B 13–18, C 94–114, D 2–3, F 8–9). The mechanism: a trade with one check-3 failure drops from B to C once check 13's pass leaves the denominator. This is coverage, not the seed | `dev/scripts/review_pack.sh` line 119; `site/data/k*_faithfulness.json` `.failures[0,12].known`: k0 35 / 537, k1–k4 0 / 0; `read/pack-checks.txt` |
| 4 | review pack | "Missed winners" capture is uninformative. "Rode" is 13 of 2,009 owned episodes in k0 (11–19 across seeds), and those 13 are just the run's monsters. The forward return runs to a later peak a median 8 years out (p25 3, p75 14; median +295 %). Ownership is any long trade that overlaps the signal-to-peak interval: MMYT's 2017-01-27 signal counts as "rode" by a 2023 trade. The label compares a ~93-day trade with a multi-year move | `dev/lib/review_pack/index.html` lines 580–582; `read/pack-checks.txt` |
| 5 | review pack wording | The pack labels the seeds as arms: "different configs, not salts of one … the levers' effect plus path noise". A seed set is one config, so its differences are path noise only. The `run_kind` auto rule gives `salt` only for `<base>s<N>` labels; the chain passed `k0..k4` without `--run-kind salt`, and there is no seed kind. The collapsed "rests on … the salt" note would read "the arm" | `site/data/manifest.json` (`"run_kind": "arm"`); `review_pack.sh` lines 76–78; `index.html` lines 526–533 |
| 6 | review pack (render) | Wide tables clip at 1,400 px: Missed winners' reasons are truncated and its last two columns are missing, as are "Biggest trades only this arm took" and the career scorecard's "Because". Scroll-box tables show rows only up to 2022–23, so the 2023–26 rows were read from data | `render/part-3.png`, `part-13.png`, `part-14.png` |
| 7 | review pack (false positive) | "Fill outside the day's high–low: 2" counts two trades. OKE 2013-09-18 is the known spin-off encoded as a split (#3215). IHG 2012-06-19's entry of 25.69 is on the exit basis after a 15:14 consolidation: 25.69 × 0.9333 = 23.98, inside the raw bar 23.80–24.22. The split whitelist accepts only ratios k/q with q ≤ 5 | `read/specimens.txt`; `data/I/G/IHG/splits.csv` (2012-10-09, 0.93333); `dev/lib/review_pack/trade_extract.awk` `in_range` |
| 8 | simulator (minor) | Stop levels are not tick-rounded before the trigger check. SGNT-wein-703 (k0) has `installed_stop 23.759999999999998`. The 2014-08-04 low was 23.76, so `low <= stop` fails by 2e-15 and the exit slips a day. On 2014-08-05 it fills at 23.73, $0.005 under that bar's low (the stop-fill slippage is not clamped to the bar; V13 counts it). This is the pack's "1 sold at an open after the day the stop traded"; it did not sell at the open (23.93). About $0.6k | `read/specimens.txt`; `weinstein_stops.ml` line 36 (`check_stop_hit`); `results/rk-k0-s0-validator.sexp.md`, V13 SGNT row |
| 9 | review pack wording (minor) | (a) On one NAV peak, "Concentrated gains at NAV peak 2021-04-12: n/a for 1 position" sits next to "Concentrated open gain … 2021-04-12 … APPS $4,306,314". The n/a is correct: the held position's adjusted/raw ratio moves by more than 5 % (BBWI here; DECK at 2010-04-23; WING at 2018-06-06). The bullet should name the position. (b) "Trade overlap: the trade lists first differ at … TWX1 2000-01-28" names a trade every seed holds, because the comparison is positional | `site/data/k0_peaks.json` (`"gain":null`); `dev/lib/review_pack/peak_gain.awk`; `render/part-14.png` |
| 10 | artifact (known) | `params.sexp` reads `code_version unknown` in a pinned worktree (#3266 defect 2). Provenance is in `chain.log` line 1 | `results/rk-k*-s0-params.sexp` line 1 |
| 11 | data (known, still present) | The MRUS `delisted` exit fills at 90.00 on a zero-volume stub bar (#3266 defect 1). It is in all five seeds and costs $117k–209k per seed, so it does not move the width | `results/rk-k*-s0-trades.csv`, MRUS 2025-07-18 → 2025-12-30 |

**Not a defect.** The audit lists fewer long decisions than `long_top_n_admitted` in 339 of k0's 1,335 screens (530
slots). The contract says "at most the screener's top-N rows" (`audit_recorder.mli`, `decisions`). The 2022–24
screens traced above list all 20.

### Review-pack look

**The pack.**

- Published (RV1): https://claude.ai/artifact/TN5LbsLKaMVwhNj4rQJjJX.
- Built at `fc78391dd` on 10-28 19:56 (`/tmp/rk-run/pack4.log`), after defect 2.
- The look read `render/top.png` and `part-1` to `part-15`: 16 images.

**Clean:**

- **Window.** 2000-01-03 → 2026-06-25 on the equity, drawdown/exposure, macro-strip, eras and arms charts.
- **KPI strip**, against k0's `actual.sexp` and `summary.sexp`:

  | KPI | pack | file |
  |---|---:|---:|
  | total return | +1,313 % | 1,312.79 % |
  | CAGR | 10.5 % | 10.51 % |
  | max DD | −26.2 % | 26.227 % |
  | Sharpe | 0.61 | 0.6059 |
  | trades | 566 | 566 |
  | win rate | 40.8 % | 40.81 % |
  | avg hold | 93 d | 92.92 d |
  | open at end | 5 | 5 |
  | profit factor | 1.49 | 1.49 |
  | final NAV | 14,127,882.00 | 14,127,881.61 |

- **Cross-seed figures** match the artifacts: the arms bullet's five returns, the yearly-return-by-arm table, and the
  overlap counts (274 / 404 / 257).
- **Text.** No mojibake, NaN or undefined. Each n/a states its reason.
- **Config-implied zeros.**
  - Zero, as the config implies: 4 % fallback stops (0 of 566), fills on non-trading days and initial stops wider
    than 15 %.
  - "Filled against the macro: 17" are resting tickets that filled after the screen turned.
    `entry_ticket_macro_suspend` Off allows that. R8 reads 567 of 670 Bullish; the rest are Neutral, which is also
    allowed.
  - "Stop breached before the exit day: 1" is SGNT (defect 8).

**The dispatcher's five findings, verified:**

1. **KPIs and window:** confirmed, as above.
2. **The faithfulness table:** confirmed. The stage replay ran for k0 only: `runs/k0/stage` exists and k1–k4 have
   none, and `pack4.log` says "stage replay for k0". Quantified as defect 3.
3. **Missed winners:** confirmed, with one correction. A replica of the pack's rule gives **13** "rode" out of 2,009
   owned episodes for k0; 11 is k3's count. Defect 4.
4. **Seeds labelled as arms:** confirmed. Defect 5.
5. **V7/V12/V13 are not new** (`read/validator-counts.txt`):

   | runs | V7 | V12 | V13 (skipped) |
   |---|---|---|---|
   | k0 | 21 | 34 | 24 (9) |
   | five seeds | 15–22 | 24–34 | 19–24 (6–9) |
   | N s0–s2 | 23–24 | 28–39 | 18–21 (6–7) |
   | M | 22 | 29 | 19 (8) |

   The ranges overlap, and the specimen classes are the same:
   - **V7:** virgin territory under 520 weekly bars (XERS 295, VRSK 385, as in #3266).
   - **V12:** installed stops just over 0.15 from fills that rested above the decision price, plus split-basis rows
     (#3420 item 1, for example TRMB 2003-11-24).
   - **V13:**
     - delisting exits on a day with no bar: PPDI, NLC, PLMD (#3420 item 2);
     - a spin-off encoded as a split: OKE (#3215);
     - a split basis: NEOG 2017-09-05;
     - sub-cent overshoots: SGNT, SHOO, NUAN, NMK1, NTTYY.

**Found beyond those:** defects 6–9, and the refinement of the 2010-08 reopen (appendix, row 12).

**Pattern seen in the analysis that the pack did not flag (RV3).**

- The largest seed-specific event is invisible in "Trade overlap", which lists only trades held in a single run. That
  event is ADMA: held in 3 of 5 runs, worth $3.6–5.2M, 0.30 of entry NAV.
- A detector is feasible: rank the trades held by some but not all runs by entry-NAV weight, and name the runs that
  hold them.
- Proposed for the review-pack umbrella (#3384).

### Appendix: What-stands-out bullets (RV3)

| # | bullet (k0) | read |
|---|---|---|
| 1 | Eras vs SPY: built 2000–08 (1.00→3.67×), eroded 2009–11, built 2012–15, eroded 2016–19, built 2020–22, eroded 2023–26; ends at 1.75× | **Refine.** The era shape is common: in every seed, 2000–08 makes +145.4 % to +173.9 % over all days against SPY's −27.8 %. The end ratio is a draw: 1.60× (k3) to 2.88× (k1). M ends at 2.01× and N s0 at 1.18× |
| 2 | Eroded 2009–11: cash through rebounds (DOWN days +5.1 % vs +27.4 %, at 37 % invested) | **Refine.** The 2009 sit-out is common: all five seeds make 0 entries in the 13 weeks after 2009-05-01. DOWN days make +5.1 % to +16.2 %, at 36.8–44.1 % invested. UP days range from +11.5 % (k3) to +37.3 % (k1) against SPY's +29.2 %, so for k3 the bigger gap is holdings |
| 3 | Eroded 2016–19: holdings lagged (UP days +17.6 % vs +37.1 %, at 65 %); cash through rebounds (DOWN days −0.3 % vs +11.9 %, at 12 %) | **Confirm.** Every seed: UP days +16.4 % to +31.9 % (62.0–65.3 % invested), DOWN days −3.6 % to −0.3 % (9.9–13.1 %). N s0 has the same shape |
| 4 | Eroded 2023–26: holdings lagged (UP days +5.3 % vs +68.9 %, at 68 %); cash (DOWN days +2.5 % vs +21.1 %, at 18 %) | **Confirm the shape; refine the depth.** Every seed lags on UP days, at 67.3–70.3 % invested. The depth is ADMA: k0 +5.3 % and k3 +1.5 %, against +28.8 % to +35.6 % for the ADMA seeds |
| 5–7 | Concentrated gains at NAV peak 2010-04-23, 2018-06-06 and 2021-04-12: n/a for 1 position | **Confirm** as honest n/a (DECK, WING, BBWI). The wording next to a figured bullet for the same peak is defect 9 |
| 8–10 | Concentrated open gain before a drawdown: FOSL 2011-07-19 (21.0 % of peak NAV, then −26.2 %); APPS 2021-04-12 (30.6 %, then −21.4 %); MMYT 2024-12-05 (19.4 %, then −19.6 %) | **Confirm.** This is the detector proposed in the #3266 look, firing as designed. **Refine:** the max DD is itself a draw. It is the FOSL give-back in k0, k1 and k4 (24.2–26.2 %); the APPS give-back without GLNG in k2 (32.1 %); and 2018–20 in k3 (23.9 %; k3 never held FOSL) |
| 11 | Fill-week volume: 520 of 566 under 2× | **Refine: not new.** M reads 516/566 and N 522/570 (#3266 look). Resting tickets fill after the screened breakout week |
| 12 | Gate reopens: 14. Sat out 2009-05; invested and lagged in 2010-08 (8 entries, +6.6 % vs +17.9 %) and 2025-05 (13 entries, +0.1 % vs +16.6 %) | **Refine.** 2009-05 and 2025-05 are config properties: all five seeds sat out or lagged. 2010-08 is a draw: it would flag k0 (+6.6 %) and k3 (+7.6 %), but not k1 (+24.0 %), k2 (+14.3 %) or k4 (+16.5 %), against SPY's +17.9 % |
| 13 | Entries cancelled at the fill for cash: 43; 7 of them at least 90 % funded | **Confirm** (the `GUARDS` line for k0 reads `cash_rejections=43`). The seeds read 41–51 |
| 14 | Worst three-year stretch, 2023–25: +24.2 % vs SPY's +85.5 % | **Refine.** Every seed lags, from +17.9 % (k3) to +48.2 % (k1). The depth is ADMA |
| 15 | Ten trades made $11.87M of the $9.57M realised; price-only | **Confirm.** The top ten are 110–128 % of realised price P&L in every seed |
| 16 | 0 of 566 trades used the 4 % fallback stop | **Confirm** (`require_structural_stop` is on) |
| 17 | 69 of 280 stop exits filled > 0.5 % beyond the stop; 1 sold at an open after the stop traded; 130 D/F losers lost −$8.06M | **Confirm** the config-implied zero, apart from one specimen. **Refine** that one: it is SGNT, a float tie (defect 8), not a #3075 late stop |
| 18 | Average invested: 58 % of NAV, about 5.5 positions | **Refine (RV2).** It is the same in every seed: 56.1–57.3 % day-weighted (the pack's 58 % is a mean of yearly means). By regime and period (§3.3), exposure explains none of the seed spread |
| 19 | 0 fills on a day with no bar; V13 counts 24 (9 skipped) | **Confirm.** V13's specimens are known classes |
| 20 | "The 5 arms returned +1,313 %, +2,219 %, +1,515 %, +1,193 %, +1,649 % (different configs, not salts of one)" | **Numbers confirmed** against `actual.sexp`. **Wording rejected** (defect 5) |
| 21 | (collapsed) Years that rest on one trade or on the salt | Not visible in the render. From the data, the years with a seed spread of at least 15 pp are 2004 (21.7), 2006 (17.6), 2010 (20.6), 2013 (16.5), 2014 (15.2) and 2024 (31.7). The note would attribute them to "the arm" (defect 5) |

### Record

- **Memory.**
  - `project_record_kseed_band` (new): the record becomes the K-seed band: median 2.7819, SD 0.2254, range 2.5593–3.1436; k0 reads 2.6482.
  - `project_path_stability_seeded_noise`: the 26y SD is now measured, and the gate-1 draws recur at the same seeds.
  - `project_26y_path_noise_floor`: the single-cell floor is 0.45 log at 2 SD.
- **Ledger.** A baseline entry for this band supersedes `2026-10-12-breadth-fix-rb1-record-baseline` as the record.
- **#3404.** Takes the band and the Verifies line. It stays `verify/pending` for the tier-4 golden re-pin.

## Log

- 2026-10-27: pre-registered.
- 2026-10-28: ran (5 of 5 included); read by results-analyst; pack rebuilt by hand (defect 2) and published.
