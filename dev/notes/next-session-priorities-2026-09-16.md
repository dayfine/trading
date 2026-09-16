# Next-session priorities — 2026-09-16 (supersedes 2026-09-15)

Written at the end of the autonomous 2026-09-15 session (00:08 PT 09-15 → ~04:00 PT 09-16). The 09-15 doc's P0 —
finish the PIT record band — is done; this doc carries what the band is, what it changed, and the queue.

## The record baseline is now the PIT band (PR #2843, three gates pending at write time)

| salt | return % | trades | Sharpe | maxDD % | V6 | wall |
|---|---:|---:|---:|---:|---|---|
| 0 | 457.01 | 732 | 0.482 | 40.64 | 0 | 5h58m |
| 1 | 188.05 | 766 | 0.329 | 53.05 | 0 | 6h30m |
| 2 | 152.03 | 762 | 0.297 | 51.32 | 0 | 7h05m |

**152 / 188 / 457 (s2/s1/s0), median 188; quote the band, never a salt.** Not comparable to the 2000-vintage
312 / 383 / 640 (construction + warehouse + path). Every arm from here pairs against `a0-pit-null-s{0,1,2}-v11`
at the same salt on `_v11pit` (9,364 entries), gated by `validator_diff -check V6`. Record:
`dev/experiments/pit-universe-2026-09-14/README.md` §4; ledger `2026-09-15-pit-universe-record-baseline`;
memory `project_record_rebase_2026_09_15`.

Two data findings on the way (both recorded, both open as issues):
- **A chunked `-incremental` build misses every cross-chunk rename twin** (233 legs on the 9.6k union; first cell V6 = 3).
  Fixed by six chunk-pair scans + one dedupe rebuild + list aliasing (README §3b addendum, `step4/twin-scan/`,
  `memory/project_pit_chunked_twin_miss`). Detector fix = **#2823** (`require_direct_match`, hub guard; `agent/claude`).
- **A PIT cell costs ~6.3 h** (union-wide weekly `_classify_all`). **#2839**: cut it bit-identically; membership pruning
  is rejected (user, 09-15) because it breaks prior-stage continuity.

## Merged this session

#2826 (Codex policy, reviewed inline), #2827 (§5.1 tier-3 write-back + harness count), #2828 (step-5 grid rule:
universe diversity = breadth tier of the same construction), #2829 / #2833 / #2838 (orchestrator daily records),
#2832 (interim handoff). Orchestrator cron landed #2830 / #2831 / #2834 / #2836 on its own.

## P0 for the next session

1. **Land #2843** — CI → qc-structural → qc-behavioral → merge (`sh dev/scripts/pr_gate_status.sh`). It is mixed
   (sexp fixtures + shell/perl scripts + docs), so both QC gates apply. If a QC agent objects to the 9.7 MB of
   lists: that was a user decision (09-15), cite it.
2. **Step 6 — one scheduled smoke golden in CI** so the `universe_schedule` seam is exercised end to end: the
   `panel-golden-2019-full` two-list arm in `test_universe_schedule_e2e.ml` is the fixture. Also pin the
   `(pi=true, sched=true)` truth-table row left open by #2816. `feat-backtest`, container-exclusive with #3.
3. **#2823 detector fix** (`feat-backtest` or `feat-data`; default-off knob so existing reports stay bit-identical).
   Cap 3 agents, one dune at a time.
4. **Top-of-funnel screen on the new band** — breakout-gate width and top-N (`project_monster_funnel_top_of_funnel`):
   `experiment-gap-closing`, **pre-register first** (arms, salts 0/1/2, criteria: realised AND Calmar vs the band at
   ≥ 2 of 3 salts; `validator_diff -check V6` on every pair). Budget ~6.3 h per cell, one lane: a 2-arm × 3-salt
   surface is ~38 h of container time — plan it as a chain with a file log and pinned worktree, and prefer
   dispatching #2839 first if a bit-identical speedup looks reachable.

## Codex queue (all `ready-for-agent` + `agent/codex`, triaged 09-15 evening)

| issue | P | what |
|---|---|---|
| #2837 | P2 | `pr_gate_status.sh`: make a QC verdict posted as an issue comment loud (`misposted`) instead of `none` |
| #2793 | P3 | unblocked — option 2 scoped small: `dev/scripts/codex_push.sh` (no args, pushes `HEAD:refs/heads/<codex/* branch>`), raw `git push` → prompt, rules probes, howto + AGENTS.md step 3 |
| #2835 | P3 | orchestrator prose: derive the prior-summary timestamp from `git log`, not mtime |
| #2702 | P3 | weekly-start-sweep step 7: curl REST instead of `gh` (may BLOCK on workflow scope) |
| #2634 | P3 | narrowed to the wiring half: run `scheduled_workflow_health.sh` in Step 6, fixed daily-summary section, verify gate |

#2394 stays `needs-info` (no config arms `min_rs_normalized`).

## Carried / small

- L6 taxonomy (R7 two-meaning: stop never placed vs breaker exit) — `dev/status/trade-audit.md` design item, not a book question.
- `.claude/rules` note: `gh pr review` takes `--body-file`; `-F body=@file` is the `gh api` form (memory updated; rules files carry no wrong form).
- Rule-4 hygiene, orchestrator D2 push, #2729 residuals: unchanged.

## Ops notes

- **One lane on `_v11pit`.** A single PIT worker sits at 5.5–6.5 GB; the container is 7.75 GB. `CELL_TIMEOUT=36000`.
- **Chunked builds need the pairwise twin scan before the first measured cell** (`step4/twin-scan/pair-scan.sh`: ~35 min
  per 5.2k-name pair, kill the build once `rename_twin_report.txt` exists). A full-union scan OOMs.
- Host state that is NOT in VCS and can be deleted once #2843 merges: `/tmp/pit-fetch/`, `/tmp/pit-run/`,
  `/tmp/twin-scan/` (incl. the as-run-lists tarball — now committed), container `/tmp/sweeps/pit-null/` (trade_audit +
  equity_curve per cell, 34 MB — the only copies), and the pinned worktree `.claude/worktrees/sweep-pit` (keep while any
  arm still needs `@3a20f4987`; main has moved only by docs/harness since).
- The warehouse `/tmp/snap_top3000_pit_v11pit` (3.5 GB, container) is the record's input — do not rebuild it without
  re-running the band; a rebuild is a new 3-salt band.
- The session ran 28 h across a date boundary with no rate-limit gap; the chain survived the `/clear`-ed prior
  session because it was `nohup`-detached.
