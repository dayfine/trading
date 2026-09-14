# Next-session priorities — 2026-09-14 (supersedes 2026-09-13)

Written 18:05 PT 2026-09-13 (autonomous 16:31–18:10 PT). The 09-13 doc's queue items 1–3 and 5–6 are resolved below; the
grid is complete.

## Merged this session

- **#2791** docs: item-4 grid interim (salt-0 pairs, `read.sh` `NULL=` override, handoff note). Docs + artifacts; squash-merged on green.
- **#2786** chore: `.codex/rules/trading.rules` project Codex command policy — rework iteration 1 by Codex addressed all four
  first-round items (jj / merge forbidden, review + api prompt, docker narrowed to `exec trading-1-dev`/inspect/stats/ps with
  stop/rm/kill/system forbidden, startup-loading smoke test in the howto). Verified every decision at the tip with
  `codex execpolicy check --rules … -- <cmd>` (21 probes; note zsh needs `${=c}` to word-split), posted structural + behavioral
  APPROVED, admin-merged (BEHIND, disjoint new files). Follow-up **#2793** (Codex queue, P3): bare `git push` allows `origin main`.
- **#2792** docs: deteriorating-gate ledger amendment closing **#2780** — classification → **REJECT-as-default-but-legitimate-axis**
  (the pre-registration's failure branch; Rule-4 do-not-revive needs every tested context, this was one period × one universe),
  UTHR 2020-12-02 is null-only at two salts not three (absent both arms at salt 0), calmar placeholders filled (gate 0.100 /
  0.133 / 0.105 vs null 0.163 / 0.168 / 0.183). `deteriorating_blocks_longs` is OFF the Rule-4 retirement worklist; do-not-revive
  is earned only by a second vintage cell failing both criteria. `memory/project_deteriorating_gate_reject` updated.

## The result that changes what comes next — the item-4 confirmation grid FAILS

`dev/experiments/cadence-12w-v10-2026-09-13/README.md` §"Confirmation-grid verdict"; ledger
`2026-09-13-stop-width-12pct-weekly-confirmation-grid` (verdict Reject); memory `project_cadence_12w_v10dedup_accept` (updated).

| cell | realised null → arm | maxDD null → arm | maxDD episode null → arm |
|---|---:|---|---|
| 2019 s0 | $469k → $166k | 22.6 → 30.9 | Covid crash 2020-02/03 → 2021-05 … 2023-10 grind |
| 2019 s1 | $258k → $207k | 22.5 → 31.1 | same |
| 2009 s0 | $106k → −$23k | 17.9 → 27.1 | 2011-04 … 2012-11 → 2010-04 … 2012-06 |
| 2009 s1 | $277k → $10k | 20.4 → 25.2 | 2011-05 … 2012-08 → 2010-04 … 2012-06 |

Both 5y cells fail both pre-registered criteria at two of three salts, so the grid cannot clear regardless of salt 2.
**12%-weekly keeps its 26y single-surface ACCEPT and stays a default-off axis; it is not promotable.** Why: the
shared-trades-run-wider term is positive in every cell; the path re-draw and the drawdown *episode* flip the sign — the wide
arm's maxDD is a slow grind (2021–23, 2010–12), the null's is a fast crash. Wide-weekly wins fast-crash-then-recovery tapes
(the 26y composition) and loses grinds. Same lesson as the 05-30 early-admission grid.

Consequences: no promotion PR, no two-knob goldens, **no 10%-weekly neighbour arm** (same plateau, directional reversal).
**Item 3 cancel-on-Bearish = no build for now**: the mechanism already exists as the macro half of
`enable_entry_ticket_rescreen` (rejected 08-18 for its stage-wobble half), a Bearish-only flag would be new — but the
Bearish-week-fill cohort is *positive* on the record convention (+$0.12/+$0.22/+$0.19M per salt) and only negative on the
wide arm. Brief kept at the bottom of this doc's §"Parked briefs" in case a wide preset returns.

**Item 2 (force-liquidation dissection) settled** — README §"Force-liquidation dissection": every event is the 25%
`Per_position` breaker labelled `stop_loss` (the carried label bug); six of seven are real one-day earnings gaps through the
12% stop (ATLC 2000-10, AWRE 2014-07, ARCB 2014-07, CBKCQ 2014-10, IMMR 2018-08, OSPN 2020-08); one phantom, **SGP_old1**
stub prints 2010-09-20/21/23 on a series that should end at the 2009-11 Merck merger (−$60k/salt, all salts + the 2009-s0 5y
arm; already in `splice-scan.csv`). Data fix = truncate `SGP_old1` at the merger in the next warehouse rebuild (#2782 family).

**Item 6 screen** (README §"Item-6 screen"): `long_top_n_admitted` = 20 every week through spring 2020 while 1–3 entries fill
per week — the sizing cap (0.14 × 0.70 = five slots) binds, not admission. A Recovering-week ramp is a regime-conditioned
concentration knob (`project_capacity_concentration_surface`), not an admission mechanism; screen the cohort's paired P&L at
wider caps before building anything.

## Grid state — COMPLETE (both lanes DONE 17:55 PT)

All twelve cells ran; salt-2 pairs confirm both 5y cells at three of three salts (2019 s2: $245k → $213k, 22.8 → 31.2; 2009 s2:
$77k → −$12k, 17.1 → 25.4). Artifacts committed under `cadence-12w-v10-2026-09-13/results/`; README log + ledger `variants` hold
all twelve. Pinned worktree `sweep-detgate` removed; lane monitors stopped. Nothing to pick up.

## Codex integration state

- `AGENTS.md` + `.codex/rules/trading.rules` on main. Codex claimed **#2788** at 15:43 PT and pushed
  `codex/2788-behavioral-tools` (no PR yet at 17:30 PT) — do not duplicate; run the gate loop when the PR appears.
- **#2785** (review howto, draft) still waits on #2788 landing, then the "docs-only PRs skip the build gate" line + Codex's
  second look. Queue after #2788: #2653, #2753, #2793 (new), then P3 #2539 / #2742 / #2639 / #2394.
- `pr_gate_status.sh` classifies experiment `.sexp`/`.csv` artifacts and ledger entries as full-three-gate (its comment says
  so deliberately); the repo practice since #2776/#2783 is admin-merge on green for experiment-record PRs. #2792 got
  dispatcher-side structural + behavioral reviews (fact-checked against the artifacts) to satisfy the script. **Decide and
  write down one rule** — either widen the docs-only allowlist to `dev/experiments/**/results/*` + `dev/experiments/_ledger/*`
  (with the ledger linter as the gate) or stop admin-merging records — and fix the script or the practice accordingly.

## Queue (in order)

1. **Finish the grid bands** (Live above) → salt-2 rows → PR the grid docs commit → merge.
2. **Rule-4 / axis hygiene**: nothing retires (deteriorating gate is keep-axis; 12%-weekly is an ACCEPT-but-not-promoted
   axis). Record in `dev/notes/mechanism-flag-inventory-*.md` if that file is refreshed.
3. **Entry side is the gap** (`project_exit_stack_survives_fixed_basis`, `project_monster_funnel_top_of_funnel`): 87% of
   monsters die at the breakout gate + top-N. The item-6 screen says deployment is slot-bound in recoveries. Next screen:
   paired P&L of the Recovering-week cohort at `max_position_pct_long ∈ {0.14, 0.20, 0.25}` × `max_long_exposure_pct ∈ {0.70,
   0.85}` on the 26y record (3 salts, V6 gate) — a surface, not a flag; `experiment-gap-closing` skill.
4. **`stop_loss` label hides the `Per_position` breaker** (carried; now measured: 5–6 mislabelled exits per wide cell, 2–3 per
   null cell). Root cause read 09-13: `force_liquidation_runner.ml` `_transition_of_event` emits `Position.StopLoss` on purpose
   and its comment says the distinction is "recorded separately"; `force_liquidation_log.mli` claims the events post-process
   trades.csv's `exit_trigger`, but the only consumers (`result_writer.ml`, `runner.ml`) persist the events — no relabel exists.
   Fix (weinstein tier, no core-module change): emit `Position.StrategySignal { label = "force_liquidation"; detail = Some
   "per_position" / "portfolio_floor" }` so `Stop_log.exit_trigger_of_reason` surfaces it exactly like `stage3_force_exit`;
   correct both docstrings; pin with a sim-level test (position down > 25% → `exit_trigger` = `force_liquidation`, and the
   breaker's P&L unchanged). Check whether any golden compares the trades.csv trigger column (metrics are unaffected);
   `read.sh`'s exit-mix table already lists the token. feat-backtest, small.
5. **SGP_old1 truncation** + the #2782 spin-off twins before the next warehouse rebuild (ops-data).
6. Carried: orchestrator D2 push (09-10 item 5); #2729 residuals; #2785.

## Ops notes

- Two grid lane monitors may still be listed in `/tasks` (one from the previous session, one from this one); stop both after
  `LANE .. DONE`.
- `read.sh` lives on main with the `NULL=` override; a working copy branched before #2791 lacks it — use
  `git show origin/main:dev/experiments/deteriorating-gate-2026-09-13/read.sh`.
- Equity curves are not copied by `chain-grid.sh`; they sit in the container run dirs
  (`sweep-detgate/trading/dev/backtest/scenarios-<ts>/<name>/equity_curve.csv`) — that is where the maxDD episode dates came
  from. Worth adding `equity_curve.csv` to the chain's copy list.
- `gh api …/reviews` needs the **full** 40-char `commit_id`; a short SHA returns 422 "Variable $commitOID … invalid value".
- Memory index trimmed under its 24.4 KB limit (was cutting four lines).

## Parked briefs

- **`cancel_resting_longs_on_bearish`** (item 3, no-build): scratch brief content — new `Weinstein_strategy_config` bool
  `[@sexp.default false]`; read site `weinstein_strategy_screening.ml` `_run_entry_ticket_ttl` → extend
  `Entry_ticket_ttl.cancellations/run` with a macro-only predicate (reuse `_macro_admits_side`), longs only, unfilled
  `Entering` only, precedence rescreen > macro > clock; new token `entry_ticket_macro_gate_closed` added to
  `test_cancel_reason_closed_list.ml` and the `cancel_handler.mli` token list; flag-off bit-identical; unit + sim-level
  tests modelled on `test_delisted_ticket_cancel_sim.ml`; W2 = book §Macro (suspend buying on a bearish tape).
