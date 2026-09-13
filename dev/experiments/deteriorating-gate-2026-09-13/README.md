# Deteriorating-breadth long gate — three-salt read on `_v10dedup` (2026-09-13)

**Status: PRE-REGISTERED** (written before any cell ran). Mechanism: `deteriorating_blocks_longs`
(issue #2755, PR #2759) — a default-off long-admission gate that rejects new longs when
`Macro.result.breadth_state = Deteriorating`; inert unless `macro_config.breadth_direction.enabled`.

## Why

Entries made while breadth is Deteriorating lose in both books over 2000–2026 (record bundle n=80,
29% win, −$604k; `stop-width-cadence-surface-2026-09-05/README.md` §"Breadth state across 27 years").
Nothing blocks them: the macro gate blocks only `Bearish`; `neutral_blocks_longs` would also kill
`Recovering`, the best cohort. Sizing the stop by state (item 3, ledger
`2026-09-09-stop-width-by-macro-state-surface`) was the wrong instrument and is REJECT-as-default.

## Design (binary, no value search)

| | |
|---|---|
| warehouse | `/tmp/snap_top3000_2000_v10dedup` (rename twins dropped, MEL quarantined) |
| null | the committed `stop-width-by-state-2026-09-08/results/a0-breadth-on-null-s{0,1,2}-v10-*` cells (build 969637974): **382.74 / 311.75 / 639.74 %**, 710 / 707 / 728 trades, maxDD **37.60 / 32.75 / 42.96** (salts 0 / 1 / 2) |
| arm | `specs/a3-deteriorating-gate.sexp` = the a0 spec + ONE override `((deteriorating_blocks_longs true))` |
| build | main after #2759 merges, pinned in `.claude/worktrees/sweep-detgate`; runtime-inert vs 969637974 apart from #2759 by construction (only #2758's default-off builder flag and docs merged in between — verify at launch with `git log 969637974..HEAD --oneline`) |
| salts | 0, 1, 2 (`TRADING_PATH_SEED_SALT`), two concurrent lanes (`chain.sh A a3-deteriorating-gate:0 a3-deteriorating-gate:2`, `chain.sh B a3-deteriorating-gate:1`) |
| pairing gate | `validator_diff.exe -check V6 -report null=<a0-v10> -report gate=<a3-v10>` exit 0 per salt, V6 = 0 on both |
| read | per salt: level, **realised** P&L (closed trades), unrealised (open MTM — decomposed by name), maxDD, trade count, exit mix; join on `symbol|entry_date` (position_id is not shared across arms) for shared / null-only / arm-only P&L; count of Deteriorating-state entries removed (from `trade_audit.sexp`) |

**Pre-registered decision rule (from #2755):** the gate CLEARS if realised P&L AND maxDD both improve
vs the a0-v10 null at ≥ 2 of 3 salts. Otherwise the state-conditioning idea retires
(REJECT-as-default; keep-as-axis only if one salt shows a large, name-attributable win worth a
regime read). No per-state value search — 80 / 36 entries per cohort is below the 230-trade
measurability floor. Level (total_return_pct) is reported but NOT a criterion: the null's salt-2
640% is $3.84M of open MTM on three names.

**Expected mechanism if it works:** ~80 fewer entries over 26y (the Deteriorating cohort), those
entries were −$604k realised on the record, so the realised delta should be of that order plus
whatever the freed cash buys instead (the substitution is the unknown — the freed slots may land on
worse names). maxDD should improve only if the removed entries cluster inside the drawdown windows
(2001–02, 2008, 2020, 2022).

## Log

(filled as cells finish; per-arm raw artifacts committed under `results/` — never read a number
from the chain log, the second-finishing lane's summary line can carry both arms.)

- 03:50 PT 09-13: #2759 merged (squash 31e4bb9c3; two QC rounds — rework iteration 1 threaded `~macro_trend`
  into `longs_admitted_by_breadth` so flag-off is bit-identical by construction, and added the strategy-level
  fresh-candidate pin; probes A–E all caught at 4fdaab859). Worktree `sweep-detgate` pinned at 31e4bb9c3.
  Runtime drift vs the null's build 969637974, by inspection of `git log 969637974..31e4bb9c3`: #2759 itself
  (flag-off identity pinned by `test_deteriorating_blocks_longs_off_is_identity` + the widened truth table),
  #2758 (build-time builder flag, default-off, warehouse already built), #2750 (V18 validator check — post-run
  report only), #2767 (devtools test), ops/docs/harness. No a0 tripwire cell re-run (3 h); accepted by inspection.
