# verify-3266-rerun-2026-10-22: rerun M-pre3339 s0 on the #3391-deduped lists, read #3266 against N s0

**Pre-registration.** Nothing has run. The read below is fixed before the cell launches. User-approved plan "(a) minimal",
2026-10-22.

**Why.** Chain V (`../verify-chain-v-2026-10-19/`, §1.1) could not read the [after-merge] item of #3266: every M-vs-N pair
failed `validator_diff -check V6` on one specimen, the CMD/CMN (Cantel Medical) rename twin, held twice on 2009-11-09 in
every chain cell. #3391 removed CMN from the pit-v12 top-3000 lists for 2005, 2009, 2013, 2014 and 2015 and added
`trading/devtools/checks/pit_twin_cooccur_check.sh`. This experiment reruns the one cell that the #3266 rule reads, on the
deduped lists, and nothing else.

## Design

One 26y cell, **M-pre3339 s0**, on current `origin/main` (which holds #3283, #3339 and #3391), compared with the committed
**N s0** (`../breadth-fix-rb1-2026-10-11/results/N-rb1-26-s0-v12-*`).

- **Spec:** `specs/v3266-Mpre3339.sexp` is chain V's `specs/vcv-Mpre3339.sexp` with only `name` and `description` changed
  (`diff` the two). Same overrides, same 27-entry `universe_schedule`, same window 2000-01-01..2026-06-26, salt 0.
- **A-D fixture:** the pre-#3339 NYSE A-D CSVs, swapped in through `TRADING_DATA_DIR` exactly as chain V did, so the pair
  differs from N by #3283 (code plus a warehouse rebuilt at the pinned tree), input drift, and the list change below, and
  not by #3339. `chain.sh` checks that #3339 changes no shipped code and that nothing after it touches the A-D CSVs.
- **Warehouse:** `/tmp/snap_top3000_pit_v12wk`, rebuilt by `chain.sh` at the pinned tree (the container was recreated on
  2026-10-22 and chain V's warehouses are gone). The symbol set is the union of the run tree's yearly lists (minus MEL,
  plus `GSPC.INDX`) plus the 14 symbols the runner always loads outside list membership (the 11 SPDR sector ETFs and
  GDAXI.INDX, N225.INDX, ISF.LSE), parsed at launch from the run tree's `macro_inputs.ml`, since the v12 manifest it was
  taken from is gone. How it is guaranteed to match N's: launch aborts unless the set is exactly 9,236 symbols (N's
  manifest count), and the cache line's `n_symbols_absent` must be N's 1 (MEL) after the preflight (at most 1) and after
  the cell (exactly 1), else the cell is VOID and no RESULT is written.
- **Guards:** cell guard 60,000 s (1.5 x the slowest same-spec cell, 39,142 s, #3381; chain V's own M-pre3339 s0 took
  11,709 s); host disk >= 20 GB; pinned worktree, clean-tree and HEAD checks; the #3391 twin guard at launch.
- **Defects of chain V fixed in this copy:** D2 (the `cash_rejections` count in `GUARDS`) and D3 (a guard-killed cell
  printed validator lines and `v6diff ... exit=0`). Both are described in the `chain.sh` header.

## The #3266 rule, as chain V pre-registered it (`../verify-chain-v-2026-10-19/README.md` §1)

> **[after-merge] item:** "Rerun the record on N's spec (one salt is enough) and report the delta", on a rebuilt
> warehouse.
>
> **Read:** the #3266 delta is **M-pre3339 s0 against the committed N s0**
> (`../breadth-fix-rb1-2026-10-11/results/N-rb1-26-s0-v12-*`): both run on the pre-#3339 A-D fixture, so the pair
> differs by #3283 (code plus rebuilt warehouse) and input drift only. [...]
>
> 1. **Delta.** M-pre3339 s0 − N s0 [...] on: total return, in log `ln(1+R)` and in %; CAGR, max DD, Sharpe, Calmar, trades.
>    N reads 849.28 / 835.99 / 878.27 %, i.e. 2.2505 / 2.2364 / 2.2806 log; its own salt range is 0.044 log.
> 2. **Where the fix acts.** From `macro_trend.sexp`, count the weekly readings whose `trend` or `breadth_state` differs
>    between **M-pre3339 s0 and N s0**, by year, split into weeks within ±2 weeks of 1 January and all other weeks.
>    - The fix changes bucketing only at year-crossing weeks. A difference far from a year-end comes through the
>      30-week and A-D windows those weeks feed, and is traced on one example.
> 3. **Entries gained and lost** (M-pre3339 s0 vs N s0 [...]), joined on `symbol|entry_date` from `trades.csv`
>    (`position_id` is not a cross-arm key), with each set's P&L and the three largest contributors traced. Each set is
>    also split **by entry year**, so a delta concentrated in one era is visible.
> 4. **Data drift.** Any symbol in `wh/csv-mtime-changed.txt` or `corp-actions-changed.txt` that the compared cells traded
>    is listed with its P&L. It is a confound of the delta, not part of the fix.
>
> **Verdict rule.** This is a correctness fix, not a mechanism, so there is no accept or reject.
> **Satisfied:** M-pre3339 s0 completes, passes V6 against N s0, and the delta is reported with items 1–4, whatever its
> sign or size. #3266 then closes, quoting the delta. (The item asks for one salt.)

And the gate (§"Validity gate (every pair)"): "**Exit 0:** the pair is read. **Exit 1:** that pair yields no delta and is
reported as excluded, naming the specimen."

The rule's fallback (M sK − N sK) and "Record" clauses need more than one cell and do not apply here. They stay as chain V
left them: N remains the record basis, and this read does not change that.

## Applied to this one pair

**Gate.** `validator_diff -check V6`, run by `chain.sh` over the cell's post-run validator report against
`N-rb1-26-s0-v12-validator.sexp.sexp`:

- **Exit 0:** the pair is read, items 1–4 are written, and the item is satisfied (below).
- **Exit 1:** the read is **void again**. No delta is quoted, the writeup names the new V6 specimen (the
  `validator_diff` output lists the symbols present in one arm and not the other) and says whether it appears in
  `../v12-twin-scan-2026-10-22/results/drops.txt` (the 790-row whole-universe twin proposal, of which #3391 applied only
  CMN/CMD). #3266 stays `verify/pending`. The next step is then the user's choice (apply the further drops and rerun, or
  close the item as not verifiable); this experiment does not choose it.
- **Exit 2** (report not comparable; the report format could have moved since 10-12): fall back to the absolute V6 line of
  each report; both must read `V6 INVARIANT PASS` for the pair to be read. Otherwise as exit 1.
- **No `actual.sexp`** (timeout, OOM, crash): there is no cell. `chain.sh` prints `GUARD-KILLED/FAILED` and runs neither
  the validator nor the gate. The read is void and the cause is traced before any relaunch.

**What "satisfied" means for #3266's [after-merge] item.** Exactly the rule's sentence: M-pre3339 s0 completes, V6 against
N s0 exits 0, and the delta is reported with items 1–4, whatever its sign or size. It is not a statement that the change is
good or bad (a correctness fix has no accept or reject), and it makes M-pre3339 s0 a single salt: the delta is read against
N's own salt range of 0.044 log, and a difference inside that range is reported as inside it. On satisfied, #3266 closes
quoting the delta; the PR carrying the results says `Verifies #3266: rerun the record on N's spec, delta reported — <path>`.

**Residual confound: the universe now differs from N's by CMN only.** This is guaranteed, not assumed: the warehouse set
is 9,236 symbols, N's manifest count, including the 14 runner extras, and `n_symbols_absent` must equal N's 1 (MEL) or the
cell is voided (see Warehouse above). N ran on the lists before #3391. The two arms share
every list except the five from which #3391 removed CMN (2005, 2009, 2013, 2014, 2015; CMD is untouched, and 2016 still
holds CMN alone). N never selected CMN or CMD in any salt (chain V §1.1), so removing CMN cannot delete an N trade, and the
V6 gate removes the only instrument-set defect that was known. The residual is that CMN could still have been a screened
candidate that took a slot or a rank in some week without being bought. The read handles it three ways, none of which is a
claim that the confound is zero:

1. **Label.** Every delta is stated as "#3283 + input drift + removal of CMN from five lists", never as #3283 alone.
2. **Bound.** CMN is one name in five of 27 lists. Item 3 checks that CMN and CMD appear in no entry of either arm, and
   lists any entry in the gained/lost sets that was opened in a week where CMN or CMD was a screen candidate in the cell's
   `trade_audit.sexp` (N has no committed audit, so this half can only be read from the M side).
3. **Size.** The delta is compared with N's salt range, as above. A delta that is inside the salt range is not attributed
   to anything; a larger one is reported with the label from (1) and the caveat that no CMN-including arm exists to
   separate the pieces, which this experiment does not run.

Item 4 (data drift) uses `wh/syms.txt` and `corp-actions-changed.txt`, which `chain.sh` stages. The old
`csv-mtime-changed.txt` of chain V is not available, because it compared against the deleted v12 warehouse; the drift list is
therefore `corp-actions-changed.txt` plus any traded symbol whose CSV is newer than 2026-10-07 17:44 PT (the v12 build start), computed at read time from
`data/`.

## Review pack

The cell's review pack is built and rendered by `chain.sh` (`backtest-result-review.md`); the writeup carries a
"Review-pack look" section with what was checked and found, and addresses each signal bullet.

## Launch

The dispatcher launches it when the container is free (no agents, no other backtest), from the repo root, after this PR
merges:

```sh
sh dev/experiments/verify-3266-rerun-2026-10-22/chain.sh launch
# progress: tail -f /tmp/v3266-run/chain.log
# before the merge: PREREG=<this PR's head sha> sh dev/experiments/verify-3266-rerun-2026-10-22/chain.sh launch
```

The run tree is `origin/main` at launch (`RUN_SHA=<sha>` pins it elsewhere). Run `sweep-hygiene.md`'s pre-launch checks first
(host free > 50 GB, `Docker.raw` < 30 GB, no other agent or backtest). `chain.sh validate` needs a built tree and a
warehouse in the container, so it is not run by the author of this PR. After the run:
`sh dev/scripts/perf_long_cells.sh update /tmp/v3266-run/chain.log`, then `chain.sh collect <dir>/results`.

## Files

- `specs/v3266-Mpre3339.sexp`
- `chain.sh`: `launch` / `run` / `validate` / `collect`

## Results (2026-10-23)

The cell finished and wrote `actual.sexp` with `crashed false`. Its artifacts are under `results/` (this directory). N's are under `../breadth-fix-rb1-2026-10-11/results/` (written `N/` below). Chain V's same-spec cell on the non-deduped lists is used only as context; it is under `../verify-chain-v-2026-10-19/results/` (written `V/`). Names used below:
- **M** is this cell (`v3266-Mpre3339-s0`);
- **N** is N s0;
- **V** is `vcv-Mpre3339-s0`.

The read was written by results-analyst; the dispatcher spot-checked the `RESULT` line against `actual.sexp`, the first M-vs-V NAV divergence (2009-11-09) and the join counts (471 / 95 / 99).

| issue | rule outcome | action |
|---|---|---|
| #3266 | **Satisfied.** M completes, `validator_diff -check V6` against N s0 exits 0, and items 1–4 are below. The delta is **+0.5355 log** (1,521.64 % vs 849.28 %), labelled #3283 + input drift + removal of CMN from five lists. Input drift was measured as nil. | close #3266 quoting the delta; **N stays the record** |

### Run and validity

**Same build and inputs as pre-registered.**
- The run tree's HEAD is `af6109ca8`, which is the pre-registration commit (`results/chain.log` lines 1, 20). Lists md5 `51fba79e…`.
- The spec body is byte-identical to N's `rb1-26.sexp`. A diff of the two bodies, with header, name and description excluded, is empty.
- `params.sexp` differs from N's only in `data_dir` and in `code_version`, which reads `unknown` (defect 2).
- The A-D fixture md5 is `1b916149…` (`chain.log` lines 15, 26). That is chain V's pre-#3339 copy, which equals N's fixture.

**Warehouse.**
- It has 9,236 entries, `.snap` files and `.weekly` files (`chain.log` line 14).
- The symbol set (`results/wh/syms.txt`) equals the v12 manifest list that chain V staged (`cmp` equal).
- Payloads: `results/wh/rows-new.txt` (symbol, payload md5, csv mtime) is byte-identical to chain V's rebuild rows (md5 `7a889f77…` for both), and differs from the v12 build's rows (`results/wh/rows-v12.txt`) on 8,345 of 9,236 symbols.

**Cache line.**
- It reads `n_symbols_absent=1` and `n_symbols_touched=9236`, so the cell is not VOID.
- Misses are 20,659, `miss_absent` 11,423 and evictions 0. These counters match N's and V's logs.
- `split_dividend_guard rejected=4 no_files=0` appears in all three logs.

**V6 gate.** `results/v3266-Mpre3339-s0.v6diff-N.log` reads `V6 | 0 | 0 | agree`, exit 0. M reads `V6 INVARIANT PASS`, as N does.

**Bare-form audit (check 8).**
- The per-trade invariants follow the trade list:
  - V7: M 22, N 23;
  - V12: M 29, N 28;
  - V13: M 19 (8 skipped), N 21 (6 skipped).
- V16 is 1 in both arms: the NLC stale force-exit (entry 2011-08-15 in M, 2011-08-11 in N).
- V17 passes in both.

**Other checks.**
- **Metric-glob tripwire** on `chain.log`: clean. The `RESULT` line (line 32) matches `actual.sexp` to the last digit.
- The `GUARDS` line's `cash_rejections=43` equals `results/v3266-Mpre3339-s0-cash_rejections.txt` (43), so chain V's D2 is fixed.
- **Incident.** The first launch aborted on the host-disk guard after the warehouse build and preflight (line 19). The relaunch skipped the finished warehouse (line 25). This had no effect on the cell.
- **Wall time** was 27,309 s, 2.33× chain V's 11,709 s for the same spec, with identical cache counters. That is the #3381 slowdown, not a cache regression.
- **Universe:** top-3000 PIT v12 schedule. No sp500 cell is involved.

### Review-pack look (RV1)

**Published pack:** https://claude.ai/artifact/UVFyTmCWsVEvuFLBNBs1uQ, rebuilt from main at `e438c03f5` (after #3395), so chain V's D4, D6 and D10 are fixed in it. The look below read the run tree's pack (`af6109ca8`, before #3395): `render/top.png` and `part-1` to `part-26`, 27 images. The dispatcher re-read the rebuilt pack's `part-2` and `part-6`. In the rebuilt pack, "Biggest losers" ranks P&L including dividends, with TNXP first at −$618k; AD and BKE are no longer listed.

**Clean:**
- **Window.** 2000-01-03 → 2026-06-25. The equity, drawdown/exposure and macro-strip charts span the whole window.
- **KPI strip** against `actual.sexp` and `summary.sexp`:

  | KPI | pack | file |
  |---|---|---|
  | total return | +1,522 % | 1,521.64 % |
  | CAGR | 11.1 % | 11.09 % |
  | max DD | −27.7 % | 27.668 % |
  | Sharpe | 0.63 | 0.6327 |
  | Calmar | 0.40 | 0.4009 |
  | trades | 566 | 566 |
  | win rate | 42.2 % | 42.226 % |
  | avg hold | 92 d | 92.17 d |
  | open at end | 4 | 4 |
  | final NAV | 16,216,390 | 16,216,389.60 |

- **Text.** No mojibake, `NaN`, `undefined` or empty panels. Missing inputs read n/a ("Sold a healthy Stage-2 stock: n/a"), never 0.
- **Config-implied zeros:**
  - 4 % fallback stops: 0 of 566;
  - fills dated on a non-trading day: 0;
  - "stop breached before the exit day": in the all-clear list;
  - "When do stop exits fill": same day 187; next open, 2–5 days and 6+ days all 0.
- The cash-rejection card reads 43 (6 at least 90 % funded), matching `cash_rejections.txt`. V6 reads PASS in the validator section.
- **Render.** `part-26` repeats the lower half of `part-25`, because the last slice is clamped to the image edge. Nothing is missing.

**Checked further:**
1. **"Filled against the macro (screen before the fill)": 14** (V23 also counts 14).
   - No ticket was placed on a Bearish reading. Joining the placement dates in `results/v3266-Mpre3339-s0-audit_entries.csv` to `macro_trend.sexp` gives 563 Bullish and 107 Neutral, out of 670.
   - So the 14 are resting tickets that filled after the screen turned, which `entry_ticket_macro_suspend` Off allows.
   - The run-tree pack's "config implies about none" is chain V's D6, fixed by #3395.
2. **"Fill-week volume: 516 of 566 under 2×" is not new.** The pack's own rule (`dev/lib/review_pack/trade_extract.awk`, `fvr`) recomputed on each `trades.csv`:
   - M: 516 of 566 (323 / 193 / 50), the same as the pack;
   - N: 522 of 570 (317 / 205 / 48);
   - V: 523 of 574.

   N's 10-12 pack predates this bullet.
3. **The run-tree pack's "Biggest losers ($)" ranks AD 2025-08-04 first, at −$690,189.**
   - With its $745,177 of dividends the trade made +$54,988.
   - Similarly, BKE 2021-12-08 is −$228,434 on price but −$97,448 in total.
   - This is chain V's D4, fixed by #3395.
4. **"Fill outside the day's high–low": 1, net $124k.** This is OKE 2013-09-18 (V13: 46.15 against the bar [51.89, 54.53]). It is the ONE Gas spin-off encoded as a split: 46.15 × 1.1422 = 52.71, inside the bar. Chain V's D9, #3215 class.
5. **2008 in "Best and worst trade by entry year"** shows AEM as both in the run-tree pack. Chain V's D10, fixed by #3395.
6. **MRUS 2025-07-18 → 2025-12-30, +$587,427, grade "A?".** The `delisted` exit fills at 90.00 on a final bar with zero volume (defect 1).
7. **Flat stretches.** The max-DD stretch is 2021-04-12 → 2024-05-17 (−27.7 %). There is also a −25.5 % stretch starting 2011-07-21. Both start at a NAV peak carried by one open position (§3.3). No signal flags this; see the RV3 note.

Each "What stands out" bullet is confirmed, refined or rejected in the appendix.

### 1. The pre-registered read, as written

The gate exited 0, so the pair is read. The rule: "**Satisfied:** M-pre3339 s0 completes, passes V6 against N s0, and the delta is reported with items 1–4, whatever its sign or size. #3266 then closes, quoting the delta."

#### Item 1. Delta

| metric | M | N s0 | M − N | file |
|---|---:|---:|---:|---|
| total return | 1,521.64 % | 849.28 % | +672.35 pp | `actual.sexp` |
| ln(1+R) | 2.7860 | 2.2505 | **+0.5355** | from the row above |
| CAGR | 11.09 % | 8.87 % | +2.22 pp | `summary.sexp` |
| max DD | 27.668 % | 22.519 % | +5.148 pp | `actual.sexp` |
| Sharpe | 0.6327 | 0.5262 | +0.1065 | `actual.sexp` |
| Calmar | 0.4009 | 0.3938 | +0.0071 | `actual.sexp` |
| trades | 566 | 570 | −4 | `actual.sexp` |

- **Against N's salt range.**
  - N reads 849.28 / 835.99 / 878.27 %, which is 2.2505 / 2.2364 / 2.2806 log, a range of 0.0442 log.
  - The delta is 12.1× that range.
  - It is also outside N's whole band: M − N s1 is +0.5496 and M − N s2 is +0.5054.
- **Economic scale.** +2.22 pp of CAGR a year over 26.5 years. N's salt range is 0.18 pp of CAGR (8.81–8.99 %).
- **The pre-registered label:** #3283 + input drift + removal of CMN from five lists.
  - Input drift is nil (item 4).
  - No CMN-including arm exists that passes V6 against N, so no read separates the two named pieces.
  - V is context only: it has CMN in its lists but fails V6 against N (chain V §1.1). §3.4 shows what it does tell us.

#### Item 2. Where the fix acts

Eleven weekly readings differ in `trend` or `breadth_state` between `results/v3266-Mpre3339-s0-macro_trend.sexp` and `N/N-rb1-26-s0-v12-macro_trend.sexp`:

| week | M (trend / breadth) | N (trend / breadth) |
|---|---|---|
| 2002-03-01 | Neutral / Neutral_breadth | Bearish / Bearish_breadth |
| 2002-05-03 | Neutral / Neutral_breadth | Bearish / Bearish_breadth |
| 2003-03-21 | Bearish / Bearish_breadth | Neutral / Neutral_breadth |
| 2008-02-08 | Neutral / Deteriorating | Bearish / Bearish_breadth |
| 2008-05-02 | Bearish / Bearish_breadth | Neutral / Neutral_breadth |
| 2008-05-30 | Neutral / Neutral_breadth | Bullish / Bullish_breadth |
| 2009-01-02 | Bearish / Bearish_breadth | Neutral / Recovering |
| 2009-02-13 | Bearish / Bearish_breadth | Neutral / Neutral_breadth |
| 2019-02-01 | Neutral / Recovering | Bearish / Bearish_breadth |
| 2025-04-25 | Neutral / Deteriorating | Bearish / Bearish_breadth |
| 2025-05-23 | Neutral / Recovering | Bullish / Recovering |

- **Split by distance from 1 January.** One reading is within ±2 weeks (2009-01-02); the other 10 are not.
- **Same as chain V.** M's `macro_trend.sexp` is byte-identical to V's (md5 `e6f12ab1…` for both), so chain V's §1.1 account holds verbatim:
  - all 11 fall within 21 weeks after a year-crossing week that the old bucketing split;
  - 9 of them come from the A-D (26-bar) or NH-NL (13-bar) lookback landing one bar later under the old bucketing.
- **Traced: 2019-02-01**, five weeks after the split week of 2018-12-31 / 2019-01-04. The NH-NL proxy compares the S&P close with the close 13 weekly bars back (`data/G/X/GSPC.INDX/data.csv`):
  - old bucketing (N): the extra 2018-12-31 bar puts 13 bars back on 2018-11-09 (2,781.01). The ratio 2,706.53 / 2,781.01 = 0.973 is below 0.98, a Bearish vote;
  - new bucketing (M): 13 bars back is 2018-11-02 (2,723.06), and the ratio 0.994 is inside the neutral band;
  - so the composite moves from Bearish (N) to Neutral (M).
  - Chain V's traced example, 2009-02-13, re-checks on the same file: 826.84 / 800.03 = 1.034 under the old bucketing, and 826.84 / 873.29 = 0.947 under the new.
- **Direct trade effect of the 11 readings.**
  - M placed tickets in three weeks where it read Neutral and N read Bearish (`audit_entries.csv`): MOVIQ (2002-05-03), AEM (2008-02-08), and AMADY and CCEP (2025-04-25). All four are gained entries, +$223.4k together.
  - In the other direction, the only N candidate is WMB, filled 2008-05-05 (−$22.7k). That is the Monday after 2008-05-02, which N read Neutral and M read Bearish.
  - The gate therefore accounts for 4 % of the gained set's P&L. The rest of the swap does not come through the gate.
- **The fix also reached the warehouse and the screen.**
  - V7's weekly-bar counts move by exactly the number of split year-crossings. XERS had 295 weekly bars before 2024-02-14 in M and 297 in N (two split crossings, 2018-12-31 and 2019-12-31). VRSK had 385 before 2017-02-22 against 388 (the 2012, 2013 and 2014 crossings).
  - The first divergent entry is ATYT 2000-03-29: N only, −$5,104. ATYT is in none of M's screen decisions in 2000 (it first appears in M's audit in 2004). So the screen admitted different names from the first quarter.
  - 8,345 of the 9,236 `.snap` payloads differ from v12 (`results/wh/rows-new.txt` vs `results/wh/rows-v12.txt`).

#### Item 3. Entries gained and lost

The two `trades.csv` files are joined on `symbol|entry_date`. P&L is total return: `pnl_dollars` plus `dividends_received`.

| set | n | total-return P&L | price P&L | positive |
|---|---:|---:|---:|---:|
| shared | 471 | M $7,778,419; N $6,097,140 | | |
| gained (M only) | 95 | +$5,121,986 | +$4,915,662 | 50 |
| lost (N only) | 99 | +$1,129,820 | +$1,039,242 | 43 |

- **Re-timings.** 9 of the 95 gained entries re-time an N entry of the same symbol within 30 days (AUOTY, NLC and COHR among them). The rest are different picks.
- **Open positions** at the end are in neither file:
  - M holds APPS, QCOM, TWLO and UTHR, unrealised +$1,336,014;
  - N holds APPS, EC, QCOM and SXT, unrealised +$520,103 (`summary.sexp`).
  - UTHR appears in the lost set only because M still holds it.

**Distribution of total-return $ per trade:**

| set | p10 | p25 | median | p75 | p90 | max |
|---|---:|---:|---:|---:|---:|---:|
| gained | −63,026 | −26,759 | +1,197 | +45,875 | +174,943 | +2,788,163 (APPS) |
| lost | −59,148 | −23,057 | −6,132 | +26,774 | +82,875 | +463,697 (ADNT) |

Per trade, on price only, the gained set's mean is +12.07 % (median +0.38 %) and the lost set's is +4.52 % (median −3.26 %). Dropping the top two and bottom two of each set, the means are +4.05 % and +2.60 %.

**Perturbed.** Each trade's P&L divided by its own arm's NAV on the entry date, summed:

| set | all | without top 1 | without top 2 |
|---|---:|---:|---:|
| gained | 1.206 | 0.787 (− ADSK 0.419) | 0.416 (− APPS 0.372) |
| lost | 0.481 | 0.319 (− CMG 0.161) | 0.245 (− ADNT 0.075) |

Without ADSK and APPS, the gained set (0.416) falls below the lost set (0.481). At 95 and 99 trades neither set can be judged on realised P&L: below about 230 trades the total is one tail event from reversing (`feedback_perturb_before_believing_a_cohort_split`).

**By entry year** (count, total-return $). There are no swaps in 2001, 2016, 2023 or 2024.

| year | gained | lost | net |
|---|---|---|---:|
| 2000 | 1, −$1k | 1, −$5k | +$4k |
| 2002 | 2, −$23k | 0 | −$23k |
| 2003 | 5, +$503k | 6, +$25k | +$478k |
| 2004 | 4, +$3k | 13, +$106k | −$103k |
| 2005 | 1, +$1k | 4, +$84k | −$83k |
| 2006 | 6, +$94k | 1, +$13k | +$82k |
| 2007 | 5, −$48k | 4, +$22k | −$70k |
| 2008 | 1, +$17k | 1, −$23k | +$40k |
| 2009 | 4, +$167k | 2, −$22k | +$190k |
| 2010 | 9, +$171k | 7, +$416k | −$245k |
| 2011 | 7, +$9k | 8, +$38k | −$29k |
| 2012 | 3, +$139k | 2, +$103k | +$36k |
| 2013 | 6, +$305k | 8, −$83k | +$388k |
| 2014 | 5, +$487k | 5, +$77k | +$410k |
| 2015 | 4, −$42k | 6, −$120k | +$78k |
| 2017 | 1, +$48k | 1, +$7k | +$40k |
| 2018 | 5, −$133k | 6, −$183k | +$50k |
| 2019 | 5, −$93k | 1, +$266k | −$360k |
| 2020 | 5, +$2,880k | 8, +$463k | +$2,416k |
| 2021 | 6, −$163k | 8, −$48k | −$115k |
| 2022 | 1, +$106k | 1, −$19k | +$125k |
| 2025 | 8, +$901k | 6, +$13k | +$888k |
| 2026 | 1, −$206k | 0 | −$206k |

**The three largest contributors of each set, traced.** M's screen decisions come from its full `trade_audit.sexp` (14.3 MB, not committed); the decisions quoted here are extracted to `results/screen-decisions-traced.txt`. N has no committed audit, so N's side is read from its trades only.

Gained:
1. **APPS 2020-06-15 → 2021-05-17, +$2,788,163.** 57,356 sh, 9.25 → 57.86, worth 37.2 % of entry NAV.
   - LACO's ticket, placed 2020-05-22, reached its fill on 2020-05-27 in both books.
   - M had $362,553.93 of the $547,688.47 needed (66.20 %) and cancelled it (`cash_rejections.csv`). N filled 14,831 sh, which made +$123,240 and exited as `delisted` on 2020-10-09.
   - With that cash still free, M placed APPS on the 2020-06-12 screen. N never held APPS in 2020.
   - ln(M/N) went from +0.288 at end-2019 to +0.548 at end-2020. It peaked at +0.692 on 2021-03-01, APPS's top close (94.74).
2. **MRUS 2025-07-18 → 2025-12-30, +$587,427.** 20,890 sh, 61.88 → 90.00, exited as `delisted`.
   - Placed on the 2025-06-06 screen; the ticket rested 6 weeks.
   - Both cells on the fixed code hold it (V: 17,677 sh). N does not, in any salt.
   - The exit price comes from a zero-volume stub bar (defect 1).
3. **ADSK 2003-09-15 → 2005-01-10, +$483,453.** 18,750 sh, 8.83 → 34.60. At 41.9 % of entry NAV, it is the largest NAV share in either set.
   - Skipped `No_structural_stop` on the 2003-09-05 screen; placed on 2003-09-12.
   - On 2003-09-15 N held two positions that M did not (COLM since 2003-05-28, NMR since 2003-08-18). Whether N's screen admitted ADSK cannot be read.
   - ln(M/N) went from +0.026 at end-2003 to +0.227 at end-2004.

Lost:
1. **ADNT 2020-11-09 → 2021-06-21, +$463,697.** 30,997 sh, 27.06 → 42.02.
   - M's ADNT ticket, placed 2020-02-21, rested 37 weeks and reached its fill in the week N bought.
   - M had $1,021,277.67 of the $1,173,239.80 needed (87.05 %) and cancelled it. APPS was holding the cash.
2. **CMG 2010-02-08 → 2011-02-07, +$306,856.** 2,059 sh, 99.24 → 248.27, worth 16.1 % of N's entry NAV.
   - CMG was a top-N candidate in M on 2010-01-15, 01-22 and 01-29 (skipped `No_structural_stop`) and on 2010-02-05 (skipped `Insufficient_cash`).
   - BWA went the same way: skipped `Insufficient_cash` on 2010-01-29, then bought by N on 2010-02-03 (+$135,871).
   - Both books bought CRM on 2010-02-05 (M 5,575 sh, N 4,719 sh). M's cash had also gone to DECK (2009-11-02, +$174,943, M only).
3. **SGEN 2019-10-14 → 2020-01-27, +$266,203.** 8,942 sh, 82.43 → 112.20.
   - Skipped `Insufficient_cash` on M's 2019-10-11 screen. N filled it the following Monday.
   - 2019 is M's one losing year against N, at −0.051 log.

**CMN and CMD, the pre-registered bound:**
- CMN is in no entry of either arm, and in none of M's screen decisions or alternatives.
- **CMD is in one M entry**: 2009-11-09 → 2010-03-22, 12,546 sh, 17.42 → 19.66, +$28,104.29 plus $626.67 of dividends (`CMD-wein-370`, placed on the 2009-10-16 screen).
  - It is a gained entry. N holds neither ticker in any salt.
  - It is the surviving leg of chain V's twin: V held this same CMD position plus a CMN leg of the same size.
  - The pre-registration expected no CMD or CMN entry in either arm. M has this one, held once, which is why V6 now agrees.
- CMD was a top-N candidate in M on four screens: 2006-12-15, 2006-12-22 and 2009-10-09 (all skipped `No_structural_stop`), then 2009-10-16 (placed).
- Gained or lost entries opened in those weeks:
  - ARCC 2009-10-05: gained, −$22,387.34. Its ticket was placed on 2009-10-02, before CMD's weeks;
  - CMD itself: +$28,730.96.

  Together +$6.3k.

#### Item 4. Data drift

- `results/corp-actions-changed.txt` is empty: no `dividends.csv` or `splits.csv` changed after N staged its copy (2026-10-11 00:00), nor after 2026-10-07 17:44 PT.
- At read time (2026-10-23), no `data.csv` under `data/` is newer than 2026-10-07 17:44 PT, the v12 build start. The newest `csv_mtime` in the rebuilt manifest is 2026-09-14 13:05 PT (SGP_old1, in `results/wh/rows-new.txt`).
- **No traded symbol in either cell is affected, so the drift list is empty.**

#### Rule outcome

M completes, V6 against N s0 exits 0, and items 1–4 are reported.

**→ Satisfied. #3266 closes, quoting the delta: +0.5355 log (1,521.64 % vs 849.28 %), labelled #3283 + input drift (nil) + removal of CMN from five lists.**

On the record, the pre-registration says: "N remains the record basis, and this read does not change that." **N stays the record.**

### 2. The verdict, calibrated

- **Verdict.** #3266's [after-merge] item is satisfied by rule, and that is the whole verdict. A correctness fix has no accept or reject.
- **What this design can say.**
  - On one salt, the record spec run on the fixed code and the deduped lists ends +0.5355 log above N s0.
  - Every other input is the same: drift is nil, and the warehouse symbol set, the A-D file and the spec body are identical.
  - The two books hold the same instruments (V6 agrees).
- **What it cannot say:**
  - **That the delta is #3283 alone.** From 2009-11-09 on it also carries the list change (§3.4). The +0.1645 log accrued by 2009-11-06 does not: M equals V to the cent until then.
  - **That the fix improves returns.** The delta rests on two trades (§3.2), and the bodies of the gained and lost sets are alike.
  - **Anything about another salt, or about current main with #3339.** This cell swaps #3339 out. Chain V measured #3339 at +0.0005 log on the non-deduped lists.
- **Exposure is not the cause (RV2, §3.2).** 95 % of the log gap accrues on SPY UP-regime days, where M was 69 % invested and N 67 %.
- **Universe:** top-3000 PIT v12 schedule; no sp500 cell.

### 3. Why

#### 3.1 The fix changes which names the screen admits, and then cash decides the rest

- Before #3283, a week that crossed 1 January became two weekly bars. Every 30-week indicator read those bars, so the fix reached the run in two places:
  - the macro gate, in 11 weeks (item 2). Its direct trade effect is +$223.4k of gained entries and one N-only loser avoided;
  - the Stage and RS columns of most symbols. As a result the screen's top-N differs from ATYT on 2000-03-29 onward.
- From that first difference the two books hold different positions and different cash. After that, which candidate gets funded in a given week follows from cash, not from the fix:
  - CMG, BWA and SGEN were top-N in M, but M could not afford them (`Insufficient_cash`);
  - LACO and ADNT were tickets M cancelled at the fill for lack of cash.
- The paths fall back into step for years at a time. M and N took identical entries in 2023 and 2024, and ln(M/N) is exactly +0.4895 at the ends of 2022, 2023 and 2024.

#### 3.2 A few tail trades set the level

Year-end ln(M/N), from the two `equity_curve.csv` files, grouped into the episodes that move it. Each trade's weight is its P&L as a share of the holding arm's NAV at entry.

| period | step in ln(M/N) | carried by |
|---|---:|---|
| 2000–02 | −0.022 | the first divergence (ATYT, N) and small swaps |
| 2003–04 | **+0.249** | ADSK (M, 0.419); PBSOQ 2004 (N, 0.049) |
| 2005–08 | −0.055 | GPI 2005-12-01 (N, 0.051) and small swaps |
| 2009–11 | −0.073 | CMG (N, 0.161) and BWA (N, 0.070), against FOSL (M, 0.117) and DECK (M, 0.075) |
| 2012–14 | **+0.217** | M's SKX (0.057), AMED (0.053), OKE (0.031), TTC (0.027) and LAMR (0.023); N's NNI (0.038) |
| 2015–18 | +0.023 | |
| 2019 | −0.051 | SGEN (N, 0.051) |
| 2020–21 | **+0.182** | APPS (M, 0.372) against ADNT (N, 0.075) and LACO (N). The 2021 step of −0.078 is APPS's round trip |
| 2022–24 | +0.019 | identical entries in 2023–24 |
| 2025–26 | +0.046 | M's MRUS (0.036), SPNT (0.022) and AM (0.014), less M's losers BJRI and SARO; N's PHYS (0.013) |
| **total** | **+0.5355** | |

- **Three episodes give +0.648; everything else nets to −0.113.** Each of the three rests on one or two trades.
- **By SPY regime, whole window** (table below):

  | regime | M | N |
  |---|---:|---:|
  | UP days | +1,011.3 % | +566.7 % |
  | MIXED days | −0.1 % | +1.7 % |
  | DOWN days | +46.0 % | +39.9 % |

  - In log terms, UP days contribute +0.511 of the +0.536, at 69 % invested against 67 %.
  - So the gap comes from which holdings rode the advances, not from how much was invested.

**RV2 table.** Strategy and SPY return, then average invested %, by SPY regime and period. N's rows show strategy return and invested only, since SPY is the same for both arms.
- Source: `site/data/s0_nav.json` from this pack and from N's 10-12 pack (`.sweep-output/review-breadth-N-v2/`, uncommitted; the NAV itself is each arm's committed `equity_curve.csv`).
- Method: read with the pack's own `spyRegimeByDay`. M's cells reproduce this pack's era table.

| period | arm | UP | MIXED | DOWN | all days |
|---|---|---|---|---|---|
| 2000–08 | M | +121.7 / +8.9 · 66 % | −0.5 / +8.7 · 49 % | +8.2 / −39.0 · 15 % | +138.6 / −27.8 · 46 % |
| | N | +105.4 · 66 % | −0.0 · 47 % | −2.2 · 13 % | +100.8 · 45 % |
| 2009–12 | M | +29.9 / +30.1 · 67 % | +1.3 / +3.7 · 59 % | +7.1 / +27.4 · 38 % | +40.9 / +71.8 · 61 % |
| | N | +17.1 · 62 % | +2.9 · 57 % | +20.5 · 45 % | +45.2 · 58 % |
| 2013–15 | M | +67.7 / +38.0 · 81 % | +2.3 / −0.8 · 40 % | +3.7 / +11.0 · 31 % | +77.8 / +52.0 · 76 % |
| | N | +42.0 · 77 % | +2.0 · 38 % | +5.1 · 34 % | +52.3 · 72 % |
| 2016–19 | M | +24.7 / +37.1 · 66 % | +4.4 / +11.3 · 42 % | +0.3 / +11.9 · 15 % | +30.6 / +70.7 · 59 % |
| | N | +29.7 · 65 % | +5.5 · 38 % | −3.7 · 14 % | +31.8 · 58 % |
| 2020 | M | +52.5 / +5.9 · 77 % | −12.7 / −16.0 · 64 % | +11.2 / +33.0 · 72 % | +48.1 / +18.3 · 74 % |
| | N | +16.7 · 72 % | −11.9 · 64 % | +11.1 · 75 % | +14.2 · 72 % |
| 2021 | M | +2.5 / +28.7 · 57 % | – | – | +2.5 / +28.7 · 57 % |
| | N | +10.8 · 59 % | – | – | +10.8 · 59 % |
| 2022–24 | M | +45.3 / +26.8 · 72 % | +2.1 / −7.8 · 50 % | +4.9 / +10.4 · 37 % | +55.7 / +28.9 · 61 % |
| | N | +45.0 · 72 % | +0.2 · 51 % | +5.1 · 36 % | +52.7 · 61 % |
| 2025–26 | M | −18.8 / +22.8 · 66 % | +4.2 / −11.8 · 48 % | +3.9 / +17.6 · 31 % | −12.2 / +27.4 · 62 % |
| | N | −19.7 · 61 % | +4.1 · 53 % | +0.4 · 13 % | −16.1 · 57 % |
| 2000–26 | M | +1,011.3 / +468.7 · 69 % | −0.1 / −15.0 · 50 % | +46.0 / +66.7 · 24 % | +1,521.0 / +705.8 · 58 % |
| | N | +566.7 · 67 % | +1.7 · 49 % | +39.9 · 23 % | +848.9 · 56 % |

#### 3.3 Why max DD is 5.15 pp deeper

M has two drawdowns deeper than any of N's. Both start at a NAV peak carried by one open position (`equity_curve.csv`, with closes from `data/`):

| drawdown | depth | position on the peak day | open gain at the peak | exit |
|---|---:|---|---:|---|
| 2021-04-12 → 2023-10-27 | 27.67 % | APPS, 57,356 sh at 88.10 | $4.52M = 31.0 % of NAV (14,574,458) | 57.86 |
| 2011-07-21 → 2011-11-25 | 25.50 % | FOSL, 8,558 sh at 133.03 | $763k = 19.8 % of NAV (3,853,395) | 2011-10-03 at 80.12 |

- N's drawdown in 2011 was 16.81 %.
- In the episode both arms share, 2024-11-26 → 2026-06, M is shallower: 19.67 % against 22.52 %.
- The deeper max DD is the same monsters that made the return giving back their gains. It is not a riskier book.

#### 3.4 Diagnostic, outside the rule: the same spec on the non-deduped lists

V differs from M only in having CMN in five lists. Everything else is the same:
- simulator and warehouse code: there is no change to the strategy, simulator, scenario-runner or `build_snapshots` sources between `7e7c65628` and `af6109ca8`;
- the A-D file;
- the macro trace, identical;
- the `.snap` payloads, identical for all 9,236 symbols (`results/wh/rows-new.txt` equals chain V's rebuild rows).

V ended at 1,222.29 % and M at 1,521.64 %. That is **+0.2041 log, +0.85 pp of CAGR, 4.6× N's salt range.**

- **M equals V to the cent every day through 2009-11-06.** CMN in the 2005 list changed nothing. The first difference is on 2009-11-09, when V bought the CMN leg next to CMD: 12,546 sh at 17.42, which is $218.5k or 9.1 % of NAV.
- **What the extra leg pushed out:**
  - On 2009-11-13 M filled ASR. V had cancelled the same ticket at its fill, 34.85 % funded.
  - On 2009-11-27 M placed CRM (`CRM-wein-389`). V placed no CRM ticket at all (`V/vcv-Mpre3339-s0-audit_entries.csv`).
  - M's CRM filled on 2010-02-05 and made +$425,331, 18.2 % of M's NAV at entry. N also held this CRM trade.
  - The extra leg made +$28,729.71 itself. Its effect on the path was −0.204 log: 17 times larger, and of the opposite sign.
- **Later knife-edges:**
  - 2017: GRMN's ticket reached its fill in both books. V was 95.40 % funded and cancelled; M filled it and made +$47.8k.
  - 2026-04: FDX's ticket (placed 2026-04-10) reached its fill with M short by $68.58 (funded 0.9999), so M cancelled; V filled and lost $23.4k.
  - M then placed TWLO on 2026-04-24, filled on 04-30 at 146.68, which carries +$562k unrealised at the end. V has no TWLO ticket. ln(M/V) moved from +0.1670 to +0.2041.

**Year-end ln(M/V):**

| period | ln(M/V) |
|---|---:|
| 2000–2008 | 0.0000 |
| 2009 | −0.0115 |
| 2010 | +0.1210 |
| 2011 | +0.1337 |
| 2012–2016 | +0.1462 |
| 2017 | +0.1490 |
| 2018 | +0.1672 |
| 2019–2025 | +0.1670 |
| 2026-06-25 | +0.2041 |

**Gained and lost entries, M against V** (19 against 27):

| year | gained (M only) | lost (V only) |
|---|---|---|
| 2009 | 3 | 1 (CMN, +$28.7k) |
| 2010 | 6, +$301.0k (CRM +$425.3k) | 10, −$88.3k |
| 2011 | 4, +$30.4k | 8, −$30.0k |
| 2017 | 1, +$47.8k | 1, +$7.4k |
| 2018 | 5, −$132.7k | 6, −$217.2k |
| 2026 | 0 | 1 (FDX, −$23.4k) |
| total | +$246.1k | −$322.8k |

**What this shows.**
- The 26y path moves 0.204 log for a one-name list change and 0.037 log for a $68.58 cash shortfall.
- Both salt ranges understate the noise from any change to the candidate set or to cash:
  - N's: 0.044;
  - chain V's M: 0.0436 (2.5824 / 2.5388 / 2.5774).
- Those salts are near-replicate paths (chain V §2).

### 4. How it fits what we know

- **It re-derives chain V §3.1, now on a V6-clean pair.** The same trades separate the fixed-code books from N (`../verify-chain-v-2026-10-19/README.md` §3.1–3.2):
  - ADSK 2003 (M only);
  - CMG 2010 (N only);
  - LACO → APPS and ADNT in 2020.

  The level gap is a path lottery, as chain V said; now without the twin.
- **It bounds what chain V could not.** Chain V §3.1 put the twin leg's direct effect at about +0.01 log and said its knock-on "cannot be bounded without a rerun". The rerun bounds it at −0.204 log. That supports making the V6 gate categorical (`mechanism-validation-rigor.md` check 8): the defect's path effect dwarfs its own P&L.
- **It confirms four standing memories:**
  - `project_edge_is_the_fat_tail`;
  - `project_funding_grid_monster_lottery` ("one monster ≈ the whole inter-arm spread"; "the cash-pool cascade dominates everything downstream");
  - `project_top_n_capacity_verdict` ("level is a salt lottery");
  - `project_breadth_fix_ad_frozen` with ledger `2026-10-12-breadth-fix-rb1-record-baseline` ("capital-bound tail swap"). There O and N had identical trade lists from 2018-09-25; here M and N are identical through 2023–24.
- **It refines the noise floor the pre-registrations use.** Chain V's #3174 read and this pre-registration compare a delta with the salt range (0.044 log). §3.4 measures 0.204 log from a much smaller structural change. So a 26y arm delta below about 0.2 log that is not traced to the lever's own trades cannot be told apart from path noise. Chain V's #3138 and #3174 conclusions already rested on trade-level traces, so they stand.
- **It re-derives the record's standing diagnoses** (`project_investor_preset_broad`):
  - the 2009 sit-out: the gate reopened 2009-05-01, with 0 entries in the next 13 weeks in both arms;
  - 2025–26 is picks: on UP days, −18.8 % against SPY +22.8 % at 66 % invested in M, and −19.7 % at 61 % in N.
- **Known and still open: the v12 lists are not fully deduped** (`project_pit_chunked_twin_miss`; chain V §4; #3388).
  - #3391 applied 5 of the 790 proposed drops (`../v12-twin-scan-2026-10-22/results/drops.txt`); 551 of the 790 are in top-3000 lists.
  - Neither arm traded a leg that the proposal drops. Both trade survivors (BBWI, BHC, VYX, WTRG, COHR), and M also trades CMD and AXIA.
- **No contradiction was found.**

### 5. What it implies next (options; the choice is the user's)

1. **#3266: close it**, quoting the delta and its label. Nothing else in the rule remains.
2. **Record basis.** The pre-registration keeps N, and nothing here forces a change. If the user wants the record on the fixed code:
   - **(a) Keep N.** Keep pairing every new 26y arm within one tree, as chain V did. This costs nothing; N's level is then one draw of the old code's path, used for orientation only.
   - **(b) Re-baseline after the twin decision.**
     - First decide the remaining 785 rows of the twin proposal (546 of them in top-3000 lists; #3388). Any dedupe re-draws the path, as §3.4 shows.
     - Then run current main (with #3339) at s0–s2 on the final lists, each gated V6 against N. Chain V's Record clause needs at least two salts.
     - Cost: three cells at 11.7k–39.1k s each on this spec (this cell took 27.3k s), plus a warehouse rebuild if the symbol set changes.
   - **(c) Either way, stop reading 26y level deltas against the salt range alone.** Two ways to do that:
     - read only within-tree pairs with trade-level traces, which is current practice;
     - or measure a perturbation null once, for example 3–5 inert single-name list deletions on one salt, to set the floor a lever must clear.
3. **Strategy levers: none.** This is a correctness verification. It adds no lever, and it rules out reading the +0.54 log as an improvement from the fix.
4. **Housekeeping, none of it blocking:** the MRUS stub-bar exit (defect 1); `code_version` in pinned worktrees (defect 2).

### 6. Defects found

| # | kind | defect | specimen |
|---|---|---|---|
| 1 | data | MRUS's last bar is a stub with zero volume, and the `delisted` exit fills at its close | `data/M/S/MRUS/data.csv`, 2025-12-29: o 96.86, h 96.86, l 87.14, c 90.00, v 0, after closes of 96.90–96.92 on 2025-12-23..26. M's MRUS trade (2025-07-18 → 2025-12-30) exits at 90.00 (`results/v3266-Mpre3339-s0-trades.csv`), and so do V's and `vcv-M-s0`'s. At the 2025-12-26 close the trade would be 20,890 × 6.92 = $144.6k higher. Delisting-price class (#2672 / #3215) |
| 2 | artifact | `params.sexp` records `code_version unknown`. The likely cause: `git rev-parse HEAD` runs in the container, but the pinned worktree's `.git` file points at a host path | `results/v3266-Mpre3339-s0-params.sexp` line 1. `.claude/worktrees/sweep-v3266/.git` points at `/Users/difan/Projects/trading-1/.git/worktrees/sweep-v3266`. Chain V's params carry `7e7c65628…`. Provenance survives in `chain.log` line 1 |
| 3 | artifact gap (resolved) | Facts used above lived outside `results/`: warehouse identity and screen decisions | Now committed: `results/wh/rows-new.txt`, `results/wh/rows-v12.txt` and `results/screen-decisions-traced.txt` (the CMD, CMN, CMG, BWA, SGEN, ADSK, APPS, MRUS, CRM, ATYT, FDX and TWLO decisions from the 14.3 MB `trade_audit.sexp`, extract command in its header). N's 10-12 pack NAV extract for the RV2 table stays uncommitted; its input is N's committed `equity_curve.csv` |
| 4 | review pack (fixed) | The run-tree pack was built before #3395, so it showed D4, D6 and D10 | Fixed in the published pack, rebuilt at `e438c03f5` |
| 5 | review pack (known) | A spin-off encoded as a split reads as a fill outside the day's range (chain V's D9, #3215 class) | OKE 2013-09-18: 46.15 against the bar [51.89, 54.53] |
| 6 | perf (known) | Wall time 2.33× higher with identical cache counters | 27,309 s here against chain V's 11,709 s on the same spec (#3381) |

No simulator fill defect was found. There were no late stops, no Saturday fills and no fallback stops. Every one of the 670 placements was on a Bullish or Neutral reading.

### Appendix: What-stands-out bullets (RV3)

| # | bullet | read |
|---|---|---|
| 1 | Eras vs SPY: built 2000–08 (1.00→3.30×), eroded 2009–12, built 2013–15, eroded 2016–19, built 2020, eroded 2021, built 2022, eroded 2023, built 2024, eroded 2025–26; ends at 2.01× | **Confirm; refine.** N's pack ends at 1.18×. The gap opens in 2003–04 (ADSK, M only) and in 2020 (APPS). "Built 2020 / eroded 2021" is APPS's round trip: top close 94.74 on 2021-03-01, exit 57.86 (`data/A/S/APPS/data.csv`) |
| 2 | Eroded 2009–12: cash through rebounds (DOWN days +7.1 % vs SPY +27.4 % at 38 %) | **Confirm.** The 2009 sit-out (reopen 2009-05-01, 0 entries in 13 weeks) is in both arms. **Refine:** in this era M's UP days match SPY (+29.9 % vs +30.1 % at 67 %). N lagged on UP days (+17.1 % at 62 %) and led on DOWN days (+20.5 % at 45 %) |
| 3 | Eroded 2016–19: cash through rebounds (DOWN +0.3 % vs +11.9 % at 15 %); holdings also lagged (UP +24.7 % vs +37.1 % at 66 %) | **Confirm.** N has the same shape: UP +29.7 % at 65 %, DOWN −3.7 % at 14 % |
| 4 | Eroded 2021: holdings lagged (UP +2.5 % vs +28.7 % at 57 %) | **Refine.** This is APPS's round trip. On the same days N made +10.8 % at 59 %; N held ADNT (+$463.7k) to 2021-06-21 and M did not |
| 5 | Eroded 2023: behind in transition weeks (MIXED +4.5 % vs +11.3 % at 37 %); holdings also lagged (UP +5.1 % vs +10.1 % at 49 %) | **Confirm.** N is identical: both arms made the same 2023 entries |
| 6 | Eroded 2025–26: holdings lagged (UP −18.8 % vs +22.8 % at 66 %) | **Confirm.** This is the record's "2025–26 is picks" (N: −19.7 % at 61 %) |
| 7 | Fill-week volume: 516 of 566 long fills under 2× | **Refine: not new.** The pack's own rule gives N 522 of 570 and V 523 of 574. Resting tickets fill after the screened breakout week, so this is a standing property. The screen-week volume check passes 552 of 670 (audit R2, 82.4 %) |
| 8 | Gate reopens: 13. Sat out 2009-05 (0 entries, −2.3 % vs +19.1 %); invested and lagged 2025-05 (14 entries, −0.3 % vs +16.6 %) | **Confirm.** N has the same two: 2009-05 with 0 entries (−2.4 %), and 2025-05 with 13 entries (−4.2 % vs +14.5 %). M's reopen is 2025-05-30, a week after N's 2025-05-23, because of the 2025-05-23 reading in item 2 |
| 9 | Entries cancelled at the fill for cash: 43; 6 at least 90 % funded | **Confirm** (`cash_rejections.txt` reads 43; N had 41, 3 of them at least 90 % funded). **Refine:** one of the six, FDX 2026-04-10 at 0.9999 funded, is the knife-edge that separates M from V in 2026 (§3.4) |
| 10 | Worst three-year stretch: 2023–25, +47.3 % vs SPY +85.5 % | **Refine.** N's worst stretch is 2019–21 (+43.2 % vs +99.9 %). APPS lifts M's 2019–21, so the record's known UP-regime lag in 2023–25 becomes M's worst |
| 11 | Ten trades made $14.50M of the $10.78M realised; the 152 A-grade trades made $27.57M | **Confirm the fat tail.** These figures are price-only. With dividends, closed trades made $12.90M, plus $1.25M of interest |
| 12 | 0 of 566 used the 4 % fallback stop | **Confirm** (the config implies zero) |
| 13 | 67 of 283 stop exits filled more than 0.5 % beyond the stop; 0 sold at an open after the stop traded; 138 D/F losers, −$8.56M | **Confirm** the config-implied zero: 187 fills on the same day, 0 later. N has the same shape (74 of 287; 146 losers; −$5.85M) |
| 14 | Average invested: 58 % of NAV, about 5.5 positions | **Refine (RV2).** By regime: UP 69 %, MIXED 50 %, DOWN 24 %, against N's 67 %, 49 % and 23 %. The M − N gap comes on UP days at 2 pp more exposure (§3.2) |
| 15 | 0 trades with a fill on a day with no bar; V13 counts 19 (8 skipped) | **Confirm.** N's 10-12 pack read 1: the NLC exit stamp, which #3262 now excludes. N's V13 is 21 (6 skipped) |
| 16 | Collapsed note, years that rest on one trade: 2022 GLNG (+8.9 % of start-of-year NAV, against a +13.9 pp gap); 2024 ADMA (+29.6 %, against +25.3 pp) | **Confirm.** The same two appear in N's pack and in chain V's packs |

**A pattern seen by eye that no signal flags (RV3).**
- Both of M's two deepest drawdowns start at a NAV peak where one open position holds 20–31 % of NAV in open gain: FOSL on 2011-07-21 and APPS on 2021-04-12.
- Chain V's `vcv-M` has the APPS case too.
- The NAV-peak give-back signal looks only at the final peak.
- A detector is feasible: for each drawdown of at least 15 %, take the largest single position's open gain at the peak as a share of NAV, and flag it at 15 %. Filed as a follow-up on the review-pack defect umbrella (#3384).
