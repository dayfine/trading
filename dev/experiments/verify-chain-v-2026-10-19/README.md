# verify-chain-v-2026-10-19: the 26y verification chain for #3266, #3173, #3138 and #3174

**Pre-registration.** Nothing has run. Every read below is fixed before the first cell launches. Plan:
`dev/plans/issue-burndown-2026-10-19.md` §Chain V (PR #3340).

This chain closes, or fails to close, the `[after-merge]` items of four `verify/pending` issues with one set of 26y
cells on the record spec.

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
    - #3195 (#3138's audit record).
  - Since N's tree (524bc2df0), main changed strategy or simulator code only behind default-off flags or in reporting:
    - #3254 holiday-Friday screening;
    - #3280 symbol-class filter;
    - #3282 stop-vs-margin cover;
    - #3297 `raw_confirm_min_share` (no caller sets it);
    - #3301 true-dollar liquidity gates;
    - #3256 and #3296 (trades.csv and audit columns only).

    #3283 is the one default-on change.
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
    - at least one `.snap` payload or `.weekly` file must differ from v12, or the chain aborts ("the fix did not
      reach the stored columns");
    - the symbols whose CSV `mtime` changed since the v12 build are written to `wh/csv-mtime-changed.txt`.
  - **Every arm runs on the rebuilt warehouse**, so all within-chain pairs share one warehouse.
- **Inputs are staged outside any VCS tree** (`/tmp/vcv-run`):
  - specs and `chain.sh` come from the pre-registration commit;
  - the v12 lists must be a subset of the manifest (MEL excepted);
  - EODHD `dividends.csv` and `splits.csv` are rsynced into the run tree's `test_data`.

### Arms (spec files in `specs/`)

| arm | spec | differs from M by | salts |
|---|---|---|---|
| **M** | `vcv-M.sexp` | (the record N spec, on current main) | 0, 1, 2 |
| **M+3138** | `vcv-M3138.sexp` | `((entry_fill_size_to_available true))`; `entry_fill_min_size_fraction` stays at its default 0.5 | 0, 1, 2 |
| **M+3174** | `vcv-M3174.sexp` | `((ex_dividend_stop_adjust true))` | 0 |

The flag names are the config fields in `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli`. Both
default to `false`.

### Cells, one at a time (`container-capacity-scheduling.md`: no agents beside the chain)

Order: M s0, M+3174 s0, M+3138 s0, M s1, M+3138 s1, M s2, M+3138 s2.

- Salt 0 of every arm runs first, so a mid-chain death still leaves one salt of each read.
- **Cost:**
  - warehouse rebuild about 1.5 h (v12 chunks took about 20 min each per 2,300 names);
  - three 3-month preflights;
  - 7 cells at about 2.3–3.3 h each (this spec measured 8,207–11,881 s);
  - **about 22–24 h in total**. Plan §Chain V said about 17 h; the difference is the rebuild plus the preflights.
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
  - its validator V6/V16/V17 lines;
  - `RESULT … (wall Ns)` for `perf_long_cells.sh`.

## Validity gate (every pair)

Each pair is gated with `validator_diff -check V6`; the chain runs it per cell:

- M sN against the committed N sN report, `../breadth-fix-rb1-2026-10-11/results/N-rb1-26-sN-v12-validator.sexp.sexp`;
- M+3138 sN against M sN;
- M+3174 s0 against M s0.

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

**Read:** arm M against the committed N (`../breadth-fix-rb1-2026-10-11/results/N-rb1-26-sK-v12-*`), per salt that
passes V6.

1. **Delta.** M − N on:
   - total return, in log `ln(1+R)` and in %;
   - CAGR, max DD, Sharpe, Calmar, trades.

   N reads 849.28 / 835.99 / 878.27 %, i.e. 2.2505 / 2.2364 / 2.2806 log; its own salt range is 0.044 log.
2. **Where the fix acts.** From `macro_trend.sexp`, count the weekly readings whose `trend` or `breadth_state`
   differs between M and N, by year, split into weeks within ±2 weeks of 1 January and all other weeks.
   - The fix changes bucketing only at year-crossing weeks. A difference far from a year-end comes through the
     30-week and A-D windows those weeks feed, and is traced on one example.
3. **Entries gained and lost**, joined on `symbol|entry_date` (`position_id` is not a cross-arm key), with each set's
   P&L and the three largest contributors traced.
4. **Data drift.** Any symbol in `wh/csv-mtime-changed.txt` that M or N traded is listed with its P&L. It is a
   confound of the delta, not part of the fix.

**Verdict rule.** This is a correctness fix, not a mechanism, so there is no accept or reject.

- **Satisfied:** at least one M salt passes the gate (V6 agrees with N) and the delta is reported with items 1–4,
  whatever its sign or size. #3266 then closes, quoting the delta.
- **Not satisfied:** no salt passes V6. #3266 stays `verify/pending`, with the specimen.
- **Record:** M replaces N as the record basis for later 26y comparisons, as breadth-fix did for N. That needs at
  least two salts gated. Otherwise N stays the record and the delta is reported only.

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

### #3138: `entry_fill_size_to_available`, paired 3-salt read

**[after-merge] item:** "Paired 3-salt 26y run with `entry_fill_size_to_available` on the investor preset (expected
~+0.09 log, lower salt dispersion), pre-registered."

**Read:** M+3138 against M, per salt that passes V6.

`Δk = ln(1+R[M+3138, sk]) − ln(1+R[M, sk])`. Salt dispersion is the range (max − min) of `ln(1+R)` over salts
within an arm.

1. **Liveness.** The mechanism is *live* if M+3138 records fewer `cash_rejection` cancellations
   (`<tag>-cash_rejections.txt`, from `trade_audit.sexp`) than M on at least one salt. If the counts are equal on
   every salt, the flag did not fire: **not tested**. Trace why before reading Δ.
2. **Rule, fixed now.** The issue's expectation is +0.09 log; half of it, 0.045, is the bar.

   | outcome | condition |
   |---|---|
   | **Confirm** | mean Δ ≥ +0.045 **and** Δ > 0 on at least 2 of 3 salts **and** M+3138's dispersion < M's |
   | **Confirm return, not dispersion** | the first two conditions hold, but dispersion is not lower |
   | **Inconclusive** | 0 < mean Δ < +0.045, or the first two conditions are split |
   | **Refute** | mean Δ ≤ 0, **or** Δ > 0 on at most 1 of 3 salts |

   With fewer than 3 salts gated, the read is reported per salt and is **inconclusive** by rule.
3. **Paired per-event read** (`mechanism-validation-rigor.md` check 6).
   - Find the entries that M cancelled at fill for cash and that M+3138 booked resized, joined on
     `symbol|entry_date`.
   - Report their count, fill fraction (filled ÷ designed) and realised P&L, and the three largest, traced. The
     issue's +0.09 came from one specimen: s1 ADMA, about $1.6M.
   - Also report the path divergence after the first resized fill: trades gained and lost elsewhere.
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
- the output is copied to `.sweep-output/review-vcv-{M,M3138,M3174}/` (`site/`, `render/top.png`, `part-N.png`).

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
   `params.sexp`, `force_liquidations.sexp`, `validator.sexp.{sexp,md}`, `.log`, `.rss` and `.v6diff.log`.
   - `trade_audit.sexp` is reduced to `<tag>-cash_rejections.txt`.
   - Also copied: the chain log, and the warehouse chunk build logs plus `csv-mtime-changed.txt`.
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
`origin/main`.

To validate the specs without a 26y cell, from a built tree:

```sh
WTREL=<built tree> sh chain.sh validate [vcv-M vcv-M3138 vcv-M3174 control]
```

This is a parse and override check only. `scenario_runner` applies `config_overrides` (`Overlay_validator`) before
it prints `Running backtest`.

- Each spec is VALID iff its log reaches that line within `timeout 300`.
- `control` (vcv-M plus a nonexistent override) must fail before that line.

Run on 2026-10-19 at bf264f258 against `_v12pit`: vcv-M, vcv-M3138 and vcv-M3174 were VALID, and the control was
rejected ("Scenario control crashed: (Failure … unknown keys …)").

## Files

- `specs/vcv-M.sexp`, `specs/vcv-M3138.sexp`, `specs/vcv-M3174.sexp`
- `chain.sh`: `launch` / `run` / `validate` / `collect`
- `results/`: per-arm artifacts, after the run

## Log

- 2026-10-19: pre-registered; `validate` passed (see Launch).
