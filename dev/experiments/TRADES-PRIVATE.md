# Price-bearing trade files live in dayfine/trading-results

Per-trade CSVs that carry entry and exit prices (`entry_price`/`exit_price` or `entry_px`/`exit_px` columns) are bar-derived data under the EODHD terms, so they are kept only in the private `dayfine/trading-results` repo, at the same path they had here. Moves so far:

- 2026-11-16, #3665 (trading-results 477a85e): the 18 `rt-freshness-*-2026-08-20` arm files.
- 2026-11-17 (trading-results e0252b2): the 709 files listed below by directory, copied from main at 777f09ed4 and checked byte-identical before the delete.

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
