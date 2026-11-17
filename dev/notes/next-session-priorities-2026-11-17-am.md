# Next-session priorities — 2026-11-17 am (supersedes 2026-11-17)

The night found that the record's own new-high-ground test (`is_virgin`) and its overhead-supply grade compare a raw
breakout with a back-adjusted 520-week high. This is #3664, the same look-ahead class as #3659 but on the record's path.
The trades that pass the virgin test only through this mix carry up to 31–47 % of S's summed contribution per seed
(an upper bound). The fix is merged behind a default-off knob, and the paired record-vs-fixed run (`vsb-1`) is on the
cloud lane. The local dev container is now on-demand. Ground rules are unchanged.

## 1. Merged overnight (11-16 18:39 PT → 11-17 01:00 PT)

| PR | what |
|---|---|
| #3660 | `weekly_picks_dry_run_check.sh` pins that `weekly.sh` calls `bucket_shards` and `check_public_price_free` |
| #3661 | #3659 fix: failed-breakout gate reads the new `Stock_analysis.t.current_raw_close` at all three sites; later-split fixture; registry row `fixed`. #3659 closed after its sibling audit |
| #3662 | the 11-17 handoff, memory export, budget records |
| #3663 | container on-demand: `dev/lib/ensure_container.sh`, `container_idle_stop.sh`, `bounded_call.sh` (SIGKILL watchdog; the Go docker CLI ignores SIGALRM); 111-assertion check; standing-rules sentence in 8 agents; `dispatcher-cadence.md` rule 5 (rework 1: bound every docker call) |
| #3665 | the 18 rt-freshness `trades.csv` moved to private trading-results 477a85e; README pointers (contention-null too, rework 1); #3664 basis caveat on the seeded and broad-5y READMEs |
| #3666 | #3664 fix: knob `virgin_supply_basis` (`Legacy_mixed` default / `One_basis`); continuation and entry_freshness on one basis unconditionally (both default-off); 3 registry rows; dispatcher fix for a goldens-affected false positive |
| #3667 | cap-40 lane results, flag none (median D_end −0.451; 2/5 seeds neg60) |
| #3668 | queue row `vsb-1` = S + `((virgin_supply_basis One_basis))` |

User decisions, 11-16 evening:
- **Quota:** "we can spend a little bit more".
- **Docker:** on-demand (option 1).
- **#3664:** fix + paired run.
- **Rt price files:** move to private.
- **#3659:** I took the recommended fix; you did not pick.

## 2. Findings

- **#3659 sibling audit** (private trading-results afc9a39; comment on #3659):
  - rt-freshness: the verdict needs a rerun. Both its tests mixed bases, so "drawdown lever" is not quotable; "not promotable" stands.
  - Continuation: the REJECT is void as evidence. It was also run on sp500.
  - The new defect found by the audit is #3664.
- **cap-40:** its loss sits where the fbt-05 read predicted.
  - 2000–02, 2008 and 2022–23 together: median −0.34 per seed, against −0.10 for all other years.
  - Bearish weeks are negative on 5/5 seeds.
  - Bull weeks are mixed: k1 shows a broad −0.74 bleed.
  - #3664 is an open confound, since S itself mixes bases.
- **Data defects** the audit found, for the data-defect backlog:
  - KG resolves to another issuer's bars (a 2025 1:20 reverse split back-adjusts 2010 by ~14×).
  - The COL 2016-06-01 factor-0.1 row (no such split).
  - The SIAL 2014 and WTW 2016 rows look suspect.
  - The ELI 2014-05 interleaved bars, from the fbt-05 read.

## 3. In flight

- **vsb-1 lane:**
  - Cloud session `cse_013VUubfC58mmEyg6Uh1SW2T` (routine `trig_01EGdsscqsgyTNNLHwbG7h5T`), LANE_SHA 96cacbe20, launched 08:59Z 11-17.
  - 10 cells (S re-runs at this HEAD), about 12–14 h, so ~22:00Z 11-17.
  - The pre-registration is on #3664 (comment 6943210083): D_end per seed, each vsb-1 seed's ln(1+R) against the K=5 band (2.78, SD 0.225), and a descriptive flag.
  - Size check before reading: if median `s_out` > ~840 (30 % of S's 2,816 trades) or virgin readmissions are ~0 on any seed, treat it as a possible collapse first.
  - Then: mechanical read, merge main into the recreated `observatory/lane-results`, results PR → qc-results. This read is direction-class (it sizes the record), so it goes to results-analyst.

## 4. Queue

1. **vsb-1 read** (above), then the default decision (§5).
2. **Weekly picks, Sat 11-21, as-of 11-20:** `sh dev/weekly-picks/weekly.sh 2026-11-20`. The container now starts on demand through `docker_dune.sh` and `run-in-env.sh`. Run `container_idle_stop.sh` afterwards.
3. **Small harness follow-ups:**
   - `weekly.sh` guard-text pin (`[ "$DRY" = 1 ] || check_public_price_free`), from the #3660 QC.
   - Bound the remaining docker calls in `run-in-env.sh` (probe, inspect) and `docker_dune.sh` (polling), and drop the duplicate probe.
   - Retry a cold Docker Desktop `docker info` within the 180 s window instead of a hard FAIL after 30 s.
4. **Small test follow-ups:**
   - A panel-path `current_raw_close` test (#3661 QC note).
   - Harden the #2973 split-week mis-scale under `One_basis` (#3666 QC note; registry rows at :438 and :443).
5. **cap-40 leftovers:** the cash-lost-fill check (MMYT 2023, APPS 2020, BGO 2003), and the per-window entry counts (~2× S in the three windows).
6. **Unaudited bundles with the same code:**
   - arc-rerun-2026-09-01 (rt inside; `b5-arc` vs `b5-arc-macross` isolates it);
   - trader-presets 09-29 and 10-02 (continuation inside).
7. **Live weekly-snapshot generator:** it does not pass `virgin_crossing_readmission` or the new knob to `stock_analysis_config`. This is harmless at the live edge (factor 1); note it for completeness.
8. **Carried from 11-17:**
   - observatory hygiene (basis partition, `obs_read.sh` DD guard, review pack);
   - the P2c curves page;
   - the 11-17 carried list.

## 5. Decisions waiting (raise at 11:00 PT)

- **#3664 default once vsb-1 reads:**
  - (a) **Flip `virgin_supply_basis` to `One_basis` on correctness, whatever D_end shows (recommended).** Only a collapse or an invalid run would stop it. vsb-1's five cells become the new record band with no re-run. Later arms' S changes at the flip HEAD, and the finished msd/fbt/cap rows stay as mixed-basis reads.
  - (b) **Keep it default-off and only measure**, as #2982's stop-raise fix did. The record keeps the look-ahead.
  - Either way, R3 of `experiment-flag-discipline.md` has no ledger ACCEPT to stand on, so this is your call.
- **The other ~740 public `*trades*.csv` files with price columns** (59 experiment directories, all pre-11-14):
  - Recommended: move them to trading-results the same way as #3665, after checking that no script or test reads them.
  - Git history keeps them unless purged. A purge would be irreversible and is not recommended.
- **`CLAUDE.md` line** (the #3663 agent's suggestion): next to the `docker exec` guidance, "the container is stopped when idle: `sh dev/lib/ensure_container.sh` first". I left `CLAUDE.md` untouched.

## 6. Lessons

- **Grep for every spelling of a path before claiming nothing references it.** I searched `s[0-9]-core-trades` and missed `s{0,1,2}-core-trades`; qc-results caught the contention-null README.
- **jj workspaces have no `.git`.** Scripts that call git (`lane.sh`, `export-memory.sh`, `budget_local_record.sh`) silently use the main checkout's stale tree. Run a lane dry run from a git worktree, and copy export outputs across.
- **goldens_affected_check reads a moved default as a changed one.** It fires when a default field's line text changes, even for a pure move. Keep the field line identical (a private alias) rather than labelling `paired-run-done`.
- **A Go CLI ignores SIGALRM.** `perl -e 'alarm; exec docker …'` does not bound it; use a SIGKILL watchdog (`dev/lib/bounded_call.sh`).
