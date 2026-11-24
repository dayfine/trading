# Universe depth and the structural stop at live size: run kit

The pre-registration is `PREREG.md` beside this file. It fixes the arms, the tripwire, the liveness rules, the
measures and the decision rule, and nothing here changes them. This file covers how the run is launched and where its
outputs go. Nothing has run yet.

## Files

- `make_specs.sh` writes `specs/ud-{S3,U4,N3,UN4}-k{0..4}.sexp` (20 cells) from the record cells
  `../record-kseed-2026-10-27/specs/rk-kK.sexp`. Each spec is NAV-scale's `ns-P-100k-kK` (the record at
  `initial_cash 100000.0`, with `dev/weekly-picks/live-size-overrides.sexp` appended after `tiebreak_seed`). The
  differences from that spec are the ones `PREREG.md` names:
  - all arms: the universe schedule moves from `pit-v12/composition/` to `pit-v13/composition/`, with the same 27
    rebalance dates (1999-05-31 to 2025-05-31) as the record. The 2026 list is not used, as in the record.
  - U4 and UN4: `top-3000-YYYY` becomes `top-4000-YYYY` in every list path, and `universe_size` becomes 4000.
  - N3 and UN4: `((require_structural_stop false))` is appended as the last override. The record's own `true` line
    stays, and the later line wins.
- `chain.sh` runs one seed per cloud session. `sh chain.sh dry-run [K]` prints the plan and runs the spec checks
  without a container or network access. Its header documents every subcommand.

## Run (cloud, one session per seed)

The setup is in `docs/howtos/claude_cloud_sessions.md`, under "Briefs that work" and "Backtest chain longer than 2 h".
Each session needs the R2 credentials in its environment, Docker, the image `ghcr.io/dayfine/trading-ci:latest`, and a
checkout of `dayfine/trading-results` at `../trading-results` (or `TR=<path>`) for `publish`.

All five sessions run at the same SHA, which is main at or after the merge of this kit:

```sh
git checkout <SC_SHA>
mkdir -p .sweep-output/universe-depth
SC_SHA=<SC_SHA> setsid nohup sh dev/experiments/universe-depth-2026-11-23/chain.sh run K \
  >> .sweep-output/universe-depth/run.out 2>&1 < /dev/null &
```

Use K = 0..4, one per session. The brief must give this exact command, since a background Bash task is killed at 2 h.
The session waits with a Monitor until-loop on `.sweep-output/universe-depth/chain.log`, watching for
`UNIVERSE-DEPTH kK DONE` or `ABORT`, plus a 30-minute `send_later` heartbeat. It must never `docker kill` all
containers. When the run is done:

```sh
sh dev/experiments/universe-depth-2026-11-23/chain.sh publish K    # price-bearing half -> trading-results main
```

The session then reports the `RESULT`, `PAIR`, `LIVE`, `ABSENT` and `TRIPWIRE` lines. The dispatcher commits
`.sweep-output/universe-depth/results/kK/public/dev/experiments/universe-depth-2026-11-23/results/kK/` into this
directory in a results PR.

`run K` does these steps in order:

1. **Guards.** HEAD is `SC_SHA` and on `origin/main`, the checkout is clean, the PR commits the kit needs are
   ancestors, MemTotal is at least 10 GB, and the tripwire spec and md5 file are unchanged since NAV-scale's run.
2. **Spec checks** for seed K.
3. **Build.**
4. **Tripwire, on its own stage.** Pull NAV-scale's stage: warehouse `v12wk-9236` (9,236 manifest entries),
   `corpact-2026-10-27`, bars `data-20261102`, 11,880 `dividends.csv`, `SNAPSHOT_MAX_MMAP_HANDLES` 12000. Run
   NAV-scale's own spec `../nav-scale-participation-2026-11-23/specs/ns-P-100k-k0.sexp` alone and compare its
   `trades.csv` md5 with `../nav-scale-participation-2026-11-23/results/k0/ns-P-100k-k0-s0-trades.md5.txt`
   (`f7746eb838618c9eac4aed7f969e63af`).
   - A mismatch stops the session, as `PREREG.md` requires. `TRIPWIRE_WAIVE="<reason>"` continues past it, and only
     the dispatcher may set it.
   - After a match, the v12 stage is deleted (`KEEP_V12=1` keeps it).
   - `sh chain.sh trip` runs this step alone.
   - Every session runs the tripwire, so every session's build, image and pulls are checked.
5. **v13 stage.** Warehouse `v13pit-12710` (12,710 manifest entries, #3712), `corpact-2026-11-23`, bars
   `data-20261123`, `SNAPSHOT_MAX_MMAP_HANDLES` 16000 (above U4's 12,345 loaded names). No `dividends.csv` count is on
   record for this corpact, so the check is that the data dir's set equals the tarball's file list.
6. **Preflight** of the four arms on three months. It checks that `params.sexp` carries cash 100000, the three
   live-size lines in order, `require_structural_stop false` last in the N arms only, and `universe_size` equal to the
   union of the schedule's lists (S/N 9,679, U 12,330). The cache must load the union plus
   the 15 warehouse extras (9,694 and 12,345).
   - **ABSENT** is logged per arm: the loadable names the v13 manifest lacks (at least the four in
     `pit-v13/quarantine.txt`). They are saved as `ud-<arm>-kK-absent.txt`, and the preflight's `n_symbols_absent` must
     not exceed that count.
   - The full list union (13,171 names) is larger than the manifest (12,710). Read these lines first: a list name with
     no snapshot cannot trade, and a large hole in ranks 3001–4000 weakens U4.
7. **Cells.** Four 26y cells, PAR at a time.
   - PAR = (MemTotal − 3) / 7, which is 1 on the 15 GB VM. v12 cells peaked at 5.7–5.9 GB of RSS, and U4 loads 34 %
     more names. `PAR=2` overrides this.
   - `CELL_TIMEOUT` is 28,000 s.
   - A session takes roughly 13–15 h.
8. **Reads.**
   - Extracts per arm: `entries.tsv`, `nss.tsv` and `depth.tsv`.
   - V6 for U4 vs S3, N3 vs S3 and UN4 vs U4, at the same seed.
   - `LIVE` lines.
9. **Collect.** Files are split into public (this repo) and private (trading-results).

A relaunch with the same command resumes. Finished cells, a MATCHed tripwire, logged preflights and written extracts
are skipped.

## Liveness, from the artifacts

Both PREREG liveness rules can be computed from per-cell files the chain writes. The chain logs them per seed. The
read applies the 3-of-5 rule.

- **U4:** the number of round trips in names that are in top-4000 but not top-3000 for their decision year (≥ 10).
  - The source is `ud-U4-kK-s0-depth.tsv`, which has one row per `trades.csv` round trip.
  - The decision date comes from the audit's entry record, joined on `position_id`. The `date_source` column says
    `fill` where no audit record matched.
  - `list_year` is the list the spec's own schedule had in force on that date.
  - `band` is `1-3000` (in that year's top-3000), `3001-4000` (only in its top-4000), or `off-list`.
  - The log line is `LIVE kK U4: <n> round trips in top-4000-not-top-3000 names ...`.
  - S3 and N3 should show 0 in band 3001–4000, which checks the join.
- **N3:** the share of entries with a `Buffer_fallback` initial stop (≥ 20 %).
  - The source is `ud-N3-kK-s0-entries.tsv`, whose column 7 is the placed entry's `stop_floor_kind` from the audit.
  - The log line is `LIVE kK N3: <b> of <n> placed entries Buffer_fallback = <x>%`.
  - The share is over placed entries, meaning the audit's entry records. `depth.tsv` carries the same kind per round
    trip, for a share over filled trades.

## Measures the read derives

- **Measures 1–2** (log NAV ratio, max DD, Ulcer) come from `actual.sexp` and `summary.sexp`, which are public. The
  per-period split comes from `equity_curve.csv`, which is private.
- **Measures 3–5** use `trades.csv` (private) joined on `position_id` to the public `depth.tsv` and `entries.tsv`.
  - Measure 3: raw entry price ≤ $14 and doublers.
  - Measure 4: round trips and summed NAV% by band.
  - Measure 5: win rate, median return and doublers by `stop_floor_kind`.
- **Measure 6** (`No_structural_stop` skips per year) is `nss.tsv`. It comes from the audit's weekly decision
  record, so it counts every screening Friday and not only those with a buy.
- **Measure 7** compares S3 with NAV-scale P-100k. It uses this run's S3 files and
  `../nav-scale-participation-2026-11-23/results/kK/ns-P-100k-kK-s0-*`.

## Outputs

- **Public**, committed here under `results/kK/`:
  - `actual.sexp`, `summary.sexp`, `params.sexp`, `macro_trend.sexp`
  - `entries.tsv`, `depth.tsv`, `nss.tsv`, `absent.txt`
  - the `trades.csv` md5, `.rss`, the validator log, the V6 diff logs and the chain log
  - the tripwire's mark-free files under `trip/`
- **Private**, in `dayfine/trading-results` under the same path: `trades.csv`, `equity_curve.csv`,
  `open_positions.csv`, `splits.csv`, `force_liquidations.sexp`, the validator reports and the cell logs.
- **Not kept:** `trade_audit.sexp`, because of its size. The extracts carry what the read uses.

The read is drafted by `results-analyst` and reviewed by `qc-results`, as `PREREG.md` says.

## Not checked by this kit

The R2 objects `v13pit-12710`, `corpact-2026-11-23` and `data-20261123` were not pulled when the kit was written. The
stage step checks their counts in the session. The ABSENT bound was exercised only on a synthetic manifest.
