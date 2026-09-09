# Next-session priorities — 2026-09-10 (supersedes 2026-09-09)

Written 14:10 PT 2026-09-09 at session end. The 09-09 handoff's queue items 1–4 are resolved; r0 tripwire landed identical; container idle, no worktrees, no live processes.

## Merged this session (all docs / artifacts, admin-merged on green CI)

- #2737 (token audit correction) · #2739 (a0-s2 = record s2 digit-for-digit; `chain-v10.sh`) · #2740 (`_v10dedup` rebuilt: three vintages, twin reports + terminal runs, per-vintage MEL check) · #2743 / #2745 / #2751 (item-3 on `_v10dedup`, salts 0 / 1 / 2 + three-salt read + **ledger entry `2026-09-09-stop-width-by-macro-state-surface` = Reject, classified REJECT-as-default / keep-as-regime-axis**) · #2744 (ops daily).

## The two results that change what comes next

1. **Item 3 is settled.** On the deduped warehouse (V6 = 0 on every cell, `validator_diff -check V6` exit 0 per salt) the 12/8/4% per-state map has no salt-robust property: level −101 / +91 / −242pp, realised −$683k / +$170k / +$1.06M, maxDD worse / worse / better. The `_v7mark` "drawdown floor" was twin double-funding (both legs of NLS/BFX and BB/BBRY funded under the wider stop). **Item 4 (per-state width × 12%-weekly cadence) does not proceed.** Rule extracted: a maxDD improvement on a warehouse with V6 > 0 is not a read; decompose open MTM before any maxDD claim. `memory/project_stop_buffer_by_macro_state_axis`.
2. **The record band is re-based on `_v10dedup`: 312 / 383 / 640% (salts 1 / 0 / 2), maxDD 32.8–43.0, 707–728 trades, build 969637974** (`stop-width-by-state-2026-09-08/results/a0-breadth-on-null-s{0,1,2}-v10-*`). Salt 2's 640 is $3.84M unrealised on ADTN/MU/URI — quote the band. `_v10dedup` is a NEW path draw vs `_v7mark` (diverges 2005-02-04), not record-minus-twins: a new warehouse = a new three-salt band, always. `memory/project_record_rebase_2026_09_09`. Every later arm on the 2000 vintage pairs against a0-v10 at the same salt.

## Live (check first)

- **PR #2749 (harness/publisher-mutant-reconcile, cron-authored) — HUMAN MERGE DECISION.** CI pass; qc-structural APPROVED at the tip `6024976c9`; qc-behavioral at the tip = NEEDS_REWORK on the PR BODY ONLY (four stale numbers) — the in-tree content reproduces by replay. Rework cap 2 exhausted; the body was corrected dispatcher-side by REST PATCH (tip unchanged) and a comment explains. Merge or not is yours; the gate script will keep printing `rework`. Follow-up worth an issue: the 422-guard `return 0` flip is unpinned (53/53) — a 422-empty-lookup scenario closes it.

- r0 tripwire DONE 14:03: byte-identical to a0-s0-v10 (`stop-width-by-state-2026-09-08/results/r0-record-asis-s0-v10-*`). Nothing is running; `sweep-item3v10` and `sweep-dedup` removed.

## Queue (in order)

1. **Docker.raw recompaction** — host free fell 33 → 25 GB during the session, `Docker.raw` 44 → 47 GB. Once r0 is done and nothing runs: Docker Desktop → Resources → Apply & restart. Then delete the superseded container warehouses (`_v9gap` 2009/2019 are superseded by `_v10dedup`; `snap_top3000_{2009,2019}` plain, `dedup_v5thin_adj`, `_v8ctl`, `snap_top3000_1998_2026` were already candidates). Keep `_v7mark` 2000 until the 09-05 cadence candidate (item 3 below) is re-read — its committed reads cite it.
2. **#2732 store-level guard** (feat-data): the terminal-runs pass already classifies `prefix_misscale` (12 / 12 / 6 series per vintage: AGR $73,567 → $33.94, BKNG/PEGX 999999.9999, SBER $107,000, CMG, BHRB) and KEEPS them — quarantine or cut the class at build; add the validator expectation (median close > $10k, or a > 90% one-bar move on zero volume). Lead + list are on the issue.
3. **Re-measure the 09-05 cadence candidate (12%-weekly) against the v10 band** — `memory/project_stop_width_cadence_surface_2026_09_05` cleared 761% / DD 29.7 on the OLD basis and `_v7mark`; it is the next width lever and must run three salts on `_v10dedup` paired against a0-v10, V6-gated, with the open-MTM decomposition. If it does not clear the band on realised P&L AND maxDD at ≥ 2 of 3 salts, retire it the same way.
4. **Orchestrator summary push (D2, from the 09-09 daily summary #2744):** step 8 sets git identity, but jj reads its own (`jj config set --user user.name/user.email`) and `@` is never described (`jj describe`) — both independently fatal. Harness PR on `.github/workflows/` (full QC gates; needs an idle container).
5. Follow-ups carried: #2729 residuals; the `stop_loss` label hiding the `Per_position` breaker; `_v9gap` 2009 has no 5y spec (and is now superseded by `_v10dedup` 2009 — write the spec against that).

## Ops notes

- No agents were dispatched this session (cells + rebuild held the container continuously; the capacity rule's cost was wall-time, not OOM — cells ran 2h55m–3h30m each with two concurrent).
- Every wait was a `Monitor` tail on the chain logs; Bash `run_in_background` caps at 10 min and is useless for cells. The lane chain + waiter pattern (`/tmp/item3v10-run/waiter.sh` → worktree add → targeted `dune build` of three exes → two `nohup` lanes) launched the re-run 2 min after the rebuild finished with no session turn.
- `rebuild4.sh`'s MEL check is now per vintage (1 / 0 / 0); the strict `=1` aborted the chain on 2009 once.
