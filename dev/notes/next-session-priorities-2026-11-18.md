# Next-session priorities — 2026-11-18 (covers 11-17 evening to 11-18 01:00 PT; supersedes 2026-11-15)

The virgin/supply look-ahead (#3664) is being fixed by flipping `virgin_supply_basis` to `One_basis` (user decision
11-17, "flip on correctness"). The fix is PR #3677. It waits on a paired golden chain, after which the moved goldens
are re-pinned. Separately, every price-bearing file that was still public in `dev/experiments/` is moving to the
private `dayfine/trading-results` repo, on the user's "move all" call. Quota is SMALL: 78 % of the week used, 4.1
days to reset. Run one agent at a time and no batch runs.

## 1. Merged (11-17)

| PR | what |
|---|---|
| #3671 | vsb-1 read rewritten around the supply-path count. The One_basis dial is live: S 114/114 audit records graded by the supply path, vsb-1 102/103. V7 does not read the knob. |
| #3672 | CLAUDE.md container line |
| #3673 | 709 trades CSVs moved to trading-results (e0252b2) |
| #3675 | 515 position and mark files moved (trading-results 3ccfce9, 0d2eec7) |
| #3678 | 493 run tables moved (trading-results a5753f7, dca23d2, 96f047f): equity curves, dumps, event tables, firstdiff trade dumps, fresh-eyes tickets and logs. Two QC rework rounds: a header scan misses header-less price files, so scan by value |
| #3680 | 47 run files outside `dev/experiments` moved (f72dd07, 192fba1); `.gitignore` trades negations dropped; review-pack shorts fixture made synthetic |

## 2. In flight (#3677 merged 11-18 as 1b5b991; the flip is done, no golden moved)

- **#3677, the flip** (`feat/virgin-supply-one-basis-default`, tip 08e2fac19).
  - The tripwire passed: S k0 26y on the flip build reproduces vsb-1 k0 `trades.csv` exactly (md5 `3ee10dca319e54a85f5e0a7842d8c537`, 559 round trips). The files are in trading-results 6cad233.
  - The paired golden chain is running locally. The script and log are in `.sweep-output/vsb-flip-run/` (moved out of `/tmp` after a second host restart); artifacts go to `.sweep-output/vsbg/`. The old arm is the same spec with `((virgin_supply_basis Legacy_mixed))` prepended.
  - Chain progress: phases 1 and 2 are done (33 cells). A host restart killed it in phase 3. It was resumed at 21:39 PT, and its log was rebuilt from the finished cells' summaries.
  - When the chain is done:
    - build the paired table;
    - commit the chain script, specs and mark-free results under `dev/experiments/virgin-supply-flip-2026-11-17/`, with trades CSVs going to trading-results;
    - re-pin the moved goldens (±15 % around the new actual, as in the precedent `repin.sh`);
    - update lane.sh `TRIP_MD5`, `observatory_lane_check.sh:90` and observatory README:219 from `0928cfe4` to `3ee10dca…`;
    - add the table to the PR body, add the `paired-run-done` label, and change the body to `Closes #3664`.
  - Then run the gates: CI → qc-structural (sonnet) → qc-behavioral → merge.

## 3. Queue

0. **Cheap-stock line: step 1 done (11-18, read-only).** Source: the gate-funnel S-k0 `pool_outcomes`, with raw closes joined from `data/`. It is one seed on a pre-flip build.
   - `No_structural_stop` is not cheap-specific. It skips 85.7 % of admitted rows at ≤ $14, 92.3 % at $14–33 and 92.8 % above $33. A cheap name skipped there is more often a monster: 13.6 % against 3.6 % above $33.
   - The loss that is specific to cheap names is the $1M entry-ADV liquidity floor. It accounts for 313 of the 319 cheap `Not_reached` rows (9.5 % of cheap admitted rows, against 0.5 % above $33), and all 64 cheap monsters among them.
   - So there is no detector defect to fix. The open lever is `min_entry_dollar_adv`, a capacity dial: see Decisions waiting. Memory: `project_trait_y_low_price`.
0a. **#3681: participation-scaled entry liquidity gate** (`ready-for-agent`; build after the quota reset, about 11-21,
   with one feat-weinstein agent). Today's entry floor is a fixed $1M of 20-day dollar ADV. #3681 adds
   `max_entry_adv_participation` (default off) so the bar scales with position size, and lets the weekly picks take
   an account or position size. User, 11-18: "initially if we can buy $10k it's good enough -- this should be
   configurable", then "we can wait". So the live picks keep the $1M floor
   (`dev/weekly-picks/record-config-overrides.sexp:22`) until #3681 merges; do not lower it by hand.
1. **#3676 bar fixtures.** Move the 650 EODHD bar files in `trading/test_data/<A-Z>/` to trading-results. CI fetches them with a read-only deploy key, and the repo stays public. Purging them from history is a separate decision. Do this after the flip.
2. **After the flip:**
   - `weekly_snapshot_generator.ml` does not pass `virgin_supply_basis` through, so it always uses the default (follow-up);
   - check the live config overrides and the Saturday 11-21 weekly picks.
3. **vsb-1 read QC notes** (non-blocking): say where the panel-path `current_raw_close` follow-up lives, and note the raw/adjusted length-mismatch route.
4. **Older items:**
   - the weekly.sh guard-text pin;
   - bounded docker calls;
   - a retry on the cold-start `docker info`;
   - #2973;
   - the cap-40 cash check;
   - observatory hygiene;
   - the P2c curves page;
   - an option for lane.sh to keep trade_audit counts.

## 4. For the user

- **Still public, your call:** about 150 runner logs that quote one fill price per rejected fill, 303 validator reports with `entry=<p>` sample lines, and passing quotes in reports. All are listed in `dev/experiments/TRADES-PRIVATE.md` §Still public. The bar fixtures are #3676.
- **x86 sweep done (11-17):** the dead Python 3.8 links, Parallels links and rustup proxies are removed, and the hook now runs on `/usr/bin/python3`. Still needs sudo: `sudo rm -rf /Library/Frameworks/Python.framework "/Applications/Python 3.8"`. HiPKILocalSignServer and Memory Clean 2 need Rosetta.
- **Rotate the GitHub token.** Then update the plaintext `~/.git-credentials` entry; credential.helper is `store`.
- **The host moved or restarted on 11-17 evening.** `/tmp` and the session scratchpad were wiped. The container and the repo, including `.sweep-output`, survived.

## Decisions waiting (deferred to 11:00 PT)

None. The cheap-stock choice was answered: the user picked (a) on 11-18. The ADV-floor screen then came out NO-BUILD. A median-size position would be a median 46 % of a day's dollar volume, and none of the 64 monster rows fit under 10 %. Capping positions to 10 % of volume leaves about +0.06 log over 26 years, which is under the 0.2 noise floor. The cheap-stock line is closed at backtest size. At live size ($10k positions) the same names fit, which is #3681; the user chose to wait for it rather than lower the floor now. `No_structural_stop` remains an open question for every price band. Memory: `project_trait_y_low_price`.
