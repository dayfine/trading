# Next-session priorities — 2026-08-15

**Supersedes** `next-session-priorities-2026-08-14b.md`. Read this one.

## Start here

1. `gh run list --branch main --workflow CI --limit 1` — main was green at 00:47.
2. `sh dev/scripts/pr_gate_status.sh` — every open PR's gate state and its ONE
   next action. Run at session start and after every agent wave.

## The two carried-forward items that turned out to be one bug — both now closed

`#18` ("`stop_initial_distance_pct` empty on ~57% of trades.csv rows") was never
a column bug, and it was the same bug as `#4` ("position_id join for audit").

`Trade_context._lookup_audit_for_trade` joined audit records to round-trips by
`(symbol, entry_date)` with a 7-day proximity fallback. On a 288-trade async
resting-ticket run, **147 rows (51%) lost the join** — and all four
audit-derived columns were empty on *exactly the same rows*, which is what
identifies it as one join failing rather than four emission bugs. For every
missed row the symbol had audit records, all preceding the fill, none within 7
days: **mean gap 96.7 days, max 1322**.

Diagnosis PR #2316; fix PR #2317 (threads `position_id` from the simulator
through round-trip pairing, keeps the date path as fallback).

### Two things worth carrying forward

**The "ticket age capped at ~1 week" caveat was circular.** It is capped at a
week *because the join window is a week* — a ticket resting longer has no audit
record within 7 days of its fill, so it never appears as an aged ticket; it
appears as an empty row and drops out. Any ticket-age figure produced before
#2317 is truncated at the join window, whatever its spec header says. The 51
ladder-v4 / nearfloor spec headers still carry the caveat and are deliberately
left alone (#2318) — they record what those experiments knew when they ran.

**The old join wrote WRONG values, not just empty ones.** Post-fix re-run of the
same async spec: population 49.0% → 100.0%, and `trades.csv` cols 1-10 +
`equity_curve.csv` + `summary.sexp` + `actual.sexp` all **identical** (so the fix
is reporting-only, measured). But `exit_trigger` changed on **49** rows where
only **29** had been empty — with no position id the fallback took
`stop_first_by_symbol`, the first stop_info for that symbol regardless of round
trip, so repeat-traded symbols inherited the first trade's trigger and stops.
`stage3_force_exit` went **0 → 1**: an exit mechanism read as never firing purely
because its trades lost the join.

**→ Any prior analysis that grouped async-config trades by `exit_trigger` is
suspect, not merely incomplete** — including the "laggard rotation is a profit
channel" reading in `project_trade_forensics_2026_06_12` (laggard 72 → 89 on this
config, +24%). Recompute before citing. This is the top open analysis item.

## P0.2 payoff run: correctness PASS, but the motivation is NOT established

`dev/experiments/candidate-universe-payoff-2026-08-13/` (PR #2319). Top-3000 ×
2018-2023, one variable changed from the 302-symbol acceptance run.

| | baseline | fixture |
|---|---|---|
| universe | 3000 | **277** |
| wall | 1020s | 808s |

All six artefacts byte-identical — 2,723 dropped symbols changed nothing. The
soundness argument now holds at **10.8×** compression where the acceptance run
could only show 1.04×.

**But 10.8× fewer symbols bought 1.26× less wall time.** Universe size is not
what dominates scenario cost at this window: dropping 91% of the universe removed
21% of the work. Capture cost **3h09m** against **212s saved per re-run** →
**break-even ≈ 54 runs** on the same (window × config family). A one-off scenario
is a large net loss; a full ladder sweep (~72 runs) wins by ~25%.

So "makes per-mechanism scenarios affordable" — the builder's stated motivation —
is **not** established by this run. If that is the goal, **profile the 808s
floor**; do not shrink the universe further. Also note the baseline is 17 minutes,
not hours.

⚠ Does **not** generalise to 26y — only universe size was varied. Do not assume
the 21% carries.

## Open

- **Recompute async `exit_trigger` groupings** against post-fix runs (above).
  Highest-value open analysis item.
- **Profile the per-run cost floor** — what is the 808s actually spent on?
- **Report path** — `trade_audit_report.ml` / `optimal_run_artefacts.ml` read
  `trades.csv` back, hardcode `position_id = None`, and re-do their own symmetric
  7-day nearest-date scan, retaining the exact misattribution #2317 removed. In
  flight as `feat/report-path-position-id`; check whether it landed.
- **#12** DSR best-of-N = 24, not 13. **#14** base-extent anchor. **#8**
  blind-judge first run. **#15**, **#16**, **#10**, **#11**, **#6**.

## Process notes from this session

- **A dune process wedged three times** in `trading-1-dev` — alive at 0.01% CPU,
  holding memory, no progress. Once it blocked a feat-agent for 28 minutes. It is
  not purely the dead-pipe mode (it happened to a detached call with a file log
  too). Remedy: `kill -9`, remove `_build/.db` and `_build/.lock`, re-run. Watch
  for a long-running `dune` at ~0% CPU.
- **QC agents post issue comments instead of PR reviews.** `pr_gate_status.sh`
  reads only reviews, so the verdict silently does not register. Instruct
  explicitly: `gh pr review <N> --comment --body-file`, head the body
  `## qc-structural` / `## qc-behavioral`, and verify
  `gh pr view <N> --json reviews --jq '.reviews | length'` before finishing.
- **The PR body is squashed into main's commit message verbatim.** A stale claim
  in a body becomes a false statement in permanent history — fix the body before
  merging, not after. Caught twice this session.
- **`jj new` in the parent workspace deleted a running script's own directory**
  three hours into the payoff chain, failing its final `docker cp`. Artefacts were
  recovered from the container. `feedback_jj_new_wipes_long_running_outputs` warns
  about outputs written into the repo; this was the script's *own directory*
  vanishing mid-execution. Long chains should resolve host-side paths outside the
  repo, or capture them into variables before the first long step.
- **Disk:** local Time Machine snapshots held ~33 GB of already-deleted worktree
  space. `tmutil thinlocalsnapshots / 35000000000 1` reclaimed it (a TM
  destination is configured, so local snapshots are a cache).
