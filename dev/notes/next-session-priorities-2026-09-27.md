# Next-session priorities — 2026-09-27 (supersedes 2026-09-26)

Written ~23:30 PT 2026-09-27. Main green. A backtest chain is running overnight (details below). **No agents
may run beside it** (`container-capacity-scheduling.md`); code work goes to cloud sessions (`env/cloud`).

## State in one paragraph

All five code branches from the 09-26 night merged, plus one cloud-authored fix:
- #2986: stop-decision audit (#2977).
- #2987: split corpus, slice 1 (#2973).
- #2988: `n_stop_raises` counts silent tightening moves (#2974).
- #2995: `entry_ticket_macro_suspend`, default Off (#2976).
- #2996: three default-off stop flags. `stop_ma_same_basis` fixes the P0 basis mix (#2982); `correction_must_follow_peak` and `tightened_can_ratchet` fix the other #2974 defects.
- #2997 (cloud session): the late-Stage-2 tighten now actually fires (#2983).

Both #2995 and #2996 took one behavioral rework each: test-only; 5 and 6 unpinned contracts were found by mutation probes. **No default changed.** Issues #2974/#2976/#2977/#2983 closed. #2982 stays open until `stop_ma_same_basis` is measured.

## Running now — chain lane I (pinned `sweep-post2996` @ f5507ad86)

Launcher `/tmp/investor-run/launch-post2996.sh`; log `/tmp/investor-run/chain-I.log`; artifacts
`.sweep-output/investor-preset/`. All 7 specs passed PREFLIGHT. Order and ETA (PT):

| cell | 5y broad, V6-paired vs `inv5-hybrid` s0 | status / ETA |
|---|---|---|
| `inv5-hybrid` s0 (control) | −25.9 % / DD 39.5 % / 196 trades / Calmar −0.15 | done 22:16 |
| 9a `stop_ma_same_basis` | **−6.2 % / DD 38.6 % / 191 / −0.03** (+19.7 pp; V6 agree) | done 22:58 |
| 9b `correction_must_follow_peak` | | ~23:40 |
| 9c `tightened_can_ratchet` | | ~00:25 |
| 9d `entry_ticket_macro_suspend On_bearish_macro` | | ~01:10 |
| 9e 9a+9b+9c | | ~01:55 |
| investor preset vs hybrid, s0/s1/s2 (QUEUE item 3, pre-registered rule) | | ~02:00 → ~07:30 |
| then `f1-stoplimit-fresh` 26y s0 via `chain-fixes.sh` (lane F1), same build | V6 vs `f2-fills-faithful-s0` **by hand** (chain-fixes has no pairing) | ~07:30 → ~13:00 Mon |

**9a dissection:** raised trades 34 → 45 (+$131k). The paths diverge after the first changed raise (48 trades only in 9a, 53 only in the control), and no single trade carries the gap. **About half the +19.7 pp is unrealised end-window value** ($859k vs $579k open), so it is fragile. One salt on one window can only escalate: run 26y × 3 salts (QUEUE item 10), where the #2974 replay's tail warning (p10 −14 %) gets tested.

## P0 next session

1. Read lane I results; write the flag-screen + investor-preset results up as one results-only PR (qc-results; commit the per-arm `actual.sexp`, `trades.csv` and validator artifacts; V6 gate on each pair). Apply item 3's pre-registered rule as written.
2. Queue item 10: `stop_ma_same_basis` 26y × 3 salts paired vs the f2 record (first), then any 9-arm that is not clearly worse.
3. Run `sh dev/scripts/perf_long_cells.sh update` on `/tmp/fixes-run/chain-A.log` and on lane I / F1.
4. Obvious-fixes verdict PR (s2 carries a V6 flag: AGYS/HXL twin 2006-01-09); it closes #2961 if the verdict holds.

## Cloud queue (`env/cloud`, no warehouse or book needed)

#2975 (installed stop vs suggested stop), #2984 (live: no broker stop until first raise), #2989 (re-issued
ticket position_id), #2998 (late-tighten test gaps), #2999 (`trades_so_far` → `fills_so_far`), **#3001**
(findings registry + CI check: every finding names its guard), **#3002** (validators V19–V23: audit join,
audit basis, installed-vs-suggested stop, stalled ratchet, macro-gate bypass). A cloud PR's self-run QC
verdicts count only at the current tip, with CI green; they carry no mutation probes, so say so before merging
(`memory/project_env_cloud_label`).

## Hygiene notes from tonight

- Host disk: Time Machine local snapshots pinned deleted `_build` dirs (19 G free → 66 G after
  `tmutil thinlocalsnapshots / 40000000000 3`). Check `tmutil listlocalsnapshots / | wc -l` before each launch.
- A `pgrep -f scenario_runner.exe` guard inside `docker exec sh -c '…'` matches itself; use `[s]cenario_runner`.
- `gh pr update-branch` is refused by the auto-mode classifier ("merge without review"); the user ran it.
- 64 stale remote branches deleted (merged PR heads verified equal to branch tips). Left: `ops/prune-candidates-2026-09-21` (unpublished weekly report: PR it or delete, user's call) and the cloud session's `claude/devcontainer-deps-install-ta5zf4`.
