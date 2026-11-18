# Price-bearing trade files live in dayfine/trading-results

Per-trade CSVs that carry entry and exit prices (`entry_price`/`exit_price` or `entry_px`/`exit_px` columns) are bar-derived data under the EODHD terms, so they are kept only in the private `dayfine/trading-results` repo, at the same path they had here. Moves so far:

- 2026-11-16, #3665 (trading-results 477a85e): the 18 `rt-freshness-*-2026-08-20` arm files.
- 2026-11-17 (trading-results e0252b2): the 709 files listed below by directory, copied from main at 777f09ed4 and checked byte-identical before the delete.
- 2026-11-17 (trading-results 3ccfce9, 0d2eec7): 515 position and mark files (open positions, forced liquidations, trade audits, final marks), listed under §Position files below.
- 2026-11-17 (trading-results a5753f7, dca23d2, 96f047f): 493 run tables that carry a price or close in every row (equity curves, bar and close dumps, per-event tables, trade-row dumps, order tickets and follow logs), listed under §Run tables below.

Trade files with returns only (`ret`, `spy_ret`, `excess`; no price column) stay public. New experiment and lane output follows the same split: price-bearing files to trading-results, mark-free files here (`dev/experiments/observatory/README.md` §Lane).

| directory | files moved |
|---|---:|
| `arc-rerun-2026-09-01` | 19 |
| `breadth-fix-rb1-2026-10-11` | 6 |
| `cadence-12w-v10-2026-09-13` | 13 |
| `capital-recycling-combined-2026-05-07` | 5 |
| `cash-reserve-2026-07-06` | 3 |
| `cell-e-15y-2026-05-07` | 1 |
| `chain-w-2026-11-10` | 2 |
| `clock-default-fixed-basis-2026-09-04` | 8 |
| `clock-surface-2026-08-27` | 48 |
| `concentration-deploy-2026-09-13` | 4 |
| `contention-null-mechanism-2026-08-20` | 3 |
| `deep-1998-2026-2026-06-14` | 1 |
| `delisting-guards-rerun-2026-09-06` | 5 |
| `deteriorating-gate-2026-09-13` | 3 |
| `diagnostics-fullsize-2026-05-28` | 2 |
| `entry-anchor-recovery-2026-10-02` | 24 |
| `exit-basis-flip-2026-09-03` | 43 |
| `exit-lever-surface-2026-09-04` | 18 |
| `floor-nearest-2026-10-25` | 12 |
| `fresh-eyes-2026-10-13` | 7 |
| `fresh-eyes-dated-2026-10-18` | 81 |
| `funding-grid-2026-08-22` | 5 |
| `index-stage-veto-2026-09-16` | 3 |
| `inspect-6mo-2026-08-21` | 9 |
| `instrumented-record-2026-08-23` | 4 |
| `investor-preset-2026-09-26` | 21 |
| `macro-suspend-investor-2026-10-04` | 12 |
| `mechanism-ablation-2026-05-29` | 9 |
| `obvious-fixes-2026-09-25` | 7 |
| `path-stability-2026-10-23` | 24 |
| `pit-universe-2026-09-14` | 3 |
| `price-band-binding-2026-11-13` | 1 |
| `price-band-confirm-2026-11-13` | 20 |
| `price-band-tiebreak-2026-11-13` | 10 |
| `rebaseline-v12-2026-10-08` | 6 |
| `record-baseline-2026-08-24` | 1 |
| `record-kseed-2026-10-27` | 5 |
| `record-rebase-2026-09-03` | 6 |
| `short-on-off` | 2 |
| `short-only-liveness-2026-10-04` | 2 |
| `shorts-liveness-2026-10-03` | 2 |
| `shorts-phase-b-2026-10-09` | 6 |
| `spy-benchmark-26y-2026-10-04` | 2 |
| `stop-anchor-rebase-2026-09-03` | 18 |
| `stop-width-by-state-2026-09-08` | 14 |
| `stop-width-cadence-surface-2026-09-05` | 37 |
| `stop-width-surface-2026-09-03` | 11 |
| `stoplimit-entry-wfcv-2026-08-04` | 10 |
| `tier4-seed-band-2026-10-29` | 16 |
| `tier4-seeded-repin-2026-10-29` | 30 |
| `top-n-grid-2026-09-22` | 18 |
| `top-of-funnel-2026-09-21` | 4 |
| `total-return-26y-2026-10-06` | 6 |
| `trader-presets-2026-09-29` | 30 |
| `trader-presets-rerun-2026-10-02` | 21 |
| `twin-dedupe-26y-2026-10-29` | 6 |
| `verify-3266-rerun-2026-10-22` | 1 |
| `verify-chain-v-2026-10-19` | 8 |
| `warehouse-rebuild-2026-09-06` | 11 |

## Position files (2026-11-17, trading-results 3ccfce9 and 0d2eec7)

The #3673 and #3675 reviews found the same prices in other per-run files. These moved too, copied from main at 2677801ec and checked byte-identical before the delete: `*open_positions.csv` with at least one row (`symbol,side,entry_date,entry_price,quantity`; the 6 header-only files stay), `*force_liquidations.sexp` with `entry_price`/`current_price` fields, `trade_audit.sexp`, `*final_prices.csv` (`symbol,price`, end-of-run marks), and the per-trade table `twin-dedupe-26y-2026-10-29/why/arm-only-trades.txt`.

| directory | open_positions | force_liquidations | trade_audit | final_prices | other | total |
|---|---:|---:|---:|---:|---:|---:|
| `arc-rerun-2026-09-01` | 19 | 0 | 0 | 0 | 0 | 19 |
| `breadth-fix-rb1-2026-10-11` | 6 | 6 | 0 | 0 | 0 | 12 |
| `cadence-12w-v10-2026-09-13` | 13 | 11 | 0 | 0 | 0 | 24 |
| `cell-e-15y-2026-05-07` | 1 | 1 | 0 | 1 | 0 | 3 |
| `chain-w-2026-11-10` | 2 | 0 | 0 | 0 | 0 | 2 |
| `clock-default-fixed-basis-2026-09-04` | 8 | 0 | 0 | 8 | 0 | 16 |
| `concentration-deploy-2026-09-13` | 4 | 4 | 0 | 0 | 0 | 8 |
| `delisting-guards-rerun-2026-09-06` | 5 | 0 | 0 | 0 | 0 | 5 |
| `deteriorating-gate-2026-09-13` | 3 | 3 | 0 | 0 | 0 | 6 |
| `entry-anchor-recovery-2026-10-02` | 24 | 0 | 0 | 0 | 0 | 24 |
| `exit-lever-surface-2026-09-04` | 18 | 0 | 0 | 18 | 0 | 36 |
| `floor-nearest-2026-10-25` | 12 | 12 | 0 | 0 | 0 | 24 |
| `index-stage-veto-2026-09-16` | 3 | 3 | 0 | 0 | 0 | 6 |
| `investor-preset-2026-09-26` | 20 | 0 | 0 | 0 | 0 | 20 |
| `macro-suspend-investor-2026-10-04` | 12 | 0 | 0 | 0 | 0 | 12 |
| `obvious-fixes-2026-09-25` | 7 | 0 | 0 | 0 | 0 | 7 |
| `path-stability-2026-10-23` | 24 | 24 | 0 | 0 | 0 | 48 |
| `pit-universe-2026-09-14` | 3 | 3 | 0 | 0 | 0 | 6 |
| `price-band-binding-2026-11-13` | 1 | 0 | 0 | 0 | 0 | 1 |
| `price-band-confirm-2026-11-13` | 20 | 0 | 0 | 0 | 0 | 20 |
| `price-band-tiebreak-2026-11-13` | 10 | 0 | 0 | 0 | 0 | 10 |
| `rebaseline-v12-2026-10-08` | 6 | 6 | 0 | 0 | 0 | 12 |
| `record-kseed-2026-10-27` | 5 | 5 | 0 | 0 | 0 | 10 |
| `short-on-off` | 2 | 1 | 0 | 0 | 0 | 3 |
| `short-only-liveness-2026-10-04` | 2 | 2 | 2 | 0 | 0 | 6 |
| `shorts-liveness-2026-10-03` | 2 | 2 | 1 | 0 | 0 | 5 |
| `shorts-phase-b-2026-10-09` | 0 | 6 | 0 | 0 | 0 | 6 |
| `spy-benchmark-26y-2026-10-04` | 2 | 0 | 0 | 0 | 0 | 2 |
| `stop-width-by-state-2026-09-08` | 14 | 14 | 0 | 0 | 0 | 28 |
| `stop-width-cadence-surface-2026-09-05` | 14 | 0 | 0 | 14 | 0 | 28 |
| `total-return-26y-2026-10-06` | 6 | 6 | 0 | 0 | 0 | 12 |
| `trader-presets-2026-09-29` | 30 | 0 | 0 | 0 | 0 | 30 |
| `trader-presets-rerun-2026-10-02` | 21 | 0 | 0 | 0 | 0 | 21 |
| `twin-dedupe-26y-2026-10-29` | 6 | 6 | 0 | 0 | 1 | 13 |
| `verify-3266-rerun-2026-10-22` | 1 | 1 | 0 | 0 | 0 | 2 |
| `verify-chain-v-2026-10-19` | 8 | 8 | 0 | 0 | 0 | 16 |
| `warehouse-rebuild-2026-09-06` | 11 | 1 | 0 | 0 | 0 | 12 |
| **total** | **345** | **125** | **3** | **41** | **1** | **515** |

## Run tables (2026-11-17, trading-results a5753f7, dca23d2 and 96f047f)

The user chose on 2026-11-17 to move every price-bearing file; these are the ones found so far. The first 458 match main at 958d301ca byte for byte in trading-results: 240 `equity_curve.csv` (a day with one open position gives back that day's close from the change in NAV), the bar and close dumps, the per-event tables (`raw_close`, `e1_px`, `stop`), the `audit_extract.csv` and `terminal_runs_*.csv` tables, the arc-rerun same-day-stop, fill-day-gap and Saturday-exit reprice tables, and the fresh-eyes order tickets (`trigger,limit,stop`), follow logs (`trigger,stop`), forward decisions and list scan (`close,anchor`). The 124 files in dca23d2 were found by the #3675 review (note N4). The second batch, 35 files in 96f047f, was found by the #3678 review's value scan; they match main at 10a5b1160 byte for byte. They are listed after the first table.

| directory | files | kinds | commit |
|---|---:|---|---|
| `arc-rerun-2026-09-01` | 25 | 19 audit extracts, 3 bar/close dumps and daily tables, 3 reprice tables | a5753f7, dca23d2 |
| `breadth-fix-rb1-2026-10-11` | 6 | 6 equity curves | a5753f7 |
| `cell-e-15y-2026-05-07` | 1 | 1 equity curve | a5753f7 |
| `chain-w-2026-11-10` | 2 | 2 equity curves | a5753f7 |
| `concentration-deploy-2026-09-13` | 4 | 4 equity curves | a5753f7 |
| `deep-1998-2026-2026-06-14` | 1 | 1 equity curve | a5753f7 |
| `delisting-guards-rerun-2026-09-06` | 1 | 1 terminal-run table | a5753f7 |
| `entry-anchor-recovery-2026-10-02` | 24 | 24 equity curves | a5753f7 |
| `floor-nearest-2026-10-25` | 12 | 12 equity curves | a5753f7 |
| `fresh-eyes-2026-10-13` | 10 | 6 follow logs, 4 bar/close dumps and daily tables | a5753f7, dca23d2 |
| `fresh-eyes-dated-2026-10-18` | 114 | 81 follow logs, 32 order tickets, 1 bar/close dump or daily table | dca23d2 |
| `index-hedge-screen-2026-10-12` | 1 | 1 bar/close dump or daily table | a5753f7 |
| `investor-preset-2026-09-26` | 4 | 4 equity curves | a5753f7 |
| `macro-suspend-investor-2026-10-04` | 12 | 12 equity curves | a5753f7 |
| `path-stability-2026-10-23` | 24 | 24 equity curves | a5753f7 |
| `pit-universe-2026-09-14` | 1 | 1 terminal-run table | a5753f7 |
| `price-band-binding-2026-11-13` | 1 | 1 equity curve | a5753f7 |
| `price-band-confirm-2026-11-13` | 20 | 20 equity curves | a5753f7 |
| `price-band-tiebreak-2026-11-13` | 10 | 10 equity curves | a5753f7 |
| `rebaseline-v12-2026-10-08` | 7 | 6 equity curves, 1 terminal-run table | a5753f7 |
| `record-kseed-2026-10-27` | 5 | 5 equity curves | a5753f7 |
| `short-only-liveness-2026-10-04` | 2 | 2 equity curves | a5753f7 |
| `short-setup-map-2026-10-12` | 26 | 26 per-event tables | a5753f7 |
| `short-wide-top-2026-10-13` | 26 | 26 per-event tables | a5753f7 |
| `shorts-liveness-2026-10-03` | 2 | 2 equity curves | a5753f7 |
| `shorts-phase-b-2026-10-09` | 6 | 6 equity curves | a5753f7 |
| `spy-benchmark-26y-2026-10-04` | 2 | 2 equity curves | a5753f7 |
| `stoplimit-entry-wfcv-2026-08-04` | 2 | 2 equity curves | a5753f7 |
| `top-n-grid-2026-09-22` | 18 | 18 equity curves | a5753f7 |
| `top-of-funnel-2026-09-21` | 4 | 4 equity curves | a5753f7 |
| `total-return-26y-2026-10-06` | 6 | 6 equity curves | a5753f7 |
| `trader-presets-2026-09-29` | 30 | 30 equity curves | a5753f7 |
| `trader-presets-rerun-2026-10-02` | 21 | 21 equity curves | a5753f7 |
| `twin-dedupe-26y-2026-10-29` | 6 | 6 equity curves | a5753f7 |
| `verify-3266-rerun-2026-10-22` | 1 | 1 equity curve | a5753f7 |
| `verify-chain-v-2026-10-19` | 8 | 8 equity curves | a5753f7 |
| `warehouse-dedup-2026-09-08` | 3 | 3 terminal-run tables | a5753f7 |
| `warehouse-rebuild-2026-09-06` | 10 | 1 bar/close dump or daily table, 9 terminal-run tables | a5753f7 |
| **total** | **458** | | |

Second batch (trading-results 96f047f):

| directory | files | what |
|---|---:|---|
| `arc-rerun-2026-09-01` | 4 | `splice-scan.csv`, `splice-scan-tradeable.csv` (consecutive closes), `b5-arc-s0/fwdvol.csv` (fill and later close), `b5-arc-s0/neverfilled-crossing.csv` (E and bar prices) |
| `chain-w-2026-11-10` | 1 | `results/firstdiff.txt` (keyed trades.csv diff, full trade rows) |
| `decision-walk-rk-2026-11-06` | 1 | `out/extras.txt` (E, close, stop) |
| `floor-nearest-2026-10-25` | 1 | `results/sm/read/y2022-positions.txt` (entry and exit prices) |
| `fresh-eyes-2026-10-13` | 1 | `results/forward/analysis/ours.csv` (weekly closes) |
| `fresh-eyes-dated-2026-10-18` | 5 | `results/analysis/{nss_sample_scan,placed_geo,placed_s0,nss,nearest_on_none}.csv` (anchor, close, trigger, limit, stop) |
| `pit-universe-2026-09-14` | 2 | `results/fetch_miss.txt`, `results/fetch_2026-09-14.log` (`MISS` lines carry an OHLCV bar) |
| `price-band-confirm-2026-11-13` | 10 | `results/k*/pbc{1,2}-P-k*-s0-firstdiff.txt` (full trade rows) |
| `price-band-tiebreak-2026-11-13` | 5 | `results/k*/pb-P-k*-s0-firstdiff.txt` (full trade rows) |
| `short-setup-map-2026-10-12` | 1 | `results/analysis/traces.txt` (raw and adjusted closes) |
| `stoplimit-entry-wfcv-2026-08-04` | 3 | `localtop-ladder/*-equity.csv` (daily equity curves) |
| `yearly-trade-review-2026-09-04` | 1 | `graded.csv` (entry and exit prices, `ep,xp`) |
| **total** | **35** | |

### Still public

A value scan of what is left (a line with a ticker and at least two numbers ≥ 1, at least 20 such lines per file) still flags about 215 files in `dev/experiments/`. A sample read shows two kinds. They stay here pending the user's call:

- **Runner logs** (about 150 `*.log`): `WARN: portfolio rejected fill for <SYM> (... price=<p>)` and similar lines that quote one fill price per event.
- **Analysis tables and reports** whose numbers are cash in dollars (`required`, `available` in `*cash_rejections.csv` and `*audit_entries.csv`), returns, ratios or scores rather than prices. Examples are the `entry-timing-screen-2026-11-12` replay and feature tables, `fresh-eyes-dated` `fwd*.csv`, and the read `.txt` reports. Some of them quote a single price in passing.

Outside `dev/experiments/`:

- **Run files** with a price column in `dev/backtest`, `dev/warmup-fix-runs` and `dev/all_eligible`. They are already copied to trading-results f72dd07. Their delete takes the full PR gates and comes next.
- **Test fixture** `trading/devtools/checks/fixtures/review_pack/shorts/trade_audit.sexp`, which holds real tickers with entry prices (#3675 review note N2). It goes with that full-gate PR.
- **Bar fixtures:** 650 EODHD daily bar files in `trading/test_data/<A-Z>/`, tracked by #3676.
