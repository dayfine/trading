# Next-session priorities — 2026-09-09 (supersedes 2026-09-08)

Written 21:40 PT 2026-09-08 at session end. Context: the 09-08 evening handoff's queue items 1–3 are done; item 4 waits on the deduped warehouse.

## Merged this session (CI + qc-structural + qc-behavioral at the tip unless docs-only)

- #2725 (prune probe, behavioral re-run APPROVED) · #2731 (handoff) · #2734 (docs: a2-s0 + a1-s1 reads) · **#2733 — #2730 ask 1: `build_snapshots.exe` carries the rename-twin pass** (`-dedupe-rename-twins -twin-basis returns`, shared `Twin_pass` library, incremental rule = twin-dropped symbols leave the carry set) · **#2735 — #2730 ask 2: `validator_diff.exe`** (cross-arm Invariant-count gate; exit 0 agree / 1 differ / 2 unreadable; **paired reads gate with `-check V6`** — V7/V12/V13 move with the trade list; check 8 of `mechanism-validation-rigor.md`).
- Issue **#2732**: MEL in the 2000 vintage is a ~$170k/share mis-scaled series; map arms lost $172k–$343k on its 12.2 bar.
- `dev/notes/token-usage-audit-2026-09-08.md` — quota audit (main-session context 450–995k re-read every turn ≈ 55% of spend; 72 qc-structural agents in 3 days vs ~20 reviews posted; sub-agent cache writes on the 1h TTL ≈ 40%). Levers: handoff+clear at ~300k; check the review count before any QC re-dispatch; 5m TTL for subagents if settable; trim `.claude/rules`.

## Item-3 surface — three salts read (`dev/experiments/stop-width-by-state-2026-09-08/README.md` §"Three-salt read")

Map (12/8/4%) vs record: +429 / +207 / +571pp, but ≈ $0.8–0.9M twin double-count and $1.4–1.9M open MTM (VIAV) per cell; realised ex-twin delta −/−/+. **Salt-robust: maxDD 42–45 → 31–38 in every cell + the stop_loss→rotation exit shift** — the clock-52 shape. Null controls a0-s0 and a0-s1 = the record digit-for-digit (build inert). Verdict: drawdown-floor property, no consistent realised edge, **not promotable until re-run on the deduped warehouse.**

## Live processes (nohup on the host)

- Lane A: `a0-breadth-on-null-s2` (since 21:20; control vs the record's s2 = 180.89 / 755 / 0.3208 / 42.18; log `/tmp/item3-run/chain-A.log`, artifacts in the container at `/tmp/sweeps/item3/`, docker cp into the experiment's `results/`). Expect digit-for-digit; if not, the build is NOT inert at s2 and the s2 map read must be paired against a0-s2 instead of the record.
- **`/tmp/wh-rebuild/rebuild4-waiter.sh` (pid in `/tmp/wh-rebuild/rebuild4-launch.log`)** waits for both lanes DONE + zero `scenario_runner` processes, then runs `dev/experiments/warehouse-dedup-2026-09-08/rebuild4.sh`: the three vintages → `/tmp/snap_top3000_{2000,2009,2019}_v10dedup` with the twin pass armed and MEL quarantined, from the pinned `sweep-dedup` worktree (c70c39c23, builder already built). Log `/tmp/wh-rebuild/rebuild4.log`; per-vintage `rename_twin_report_<v>_v10.txt` + `terminal_runs_<v>_v10.csv` copied into that experiment's `results/`. **Do not dispatch agents or launch cells while it runs** (each vintage is a full 3,000-symbol build). If it has not started by the time you read this, check the waiter is alive and the lane logs say DONE.

## Queue (in order)

1. **Read a0-s2** (control) and write it into the item-3 README; docs PR.
2. **When `_v10dedup` is built:** commit the twin reports (which pairs were dropped per vintage — expect NLS/BFX, BB/BBRY, AABA/YHOO, AORT/CRY_old, CSC/DXC, RCII/UPBD, LANC/MZTI, HPT/SVC, AZN/AZN_old, DOC/HCP_old among them); manifest vs .snap counts; then **re-run the item-3 null + a1 map at salts 0–2 on `_v10dedup` 2000** (new chain dir, `--snapshot-dir /tmp/snap_top3000_2000_v10dedup`, same specs) with `validator_diff -report null=<a0>.sexp -report map=<a1>.sexp -check V6` as the pairing gate (must exit 0 = V6 equal, ideally 0 on both). Read: does the maxDD floor survive? realised ex-MTM delta?
3. **Re-base the record band on `_v10dedup`** (the record's own s1/s2 cells carry V6 = 2 / 5): three salts, commit as `record-rebase-2026-09-0x`; V6 must read 0 on every cell.
4. Item 4 (per-state width × the 12%-weekly cadence candidate) ONLY if the floor survives step 2; otherwise classify the map REJECT-as-default / keep-as-regime-axis in the ledger.
5. Follow-ups: #2732 (store-level sanity check for mis-scaled series — a validator expectation on median close > $10k or a >90% one-bar move on zero volume); #2729 residuals; the `stop_loss` label hiding the `Per_position` breaker; `_v9gap` 2009 has no 5y spec.

## Ops notes

- Host data volume is 95% full (24 GB avail); `Docker.raw` 44 GB — recompact (Docker Desktop → Resources) once the rebuild is done and nothing runs. Old warehouses `snap_top3000_{2009,2019}`, `dedup_v5thin_adj`, `_v8ctl`, `snap_top3000_1998_2026` are candidates to delete after `_v10dedup` is validated.
- Worktrees: `sweep-item3` (remove after a0-s2 is read), `sweep-dedup` (keep until the rebuild finishes).
- Every QC/feat agent this session hit the sandbox refusing `docker exec … bash -c` from a worktree and `jj workspace add`; they used a wrapper script + plain git. Put both fallbacks in every brief.
- Three builders in sequence alongside two cells stretched a1-s2 to 6h45m (s0 was 3h14m). The capacity rule's cost is wall-time, not OOM.
