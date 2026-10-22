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
