# Issue burn-down: 19 open → about 8 by 10-24, with a quota projection (2026-10-19)

User direction (10-19, 00:11 PT): *"Burn down the issue list with planning and delegation (with projected quota)."*
It was quiet hours, so the recommended options were taken; the user reviews them at 11:00.

## Budget

- **Quota at start:** week 26 % used, 6.0 days to reset. Management reserve 15 %, which leaves about 59 % for
  project work, or **about 9.8 %/day**. Readings: `dev/scripts/quota_status.sh`.
- **10-18 overspent** (about 16 % in one day), so this plan targets **about 8 %/day** and keeps the rest as slack.
- **Unit costs** (measured 10-09..10-18, `dev/budget/local-*.json`; ±50 %):

| unit | % of week |
|---|---:|
| qc-structural (Haiku) | ~0.3 |
| qc-behavioral / qc-results (Opus) | ~1–1.5 |
| feat / harness agent, small PR | ~2–4 |
| results-analyst reading | ~4–6 |
| Codex (local `codex exec`) or Jules writing | ~0: their quota, not ours. We pay only for the review |
| 26y backtest chain | ~0 model quota: container hours, plus about 1 % of dispatcher time |

## Lanes and order

| # | issue | lane | action | Claude quota | day |
|---|---|---|---|---:|---|
| 1 | #3217 screen: candidate-quality features | — | **close, not planned**. Priors: entry-shape and extension gates are no-build (`project_entry_shape_gates_no_build`, `project_extension_stop_screen_no_build`). Reopen if a new loser-cohort specimen class appears | 0 | 10-19 |
| 2 | #3216 universe `all_observed` | — | **close, not planned** until #3136's rebuild decision (it depends on #3136). Reopen trigger: that decision says rebuild | 0 | 10-19 |
| 3 | #3263 A-D fixture calendar (PR #3339, Codex) | Codex → Claude gates | structural, then behavioral QC, then merge; its [after-merge] macro-trace diff rides on chain V below | 1.5 | 10-19 |
| 4 | #3136 dollar-volume basis, P1 | feat agent (Claude) | [merge] items: one basis + a test with AMZN-2018 / C-2010 shapes; measure membership and gate flips per vintage. No rebuild yet | 4 + QC 2 | 10-19/20 |
| 5 | **chain V**: verifies #3266, #3173, #3174, #3138 (+ the #3263 trace) | local chain + results-analyst | one pre-registered 26y TR chain on the record N spec, details below. Closes up to 4 issues and the #3263 after-merge item | build 3, read 6, QC 1.5 | build 10-19, run 10-19/20 overnight, read 10-21 |
| 6 | #3109 split-detector default flip | local | the paired golden run for the default flip, with #3104 (sp500 goldens = pin purpose, allowed) | 1 | 10-21 |
| 7 | #3206 short-side margin cover | local, one salt | paired short-only run, flag on/off, counting the affected exits. Shorts track is idle, so run it only if it fits beside chain V; otherwise defer | 0.5 | 10-22 |
| 8 | #3183 symbol-class filter | Codex local | data-only: measured effect on per-vintage membership vs pit-v12 (a shell/awk count). No backtest | review 1.5 | 10-21 |
| 9 | #3140 review-pack cards | Codex local (part 1) | missed-winners card (HTML/awk), with tests in `review_pack_test.sh` | review 2 | 10-22 |
| 10 | #3239 vendor data scan | Codex local | the ≥ 50 % single-session move check + the v12 scan list; the HRC fix is decided after the list | review 2 | 10-22/23 |
| 11 | #3215 spin-off crediting | feat agent (Claude) | design note + BBWI test + data source; its paired 26y read joins a later chain | 5 + QC 2 | 10-23 |
| 12 | quota tapering + per-lane budget lines (no issue; user idea 10-18) | Jules | `quota_status.sh`: reserve × days_left/7, guard tapered, used-today line, Codex usage line | review 1.5 | 10-19 |
| 13 | devcontainer `init: true` (zombies, 10-18) | Codex local | one-line config + a note | review 0.5 | 10-20 |
| — | #2973 split corpus (size L) | next week | too large for this week's budget | 0 | — |
| — | #2803 orchestrator umbrella | keep | items are taken as they bite | 0 | — |
| — | #3145 (blocked, shorts idle), #3324 (user), #3330 (board, permanent) | keep | — | 0 | — |

**Projected Claude spend:** about 45 % of a week over 5 days (≈ 9 %/day, inside the 9.8 % allowance).
- The reading for chain V is the largest single item (about 6 %).
- If a day's reading shows SMALL, items 9–11 slip a day; nothing else moves.
- **Issues closed by 10-24 if all lands:** #3217, #3216, #3263, #3266, #3173, #3174, #3138, #3109, #3183 and,
  partly or fully, #3136, #3140, #3239, #3215. That is **19 → about 8**.

## Chain V (pre-registration summary; the full spec lands with the chain script)

- **Base:** the record N spec (rb1 + full NYSE A-D), 26y, total-return accounting, current main (includes #3266,
  #3173, #3174 fixes behind their flags), v12 warehouse, pinned worktree.
- **Arms:**
  - **M:** main defaults, salts 0–2. This verifies #3173: TDG/WING/BCH credited once. It verifies #3266: the delta
    vs the committed N, one salt is enough, so all three are reported. It also gives the #3263 macro-trace diff when
    run after #3339 merges.
  - **M+3138:** `entry_fill_size_to_available` on, salts 0–2. Pre-registered rule: expected about +0.09 log, with
    lower salt dispersion.
  - **M+3174:** the ex-dividend stop-adjustment flag on, salt 0. This is the axis read.
- **Cost:** 7 runs × about 2.5 h = **about 17 h of container time**, sequential, overnight 10-19→10-20 and
  10-20→10-21.
  - No agents run beside it (`container-capacity-scheduling.md`). QC waves go in the gaps between runs.
- **Gate:** V6 paired-read gate on every pair. The review pack is rendered and looked at for each arm, as for any
  26y run.

## Rules this plan runs under

- The 30-minute lane check and the #3330 board drive the Codex and Jules items.
- After 2 corrective rounds, the dispatcher finishes the task (`feedback_external_agent_briefs`).
- Daily: read `quota_status.sh` at session start; if `suggest` is SMALL, drop to items already in review.
- At the weekly slot (`perf-review-weekly.md` §Usage review), compare projection with actuals; record both.
