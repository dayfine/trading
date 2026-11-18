# Next-session priorities — 2026-11-17 (supersedes 2026-11-15)

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

## 2. In flight

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

0. **Cheap-stock line, step 1 (USER 11-17).** Once #3677 merges, do a read-only dissection of cheap (≤ $14) candidates dropped as `No_structural_stop` in the #3602 S-k0 candidate log. The question is whether they are real no-base breakouts or volatile names whose base the detector misses. If bases are being missed, pre-register a default-off MA-fallback initial stop (spine 5), K=5 paired 26y plus a top-1000 cell, after the quota reset. If they really have no base, close the line. Memory: `project_trait_y_low_price`.
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

None.
