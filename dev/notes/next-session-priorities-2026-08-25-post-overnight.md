# Next-session priorities — 2026-08-25 post-overnight (~06:15 PT handoff)

Supersedes `next-session-priorities-2026-08-25.md`. The overnight autonomous
session (23:40 PT → 06:15 PT) executed the burn-down directive. **Eight PRs
merged, four issues closed, three filed. Main green throughout; zero open
non-ops PRs at handoff.**

## What shipped overnight

| PR | What | Issue |
|---|---|---|
| #2534 | handoff doc | — |
| #2535 | record-baseline spec header + README fixes (#2532 findings ⑥⑦) | — |
| #2536 | goldens_affected_check blind spots: whole-weinstein-subtree surface, default-record-literal extraction (Step 2b), embedding-field emission (Step 2c) — replay of the real #2530 diff now FAILs, including via the embeds path against pre-#2532 golden text | closed #2531 |
| #2538 | weinstein-2019-top-500 re-pinned ±15% at the book-faithful stops basis (fewer-trades/longer-holds signature, matches record-baseline shifts); verified 3× independently, digit-identical | part of #2403 |
| #2540 | golden↔live drift linter (`golden_drift`) + `deviates_from_live` declarations in 12 goldens. **Census: 196 deviations / 24 knobs; 15 of 24 drift identically in all 12 specs.** Reasons mandatory (enforced). 1 QC rework iteration | #2403 structural half |
| #2542 | simulator.ml rejection-tail extraction to Cancel_handler (cron-built; pure move, mutation-verified) | closed #2524 |
| #2544 | stale-comment repairs after #2542 (cron-built) | — |
| #2541 | trades.csv incremental streaming for crash salvage (cron-built; 1 QC rework iteration — batch-order/cadence-parity/raise-path tests added, mutation-verified) | closed #2502 |
| #2543 | workflow run:-block shellcheck linter + Dockerfile shellcheck + 9 mechanical workflow fixes. 2 QC rework iterations — **honest scope**: catches SC2030/31 pipeline-subshell class; provably does NOT catch the exact ce88954 command-substitution shape (probe-verified; known-gap fixture pins the non-detection) | #2521 partially — **left open** for the residual class; #2539 tracks excluded SC codes |

## Issues filed

- **#2537** — golden-runs-sp500-15y: both 15y strategy cells time out at
  4200s/12.4GB on every completed run (pre-dates the basis flip). Re-pinning
  those goldens AND the 15y soak-flip are blocked on this.
- **#2547** — golden-runs-custom-universe is **flaky in GHA** (same-SHA rerun
  flipped FAIL→PASS; local repro digit-identical PASS), and per-cell logs are
  not uploaded so soak failures are undiagnosable. Asks: artifact upload
  (cheap, high value), flake tracking, and **do not flip continue-on-error
  until flake rate is understood**.
- **#2539** — (from #2543) excluded SC codes burn-down.

## State of #2403 (the P1)

- Structural half DONE (#2540). Custom-universe re-pin DONE (#2538) and the
  soak has been observed green at the new pin (3 of 5 post-re-pin runs; the 2
  FAILs adjudicated as GHA flakes per #2547).
- Remaining: shared live-base include (collapses ~200 lines of repeated
  declarations — follow-up per #2540's decision items), historical re-pins
  (blocked on #2537), soak flips (custom gated on #2547 flake understanding;
  15y gated on #2537), and the #2404 entry_extension_max_pct value unification
  (USER decision; measurement says move live 15.0 → 2.0).

## Burn-down queue (remaining, in order)

1. **#2405 (P3/S)** re-flip entry_order_max_rest_weeks→26 — its gate
   ("goldens re-pinned to live-tracking baselines") is now substantially met
   for the PR-visible + custom surfaces; the goldens_affected_check will
   correctly FAIL on the flip and demand the paired-run table (that is the
   process working). Cite the clock26 ledger entry.
2. **#2547 ask 1** — per-cell artifact upload in golden-runs-*.yml (small,
   makes every future soak failure diagnosable; also serves #2537 diagnosis).
3. **#2394 (P3/S)** long cascade RS phase in diagnostics (serves #2533).
4. **#2533 (P3/M)** per-drop sub-reason inside Dropped_at_breakout.
5. **#2380 (P3/S)** RS-trend Rule-4 retirement proposal (classify
   do-not-revive vs keep-as-axis FIRST).
6. **#2537** 15y golden timeout (profile vs raise timeout — needs a local run
   of the 2010-2026 cells to get real walltime + actual.sexp).
7. P4s: #2407, #2409, #2006; #1729 (P3/L data) as capacity allows.

**ASKABLE now (user):** #2489 carries the deferred §2.2/arc reclassification
decision — its 1-3 preconditions are done; the issue was kept open solely as
that decision's carrier.

## Operational notes

- QC-loop friction fixed en route: reviews MUST be posted via
  `gh pr review N --comment --body-file <file-in-worktree>` (issue comments
  are invisible to `pr_gate_status.sh`; `-F body=@` is api-only syntax; the
  scratchpad path is unreadable to gh from dispatched worktrees). Two agents
  hit the background-wait stall and were resumed via SendMessage; one review
  had to be re-posted dispatcher-side.
- Killed 4 orphaned dune processes (10h+ old, deleted-worktree cwds).
  `pairs-run` + `sweep-instr-0823` worktrees removed as planned.
- Cron slots ran normally at 00:17/05:17 and picked disjoint items
  (#2502/#2524 as #2541/#2542); local fences on #2403/#2521 held.
