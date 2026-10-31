# twin-dedupe-26y-2026-10-29: the full rename-twin dedupe (#3388), applied and measured paired on the record

**Pre-registration.** Nothing has run. Everything below is fixed before the first cell launches.

Refs #3388. Applies the scan's full proposal (`../v12-twin-scan-2026-10-22/results/drops.txt`), of which #3391 applied
only the CMN/CMD rows, and pre-registers the paired 26y read that measures it as a universe change.

## Why

The v12 twin scan confirmed 107 pairs where one list holds the same instrument twice in the window it governs (a
rename with a backfilled successor file, a warrant file carrying the common's quotes, a vendor copy of a preferred
series). A backtest can buy such a pair twice on one day, which V6 catches only after the fact. #3391 fixed the one
twin that broke chain V's V6 gate. The rest were left because applying them moves every 26y number, so the change is
to be measured before it becomes the record's universe.

## What this PR changes

1. **`apply-full-dedupe.sh`** (POSIX sh + awk, host-only):
   - filters `drops.txt` (790 rows) against `exclude-pairs.txt` in both orders. Only the 6 BML-P-G/H/J/L rows drop out
     (that exclusion postdates `drops.txt`): 784 rows;
   - resolves survivor chains per list. While (list, S) is itself a dropped key, S becomes that key's survivor (its
     first row in file order), with a cycle guard; a re-pointed row carries `via=<original S>`. 67 rows are
     re-pointed. Without this, a row such as `top-1000-1998 BAC-WS-B BAC-WS-A` would leave the list with neither leg
     (BAC-WS-A leaves for BAC) and `pit_twin_cooccur_check.sh` fails it;
   - applies the rows not already in `pit-v12/twin-drops.txt` with `../v12-twin-scan-2026-10-22/apply-drops.sh`: 779
     rows, 713 entries in 54 lists (a symbol can lose to two survivors in one list and is removed once);
   - rewrites `pit-v12/twin-drops.txt` with all 784 rows. A second run applies nothing.

   `sh trading/devtools/checks/pit_twin_cooccur_check.sh` prints `OK: ... 784 per-list twin drops hold`.
2. **`pit-v12/composition.md5`** regenerated (`md5 -r *.sexp` in `composition/`). The 27 scheduled top-3000 lists'
   concatenated md5 goes from `51fba79e26a6273845c37c13f6aae070` to `369b988f703e2aa71d5248e5843d6ecb`, and their
   union from 9,222 to 9,185 symbols (dd is a subset of cur).

**The record moves to the deduped lists either way.** Holding one instrument twice is a defect, not a dial, so the read
below sizes the change; it does not decide whether to keep it.

## Design

- **Arms.** Per seed k, `td-cur-k<k>` (main's lists before this PR, CMN/CMD dropped only) and `td-dd-k<k>` (the
  deduped lists). Both are `../record-kseed-2026-10-27/specs/rk-k<k>.sexp` from line 5 on, with a new header, name and
  description. The cur specs name `pit-v12-current/composition/`, which the chain stages from `BASE` (`7615dde7d`, main
  before this PR) into the run tree, untracked. Nothing else differs.
- **Cells.** k = 0, 1, 2 (K = 3 pairs), 26y 2000-01-01 → 2026-06-26, top-3000 PIT v12 schedule (27 yearly lists,
  broad, U1 passes), path salt 0, Seeded tie order. Order: cur-k then dd-k, for k = 0..2, one cell at a time, after a
  half-year preflight of cur-k0 and dd-k0.
- **Build.** A pinned worktree at origin/main once this PR has merged (`.claude/worktrees/sweep-td`), one build for all
  six cells. `launch` checks: the dd specs equal rk-k<k> below the header; each cur spec equals its dd spec except the
  list directory; the cur lists' md5 is `51fba79e…` and the run tree's `369b988f…`; the unions are 9,222 and 9,185 and
  dd's is a subset of cur's.
- **Warehouse.** `/tmp/snap_top3000_pit_v12wk` (9,236 symbols), reused; checked against the set derived from the cur
  union, which holds dd's. MEL (no CSV) stays in both arms, so both read `n_symbols_absent=1`.
- **Cost.** record-kseed's cells took 12,336–23,162 s, so six cells are about 25–40 h. `CELL_TIMEOUT` 60,000 s =
  1.5 × the slowest same-shape cell on the ledger (vcv-M-s2, 39,142 s).

## Gates

1. **V6 on dd.** Every dd cell's validator reads `V6 INVARIANT PASS`. A dd cell that does not logs `GATE-FAIL`, and
   its seed's pair leaves the read. `validator_diff -check V6` dd vs cur is run and logged
   (`td-dd-k<k>-s0.v6diff-cur.log`). It is descriptive: cur is expected to hold twins dd removed, so a cur-side V6
   specimen is the defect being sized, not an exclusion.
2. **Cell health.** A cell with no `actual.sexp`, or with `n_symbols_absent` other than 1, has no RESULT; its pair
   leaves the read.
3. **Same build.** One run tree, one build, one warehouse for all six cells. Per seed, dd and cur `params.sexp` must be
   equal once `(universe_size N)` is masked (cur 9,222, dd 9,185). A difference elsewhere voids that pair (`summary` prints it).

Fewer than 2 included pairs: no read; an issue names the failing cells. The record still moves to the deduped lists.

## What is read (`sh chain.sh summary`)

1. **Per-seed paired effect.** d = ln(1 + R_dd) − ln(1 + R_cur), R = total_return_pct / 100; then mean d, sample SD
   and the sign count over the included pairs. Sharpe, max DD, Calmar and trades are reported per cell.
2. **Movement class**, |mean d| in units of the record band's SD (0.2254, record-kseed):
   - **≤ 1 band SD:** the dedupe moves the record by less than its own seed noise. The record band is re-measured on the
     deduped lists at the next re-baseline, not now.
   - **1–2 band SD:** a real level shift. The record band and every 26y lever read on the record config move to the
     deduped lists before the next verdict; the record memory and the ledger take the shift.
   - **> 2 band SD:** the twins carried a material share of the record. Before the record takes the new level, the
     pair whose trades move most is traced to the twin rows that caused it (`trade-dissection`), and the result goes
     to the user.
3. **dd against the band.** The dd median ln(1 + R) against the record band (median 2.7819, SD 0.2254) in SD units,
   with the same three classes. Descriptive: the band was measured on cur.
4. **cur reproduces rk-k<k>.** Each cur cell's `actual.sexp` is compared byte for byte with
   `../record-kseed-2026-10-27/results/rk-k<k>-s0-actual.sexp`. A difference means the run tree moved since
   record-kseed (another merge); the paired read stands, since both arms share the build, but the writeup names it.
5. **Review pack** (all six cells), built in the run tree, rendered and looked at per `backtest-result-review.md`;
   each signal bullet is confirmed, refined or rejected in the writeup.

## Out of scope

- **The monthly lists.** `dev/scripts/build_monthly_universe_warehouse.sh` `post` re-keys `pit-v12/twin-drops.txt`
  (a pair's dropped leg leaves every monthly list holding both legs, whatever the window). With 784 rows instead of 5,
  its `check_may31` would no longer reproduce the yearly lists byte for byte, so the next monthly build needs the
  re-key restated per window first. `pit-v12-monthly/` is not touched here.
- **The warehouse.** No rebuild: the lists only lose symbols, and a warehouse symbol in no list is never a candidate.

## How to run

```sh
PREREG=<this commit> sh dev/experiments/twin-dedupe-26y-2026-10-29/chain.sh launch   # host, after merge; detaches `run`
tail -f /tmp/td-run/chain.log
```

`run` copies results into `/tmp/td-run/results` and writes `summary.txt`; the pack goes to
`.sweep-output/review-twin-dedupe-build/`.

## Result (read 2026-10-31, against pre-registration 65b6edae8)

**Run.** One run tree, `.claude/worktrees/sweep-td` at `HEAD=65b6edae8`, built once. One warehouse, `/tmp/snap_top3000_pit_v12wk` (9,236 symbols). Six cells, `td-{cur,dd}-k{0,1,2}-s0`, took 10,362–15,253 s each, inside the 60,000 s guard (`results/chain.log`). The first launch (10-29 23:28) stopped at preflight: `td-cur-k0` wrote no `actual.sexp` within an hour, and the relaunch overwrote that log, so its cause is not recorded. The relaunch at 10-30 00:58, on the same HEAD, passed both preflights.

**Gates, as written.**
1. **V6 on dd.** Every dd validator reads `V6 INVARIANT PASS` (`results/td-dd-k*-s0-validator.sexp.sexp`). `validator_diff -check V6` dd vs cur reads `0 | 0 | agree`, `exit=0`, for each seed (`results/td-dd-k*-s0.v6diff-cur.log`).
2. **Cell health.** All six cells wrote `actual.sexp`, each with `n_symbols_absent=1` (MEL).
3. **Same build.** For each seed, `params.sexp` is equal between cur and dd once `universe_size` is masked (9,222 vs 9,185).

### Per-seed paired effect

d = ln(1+R_dd) − ln(1+R_cur). Sources: `results/td-*-s0-actual.sexp`, `results/summary.txt`.

| seed | arm | total return | ln(1+R) | Sharpe | max DD | trades | d |
|---|---|---:|---:|---:|---:|---:|---:|
| k0 | cur | +1,312.79 % | 2.6482 | 0.606 | 26.23 % | 566 | |
| k0 | dd | +1,257.32 % | 2.6081 | 0.595 | 27.22 % | 567 | **−0.0401** |
| k1 | cur | +2,218.82 % | 3.1436 | 0.726 | 24.16 % | 555 | |
| k1 | dd | +2,270.95 % | 3.1659 | 0.729 | 24.16 % | 556 | **+0.0222** |
| k2 | cur | +1,515.03 % | 2.7819 | 0.632 | 32.08 % | 552 | |
| k2 | dd | +1,438.72 % | 2.7335 | 0.624 | 32.08 % | 555 | **−0.0484** |

Mean d −0.0221, SD 0.0386, SE 0.0223, t = −0.99 (2 df), 95 % interval [−0.118, +0.074]. In money the end NAV moves −3.9 %, +2.2 % and −4.7 %. Max drawdown changes only in k0, where dd's deepest drawdown is 2018-06 → 2020-03 and contains the WIFI loss below.

**dd against the band (pre-registered item 3, descriptive).** The dd median ln(1+R) is 2.7335 (k2), −0.21 band SD from the record band median 2.7819, so ≤ 1 band SD. The cur median of the same three seeds is 2.7819 (also k2), so the dd median sits exactly k2's d below the band.

**Calmar** (cur / dd): k0 0.401 / 0.380, k1 0.522 / 0.526, k2 0.345 / 0.339 (`results/summary.txt`).

**cur reproduces the record.** Each `results/td-cur-k*-s0-actual.sexp` and `trades.csv` is byte-identical to `../record-kseed-2026-10-27/results/rk-k*-s0-*`.

### Verdict

**≤ 1 band SD, under the pre-registered rule.** |mean d| / 0.2254 = 0.10 band SD; even the 95 % bound is 0.52 band SD. The full rename-twin dedupe moves the 26y record by a mean of −0.022 log, and no seed moves more than 0.048. The deduped lists (merged in #3475) stand as the record universe. The K = 5 band (median 2.7819, SD 0.2254) is re-measured on them at the next re-baseline.

This design can claim the record's level shift on 3 of the band's 5 seeds, bounded inside ±0.52 band SD. It cannot claim the sign of the shift (K = 3), the band's SD on the deduped lists, or anything about a strategy mechanism: the dedupe is a data correction, kept either way.

### Why each seed moved the way it did

Cross-arm trades are matched on `(symbol, entry_date)`, unique within every arm; `position_id` is a per-arm counter that shifts by one at the first divergent placement. Scripts and outputs are in `why/`.

**1. The only channel: twins took slots in the binding top-20 cut, and those slots were nearly always inert.** The 27 scheduled lists lose 494 entries (98 symbols, `why/removed.txt`). In cur, removed twins held 64 / 65 / 62 top-20 slots (k0 / k1 / k2) across 1,335 screens, almost all `No_structural_stop`. In 34 weeks per seed both legs of one instrument sat in the top-20. Only 3–4 twin weeks per seed changed a placement (`why/twin-slots-*`, `why/both-legs-*`). The only twin leg ever bought in 26 years and 3 seeds is EBR in cur-k1.

**2. The effect is a few steps, and the books re-synchronise between them.** Paired NAVs are identical to the cent until the first displaced entry fills (2004-07 / 2004-10 / 2005-05). After that, ln(NAV_dd/NAV_cur) moves only while the arms hold different names, then freezes. At the window end each pair holds the same open positions, with quantities scaled by the NAV ratio (`why/ratio-steps-k*.txt`).

| seed | 2004–08 | 2011 | 2018-11 WIFI | 2021–22 | d |
|---|---:|---:|---:|---:|---:|
| k0 | −0.0055 (PRMB in; OLN, GNW out) | — | −0.0221 | −0.0126 (FHB, BCS, JOE in; QCOM, FNB out) | −0.0401 |
| k1 | +0.0513 (HAL in; AEM, MSTR out) | — | −0.0222 | +0.0031 (NNI for EBR), −0.0098 (JOE) | +0.0222 |
| k2 | −0.0244 (EGP in, then a 25-trade cash cascade to 2008-06) | −0.0015 (TDY) | −0.0223 | — | −0.0484 |

**3. The tail is untouched.** The top-8 winners by % (APPS, ADMA, ADSK, AVGO, DXCM, MMYT, BBWI and others) are common to both arms in every pair. That is why 494 removals moved each seed by at most 0.048, while #3266's single CMN removal moved a seed by 0.204: its cascade cancelled ASR and pre-empted CRM. **The size of a universe change's effect is set by whether its cascade reaches a tail trade, not by how many names it removes.**

**4. WIFI, the one step shared by every seed.** On 2018-08-24 one instrument held two of cur's top-20 slots (COHR #2, IIVI #3–4, both `No_structural_stop`). In dd, WIFI enters at #20 and is placed. The ticket rests 10 weeks, then fills from above at the limit on 2018-11-02 (open 29.86, low 24.31, filled 29.05) and gaps out the next session at 24.88: −14.35 %, −0.0221 / −0.0222 / −0.0223 log by seed (the 2018-11-02 to 2018-11-05 window; `why/ratio-steps-k*.txt` prints the single 2018-11-02 day, −0.0221 / −0.0221 / −0.0222). Without WIFI the per-seed d are −0.018, +0.044, −0.026 (mean +0.0001). So "the mean is WIFI" is a decomposition, not a significance claim.

**5. Exposure is not a channel.** Whole-window invested % by SPY regime (DOWN / MIXED / UP) differs between paired arms by at most 0.8 pp, and by 3.5 pp in the largest era × regime cell (`why/regime-split-pairs.txt`). The return cells that differ are exactly where the steps fall. The 2009–11, 2012–15 and 2023–26 cells are identical in k0 and k1; in k2 the 2009–11 cells differ by at most 0.2 pp.

**6. Validator counts between paired arms.** V6 is 0 / 0 everywhere. V7 (21/21, 20/19, 15/16), V12 (34/35, 24/24, 29/31) and V13 (24/24, 22/22, 21/21) differ by at most 2 and follow the arm-only trades. They are per-trade checks with known validator classes present in both arms (Defects, below), so they do not bear on the verdict.

### How it fits what we know

- The record K-seed band memory said #3388 would need a re-measure. Now measured: inside the band's noise.
- The 26y path-noise memory said any twin dedupe re-draws the record path. Confirmed and refined: the re-draws are local steps, and an untraced 0.2 log comes from a cascade that reaches a tail.
- The path-stability finding (gate 1 is the tie cut, gate 2 is cash at placement) names these exact channels.
- The PIT twin-miss memory said a held twin double-funds one instrument. Refined: these lists never produced a held double (V6 = 0 on cur). The distortion was in the ranking, which V6 cannot see.
- No contradictions.

### Forward options (the choice is the owner's)

1. **Record.** Keep the K = 5 band as the reference until the next re-baseline, annotated with this shift. If that re-baseline runs on a tree that has not moved the record path, only dd k3 and k4 need running (about 7–8 h).
2. **Fills from above (#3424 item 2).** The one cross-seed component here is a fill from above. Six traced fills give mixed outcomes (WIFI −14.4 %, PRMB −10.6 %, QCOM −5.8 %, EGP +3.2 %, HAL +28.7 %, INVX +93.3 %), too few to sign the class.
3. **A ranking-level twin detector:** two legs of one instrument in one week's top-N. It catches residual twins V6 never sees.
4. **A paired mode for the review pack:** a per-seed ln(NAV_b/NAV_a) step chart listing the arm-only trades at each step. This read's whole "why" came from that view.
5. Nothing here calls for another twin experiment.

### Review-pack look

**Pack.** Six runs, audit reports for all six, stage replay for cur0 only. It was rebuilt by hand in the run tree because the chain's pack step passed an `--out` outside it. It is **not published**: its chart data embeds EODHD price bars, which the data terms keep off public and shared pages (#3476). It stays local at `.claude/worktrees/sweep-td/.sweep-output/review-twin-dedupe/`.

**Checked:**
- **Window and KPIs.** Charts span 2000–2026. The KPI strip matches cur0's `actual.sexp`.
- **Text.** No mojibake, NaN or undefined.
- **Implied-zero counts.** Fallback stops 0. No-bar fills 0. "Filled against the macro" 17, equal to V23: resting tickets and Friday fills, which the config allows. "Stop breached before the exit day" 1: SGNT-wein-703, where the stop is stored as 23.759999999999998 against a low of 23.76, so `low <= stop` misses by float epsilon.
- **Consistency.** The six returns and the 1.75× era ratio match the artifacts.

**"What stands out" bullets.**
- **Confirmed:**
  - the eras (dd0 ends 1.68× vs 1.75×, steps far below the 15 % era legs);
  - 2009–11 cash through rebounds;
  - the FOSL / APPS / MMYT peaks (common to all six runs);
  - the gate reopens (`macro_trend.sexp` byte-identical across runs);
  - 43 cash-cancelled tickets (dd has 45 / 52 / 52 against cur's 43 / 51 / 50: the gate-2 cascade);
  - 2023–25 the worst three years;
  - realised $9.57M and dividends $1.22M.
- **Refined:**
  - 2016–19, where dd adds the WIFI loss;
  - 2023–26, which is one draw (UP-regime return +28.8 % in k1 and +35.6 % in k2, which caught ADMA);
  - the "n/a for 1 position" peaks, which are DECK, WING and BBWI and should be named;
  - average invested, which is 57.3 % day-weighted;
  - the "1 stop late" row (SGNT, above).
- **Rejected:** "6 arms, different configs". These are three seed pairs, and the pack has no paired mode.

### Defects found

1. **Review pack (#3487).**
   - Slices 11–14 and 27 render blank.
   - R4 and R5 read 0 / 0 with shorts off.
   - Text is clipped in several wide columns.
   - The "n/a for 1 position" bullets do not name the position.
   - There is no paired mode.
   - The "above" detector reads null on QCOM-wein-1127 (#3424 item 2).
2. **Simulator, stop-trigger float tolerance.** SGNT-wein-703, 2014-08-04, in all six runs: one exit a day late, about $500. Added to #3424 as a specimen.
3. **Simulator (#3424 item 1).** Phantom force-liquidations SDA 2023-07-13 and SIRI 2023-07-25 in all runs; WCRX 2010-09-09 in k1 and k2.
4. **Validator (#3420).**
   - V13 split-basis entry rows: NEOG 2017-09-05 and OKE 2013-09-18.
   - A V12 false row: TRMB 2003-11-24.
   - V13 no-bar exits: PPDI and PLMD are covered by the proposed delisting waiver; NLC (`stale_force_exit`) is not.
   - V13 cent rounding.
5. **Chain script.** The pack `--out` sat outside the run tree, and the first preflight's log was overwritten.
6. **Data, observation (#3239).** The two legs of a twin carry different scores (IIVI 110 vs COHR 120; EBR qualified while AXIA did not).

Raw bar extracts used for the traces (fill-day bars, the SPY series) are not committed, because the repo is public and the data terms forbid redistribution. They regenerate locally with `dump_snap.exe` on the warehouse.
