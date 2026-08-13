# Next-session priorities — 2026-08-14

**Supersedes** `next-session-priorities-2026-08-13.md`. That file's P0/P1 framing
still stands where not contradicted below; this file carries what changed
overnight and what is still owed.

## What landed (10 PRs merged, 2026-08-13 session)

| PR | what |
|---|---|
| #2285 | Short-stop citation corrected to *derived*, not quoted |
| #2260 | opam weekly (dune 3.24.1→3.24.2) |
| #2280 | `docker_dune.sh` — 4 real defects fixed + a 6-assertion smoke test |
| #2266 | audit-record fidelity + the `cp -p` guard test |
| #2299 | **scale-in retirement (Rule 4), −1,473 lines** |
| #2300 | `container-capacity-scheduling.md`, `pr-gate-loop.md`, `pr_gate_status.sh` |
| #2291 | armed-StopLimit golden, bands tightened to actually catch the defect |
| #2265 | G4 basis split — `None`-propagation contract pinned |
| #2288 | ladder-v4 read + **the 302/6y nearfloor artifact** |
| #2293 | path-seed salt |

Main green throughout. Open at session end: **#2301–#2304** (orchestrator cron
output — three code PRs + one audit/daily). Deliberately not gated: a 26y
backtest owns the container, and six agent dispatches against it is exactly the
mistake that cost 1h53m tonight.

## In flight — the 26y cell-09 run

`/tmp/chain_26y_cell09.log`, launched 01:49, pinned worktree `.claude/worktrees/v4-fixed`.
Cell 09-nearfloor × 3 salts at 26y/top-3000. **Collect with
`grep RESULT /tmp/chain_26y_cell09.log`.** Compare against the already-collected
reference arm:

- **cell 00 (core): 281.71 / 397.95 / 265.44** — mean 315, spread 132pp.

⚠ **This comparison is underpowered by construction** and should be reported as
such. Cell 00's own spread is 132pp at n=3; only an enormous effect clears it.
The 26y run earns its keep for **regime coverage** (dot-com + GFC), not for
resolving nearfloor. The powered answer is n≥10 salts at 302/6y or 500/5y, where
each run is ~4 minutes.

The script guards memory before each salt (`MIN_FREE_MIB=4096`) and logs peak
RSS. A silent OOM is the failure mode to expect: empty child log, no stack,
`<no result>` in the chain log.

## The substantive result — nearfloor is a variance dial (#2288)

`dev/experiments/nearfloor-302-6y-2026-08-13/` now holds specs + `run.sh` +
per-run metrics. Both arms, 3 salts, 302 symbols, 2018-2023:

| arm | s0 | s1 | s2 | mean | spread |
|---|---|---|---|---|---|
| 00 core | 65.91 | 47.33 | 48.27 | 53.84 | **18.58** |
| 09 nearfloor | 24.98 | 25.42 | 25.32 | 25.24 | **0.44** |

**The mechanism, stated from structure rather than a ratio:** across core's three
draws the trade count moves by **one** (288/289/288) and maxDD by **0.009pp**,
while return moves **18.58pp**. Nearly the entire draw-to-draw difference sits in
**a single trade's outcome** — §1b's "a cent re-runs the lottery" observed
directly. Nearfloor's trade count is *exactly* invariant (235/235/235) and it
holds ~62 days vs core's ~41.

So nearfloor is not "worse by ~28pp" — it is a different risk/return point: about
half the return, 4pp less drawdown, a higher win rate (37.9 vs 31–33), a ~50%
longer hold, and an outcome that barely depends on the path draw.

### What this invalidates — READ BEFORE TRUSTING THE P2 TABLE

The prior doc's concentration result claims separation on the grounds that
*"0.20's worst draw (56.8) beats the baseline's best (48.1)"*. Its baseline row
(45.6 / range 6.6 / 288 trades / 19.1 maxDD) is the **same cell** re-run here,
and its stated range is ~3x too small — this run's baseline drew **65.9**, well
above 0.20's worst. **On these numbers the arms overlap and the lever is not
separated.** Re-run the concentration arms with ≥3 salts each before treating
0.20 as a candidate.

## Method rules that came out of tonight (now enforceable)

- **`.claude/rules/container-capacity-scheduling.md`** — the container is a fixed
  7.75GB/8-core resource. A multi-hour backtest (~3.3GB) and an agent wave
  (~1-2GB each while linking) are **mutually exclusive**; cap agents at 3
  otherwise; dispatcher-side `gh`/`jj`/docs work is free. OOM kills are silent.
- **`.claude/rules/pr-gate-loop.md`** + **`dev/scripts/pr_gate_status.sh`** — run
  the script at session start and after every agent wave. It encodes two traps a
  hand-read gets wrong: QC verdicts land as COMMENTED (GitHub blocks
  self-approval), and a review body that *mentions* the other gate must not be
  counted as that gate's verdict.
- **Never quote a range from n=3 as a noise floor.** Prefer a duplicate-cell null.
- **Never chain `gh pr checks` into the same command as `gh pr merge`** — see the
  near-miss below.

## Errors made tonight (both recorded in memory)

1. **Six agents OOM-killed the 26y run 1h53m in.** The chain script's own header
   warned against exactly this. → `container-capacity-scheduling.md`.
2. **Merged #2265 with CI `pending`**, because `gh pr checks` and `gh pr merge`
   were in one compound command so the merge fired before the output could be
   read. Main happened to come back green. → appended to
   `feedback_pr_merge_ci_gate`.

## Carried forward, unchanged

- **#18** `stop_initial_distance_pct` empty on ~57% of trades.csv rows — still
  blocking stop-width analysis.
- **P0.2 integration tests** (task #19): design is settled and recorded in the
  session task list — all-eligible at `min_grade=F` yields every symbol that ever
  became a candidate; new exe modeled on `pick_small_universe/pick.ml`; **must**
  union in macro/index/sector-ETF context symbols; acceptance test is that the
  fixture universe reproduces the full-universe trade list exactly.
- **P0.1 `.mli` file-length blind spot** — `linter_file_length.sh` still never
  scans `*.mli`. #2299 took ~200 lines off the config surface; re-measure before
  extending the linter.
- **P1 retirement program** — `enable_continuation_buys` + `continuation_config`
  is the next big row (the `Continuation` module lives at
  `analysis/weinstein/continuation/`, also consumed by `stock_analysis`). Run the
  live-consumer grep first; check the ledger for the keep-as-axis/do-not-revive
  contradiction, which was present on scale-in and had to be resolved explicitly.
- **#4**, **#12**, **#14**, **#8**, **#15**, **#16**, **#10**, **#11**, **#6**.

## Known-unsourced claims (do not propagate)

- The **26y win-rate row** `40.4 > 34.0` in the nearfloor tables has no committed
  artifact anywhere. Labelled unverified in both the notes and the memory file.
  A 26y run that emits win rate would close it.
