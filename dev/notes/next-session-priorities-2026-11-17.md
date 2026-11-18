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

## 2. In flight

- **#3677, the flip** (`feat/virgin-supply-one-basis-default`, tip 08e2fac19).
  - The tripwire passed: S k0 26y on the flip build reproduces vsb-1 k0 `trades.csv` exactly (md5 `3ee10dca319e54a85f5e0a7842d8c537`, 559 round trips). The files are in trading-results 6cad233.
  - The paired golden chain is running locally. The script is `/tmp/vsb-flip-run/chain.sh` and the log is `/tmp/vsb-flip-run/chain.log`; artifacts go to `.sweep-output/vsbg/`. The old arm is the same spec with `((virgin_supply_basis Legacy_mixed))` prepended.
  - Chain progress: phases 1 and 2 are done (33 cells). A host restart killed it in phase 3. It was resumed at 21:39 PT, and its log was rebuilt from the finished cells' summaries.
  - When the chain is done:
    - build the paired table;
    - commit the chain script, specs and mark-free results under `dev/experiments/virgin-supply-flip-2026-11-17/`, with trades CSVs going to trading-results;
    - re-pin the moved goldens (±15 % around the new actual, as in the precedent `repin.sh`);
    - update lane.sh `TRIP_MD5`, `observatory_lane_check.sh:90` and observatory README:219 from `0928cfe4` to `3ee10dca…`;
    - add the table to the PR body, add the `paired-run-done` label, and change the body to `Closes #3664`.
  - Then run the gates: CI → qc-structural (sonnet) → qc-behavioral → merge.
- **#3678** deletes 458 run tables: equity curves, dumps, event tables, and fresh-eyes order tickets and logs. The private copies are a5753f7 and dca23d2. Needs CI → qc-results → merge.
- **Next PR (full gates):** delete the outside-`dev/experiments` run files (private copy f72dd07), drop the `.gitignore` negations that track them (around lines 166-175), and handle the review-pack fixture `trading/devtools/checks/fixtures/review_pack/shorts/trade_audit.sexp` (real tickers and entry prices). Count the files from the diff itself; the #3675 review recounts 35-40.

## 3. Queue

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

- **Rotate the GitHub token.** Then update the plaintext `~/.git-credentials` entry; credential.helper is `store`.
- **The host moved or restarted on 11-17 evening.** `/tmp` and the session scratchpad were wiped. The container and the repo, including `.sweep-output`, survived.

## Decisions waiting (deferred to 11:00 PT)

None.
