# Universe depth at live size, rerun on the repaired pit-v13 lists: run kit

The pre-registration is `PREREG.md` beside this file. It fixes the arms, the tripwire, the liveness rule, the measures
and the decision rule (carried over word for word from `../universe-depth-2026-11-23/`), and nothing here changes
them. This file covers how the run is launched and where its outputs go. Nothing has run yet.

The first run (`../universe-depth-2026-11-23/`, #3721) was INVALID: V6 failed on every paired read because the v13
lists held rename twins. #3727 repaired the lists. The user chose to rerun S3 and U4 only (10 cells).

## Files

- `make_specs.sh` writes `specs/udr-{S3,U4}-k{0..4}.sexp` (10 cells) from the record cells
  `../record-kseed-2026-10-27/specs/rk-kK.sexp`. It is the first run's `make_specs.sh` without the N arms. Below the
  name and description lines each spec is byte-identical to the first run's `ud-<arm>-kK.sexp`; only the lists they
  point at changed (in place, by #3727). Each spec is NAV-scale's `ns-P-100k-kK` with:
  - the universe schedule moved from `pit-v12/composition/` to `pit-v13/composition/`, with the same 27 rebalance
    dates (1999-05-31 to 2025-05-31) as the record. The 2026 list is not used, as in the record.
  - U4: `top-3000-YYYY` becomes `top-4000-YYYY` in every list path, and `universe_size` becomes 4000.
- `chain.sh` runs one seed per cloud session. `sh chain.sh dry-run [K]` prints the plan and runs the spec checks and
  the list checks without a container or network access. Its header documents every subcommand and lists what changed
  from the first run's `chain.sh`.

## Counts

Re-derived from the repaired lists, the same way the first run's kit derived them (list union over the 27 schedule
lists of the spec; `trading/test_data/backtest_scenarios/pit-v13/warehouse-extras.txt` for the 15 extras). The same
method on the pre-repair lists (`git show 96b4eb2b6^:...`) gives the first run's 9,679 and 12,330.

| count | S3 (top-3000) | U4 (top-4000) | first run | where checked |
|---|---|---|---|---|
| schedule union = params `universe_size` | 9,583 | 12,215 | 9,679 / 12,330 | `spec_checks`, preflight |
| cache `n_symbols` (union + 15 extras) | 9,598 | 12,230 | 9,694 / 12,345 | `spec_checks`, preflight |
| ABSENT (loadable names not in the `v13pit-12710` manifest) | 4 | 4 | 4 / 4 | preflight: exactly DNGFF, HLAN, MDFI, SYNI |
| preflight `n_symbols_absent` | ≤ 4 | ≤ 4 | ≤ 4 | preflight |

- The four absent names are `pit-v13/quarantine.txt`'s, which are still in the repaired lists and were absent in
  every first-run cell too. The repair only removed names, so the hole cannot grow; the preflight now requires the
  exact set instead of only bounding it.
- `SNAPSHOT_MAX_MMAP_HANDLES` stays 16000, above U4's 12,230 loads.
- The lists are pinned by `pit-v13/composition.md5`, whose md5 is `d587c5093f1a21fe137f4566826a018d` (58 lists) as
  #3727 left it.

## Run (cloud, one session per seed)

The setup is in `docs/howtos/claude_cloud_sessions.md`, under "Briefs that work" and "Backtest chain longer than 2 h".
Each session needs the R2 credentials in its environment, Docker, the image `ghcr.io/dayfine/trading-ci:latest`, and a
checkout of `dayfine/trading-results` at `../trading-results` (or `TR=<path>`) for `publish`.

**SC_SHA.** All five sessions run at the same SHA: main at or after the merge of this kit (it must contain #3727,
96b4eb2b6, which the guards check). The dispatcher picks it once, after the merge, and puts the same value in all five
briefs. A session whose HEAD is not SC_SHA, or whose SC_SHA is not on `origin/main`, aborts in the guards.

```sh
git checkout <SC_SHA>
mkdir -p .sweep-output/universe-depth-rerun
SC_SHA=<SC_SHA> setsid nohup sh dev/experiments/universe-depth-rerun-2026-11-26/chain.sh run K \
  >> .sweep-output/universe-depth-rerun/run.out 2>&1 < /dev/null &
```

Use K = 0..4, one per session. The brief must give this exact command, since a background Bash task is killed at 2 h.
The session waits with a Monitor until-loop on `.sweep-output/universe-depth-rerun/chain.log`, watching for
`UNIVERSE-DEPTH-RERUN kK DONE` or `ABORT`, plus a 30-minute `send_later` heartbeat. It must never `docker kill` all
containers. When the run is done:

```sh
sh dev/experiments/universe-depth-rerun-2026-11-26/chain.sh publish K    # price-bearing half -> trading-results main
```

The session then reports the `RESULT`, `PAIR`, `LIVE`, `ABSENT`, `LIST CHECKS`, `PACKPREP` and `TRIPWIRE` lines. The
dispatcher commits
`.sweep-output/universe-depth-rerun/results/kK/public/dev/experiments/universe-depth-rerun-2026-11-26/results/kK/`
into this directory in a results PR.

`run K` does these steps in order:

1. **Guards.** HEAD is `SC_SHA` and on `origin/main`, the checkout is clean, the PR commits the kit needs are
   ancestors (now including #3727), MemTotal is at least 10 GB, and the tripwire spec and md5 file are unchanged since
   NAV-scale's run.
2. **Spec checks** for seed K, including the union and load counts above.
3. **List checks.** `pit-v13/composition.md5` has md5 `d587c5093f1a21fe137f4566826a018d`, has 58 lines, the
   composition dir holds 58 lists and each matches its line; then `trading/devtools/checks/pit_twin_cooccur_check.sh`
   passes, including its "no pit-v12 twin pair co-occurs" line for pit-v13. They run again after the v13 stage, just
   before the preflight.
4. **Build.**
5. **Tripwire, on its own stage,** exactly as in the first run. Pull NAV-scale's stage: warehouse `v12wk-9236`
   (9,236 manifest entries), `corpact-2026-10-27`, bars `data-20261102`, 11,880 `dividends.csv`,
   `SNAPSHOT_MAX_MMAP_HANDLES` 12000. Run NAV-scale's own spec
   `../nav-scale-participation-2026-11-23/specs/ns-P-100k-k0.sexp` alone and compare its `trades.csv` md5 with
   `../nav-scale-participation-2026-11-23/results/k0/ns-P-100k-k0-s0-trades.md5.txt`
   (`f7746eb838618c9eac4aed7f969e63af`).
   - A mismatch stops the session, as `PREREG.md` requires. `TRIPWIRE_WAIVE="<reason>"` continues past it, and only
     the dispatcher may set it.
   - After a match, the v12 stage is deleted (`KEEP_V12=1` keeps it).
   - `sh chain.sh trip` runs this step alone.
6. **v13 stage.** Warehouse `v13pit-12710` (12,710 manifest entries, #3712), `corpact-2026-11-23`, bars
   `data-20261123`, `SNAPSHOT_MAX_MMAP_HANDLES` 16000. The `dividends.csv` set must equal the tarball's file list.
7. **Preflight** of the two arms on three months: `params.sexp` carries cash 100000, the three live-size lines in
   order, no `require_structural_stop false`, and `universe_size` equal to the schedule union; the cache loads the
   counts above; ABSENT is exactly the four quarantine names (saved as `udr-<arm>-kK-absent.txt`).
8. **Cells.** Two 26y cells, PAR at a time (PAR = (MemTotal − 3) / 7, 1 on the 15 GB VM; `PAR=2` overrides).
   `CELL_TIMEOUT` is 28,000 s. In the first run S3 took 6,690–8,619 s at 6.1 GB peak RSS and U4 8,509–9,891 s at
   7.4 GB. A session takes roughly 7–9 h.
9. **Reads.** Extracts per arm (`entries.tsv`, `nss.tsv`, `depth.tsv`), V6 for U4 vs S3 at the same seed, and the
   `LIVE` line for U4.
10. **Review-pack inputs** (below).
11. **Collect.** Files are split into public (this repo) and private (trading-results).

A relaunch with the same command resumes. Finished cells, a MATCHed tripwire, logged preflights, written extracts and
finished pack inputs are skipped.

## Review pack (RV1)

The first run's read could not build the pack (`../universe-depth-2026-11-23/RESULTS.md`, "Review-pack look" and
Appendix A): `trade_audit.sexp` was not kept, and the audit report needs the warehouse the run used, which only the
session has. So each session now keeps, **privately** (in trading-results, never in this repo, because they carry
prices):

- `trades.csv`, `equity_curve.csv`, `open_positions.csv` (as before) and `final_prices.csv` (new);
- `udr-<arm>-kK-s0-trade_audit_report.md` and `.html`, from `trade_audit_report_bin` run in the session against
  `v13pit-12710` (conformance rows and audit cards);
- `udr-<arm>-kK-s0-trade_audit.sexp.gz`, the audit gzipped (stop kinds, entry geometry, cash rejections, missed
  winners). One above 95 MB is not kept, and the log says so.

A failure in this step logs `PACKPREP WARN` and does not stop the session.

After all five `publish` steps, on the dispatcher's machine:

```sh
TR=<trading-results checkout> DATA=<bar store with SPY from 1999> \
  sh dev/experiments/universe-depth-rerun-2026-11-26/chain.sh pack S3     # and pack U4
sh dev/scripts/review_pack_render.sh --site .sweep-output/universe-depth-rerun/review-S3/site
```

`pack ARM` copies each published seed's files into `.sweep-output/universe-depth-rerun/pack/ARM/kK/`, unzips the
audit, and runs `dev/scripts/review_pack.sh --no-container --run-kind seed` with labels k0..k4. The in-session audit
report stands in for the pack's container step. The pack is looked at (`dev/rules/backtest-result-review.md`) before
the read is written, and the results writeup gets its "Review-pack look" section.

## Liveness, from the artifacts

- **U4:** the number of round trips in names that are in top-4000 but not top-3000 for their decision year (≥ 10 on
  ≥ 3 of 5 seeds), from `udr-U4-kK-s0-depth.tsv` (one row per `trades.csv` round trip; decision date from the audit's
  entry record joined on `position_id`, `date_source` = `fill` where none matched; `list_year` from the spec's own
  schedule; `band` = `1-3000`, `3001-4000` or `off-list`). The log line is
  `LIVE kK U4: <n> round trips in top-4000-not-top-3000 names ...`. S3 should show 0 in band 3001–4000, which checks
  the join.

## Measures the read derives

- **Measures 1–2** come from `actual.sexp` and `summary.sexp` (public); the per-period split from `equity_curve.csv`
  (private).
- **Measures 3–5** use `trades.csv` (private) joined on `position_id` to `depth.tsv` and `entries.tsv` (public).
- **Measure 6** is `nss.tsv`.
- **Measure 7** compares S3 with `../nav-scale-participation-2026-11-23/results/kK/ns-P-100k-kK-s0-*`.

## Outputs

- **Public**, committed here under `results/kK/`: `actual.sexp`, `summary.sexp`, `params.sexp`, `macro_trend.sexp`,
  `entries.tsv`, `depth.tsv`, `nss.tsv`, `absent.txt`, the `trades.csv` md5, `.rss`, the validator log, the V6 diff
  log, the chain log, and the tripwire's mark-free files under `trip/`.
- **Private**, in `dayfine/trading-results` under the same path: `trades.csv`, `equity_curve.csv`,
  `open_positions.csv`, `final_prices.csv`, `splits.csv`, `force_liquidations.sexp`, the validator reports, the cell
  logs, and the review-pack inputs above.
- **Not kept:** `trade_audit.sexp` uncompressed.

The read is drafted by `results-analyst` and reviewed by `qc-results`, as `PREREG.md` says.

## Checked by the kit's author, and not

- `sh chain.sh dry-run` for all seeds passes (spec checks, list checks, counts). `make_specs.sh` reproduces the first
  run's spec bodies byte for byte.
- `sh chain.sh pack S3` was smoke-tested on a fake trading-results tree built from the record cell `rk-k0-s0`.
- Not exercised: the in-session `packprep` step (it needs the cloud stage), and the R2 pulls, as in the first kit.
