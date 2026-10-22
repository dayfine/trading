# verify-chain-v-2026-10-19: the 26y verification chain for #3266, #3263, #3173, #3138 and #3174

**Pre-registration.** Nothing has run. Every read below is fixed before the first cell launches. Plan:
`dev/plans/issue-burndown-2026-10-19.md` §Chain V (PR #3340).

This chain closes, or fails to close, the `[after-merge]` items of five issues (four `verify/pending`, plus #3263,
whose fix #3339 merged on 10-19) with one set of 26y cells on the record spec.

## Design

- **Base spec:** the record N spec, `../breadth-fix-rb1-2026-10-11/specs/rb1-26.sexp` (rb1 + full NYSE A-D, #3252).
  - It is copied byte for byte below a new header; only `name` and `description` change.
  - Investor preset, 2000-01-01 → 2026-06-26, top-3000 PIT v12 schedule.
  - Total-return accounting: `cash_yield` T-bill series, fee 10 bp, `dividend_crediting true`,
    `split_dividend_guard true`.
- **Run tree:** one pinned worktree at `origin/main` at launch (`.claude/worktrees/sweep-vcv`).
  - `chain.sh launch` refuses a tree that lacks any of:
    - #3283 (the #3266 fix);
    - #3181 and #3222 (the #3173 guard and its default flip);
    - #3193 (#3174);
    - #3195 (#3138's audit record);
    - #3339 (1f2432fa2, the #3263 A-D fixture fix).
  - Since N's tree (524bc2df0), main changed strategy or simulator code only behind default-off flags or in reporting:
    - #3254 holiday-Friday screening;
    - #3280 symbol-class filter;
    - #3282 stop-vs-margin cover;
    - #3297 `raw_confirm_min_share` (no caller sets it);
    - #3301 true-dollar liquidity gates;
    - #3256 and #3296 (trades.csv and audit columns only).

    **Two default-on changes reach this spec:**
    - #3283, the #3266 week-bucketing fix (code, and the rebuilt warehouse below);
    - #3339, the #3263 fix: 39 rows removed from each of `trading/test_data/breadth/nyse_{advn,decln}.csv` (38 NYSE
      closures and the 2009-10-24 Saturday). It changes no shipped code, but the macro gate reads the fixture
      through `TRADING_DATA_DIR`, so every M cell's A-D input differs from N's. Ten of the removed dates fall within
      ±2 weeks of 1 January, the same weeks #3283 acts on, so the two cannot be told apart from M against N alone.
      The extra cell **M-pre3339** separates them (§Arms).
- **Warehouse: `/tmp/snap_top3000_pit_v12wk`, rebuilt by the chain, not `/tmp/snap_top3000_pit_v12pit`.**
  - **Why:** #3266's own comments say the rerun "must use a rebuilt snapshot warehouse". `_v12pit` was built on
    2026-10-08, before #3283 (2026-10-13). It still stores the split year-end weeks in its Stage, RS and Macro columns
    and its `.weekly` side-table, and no hash detects this.
  - **What it rebuilds:** exactly `_v12pit`'s 9,236 manifest symbols, at the pinned tree, in four chunks.
    - Same `START` (1998-01-01), `END` (2026-10-07) and `warehouse_exceptions.sexp` (md5 `9b7752ba…`, unchanged
      since 09-08) as the v12 build.
    - No twin dedupe: the v12 set is already deduped, and the dedupe pass only drops legs; it never alters a survivor.
    - The only builder change since v12 is #3283 itself (`git log` over `build_snapshots/`, `snapshot_pipeline/` and
      the exceptions file).
  - **Guards:**
    - the rebuilt symbol set must equal v12's;
    - the symbols whose CSV `mtime` changed since the v12 build are written to `wh/csv-mtime-changed.txt`;
    - **the fix detector counts only the other, stable symbols.** Among symbols whose CSV `mtime` is unchanged,
      at least one must have a different `.snap` payload or `.weekly` file from v12, or the chain aborts ("the
      #3266 fix did not reach the warehouse"). A refreshed CSV changes its own payload whether or not the fix
      reached the columns, so drift alone cannot satisfy the guard. The count and its share of the stable symbols
      are logged, and the list is kept as `wh/differs-stable.txt`. The fix should touch nearly every symbol whose
      history spans a split year-end week, so a small share is itself worth tracing.
    - `mtime` is a proxy: `rsync -a` keeps mtimes, so a content change with an old mtime goes unseen, and a `touch`
      reads as drift. It is a drift list, not a content diff.
  - **Every arm runs on the rebuilt warehouse**, so all within-chain pairs share one warehouse.
  - The warehouse does not read the A-D fixture (`pipeline.ml` builds the macro column with `~ad_bars:[]`), so it
    is the same for M and M-pre3339.
- **Inputs are staged outside any VCS tree** (`/tmp/vcv-run`):
  - specs and `chain.sh` come from the pre-registration commit;
  - the v12 lists must be a subset of the manifest (MEL excepted);
  - the pre-#3339 A-D CSVs (`git show 1f2432fa2^:…`), for M-pre3339;
  - the EODHD `dividends.csv` / `splits.csv` files modified since N staged its copy (2026-10-11) are listed in
    `corp-actions-changed.txt` before the rsync. They feed M and not N, so they are a confound of the M − N delta
    and of the #3173 read, like the CSV drift list;
  - EODHD `dividends.csv` and `splits.csv` are rsynced into the run tree's `test_data`.

### Arms (spec files in `specs/`)

| arm | spec | differs from M by | salts |
|---|---|---|---|
| **M** | `vcv-M.sexp` | (the record N spec, on current main) | 0, 1, 2 |
| **M+3138** | `vcv-M3138.sexp` | `((entry_fill_size_to_available true))`; `entry_fill_min_size_fraction` stays at its default 0.5 | 0, 1, 2 |
| **M+3174** | `vcv-M3174.sexp` | `((ex_dividend_stop_adjust true))` | 0 |
| **M-pre3339** | `vcv-Mpre3339.sexp` | the pre-#3339 NYSE A-D fixture (input data, not config) | 0 |

The flag names are the config fields in `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli`. Both
default to `false`.

**M-pre3339** is the tree just before #3339, as the backtest sees it. The spec is vcv-M with only `name` and
`description` changed, and it runs on the same binary and warehouse as M. Its `TRADING_DATA_DIR` is a copy of the
run tree's `test_data` (symlinks) whose `breadth/nyse_{advn,decln}.csv` are the pre-#3339 files
(`git show 1f2432fa2^:…`, which equal bf264f258's).

- **Why not a second tree at bf264f258:** #3339 changes no shipped code, only the two CSVs, a test and a README.
  `launch` checks both this and that no later commit touches the CSVs. So swapping the two files undoes #3339 and
  nothing else, without a second build. M − M-pre3339 stays #3339 alone even if main moves before launch; a
  bf264f258 tree would also carry whatever lands in between.
- **The decomposition:**
  - N s0 → M-pre3339 s0 is #3283 plus input drift (CSV refreshes, `dividends.csv` / `splits.csv` changes): the
    #3266 read;
  - M-pre3339 s0 → M s0 is #3339 exactly: the #3263 read;
  - N sK → M sK (K = 1, 2) is the joint delta, reported as such.
- The macro trace does not depend on the salt: N's three `macro_trend.sexp` files are identical (md5 `31ed4a09…`).
  So salt 0's attribution of every changed macro reading holds for all salts. The read confirms this for M (md5 of
  M s0/s1/s2 `macro_trend.sexp`); if M's three differ, the attribution is stated for s0 only.

### Cells, one at a time (`container-capacity-scheduling.md`: no agents beside the chain)

Order: M s0, M-pre3339 s0, M+3174 s0, M+3138 s0, M s1, M+3138 s1, M s2, M+3138 s2.

- Salt 0 of every arm runs first, so a mid-chain death still leaves one salt of each read.
- **Cost:**
  - warehouse rebuild about 1.5 h (v12 chunks took about 20 min each per 2,300 names);
  - four 3-month preflights;
  - 8 cells at about 2.3–3.3 h each (this spec measured 8,207–11,881 s);
  - **about 21–29 h in total, central estimate about 25 h**. Plan §Chain V said about 17 h; the difference is the
    rebuild, the preflights and the M-pre3339 cell (one more cell, about 2.3–3.3 h).
- **Guards:**
  - `CELL_TIMEOUT` is 36,000 s: the slowest measured cell of this spec took 11,881 s, and 1.5× that is 17,822 s;
    3× covers the two unmeasured arms.
  - Host free ≥ 20 GB before every cell.
  - A `mkdir` lock (macOS has no `flock`).
  - The run tree is checked for its HEAD and for being clean.
  - Launch is refused while any `build_snapshots`, `scenario_runner`, `panel_runner` or `bayesian_runner` process
    is live.
- **Every cell logs:**
  - its GNU-time `peak_rss_kb`;
  - the snapshot-cache line;
  - the corporate-action lines: `split_dividend_guard rejected/no_files`, and for M+3174
    `ex_dividend_stop_adjust reduced/skipped_no_amount/no_files`;
  - its `cash_rejection` count from `trade_audit.sexp`;
  - its `TRADING_DATA_DIR`;
  - its validator V6/V16/V17 lines;
  - `RESULT … (wall Ns)` for `perf_long_cells.sh`.

## Validity gate (every pair)

Each pair is gated with `validator_diff -check V6`; the chain runs it per cell:

- M sN against the committed N sN report, `../breadth-fix-rb1-2026-10-11/results/N-rb1-26-sN-v12-validator.sexp.sexp`;
- M-pre3339 s0 against N s0 (the #3266 pair) and against M s0 (the #3263 pair);
- M+3138 sN against M sN;
- M+3174 s0 against M s0.

Each comparison writes `<tag>.v6diff-<label>.log` (label `N` or `M`).

How each exit code is read:

- **Exit 0:** the pair is read.
- **Exit 1:** that pair yields no delta and is reported as excluded, naming the specimen.
- **Exit 2** (a report cannot be compared; possible only for the cross-build M-vs-N pair, if the report format
  moved since 10-12): the gate falls back to the absolute V6 line of each report. Both must read `V6 INVARIANT PASS`.

Every cell must also write `actual.sexp`. A `<no result>` is traced (OOM or input) before any relaunch.

## Pre-registered reads, per issue

### #3266: rerun the record on N's spec and report the delta

**[after-merge] item:** "Rerun the record on N's spec (one salt is enough) and report the delta", on a rebuilt
warehouse.

**Read:** the #3266 delta is **M-pre3339 s0 against the committed N s0**
(`../breadth-fix-rb1-2026-10-11/results/N-rb1-26-s0-v12-*`): both run on the pre-#3339 A-D fixture, so the pair
differs by #3283 (code plus rebuilt warehouse) and input drift only. The joint delta **M sK − N sK**, per salt that passes V6, is reported beside it and
labelled #3283 + #3339 + drift.

1. **Delta.** M-pre3339 s0 − N s0, and M sK − N sK, on:
   - total return, in log `ln(1+R)` and in %;
   - CAGR, max DD, Sharpe, Calmar, trades.

   N reads 849.28 / 835.99 / 878.27 %, i.e. 2.2505 / 2.2364 / 2.2806 log; its own salt range is 0.044 log.
2. **Where the fix acts.** From `macro_trend.sexp`, count the weekly readings whose `trend` or `breadth_state`
   differs between **M-pre3339 s0 and N s0**, by year, split into weeks within ±2 weeks of 1 January and all other
   weeks.
   - The fix changes bucketing only at year-crossing weeks. A difference far from a year-end comes through the
     30-week and A-D windows those weeks feed, and is traced on one example.
   - Because both cells read the same A-D fixture, none of these differences can come from #3339.
3. **Entries gained and lost** (M-pre3339 s0 vs N s0, and M sK vs N sK), joined on `symbol|entry_date` from
   `trades.csv` (`position_id` is not a cross-arm key), with each set's P&L and the three largest contributors
   traced. Each set is also split **by entry year**, so a delta concentrated in one era is visible.
4. **Data drift.** Any symbol in `wh/csv-mtime-changed.txt` or `corp-actions-changed.txt` that the compared cells
   traded is listed with its P&L. It is a confound of the delta, not part of the fix.

**Verdict rule.** This is a correctness fix, not a mechanism, so there is no accept or reject.

- **Satisfied:** M-pre3339 s0 completes, passes V6 against N s0, and the delta is reported with items 1–4, whatever
  its sign or size. #3266 then closes, quoting the delta. (The item asks for one salt.)
- **Fallback, if M-pre3339 s0 fails or V6 excludes it:** the delta is read from M sK − N sK and is **joint**. Each
  changed macro reading is then labelled #3339 (its week contains one of the 39 removed dates), #3283 (a
  year-crossing week with no removed date), or joint/propagated (anything else), and the writeup states that the
  attribution is approximate. #3266 is satisfied on that basis only if at least one M salt passes V6 against N.
- **Not satisfied:** no pair with N passes V6. #3266 stays `verify/pending`, with the specimen.
- **Record:** M replaces N as the record basis for later 26y comparisons, as breadth-fix did for N. That needs at
  least two M salts gated against N. Otherwise N stays the record and the delta is reported only.

### #3263: the record's macro trace before and after the A-D fixture fix

**[after-merge] item:** "The record's macro trace (`macro_trend.sexp`) is diffed before and after; any reading that
changes is listed on this issue."

**Read:** M s0 against M-pre3339 s0. They share the binary, warehouse, spec and salt, and differ only in the two A-D
CSVs, so every difference is #3339's.

1. **The diff.** Every weekly `macro_trend.sexp` row whose `trend` or `breadth_state` differs: date, before, after,
   and whether its week contains one of #3339's 39 removed dates (2009-10-24 included). A change in a week with no
   removed date is propagation through the A-D windows, and one such case is traced. The list may be empty; an
   empty list is an answer.
2. **Salt independence.** M's three `macro_trend.sexp` files are compared (md5). If they agree, the s0 list holds
   for every salt.
3. **Effect.** Total return (log), max DD and trades, M s0 − M-pre3339 s0, if V6 agrees on that pair; entries
   gained and lost, joined on `symbol|entry_date` and split by entry year, with the three largest traced. With V6
   disagreeing, the effect is reported as excluded, naming the specimen; the macro diff (items 1–2) stands either
   way, since the macro trace depends on market inputs only, not on the book.

**Verdict rule.**

- **Satisfied:** both cells write `macro_trend.sexp` and the list from item 1 (possibly empty) is posted on #3263
  with items 2–3. #3263 then closes.
- **Not satisfied:** either cell writes no `macro_trend.sexp`. #3263 stays `verify/pending`. The fallback is the
  labelled approximation from the #3266 fallback above, posted as such.

### #3173: TDG / WING / BCH credited once

**[after-merge] item:** "Re-run of the 26y TR pair shows the three events credited once."

**Read:** arm M, all three salts. M+3138 and M+3174 cells are supporting evidence only.

Specimens: TDG 2013-07-11 ($22.00), WING 2018-02-08 ($3.17), BCH 2010-03-17 ($3.90).

1. **Held.** A specimen is *held* in a cell if a position spans its ex-date. A resting entry ticket that never fills
   leaves no evidence, so it counts as **not tested**.
2. **Pass condition.** A held instance **passes** when all of these hold:
   - the cell's `splits.csv` has no split for that symbol within ±2 bars of the ex-date;
   - the position's quantity does not jump on that date (`trades.csv`, `open_positions.csv`);
   - the dividend is credited once: the position's `dividends_received` (#3175) includes `quantity ×
     unadjusted_amount` for that ex-date exactly once, and the equity-curve move on the ex-date carries no second
     credit.
3. **Guard counts.** Each cell's `split_dividend_guard rejected=… no_files=…` line is reported.

Verdict rule (as rebaseline-v12 item 2):

- **Satisfied** if at least one specimen is held in an M cell and every held instance passes. #3173 then closes.
- **Fails** if any held instance fails. File the specimen.
- **Not tested** if no specimen is held in any M cell. #3173 stays `verify/pending`, resting on #3181's unit tests.
  (In rebaseline-v12, WING was held in 6 of 6 cells and TDG in 3, so this outcome is unlikely.)

**Pre-check on N's committed artifacts (2026-10-19): the item is already satisfied by the same rule.** N's tree
(524bc2df0) contains #3181 and #3222, and its spec is the TR record. From
`../breadth-fix-rb1-2026-10-11/results/N-rb1-26-s{0,1,2}-v12-*`:

- **WING 2018-02-08 ($3.17), held in 3 of 3 N cells.** One position each, 2017-08-08 → 2018-07-30, 11,953 / 11,834 /
  12,283 shares. `dividends_received` is 41,237.85 / 40,827.30 / 42,376.35, which is exactly quantity × $3.45, the
  sum of the vendor's unadjusted amounts over the hold (0.07 + 0.07 + 3.17 + 0.07 + 0.07): the special is credited
  once, on the unchanged share count.
- **TDG 2013-07-11 ($22.00), held in 3 of 3 N cells.** One position each, 2013-07-08 → 2013-07-11 (stopped out on the
  ex-date), 2,913 / 2,894 / 3,001 shares. `dividends_received` is 64,086 / 63,668 / 66,022 = quantity × $22.00
  exactly. #3173's specimen had 3,446 phantom shares against about 2,975; here the quantity is the bought one. (N s1
  also holds TDG 2013-11-26 → 2014-06-23 across the $25 special of 2014-06-12: 1,550 × 25 = 38,750, credited once.)
- **No split applied:** none of the three cells' `splits.csv` has a TDG, WING or BCH row.
- **BCH 2010-03-17:** not held in any N cell; not tested, as in rebaseline-v12 (absent from the v12 lists for
  2009–11).
- **Guard line:** `split_dividend_guard rejected=4 no_files=0` in each N cell (rebaseline-v12 rb1 read 2 / 3 / 3).
  The guard prints counts only, so the four events are not named.

So #3173's item can close on N's artifacts now; that is the dispatcher's call. M's read above still runs as written:
it re-confirms the guard on the post-#3283 tree and the refreshed `dividends.csv` / `splits.csv`.

### #3138: `entry_fill_size_to_available`, paired 3-salt read

**[after-merge] item:** "Paired 3-salt 26y run with `entry_fill_size_to_available` on the investor preset (expected
~+0.09 log, lower salt dispersion), pre-registered."

**Read:** M+3138 against M, per salt that passes V6.

`Δk = ln(1+R[M+3138, sk]) − ln(1+R[M, sk])`. Salt dispersion is the range (max − min) of `ln(1+R)` over salts
within an arm.

1. **Liveness.** The mechanism is *live* if M+3138 records fewer `cash_rejection` cancellations
   (`<tag>-cash_rejections.txt`, from `trade_audit.sexp`) than M on at least one salt. If the counts are equal on
   every salt, the flag did not fire: **not tested**. Trace why before reading Δ.
   - Corroboration: M+3138's `trades.csv` differs from M's on that salt. Counts can rise again after the paths
     diverge, so equal counts with differing trades are traced to a resized fill before being called not live.
2. **Rule, fixed now.** The issue's expectation is +0.09 log; half of it, 0.045, is the bar. Write *k* for the
   number of salts with Δ > 0 and *D* for "M+3138's dispersion < M's". **The rows are evaluated in order and the
   first that matches is the outcome**, so every result gets exactly one.

   | order | outcome | condition |
   |---|---|---|
   | 1 | **Refute** | mean Δ ≤ 0 |
   | 2 | **Confirm** | mean Δ ≥ +0.045 **and** k ≥ 2 **and** D |
   | 3 | **Confirm return, not dispersion** | mean Δ ≥ +0.045 **and** k ≥ 2, **not** D |
   | 4 | **Inconclusive** | everything else: 0 < mean Δ < +0.045 (any k), **or** mean Δ ≥ +0.045 with k ≤ 1 |

   - **The one-salt case** (mean Δ ≥ +0.045 carried by a single positive salt, k = 1 or 0) is **Inconclusive**, not
     Confirm and not Refute. It is the shape the issue's own +0.09 had (one specimen, s1 ADMA), so it is named here.
   - Only a mean Δ ≤ 0 refutes.
   - With fewer than 3 salts gated, the read is reported per salt and is **Inconclusive** by rule.
3. **Paired per-event read** (`mechanism-validation-rigor.md` check 6).
   - The committed inputs: each cell's `<tag>-cash_rejections.csv` (one row per cash cancellation: `position_id`,
     `symbol`, `entry_date`, `ticket_age_weeks_at_cancel`, `required`, `available`, `funded_fraction`) and
     `<tag>-audit_entries.csv` (one row per audit record: `position_id`, `symbol`, `entry_date`, `cancel_reason`,
     …). `entry_date` there is the audit's placement date; the cancel step's date is not stored (it is placement +
     `ticket_age_weeks_at_cancel` weeks).
   - Find the entries that M cancelled at fill for cash and that M+3138 booked resized: join M's
     `cash_rejections.csv` to M+3138's `audit_entries.csv` on `symbol|entry_date` (placement date, the same ticket in
     both arms), then M+3138's `position_id` to its `trades.csv`.
   - Report their count, fill fraction (filled ÷ designed: M+3138's `quantity × entry_price` over M's `required`)
     and realised P&L, and the three largest, traced. The issue's +0.09 came from one specimen: s1 ADMA, about
     $1.6M.
   - Split the recovered cohort, and the gained / lost trades below, **by entry year**
     (`cash_rejections_by_year.csv` gives each cell's rejections per year).
   - Also report the path divergence after the first resized fill: trades gained and lost elsewhere, joined on
     `symbol|entry_date` from `trades.csv`.
4. **Calibration.** At most this verifies the issue's stated expectation. It is not a ledger ACCEPT.
   - The flag stays default-off.
   - A default flip needs a ledger entry plus the confirmation grid (`promotion-confirmation.md`); this is one window
     and three salts.
   - The writeup states the *why*: a near-miss cohort recovered, versus a fat-tail lottery on one name.

#3138 is **satisfied** (closes) once the pre-registered read is applied and reported with any of the four outcomes.
It is not satisfied if liveness fails or fewer than 2 salts pass V6; the issue then stays `verify/pending` with the
reason.

### #3174: ex-dividend stop adjustment, axis read at salt 0

**[after-merge] item:** "Axis read on the 26y TR pair."

**Read:** M+3174 s0 against M s0, if V6 agrees.

1. **Liveness:** the cell's `ex_dividend_stop_adjust reduced=N` line, with N > 0.
   - With N = 0, the read is **not tested**: trace `no_files` and `skipped_no_amount` first.
2. **Delta:**
   - total return (log), max DD, Sharpe, trades;
   - the stop exits that fall on an ex-date in M and do not in M+3174, each with its P&L.
3. **Specimens.** AD 2025-08-20 ($23 special) and BKE 2021-12-17 ($6), if held in s0: M exits at the ex-date open;
   M+3174 does not.
4. **Calibration.** One salt is an axis read, not a verdict.
   - |Δ| below M's own salt range (N's was 0.044 log; M's is measured by this chain) reads as "indistinguishable
     from path noise".
   - The flag stays default-off either way.
   - Promoting it is a separate decision under `experiment-flag-discipline.md` R3. Like `dividend_crediting`, it is
     a fill-realism dial, so the accounting-change precedent (#1926) may apply. That is for the writeup to argue,
     not this run.

#3174 is **satisfied** (closes) when the cell completes, V6 agrees and liveness holds, whatever the sign.

The `BOOK-CHECK-NEEDED` item from #3193's review (Weinstein Ch. 6 and the never-lower-the-stop rule) is separate:
this run does not answer it, and the writeup says so.

## Review packs (`backtest-result-review.md`)

`chain.sh` builds one pack per arm, from the pinned tree and against the rebuilt warehouse:

- `review_pack.sh` over that arm's salts;
- `review_pack_render.sh`;
- the output is copied to `.sweep-output/review-vcv-{M,Mpre3339,M3138,M3174}/` (`site/`, `render/top.png`,
  `part-N.png`).

Before any analysis:

- `top.png` and every `part-N.png` are read: window 2000–2026, the KPI strip matching `actual.sexp`, no mojibake or
  empty panels;
- config-implied zeros are checked: stop breaches before the exit day ≈ 0 with trigger-bar fills on; no Bearish-macro
  buys;
- the cash-rejection card (#3195) must read lower in M+3138 than in M.

What the look found goes in the writeup's "Review-pack look" section (RV1). Every signal bullet is confirmed, refined
or rejected (RV3). Packs are published as artifacts and linked in the results PR.

## After the run

1. `sh chain.sh collect dev/experiments/verify-chain-v-2026-10-19/results`. This copies the per-cell `actual.sexp`,
   `trades.csv`, `splits.csv`, `equity_curve.csv`, `macro_trend.sexp`, `open_positions.csv`, `summary.sexp`,
   `params.sexp`, `force_liquidations.sexp`, `validator.sexp.{sexp,md}`, `.log`, `.rss` and `.v6diff-<label>.log`.
   - `trade_audit.sexp` (about 12 MB a cell) is reduced to `<tag>-audit_entries.csv` (one row per record),
     `<tag>-cash_rejections.csv` (one row per cash cancellation, about 40 a cell), `<tag>-cash_rejections.txt` (the
     count) and `cash_rejections_by_year.csv` (cell, entry year, count).
   - Also copied: the chain log, `corp-actions-changed.txt`, and the warehouse chunk build logs plus
     `csv-mtime-changed.txt` and `differs-stable.txt`.
   - A `<no result>` cell still logs `RESULT <tag>`, so a relaunch skips it. To rerun it after tracing, delete that
     line from `/tmp/vcv-run/chain.log`.
2. `sh dev/scripts/perf_long_cells.sh update results/chain.log` (`perf-review-weekly.md` step 3).
3. Run `results-analyst` (direction class) on this README plus the artifacts and the rendered packs. `qc-results`
   reviews the results PR.
4. The PR body carries one `Verifies #N: <item> — <evidence path>` line per satisfied item (`issue-hygiene.md` B).
   The dispatcher closes each satisfied issue after merge, quoting the evidence.

## Launch

The dispatcher launches it when the container is free, from the repo root, after this PR merges (the run SHA then
holds the specs and the script):

```sh
sh dev/experiments/verify-chain-v-2026-10-19/chain.sh launch
# progress: tail -f /tmp/vcv-run/chain.log
```

To launch before the merge, set `PREREG=<this PR's head sha>` (fetched locally). The run tree stays at
`origin/main`; `RUN_SHA=<sha>` pins it elsewhere (any length; it is normalised to 9 characters).

Before launching, the operator runs `sweep-hygiene.md`'s pre-launch checks (host free > 50 GB, `Docker.raw`
< 30 GB, no other agent or backtest). The script's own 20 GB check is the during-sweep floor, not that checklist.

To validate the specs without a 26y cell, from a built tree:

```sh
WTREL=<built tree> sh chain.sh validate [vcv-M vcv-Mpre3339 vcv-M3138 vcv-M3174 control]
```

This is a parse and override check only. `scenario_runner` applies `config_overrides` (`Overlay_validator`) before
it prints `Running backtest`.

- Each spec is VALID iff its log reaches that line within `timeout 300`.
- `control` (vcv-M plus a nonexistent override) must fail before that line.

Run on 2026-10-19 at bf264f258 against `_v12pit`: vcv-M, vcv-M3138 and vcv-M3174 were VALID, and the control was
rejected ("Scenario control crashed: (Failure … unknown keys …)").

Re-run on 2026-10-19 at the rework tree (bf264f258 plus this directory) against `_v12pit`: vcv-M, vcv-Mpre3339,
vcv-M3138 and vcv-M3174 were VALID, and the control was rejected the same way.

## Files

- `specs/vcv-M.sexp`, `specs/vcv-Mpre3339.sexp`, `specs/vcv-M3138.sexp`, `specs/vcv-M3174.sexp`
- `chain.sh`: `launch` / `run` / `validate` / `collect`
- `results/`: per-arm artifacts, after the run

## Log

- 2026-10-19: pre-registered; `validate` passed (see Launch).
- 2026-10-19, QC rework 1 (PR #3342): added #3263 and the M-pre3339 cell (#3339 had merged); made the #3138 outcomes
  an ordered, exclusive list; the warehouse fix detector now counts stable symbols only; `collect` keeps one row
  per cash rejection and per audit record; recorded the #3173 pre-check on N. `validate` re-run at the rework tip
  (see Launch).

- 2026-10-22: results read committed (Results section). qc-results R9 rework: memories `project_sim_price_only_accounting` (ADMA-style cancellations are path luck, superseding the 10-07 "not path luck" line) and `project_funding_grid_monster_lottery` (chain V re-derives the funding lottery) updated; RV3 bullet 16 read from its criteria.
## Results (2026-10-22)

All eight cells finished, and each wrote `actual.sexp` with `crashed false`. The artifacts are at `0a574dad9` under
`results/` (this directory). N's are under `../breadth-fix-rb1-2026-10-11/results/` (written `N/` below).

**Outcome in one line per issue:**

| issue | rule outcome | action |
|---|---|---|
| #3266 | **Not satisfied.** No pair with N passes V6. The only specimen is a CMD/CMN twin held in every chain cell. | stays `verify/pending` with the specimen; **N stays the record** |
| #3263 | **Satisfied.** 11 weekly readings change. None of them falls in a week that contains a removed row. Effect +0.0005 log. | post the list (§1.2) on #3263, then close |
| #3173 | **Satisfied (re-confirmation).** TDG and WING are each held in 3 of 3 M cells and every instance passes. BCH is not held. | already closed 10-19; remove the stale `verify/pending` label |
| #3138 | **Refute** (row 1). Mean Δ is −0.047 log, and 0 of 3 salts are positive. | closes; the flag stays default-off |
| #3174 | **Live; axis read only.** Δ is −0.048 log at s0, and \|Δ\| is just above M's salt range of 0.044. | closes; the flag stays default-off |

### Run and validity

- **Same build, same input.**
  - Every cell ran at HEAD `7e7c65628`, which is the pre-registration commit, on the rebuilt `/tmp/snap_top3000_pit_v12wk`
    (`results/chain.log` lines 1, 29–66).
  - `TRADING_DATA_DIR` is the run tree for M, M+3138 and M+3174, and `/tmp/vcv-td-pre3339` for M-pre3339.
    - Line 19 logs that copy's A-D md5 as `1b916149…`.
    - I checked that it equals `git show 1f2432fa2^:…`, and that it equals the fixture in N's tree `524bc2df0`.
    - So N and M-pre3339 read the same A-D input.
- **Specs.** The body of `vcv-M.sexp` is byte-identical to N's `rb1-26.sexp` (a diff of the two bodies is empty). Each other arm adds
  one override (`*-params.sexp`).
- **Warehouse.**
  - The rebuilt warehouse has 9,236 entries, and 0 CSV mtimes changed since v12.
  - Of the 9,236 stable symbols, 8,851 (95.8 %) differ from v12 in payload or `.weekly` (`chain.log` line 18). The
    #3283 fix reached the warehouse.
  - Both drift lists, `wh/csv-mtime-changed.txt` and `corp-actions-changed.txt`, are empty.
- **Incidents.**
  - **M+3138 s1** was killed by the guard at 36,022 s, then rerun with a 72,000 s guard; the rerun took 29,346 s (lines 50–62).
  - **M s2:** its timeout wrapper was killed and the runner finished detached (`vcv_finish-2026-10-21.sh`). Its log
    ends "1/1 scenarios passed", with no exit line and no peak RSS.
  - **Wall time.** The same M spec took 17,226, 25,280 and 39,142 s. This does not affect validity:
    - the cache counters are identical across the three cells (hits ≈ 148.65 M, misses 20,659, evictions 0);
    - the outputs are deterministic where they should be. M's three `macro_trend.sexp` files are identical, and the
      salts' trade lists agree up to MBI 2013-05-06 (pack, "Trade overlap").
- **Metric-glob tripwire** on `chain.log`: clean. Every `RESULT` line matches its `actual.sexp` to the last digit.
- **Do not quote the `cash_rejections=` field of the `GUARDS` lines** (4/3/4 for M, 1/3/2 for M+3138). It undercounts
  (defect D2). The pre-registered source, `<tag>-cash_rejections.txt`, reads 41/39/41 and 22/23/22, and the packs
  agree with it.

**V6 gate** (`validator_diff -check V6`, `results/*.v6diff-*.log`):

| pair | exit | specimen |
|---|---|---|
| M s0 / s1 / s2 vs N s0 / s1 / s2 | 1 / 1 / 1 | `V6 CMD 2009-11-09 (twin positions: CMD/CMN) -- only in: arm` |
| M-pre3339 s0 vs N s0 | 1 | same |
| M-pre3339 s0 vs M s0 | 0 | (1 = 1) |
| M+3138 sK vs M sK | 0 / 0 / 0 | |
| M+3174 s0 vs M s0 | 0 | |

N reads `V6 INVARIANT PASS` (`N/N-rb1-26-s0-v12-validator.sexp.md` line 13). Every chain cell reads `V6 INVARIANT 1
violations`.

### Review-pack look (RV1)

Pack links: [M](https://claude.ai/artifact/GQy89riMsmCKLY4Nce1Bu9), [M+3138](https://claude.ai/artifact/EgAQaEu3cYwCLs3FgvdxtS), [M+3174](https://claude.ai/artifact/YHZPHRTJsa9CQB5X6Rmayt), [M-pre3339](https://claude.ai/artifact/7qQwz2VLHWq3N51BNutNFv).

I read `top.png` and `part-1` to `part-12` of all four packs: 52 images in `.sweep-output/review-vcv-{M,M3138,M3174,Mpre3339}/render/`.

**Clean:**
- **Window.** All four packs show 2000-01-03 → 2026-06-25, with charts spanning the whole window.
- **KPI strips match `actual.sexp` s0:**

  | arm | total return | trades | max DD | Sharpe |
  |---|---:|---:|---:|---:|
  | M | 1,223 % | 575 | 27.7 % | 0.59 |
  | M3138 | 1,137 % | 579 | 24.9 % | 0.59 |
  | M3174 | 1,161 % | 576 | 27.9 % | 0.58 |
  | Mpre3339 | 1,222 % | 574 | 27.7 % | 0.59 |

  The salt-spread bullets match `actual.sexp` for M (1,223 / 1,166 / 1,216 %) and M3138 (1,137 / 1,133 / 1,157 %).
- **Text.** No mojibake, `NaN`, `undefined` or empty panels.

**Config-implied zeros:**
- Zero in all four packs:
  - 4 % fallback stops;
  - fills dated on a non-trading day;
  - "stop breached before the exit day";
  - Saturday fills.
- "When do stop exits fill": next open, 2–5 and 6+ days are all 0. Same day is 187 / 198 / 186 / 186.
- **"Bought in a Bearish week" is not literally zero.**
  - The "Filled against the macro (screen before the fill)" card reads 18 / 17 / 18 / 15. These are V23's counts;
    N s0's V23 is 16.
  - I checked placements: 0 of the 575 / 579 / 576 / 574 s0 entries was *placed* on a Bearish reading. This joins the
    `*-audit_entries.csv` placement date to `macro_trend.sexp`.
  - These are resting tickets that filled after the screen turned, which the default `entry_ticket_macro_suspend` Off
    allows. The card's own text says so, yet its label reads "watch: the config implies about none" (D6). This is not
    a gate breach.
- **Cash-rejection card (#3195).** M s0 reads 41 (5 at least 90 % funded) and M3138 s0 reads 22 (0 at least 90 %
  funded), so M3138 is lower, as required. Mpre3339 reads 42 and M3174 reads 41.

**Odd rows, traced:**
1. **"Biggest losers ($)" and the worst trade by entry year rank on price-only P&L in a total-return run (D4).**

   | trade | price-only P&L | dividend | total return |
   |---|---:|---:|---:|
   | AD 2025-08-04 (run's #1 loser) | −$584k | $630.9k | **+$46.6k** |
   | BKE 2021 (#3) | −$193k | | −$82.5k |
   | CHH (2012's worst) | −$59k | | +$25.0k |
   | TDG (2013's worst) | −$53k | | +$9.6k |

   All four are stop-outs at the open on a special-dividend ex-date (§1.5).
2. **"Fill outside the day's high–low: 1" (net $107k) is OKE 2013-09-18**, in every pack.
   - The entry price of 46.15 sits on the basis after 2014-02-03: `data/O/E/OKE/splits.csv` carries factor 1.1422 there,
     which is the ONE Gas spin-off encoded as a split.
   - 46.15 × 1.1422 = 52.71, which is inside the 2013-09-18 bar [51.89, 54.53].
   - This is a split-basis display issue, not a fill defect (D9; #3215 class).
3. **TNXP 2025-06-10 → 06-12, −25.1 % in 2 days** is a real gap through the stop. The 2025-06-12 open was 29.05 against
   a stop of 35.88, and the fill is at the open.
4. **M's V6 = 1 (CMD/CMN)** appears only in the validator section, not in "What stands out" (D5).

**What-stands-out bullets:** each one is confirmed, refined or rejected in the RV3 appendix at the end.

### 1. The pre-registered reads, as written

#### 1.1 #3266: rerun the record on N's spec and report the delta

**The rule.** "**Satisfied:** M-pre3339 s0 completes, passes V6 against N s0, and the delta is reported with items 1–4 …
**Fallback**, if … V6 excludes it: the delta is read from M sK − N sK and is joint … satisfied on that basis only if at
least one M salt passes V6 against N. **Not satisfied:** no pair with N passes V6. #3266 stays `verify/pending`, with the
specimen."

The gate: "**Exit 1:** that pair yields no delta and is reported as excluded, naming the specimen."

**The gate result.**
- M-pre3339 s0 vs N s0 exits 1; M s0, s1 and s2 vs N each exit 1.
- The fallback needs at least one M salt to pass, and none does.

**→ Not satisfied. #3266 stays `verify/pending`.**

**The specimen** (CMD/CMN twin, 2009-11-09):
- In every chain cell, the strategy bought both CMN and CMD on 2009-11-09 at 17.42 and sold both on 2010-03-22 at 19.66,
  as two positions of equal size. In M s0 that is 12,552 shares each, ids `CMN-wein-365` and `CMD-wein-364`
  (`results/vcv-M-s0-trades.csv`).
- They are one instrument. Cantel Medical's old and new tickers have identical raw OHLC on 2009-11-05 to 09
  (`data/C/D/CMD/data.csv`, `data/C/N/CMN/data.csv`).
- Both sit in `pit-v12/composition/top-3000-2009.sexp` (lines 4524 and 5934) and in the warehouse manifest.
- N holds neither in any salt. This is luck of the path, not a twin-free universe: N used the same lists.

**Items 1 and 3 (delta; entries gained and lost):** not read, because the pair is excluded.

**Item 2 (where the fix acts)** reads market inputs only, not the book. The #3266 rule does not say whether item 2 stands
without V6. I applied the logic the #3263 rule states ("the macro diff … stands either way, since the macro trace depends
on market inputs only"). It is reported as the fix's footprint, not as a delta, and it does not satisfy the item.
- Between M-pre3339 s0 and N s0, **11 weekly readings** differ in `trend` or `breadth_state`
  (`results/vcv-Mpre3339-s0-macro_trend.sexp` vs `N/N-rb1-26-s0-v12-macro_trend.sexp`):

  | year | changed readings |
  |---|---|
  | 2002 | 03-01, 05-03 |
  | 2003 | 03-21 |
  | 2008 | 02-08, 05-02, 05-30 |
  | 2009 | 01-02, 02-13 |
  | 2019 | 02-01 |
  | 2025 | 04-25, 05-23 |

- **Split by distance from 1 January:** 1 reading is within ±2 weeks of 1 January (2009-01-02) and 10 are not. All 11
  fall within 21 weeks after a year-crossing week that the old bucketing split: the ends of 2001, 2002, 2007, 2008, 2018
  and 2024.
- **How they arise.** I rebuilt the A-D (26-bar), NH-NL (13-bar) and Momentum (200-bar) inputs under the old and the
  new bucketing.
  - The inputs are the A-D fixture (Unicorn to 2020-02-14, then the synthetic tail) and
    `data/G/X/GSPC.INDX/data.csv`.
  - 9 of the 11 changes come from one of two lookbacks landing **one week later** under the old bucketing, because of
    the extra bar:
    - the A-D Line lookback: 2008-02-08, 2008-05-30, 2025-04-25 and 2025-05-23;
    - the NH-NL lookback: 2002-03-01, 2003-03-21, 2009-01-02, 2009-02-13 and 2019-02-01.
  - Momentum flips in none of them.
  - The other 2 (2002-05-03, 2008-05-02) must come through the index-stage or global votes, the 30-week windows. Those
    are not traced.
- **Traced, 2009-02-13** (6 weeks after the split week of 2008-12-29). The NH-NL proxy compares the S&P close with the
  close 13 bars back:
  - old bucketing: 13 bars back lands on 2008-11-21 (800.03), so the ratio is 826.84 / 800.03 = 1.034 (> 1.02, Bullish);
  - new bucketing: it lands on 2008-11-14 (873.29), so the ratio is 0.947 (< 0.98, Bearish);
  - so the reading moves from Neutral (N) to Bearish (M-pre3339).

**Item 4 (data drift):** both drift lists are empty, so no traded symbol is affected.

**Record:** "Otherwise N stays the record and the delta is reported only." **N stays the record.**

The per-arm totals are N 849 / 836 / 878 % and M 1,223 / 1,166 / 1,216 %, each from its own `actual.sexp`. The gate
forbids reading their difference as #3283's effect. §3.1 describes what differs, as a diagnostic, not a read.

The pre-registration has a tension here. The record clause says the delta "is reported only", while the gate says an
excluded pair "yields no delta". I resolved it conservatively: the totals are shown side by side and the difference is
not read.

#### 1.2 #3263: the record's macro trace before and after the A-D fixture fix

**The rule.** "**Satisfied:** both cells write `macro_trend.sexp` and the list from item 1 (possibly empty) is posted on
#3263 with items 2–3. #3263 then closes."

**Item 1.** 11 readings differ between `results/vcv-Mpre3339-s0-macro_trend.sexp` (before) and
`results/vcv-M-s0-macro_trend.sexp` (after).
- None falls in a week that contains one of the 39 removed rows, so all 11 are propagation.
- In each, the 26-bar A-D Line change flips sign. The Momentum vote stays positive in all 11.
- The last two columns are rebuilt from the two fixture files on the ISO-week bucketing, not read from an artifact:
  - before: `git show 1f2432fa2^:…/nyse_{advn,decln}.csv`;
  - after: the same files at `7e7c65628`.

| week (Fri) | before | after | removed row in week | 26-bar A-D change, before → after | removed rows inside the window (net A−D) |
|---|---|---|---|---|---|
| 2004-08-13 | Bearish / Bearish_breadth | Neutral / Deteriorating | no | −90 → +741 | 2004-04-09 (−831) |
| 2006-07-21 | Neutral / Deteriorating | Bearish / Bearish_breadth | no | +92 → −2,875 | 2006-02-20, 04-14, 05-29, 07-04 (+2,967) |
| 2006-08-11 | Bullish / Recovering | Neutral / Recovering | no | +2,911 → −56 | same four |
| 2007-08-17 | Neutral / Deteriorating | Bearish / Bearish_breadth | no | +494 → −2,258 | 2007-04-06, 05-28, 07-04 (+2,752) |
| 2007-09-14 | Bullish / Recovering | Neutral / Recovering | no | +1,826 → −926 | same three |
| 2007-09-28 | Bullish / Bullish_breadth | Neutral / Neutral_breadth | no | +1,179 → −861 | 2007-05-28, 07-04 (+2,040) |
| 2008-02-01 | Neutral / Neutral_breadth | Bearish / Bearish_breadth | no | +553 → −999 | 2007-12-25, 2008-01-01 (+1,552) |
| 2008-02-08 | Neutral / Deteriorating | Bearish / Bearish_breadth | no | +423 → −1,129 | same two |
| 2008-05-09 | Bullish / Bullish_breadth | Neutral / Neutral_breadth | no | +209 → −979 | 2007-12-25, 2008-01-01, 2008-02-18 (+1,188) |
| 2008-06-06 | Bullish / Bullish_breadth | Neutral / Neutral_breadth | no | +914 → −274 | same three |
| 2009-04-03 | Neutral / Recovering | Bearish / Bearish_breadth | no | +2,969 → −211 | 2008-11-27, 2008-12-25 (+3,180) |

**Traced, 2009-04-03.**
- Two removed holiday rows sat inside the 25 weekly bars from 2008-10-13 to 2009-04-03:
  - 2008-11-27: 3,100 advancing, 581 declining (net +2,519);
  - 2008-12-25: 2,150 advancing, 1,489 declining (net +661).
- With them, the cumulative A-D line rose +2,969 over the window. Without them, it fell −211.
- The S&P fell over the same bars (899.22 on 2008-10-10 → 842.50 on 2009-04-03). So the A-D Line vote (weight 2) changed
  from "diverging bullishly" to "confirming index decline".
- The Momentum vote stayed positive: the 200-bar mean went +161.8 → +108.5.
- The other votes read index data only, which is identical in both cells. The trend fell from Neutral to Bearish.

**Item 2 (salt independence).** M s0, s1 and s2 `macro_trend.sexp` share md5 `c78c8ae2…`, and so do all three M+3138
cells and M+3174 s0. The list holds for every salt.

**Item 3 (effect).** V6 agrees (`results/vcv-Mpre3339-s0.v6diff-M.log` exits 0).

| metric | M s0 − M-pre3339 s0 |
|---|---:|
| total return | 1,222.887 % vs 1,222.286 % = **+0.00045 log** |
| max DD | 27.6676 % vs 27.6672 % |
| trades | 575 vs 574 |

Entries changed, joined on `symbol|entry_date`, total return including dividends:

| entry year | gained (M only) | lost (M-pre3339 only) |
|---|---|---|
| 2007 | ITC 09-11 (+$35.1k), TYL 09-11 (−$27.5k), KOF 12-31 (+$23.2k) | ADVS 08-20 (+$15.7k) |
| 2008 | | AEM 04-28 (+$17.0k) |

**The trace.**
- **ADVS and AEM are direct gate effects.** ADVS's ticket (2007-08-17) and AEM's (2008-02-08) were placed in weeks
  that are Neutral before the fix and Bearish after it, so M never placed them.
- **ITC, TYL and KOF are cash re-routing.**
  - M, which did not hold ADVS, placed ITC on 2007-08-24. M-pre3339, which held ADVS, placed no ITC ticket.
  - M funded TYL. M-pre3339 had cash-rejected TYL at fill: $208.3k available of $229.0k required
    (`vcv-Mpre3339-s0-audit_entries.csv`).
- **One visible swing that reverses.** M-pre3339 ends 2007 +0.049 log ahead. This is ADVS's open gain marked at 27.05
  against an entry of 19.71, given back at the 2008-01-22 stop (20.57). By the end of 2008 the arms are within $1.1k.

**→ Satisfied. Post the list on #3263, then close.**

#### 1.3 #3173: TDG / WING / BCH credited once

**The rule.** "**Satisfied** if at least one specimen is held in an M cell and every held instance passes."

| specimen | M s0 / s1 / s2 | `dividends_received` | ÷ shares |
|---|---|---|---|
| TDG 2013-07-11 ($22.00) | held 3/3: 2013-07-08 → 07-11 (stopped on the ex-date), 2,858 / 2,745 / 2,839 sh | 62,876 / 60,390 / 62,458 | 22.00 exactly |
| WING 2018-02-08 ($3.17) | held 3/3: 2017-08-08 → 2018-07-30, 14,201 / 13,690 / 14,060 sh | 48,993.45 / 47,230.50 / 48,507.00 | 3.45 = 0.07 + 0.07 + 3.17 + 0.07 + 0.07, the vendor's unadjusted amounts over the hold (`data/W/G/WING/dividends.csv`) |
| BCH 2010-03-17 | not held in any cell | | not tested (as in N and rebaseline-v12) |

**The pass conditions, checked for each held instance:**
- **No split.** No TDG, WING or BCH row appears in any of the 8 cells' `splits.csv`.
- **No quantity jump.**
  - Each trade row's quantity is the filled one, and the entry price is the raw bar: TDG 158.28 is the 2013-07-08 open,
    and WING 33.91 is inside the 2017-08-08 bar.
  - No specimen is in `open_positions.csv`.
- **No second credit.** I reconciled the equity-curve move on the ex-date against the held positions' raw-close moves
  plus one dividend credit. The residuals are tiny next to a second credit:

  | specimen | residuals, s0 / s1 / s2 | a second credit would be |
  |---|---|---:|
  | TDG 2013-07-11 | −$90.74 / −$27.45 / −$90.19 | $62.9k |
  | WING 2018-02-08 | +$110.76 / +$106.49 / +$110.00 | $45k |

- **Guard counts.** Every cell's `GUARDS` line reads `split_dividend_guard rejected=4 no_files=0`. M+3138 s1's first,
  killed attempt printed `<none>`; its rerun reads `rejected=4`.

**Supporting arms.** M+3138 holds TDG and WING in 3 of 3 cells (22.00 and 3.45 per share). M+3174 holds TDG through the
ex-date to 07-22, still at 22.00 per share, and WING at 3.45.

**→ Satisfied.** It re-confirms on the post-#3283 tree and the rebuilt warehouse. #3173 was already closed on 10-19 on
rebaseline-v12 and N. It still carries `verify/pending`; that label should come off.

#### 1.4 #3138: `entry_fill_size_to_available`, paired 3-salt read

**Liveness.** `<tag>-cash_rejections.txt` reads M 41 / 39 / 41 vs M+3138 22 / 23 / 22, so M+3138 has fewer on every
salt: **live**.
- The trades differ too: 575 → 579, 576 → 582 and 575 → 580.
- Every remaining M+3138 cancellation is under the 0.5 minimum fraction; the largest is 0.491.

**The rule** (rows evaluated in order). Δk = ln(1+R[M+3138, sk]) − ln(1+R[M, sk]), from `*-actual.sexp`:

| salt | M | M+3138 | Δ | max DD, M → M+3138 | Calmar, M → M+3138 | Sharpe, M → M+3138 |
|---|---:|---:|---:|---|---|---|
| s0 | 2.58240 | 2.51552 | **−0.06688** | 27.67 → 24.92 | 0.370 → 0.400 | 0.588 → 0.587 |
| s1 | 2.53876 | 2.51212 | **−0.02664** | 27.61 → 24.72 | 0.364 → 0.402 | 0.577 → 0.585 |
| s2 | 2.57739 | 2.53093 | **−0.04646** | 27.51 → 24.49 | 0.371 → 0.409 | 0.586 → 0.590 |

- Mean Δ = **−0.0467**, and k = 0.
- Dispersion: M's range is 0.0436 and M+3138's is 0.0188, so D is true.
- **Row 1, "Refute: mean Δ ≤ 0", matches first. → Refute.**

**Paired per-event read.** I joined M's `cash_rejections.csv` to M+3138's `audit_entries.csv` on `symbol|placement
date`, then to M+3138's `trades.csv` by `position_id`.

| | s0 | s1 | s2 |
|---|---|---|---|
| M cash cancellations | 41 | 39 | 41 |
| … of which ≥ 0.5 funded on M's path (resize-eligible) | 24 | 23 | 23 |
| **booked by M+3138** (the recovered cohort) | **19** | **18** | **19** |
| still cancelled for cash in M+3138 | 12 | 11 | 12 |
| no ticket placed in M+3138 (path) | 10 | 10 | 10 |
| cohort fill fraction (M+3138 qty × price ÷ M's `required`): min / median / max | 0.47 / 0.92 / 1.14 | 0.48 / 0.92 / 1.19 | 0.47 / 0.93 / 1.17 |
| cohort realised P&L incl. dividends | **+$775k** | **+$752k** | **+$769k** |
| … median trade; winners | +$0.7k; 10 of 19 | +$1.0k; 9 of 18 | +$0.7k; 10 of 19 |
| … ADNT alone | +$628k (81 %) | +$629k (84 %) | +$637k (83 %) |
| resize-eligible and booked, **excluding ADNT** | 12 trades, **−$1.6k** | 12, **−$6.7k** | 11, **−$9.1k** |

**Cash rejections by entry year** (`cash_rejections_by_year.csv`, s0; s1 and s2 alike):
- M has them in every era, 2003–2026.
- M+3138 keeps them only in 2007, 2009, 2011, 2012, 2017, 2020, 2021, 2023 and 2024, and all of those are under half
  funded. It has none in 2003–06 and none in 2026.

The cohort by entry year, s0. s1 and s2 are alike except in 2013–14: s1 has 2013 at +$29k and no 2014 trade.

| entry year | trades | P&L |
|---|---:|---:|
| 2003 | 1 | +$28k |
| 2004 | 2 | +$29k |
| 2005 | 1 | −$18k |
| 2006 | 1 | −$17k |
| 2007 | 1 | −$21k |
| 2010 | 1 | −$5k |
| 2011 | 1 | +$37k |
| 2013 | 3 | +$17k |
| 2014 | 1 | +$28k |
| 2016 | 1 | −$19k |
| **2020** | **2** | **+$736k** (ADNT, LACO) |
| 2021 | 2 | −$132k (NVDA, CVM) |
| 2024 | 2 | +$112k (CAKE, MNKD) |

The three largest:
- **ADNT** (+$628k, s0).
  - Placed 2020-02-21. M cancelled it at fill after 37 weeks with $864.6k available of $993.3k.
  - M+3138 filled it on 2020-11-09 at full size: 42,010 × 27.06 = $1.137M. It exited 2021-06-21 at 42.02 (laggard
    rotation).
  - This was not a resize. M+3138 had the cash because it never bought APPS (§3.2).
- **CAKE** (+$108.7k incl. dividend, s0).
  - M was 5 % funded on 2024-09-06, so it was not resize-eligible.
  - M+3138 filled it on 2024-10-01 at 0.97 of M's size, on its own cash.
- **NVDA** (−$107.5k, s0). A genuine resize: M was 0.894 funded on 2021-04-23. M+3138 filled 2,135 sh at 618.03 on
  2021-04-26, and the stop hit on 05-04 at 567.68.

**Path divergence after the first resized fill.** The first resized fill is VYX 2003-09-25, the first divergent trade
in every salt. Realised P&L for M+3138 − M, in $k incl. dividends:

| salt | recovered | other entries gained (n) | entries lost (n) | shared entries (size only) | net realised | end NAV gap |
|---|---:|---:|---:|---:|---:|---:|
| s0 | +775 | −360 (35) | −1,821 (50) | +640 | −766 | −856 |
| s1 | +752 | −275 (37) | −1,654 (49) | +882 | −295 | −333 |
| s2 | +769 | −191 (37) | −1,875 (51) | +765 | −532 | −597 |

- **Lost:** APPS 2020-06-15 → 2021-05-17 (+$2.36M / $2.27M / $2.34M) is in "lost" in every salt.
- **Gained elsewhere:**
  - the largest are CHDN 2017-03-28 (+$328k) and BWA 2010-02-03 (+$168k);
  - 2024 losers MNSO, MBC, GOOGL and FIHL (−$144k to −$169k each).
- **By entry year** (gained − lost, all three salts): 2020 −$1.54M to −$1.63M, 2024 −$0.48M to −$0.51M, 2017 +$0.44M,
  2010 +$0.17M.

**Calibration.** This refutes the issue's expectation of +0.09 log with lower salt dispersion. It is not a ledger
REJECT; the flag stays default-off.

**→ Satisfied** (the rule was applied, outcome Refute). #3138 closes.

#### 1.5 #3174: ex-dividend stop adjustment, axis read at salt 0

**Liveness.** The cell logs `ex_dividend_stop_adjust reduced=306 skipped_no_amount=0 no_files=0` (`chain.log` line 38).
**Live.** V6 agrees (`results/vcv-M3174-s0.v6diff-M.log` exits 0).

**Delta** (M+3174 s0 − M s0):

| metric | M+3174 s0 | M s0 | Δ |
|---|---:|---:|---:|
| total return | 1,160.98 % | 1,222.89 % | **−0.04793 log** |
| max DD | 27.88 % | 27.67 % | +0.21 pt |
| Sharpe | 0.5765 | 0.5879 | |
| trades | 576 | 575 | |

**Stop exits on an ex-date in M that are not ex-date exits in M+3174** (`*-trades.csv`; P&L incl. dividends):

| trade | M | M+3174 | Δ |
|---|---|---|---:|
| AOS 2009-10-26 ($0.195) | 10-28 stop 39.81, −$14.8k | 10-29 stop 39.60, −$16.4k | −$1.7k |
| CHH 2012-07-27 ($10.41 special) | 08-24 open 32.93 vs stop 36.17, +$25.0k | held; 09-04 laggard 31.48, +$13.2k | −$11.8k |
| TDG 2013-07-08 ($22 special) | 07-11 open 139.64 vs stop 144.13, +$9.6k | held; 07-22 laggard 138.04, +$4.8k | −$4.8k |
| **BKE** 2021-12-08 ($6) | **12-17 open 40.58 vs stop 45.76**, −$82.5k | stop cut to 39.76; 12-20 at 39.74, −$93.4k | −$10.9k |
| **AD** 2025-08-04 ($23 special) | **08-20 open 51.26 vs stop 67.46**, +$46.6k | stop cut to 44.45; 09-02 laggard 53.40, +$100.0k | **+$53.4k** |

MEI 2014-10-15 ($0.09) is stopped on the same day in both arms. **The specimens behave as the README predicted:** AD and
BKE exit at the ex-date open in M and not in M+3174.

**Calibration.** "|Δ| below M's own salt range … reads as indistinguishable from path noise."
- M's range, measured here, is 0.0436. |Δ| is 0.0479, which is not below it. So that clause does not apply as written.
- This is one salt, an axis read and not a verdict. The flag stays default-off.
- The #3193 `BOOK-CHECK-NEEDED` (Ch. 6, never lower the stop) is not answered by this run.

**→ Satisfied** (the cell completed, V6 agrees, the flag is live). #3174 closes.

### 2. The verdict, calibrated

- **#3266: not satisfied by rule, and nothing about #3283's return effect can be claimed.**
  - The only #3266 pairs are cross-build pairs with N, and the gate excludes all of them on a data defect.
  - The macro footprint (§1.1) does stand: the fix changes 11 readings, all in the 21 weeks after a split year-end, and
    95.8 % of warehouse symbols.
- **#3263: an empty-effect data fix.** At +0.0005 log, it is about 1 % of M's salt range. Its whole trade-level effect
  is 5 entries in 2007–08.
- **#3173: re-confirmed.** It rests on two specimens held in every M cell; BCH remains untested.
- **#3138: Refute of the stated expectation, at three salts on one window.**
  - This design can say the +0.09 log does not reproduce. Every salt is negative, and the mean is roughly as large as
    M's whole salt range.
  - It cannot say the flag "loses money". §3.2 shows the sign is set by one 2020 swap.
  - The three salts are close to one draw, not three. M's salts share 562 of about 575 trades, and M+3138's share 572
    of about 580 (packs, "Trade overlap"). So the same swap recurs in each, and "0 of 3 positive" is weaker than it
    looks.
  - The "lower dispersion" (D) is a range over 3 near-replicate paths that differ only from 2013. It is not evidence
    either way.
- **#3174: one salt.**
  - The flag's direct effect on the trades it touches is −$14.5k over 26 years, about 0.001 log (§3.3).
  - The −0.048 log arm delta is mostly a re-draw of 2013 entries. That is the same mechanism that makes salts differ.
  - This design cannot distinguish the flag from path noise. The rule's literal noise test misses by 0.004 log.
- **Universe:** every cell is top-3000 PIT v12; no sp500 cell is involved.

### 3. Why

#### 3.1 What differs from N, and why it gates (diagnostic, not a read)

**What M runs that N did not:**
- #3283 code plus the rebuilt warehouse;
- for the M cells, also #3339.
- Detected drift: none.

**What changes:**
- 11 macro readings: 20 for M against N jointly; 2008-02-08 changes in both steps and cancels.
- The Stage and RS columns of 95.8 % of symbols.
- So the screen admits different names from the first year. The first divergent entry is 2000-03-29 (N only, s0).
- Per salt, of about 570 entries, 96–97 are gained and 89–96 lost.

**The gate.**
- The selection change happens to admit Cantel Medical under both tickers on the 2009-10-16 screen. Both tickets
  rest and fill on 2009-11-09 (`*-audit_entries.csv`, every chain cell).
  `max_one_share_class_per_issuer` does not catch it, because rename twins are not in `share_classes.sexp`.
- V6 then fails. The extra leg is $218.7k, 9.1 % of M s0's $2.39M NAV, and made +$28.7k: directly about +0.01 log.
- That is about 3 % of the per-arm gap between M and N, but its knock-on path cannot be bounded without a rerun. The gate
  is categorical, and that is why it exists.

**For whoever decides the next step** (diagnostic only). The single largest trade-level difference between M and N is
the same 2020 cash knife-edge that decides #3138 (§3.2):
- N filled LACO in full on 2020-05-27 and never held APPS.
- M cash-rejected LACO (66 % funded) and caught APPS: +$2.36M, 48,558 sh at 9.25 → 57.86.
- The year-end ln(M/N) runs +0.12 at end-2019, +0.38 at end-2020 and +0.30 at end-2021.
- The other large steps are also one or two trades each: 2004 (ADSK 2003-09, +$483k, M only) and 2010 (CRM +$360k and
  CMG +$307k, N only).

The level gap is a path lottery. That is the reason not to adopt M's level as the record until a V6-clean pair exists.

#### 3.2 #3138: a near-miss cohort worth about zero, and one monster re-drawn

1. **The mechanism does what it says.**
   - Cancellations fall 41 → 22. Every cancellation funded at least 50 % disappears.
   - M+3138 books 18–19 of M's cancelled tickets at a median 0.92 of M's size.
2. **The recovered cohort is ordinary.**
   - Median trade about $0, with 9–10 winners of 18–19.
   - Excluding one trade, the resize-eligible part sums to −$2k to −$9k per salt.
   - **Perturbation.** I moved the cohort boundary in two ways:
     - all booked trades vs only the resize-eligible ones;
     - with ADNT vs without.
     The total swings from +$775k to −$2k. The p90 is about +$108k (CAKE, LACO) and the maximum is ADNT.
   - At 19 trades and a tail rate of about 1 %, the cohort total is a coin flip on whether one monster lands in it
     (`feedback_perturb_before_believing_a_cohort_split`). There is no cohort effect to estimate.
3. **The sign is one 2020 swap.** It recurs in all three salts. M's salts share 562 of about 575 trades and M+3138's
   share 572 of about 580, so the cash state in May 2020 is nearly the same in each.

   **Traced, LACO → APPS → ADNT:**
   1. **2020-05-22.** LACO's ticket is placed in both arms.
   2. **2020-05-27.**
      - M is 66 % funded ($306.9k of $463.7k) and cancels.
      - M+3138 resizes and fills 12,934 sh at 27.15 ($351k, +$107k by 2020-10-09).
   3. **2020-06-12 screen.**
      - M holds 7 positions and places APPS and DECK.
      - M+3138 holds the same 7 plus LACO and places only DECK: no APPS row in `vcv-M3138-s0-audit_entries.csv`.
      - APPS fills in M on 06-15 at 9.25. It peaks at a 94.74 close on 2021-03-01 and exits on 2021-05-17 at 57.86, for
        +$2.36M.
   4. **November 2020.**
      - M, now large in APPS, cancels ADNT at 87 % funding.
      - M+3138 has the cash and fills ADNT at full size: +$628k.

   The swap nets about −$1.6M realised in 2020–21 against M+3138. It shows as the year-end ln(M+3138/M) going from
   +0.135 / +0.173 / +0.155 at end-2019 to −0.026 / +0.013 / −0.008 at end-2021. That −0.16 is about the whole
   difference.
4. **The rest of the path is reshuffling.**
   - M+3138 was ahead from 2003 to 2019, reaching +0.14 to +0.17 log by end-2019.
   - That lead was built mainly in three years: 2004 (+0.045), 2010 (+0.071, including BWA gained, +$168k) and 2017
     (+0.036, CHDN gained, +$328k).
   - Those are re-drawn entries, not the resized cohort, which sums to +$59k before 2020 (s0).
   - In 2024 it gave back −0.05 log.
5. **The max-DD "improvement" is the same artifact.**
   - M's 27.5–27.7 % drawdown runs from the 2021-04-12 NAV high, carried by open APPS, to 2023-10-27.
   - M+3138 never has that peak. Its worst episode is 2024-11-28 → 2026-06-10, at 24.5–24.9 %.
   - On that common 2024–26 episode, M's depth is 21.9–22.1 % (pack, "Flat stretches"). **The flag is deeper there, not
     shallower.**

**The why in one sentence.** Resizing recovers a median-sized, near-zero cohort, and spends the cash that the path would
otherwise have put into whatever comes next. So its 26y result is whichever monster that cash funds or misses: ADMA in
the issue's +0.09 specimen, APPS here.

#### 3.3 #3174: the target events are about neutral; the arm delta is a 2013 re-draw

**What the reduction does.**
- **On its five target events:** AD gains +$53.4k by riding the special dividend instead of being stopped by it. The
  other four, which were either stopped later anyway or rotated lower, lose −$29.1k between them.
- **On the stops held through ex-dates.** Each of the 306 reductions keeps the stop lower until the trail next raises
  it. Over the shared trades that means:
  - 14 stop exits fill on the same day at the lower level (−$28.0k);
  - 10 exits move (+$13.5k).
- **Total direct per-share effect over 26 years:** −$14.5k.
- **Size effect.** 562 shared trades sized off a smaller NAV account for −$425k of the −$440k shared-trade difference.

**Where the NAV gap comes from.** The ratio ln(M+3174/M) runs:

| date | ratio |
|---|---:|
| 2009-10 (AOS) | −0.002 |
| 2012-08-24 (CHH) | −0.007 |
| end-2012 | −0.013 |
| 2013-03 | −0.025 |
| 2013-06 | −0.051 |
| 2013-11 | −0.066 |
| after | flat at −0.05 |

**Most of it accrues in the first half of 2013, before TDG's July ex-date.** It comes from slightly different
entries, all in 2013–14:
- M+3174 only: MBI a week earlier (−$26.8k), MYGN (−$33.0k), KBR later (−$26.8k), SKYW, BLDR, SYY;
- M only: MDU (+$22.9k), TTC (+$93.2k), AZO (+$43.1k).
- Net realised: −$110k.

This is the cash-knife-edge mechanism that makes salts differ. Here it is triggered by cash differences of tens of $k:
the gap is −0.013 log by end-2012, from CHH's later exit and the lower stop fills.

### 4. How it fits what we know

- **#3138 re-derives the 08-22 funding grid on the record basis** (`project_funding_grid_monster_lottery`, PR #2473;
  `entry_fill_size_to_available` is G2b). The verdict there was "keep default-off as an axis: direct effect positive but
  monster-lottery variance dominates".
  - Confirmed: the lottery dominates.
  - Refined: on the total-return investor record, the direct effect is about zero once the one monster is removed, not
    "net-profitable".
  - It also refines `project_sim_price_only_accounting`. That memory reads the issue's ADMA (96 % funded) as a knife-edge
    the flag would fix. This run shows the flag moves the knife-edge rather than removing it (LACO/APPS). The +0.09 and
    this −0.047 are two single-monster draws of opposite sign.
- **Matches `project_edge_is_the_fat_tail`, `project_top_n_capacity_verdict`** ("level is a salt lottery") and
  `project_breadth_fix_ad_frozen` ("capital-bound tail swap"). This run has the same shape: the arm-level result is
  set by which arm's cash funds the monster.
  - The same 2020 knife-edge (LACO → APPS) also separates M from N (§3.1). So it is a property of the record's path,
    not of any one lever.
- **#3263 re-derives `project_breadth_fix_ad_frozen` at a smaller scale.**
  - A-D fixture corrections move the record by noise.
  - A-D Line flips propagate through the 26-bar window far from the corrected rows. The 2007–08 changes are of the same
    kind as the "diverged bullishly in 2001, 2007 and 2008" reading there.
- **#3174 fits `project_macro_suspend_investor_dilutes`.** A small realism lever whose direct effect is tiny shows an
  arm-level delta set by the cash re-draw.
  - It refines the 10-02 investor reading (`project_investor_preset_broad`): "AD −29 % gapped through a ~5 % stop" was
    the $23 ex-date drop.
  - On total-return accounting AD is +$46.6k in M, so a separate realism concern remains only for the *stop*, not for
    the P&L.
- **The record (`project_investor_preset_broad`, ledger `2026-10-12-breadth-fix-rb1-record-baseline`) stays N.**
  - M's packs agree with N's two standing diagnoses:
    - the 2009 sit-out: 0 entries in the 13 weeks after the 2009-05-01 reopen;
    - 2025–26 is picks: UP-regime days −21.8 % vs SPY +22.8 % at 65 % invested, 2025–26 era row.
  - M's max-DD episode moves to 2021–23 only because M holds APPS.
- **A contradiction to dig: the v12 set is not fully deduped.**
  - The README assumes it is ("No twin dedupe: the v12 set is already deduped"), but CMD/CMN survives in the 2009 list
    and the manifest.
  - `project_pit_chunked_twin_miss` warns that chunked builds miss cross-chunk twins and that V6 sees only twins that
    are *held*. Other latent twins may exist.

### 5. What it implies next (options; the choice is the user's)

1. **#3266 and the record basis are now one problem.** Every 26y arm built on current main carries the twin, so "pair
   against N" (the 10-12 ledger convention) is blocked for all of them. The options:
   - **(a) Fix the data.** Run a full-manifest twin scan of v12, drop CMN and alias it into the 2009 list, then rerun
     M-pre3339 s0 for #3266. If the record should move, also run M s0–s2 on the fixed set. Cost: one cell for #3266;
     three more for a new record basis at this chain's 11.7k–39k s per cell. This is the only path to a gated read.
   - **(b) Amend #3266's item.** Accept a twin-only V6 mismatch with its P&L bounded. That is a written amendment and a
     user decision; it is not available from this reading.
   - **(c) Pair future arms within one tree,** as this chain did, and leave the record level at N until (a) is done.
2. **#3138: nothing more. Stop here.**
   - Close it; keep the flag default-off as the G2b axis.
   - Two independent 26y reads now say funding levers re-draw monsters.
   - A funding lever worth testing would have to protect monster entries specifically (the funding-grid conclusion),
     and no such design is on the table.
3. **#3174: the default is a realism and faithfulness call, not a return call.**
   - Return evidence at this design cannot decide it (§3.3).
   - Resolve the `BOOK-CHECK-NEEDED` (Ch. 6, never lower the stop) in a local session; the book is available locally.
   - If the book reading supports adjusting a resting stop for the dividend, so the economic level is unchanged, the
     flip fits the realism and accounting precedent (#1926, a basis change and not alpha) with paired goldens per
     `config-default-blast-radius.md`. Otherwise keep it as an axis.
4. **#3263: close** after posting §1.2's list.
5. **Harness fixes** found here, none blocking: D2–D7 below. The highest value are:
   - D4: rank winners and losers on total-return P&L;
   - D5: surface V6 > 0 at the top of the pack;
   - D2: the chain's cash-rejection count.

### 6. Defects found

| # | kind | defect | specimen |
|---|---|---|---|
| D1 | data / universe | Rename twin survived the v12 dedupe, and V6 gates every M-vs-N read on it | CMD and CMN both in `trading/test_data/backtest_scenarios/pit-v12/composition/top-3000-2009.sexp` (lines 4524, 5934) and the 9,236-symbol manifest; identical raw OHLC 2009-11-05..09; held twice 2009-11-09 → 2010-03-22 in all 8 cells (`results/vcv-M-s0-trades.csv`, CMN-wein-365 / CMD-wein-364) |
| D2 | chain script | `GUARDS … cash_rejections=` greps `(cash_rejection ` line by line in a pretty-printed sexp and undercounts. Read from the log, #3138 s1 would look not live (3 = 3) | `chain.sh` line 197; `chain.log` lines 30–65 (4/3/4, 1/3/2) vs `results/*-cash_rejections.txt` (41/39/41, 22/23/22) and the packs (41, 22) |
| D3 | chain script | A guard-killed cell still runs the validator and `validator_diff`, printing V6 lines and `exit=0` for a cell with no result | `chain.log` line 51 (`GUARD-KILLED vcv-M3138-s1 … v6diff … exit=0`) |
| D4 | review pack | "Biggest losers / winners ($)", "Best and worst trade by entry year", "Ten trades made …" and "Stop filled ≥ 3 pts beyond the stop" use price-only P&L in a total-return run | M s0: AD −$584k (TR +$46.6k), BKE −$193k (−$82.5k), CHH 2012 worst −$59k (+$25.0k), TDG 2013 worst −$53k (+$9.6k) |
| D5 | review pack | V6 > 0 (an invariant that gates paired reads) is not lifted into "What stands out" | all four packs, validator section only |
| D6 | review pack | "Filled against the macro" is graded "config implies about none" while its own text says the default allows it | M pack 18, V23 18; 0 placements on a Bearish reading |
| D7 | artifact | With `ex_dividend_stop_adjust`, `trades.csv` overwrites `entry_stop` / `exit_stop` / `max_stop` with the reduced stop while `stop_initial_distance_pct` keeps the original, so the row loses the stop at entry | BKE 2021-12-08: `entry_stop` 39.76 in M3174 vs 45.76 in M, sid 0.1034 in both (`results/vcv-M3174-s0-trades.csv`) |
| D8 | data | NYSE A-D fixture has five 0/0 rows at the Unicorn tail (missing days as zero breadth); the #3339 calendar test does not catch them | `trading/test_data/breadth/nyse_{advn,decln}.csv`: 2019-08-20, 2020-02-11..14 |
| D9 | review pack | The split-basis exclusion knows only simple ratios, so a spin-off-as-split entry reads "fill outside the day's range" | OKE 2013-09-18, entry 46.15 on the post-2014-02-03 factor-1.1422 basis (all packs; #3215 class) |
| D10 | review pack (cosmetic) | A single-trade year shows the same trade as best and worst, red in the worst column | Mpre3339 pack, 2008: AEM +$17k |

No simulator fill defect was found. There were no late stops, no Saturday fills and no fallback stops, and the
ex-date NAV reconciles to the cent scale.

### Verifies lines (PR body)

- `Verifies #3263: the record's macro trace (macro_trend.sexp) diffed before and after; 11 changed readings listed —
  dev/experiments/verify-chain-v-2026-10-19/results/vcv-M-s0-macro_trend.sexp vs vcv-Mpre3339-s0-macro_trend.sexp
  (README §1.2)`
- `Verifies #3173: re-run of the 26y TR pair shows the three events credited once (TDG, WING 3/3 M cells; BCH not held) —
  dev/experiments/verify-chain-v-2026-10-19/results/vcv-M-s{0,1,2}-trades.csv, -splits.csv, -equity_curve.csv`
- `Verifies #3138: paired 3-salt 26y run with entry_fill_size_to_available, pre-registered; outcome Refute (mean Δ −0.047
  log) — dev/experiments/verify-chain-v-2026-10-19/results/vcv-M3138-s{0,1,2}-actual.sexp vs vcv-M-s{0,1,2}-actual.sexp,
  *.v6diff-M.log exit 0`
- `Verifies #3174: axis read on the 26y TR pair (reduced=306, V6 agree, Δ −0.048 log) —
  dev/experiments/verify-chain-v-2026-10-19/results/vcv-M3174-s0-actual.sexp vs vcv-M-s0-actual.sexp, chain.log line 38`
- #3266 is not satisfied, so there is no Verifies line. Suggested comment on #3266:

  > Chain V (#PR): not satisfied. V6 fails on every pair with N, exit 1 on M-pre3339 s0 and on M s0, s1 and s2.
  > Specimen: CMD/CMN twin, both bought 2009-11-09 and sold 2010-03-22 in every chain cell. Both tickers are in
  > `pit-v12/composition/top-3000-2009.sexp`. N stays the record. The fix's macro footprint is 11 readings (README §1.1).
  > Next: dedupe CMD/CMN (full v12 twin scan), then rerun M-pre3339 s0.

### Appendix: What-stands-out bullets (RV3)

**M pack:**

| # | bullet | read |
|---|---|---|
| 1 | Eras vs SPY: built 2000–08, eroded 2009–12, built 2013–15, eroded 2016–19, built 2020, eroded 2021, built 2022, eroded 2023, built 2024, eroded 2025–26; ends 1.64× | **Confirm; refine 2020–21.** "Built 2020" is one trade (APPS, +$2.36M). "Eroded 2021" is largely its round trip: peak close 94.74 on 2021-03-01, exit 57.86 (`data/A/S/APPS/data.csv`). The M3138 pack, without APPS, has one 2016–21 eroded era instead |
| 2 | Eroded 2009–12: cash through rebounds (DOWN +1.6 % vs SPY +27.4 % at 37 %) | **Confirm.** This is the known 2009 sit-out (reopen 2009-05-01: 0 entries in 13 weeks). It is identical in all four arms, so no lever here touches it |
| 3 | Eroded 2016–19: cash through rebounds (DOWN −0.9 % vs +11.9 % at 16 %), and UP lag (+23.5 % vs +37.1 % at 66 %) | **Confirm.** Same in M-pre3339; this is the record's shape |
| 4 | Eroded 2021: holdings lagged in UP (+2.5 % vs +28.7 % at 57 %) | **Refine.** It is mostly the APPS round trip; M3138 returned +9.5 % in 2021 |
| 5 | Eroded 2023: transition weeks (MIXED +4.5 % vs +11.3 % at 37 %), UP +5.1 % vs +10.1 % at 49 % | **Confirm** |
| 6 | Eroded 2025–26: holdings lagged in UP (−21.8 % vs +22.8 % at 65 %), not exposure | **Confirm.** This is the record's 2025–26 "picks" diagnosis (rebaseline-v12: −19.8 % vs +22.8 % at 62 %) |
| 7 | Gate reopens: 14; sat out 2009-05; invested and lagged 2010-08, 2025-05 | **Confirm.** M-pre3339 shows 13 reopens: the #3263 readings of 2006-07-21 and 08-11 create M's 2006-08-18 reopen, and 2008-05-09 moves the 2008 reopen by a week |
| 8 | 41 entries cancelled at the fill for cash; 5 at least 90 % funded | **Confirm.** `vcv-M-s0-cash_rejections.txt` reads 41; the five are INGM, MECA, BLMN, GRMN and DWSN1. The chain log's "4" is D2 |
| 9 | Worst three-year stretch 2009–11, +6.8 % vs SPY +48.1 % | **Confirm.** Same cause as #2 |
| 10 | Ten trades made $12.30M of the $8.92M realised; 151 A-grade trades $23.38M; plus $1.82M dividends and $1.09M interest | **Refine.** The figures are price-only. AD's −$584k is +$46.6k on total return (D4) |
| 11 | 0 of 575 trades on the 4 % fallback stop | **Confirm.** Config-implied (`require_structural_stop`) |
| 12 | 67 of 285 stop exits more than 0.5 % beyond the stop; 0 sold at an open after the stop day; 141 D/F losers −$7.35M | **Confirm the 0.** The 67 include the special-dividend ex-date opens (AD, BKE, CHH, TDG) that #3174 removes; in M3174, "≥ 3 pts beyond" falls from 23 to 20 |
| 13 | Average invested 58 % of NAV, 5.5 positions | **Descriptive only.** No conclusion here rests on it; the regime split by era is bullets 2–6 |
| 14 | 0 Saturday fills; V13 20 violations (9 skipped) | **Confirm.** V13 holds delisting exits with no exit bar (PPDI, PLMD, NLC, MRUS), split-basis rows (NEOG, MMSI) and OKE (D9), the same classes as N |
| 15 | Salt spread 1,223 / 1,166 / 1,216 % | **Confirm.** That is 0.044 log, all from 2013–14: trade lists are identical until MBI 2013-05-06, and yearly spread is ≤ 1 pt except 2013 (3.7) and 2014 (2.1) |
| 16 | "Years that rest on one trade or on the salt" (collapsed) | **Refine (read from the criteria; the list is filled client-side and the render keeps it collapsed).** Salt clause: no year has salts ≥ 15 pp apart (largest spread 3.7 pp, 2013, Salts tab). One-trade clause: the years whose excess is carried by one realised trade are the ones bullets 1 and 4 already name (2020 rests on APPS, open at year end and realised in 2021 for +$2.36M, the largest of 2020-entry net $4.48M; 2024 rests on ADMA, +$3.08M of $3.62M realised in 2024, yearly table). Nothing new beyond those |

**The other packs, where they differ from M:**
- **M3138.**
  - Eras end at 1.53×.
  - "Eroded 2016–2021: cash through rebounds (DOWN +10.2 % vs +48.8 % at 37 %)": **refine.** The arm's difference
    from M inside this era is APPS, a holding in an UP regime, not cash.
  - "Worst three-year stretch 2019–21, +39.0 % vs SPY +99.9 %": **refine.** This is the missing APPS.
  - "22 cancelled for cash, 0 at least 90 % funded": **confirm.** Every cancellation funded at least 50 % is gone.
  - Salt spread 1,137 / 1,133 / 1,157 %: **confirm.**
  - Everything else is **confirmed**, within a few counts of M.
- **M3174.**
  - "Eroded 2009–2014 (3.30 → 2.49×); held 2015–18": **refine.** M's 2013–15 "built" leg disappears because M3174's
    2013 entries diverge (−0.05 log by end-2013, §3.3).
  - "64 of 283 stop exits more than 0.5 % beyond the stop": **confirm.** The ex-date opens are gone.
  - "41 cancelled, 6 at least 90 % funded": **confirm.**
  - The rest: **confirm.**
- **Mpre3339.**
  - It is identical to M except for 13 reopens, 42 cancellations (6 at least 90 % funded), 150 A-grade trades, 66 of
    285, and 140 losers. Each difference traces to the five 2007–08 entries of §1.2: **confirm.**

**Patterns found by eye that the pack does not flag:**
- **D4.** A special-dividend ex-date stop-out reads as a top loser. Proposed detector: a "stop exits on a
  special-dividend ex-date" signal listing price-only vs total-return P&L. That is exactly #3174's class.
- **D5.** V6 > 0 is invisible at the top. Proposed detector: a signal bullet whenever V6 is not PASS, naming the twin.
