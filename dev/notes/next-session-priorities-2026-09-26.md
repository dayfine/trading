# Next-session priorities — 2026-09-26 (supersedes 2026-09-24)

Written ~21:10 PT 2026-09-26, while salt 2 of the obvious-fixes chain was running (week 1,196/1,434 at 20:54,
ETA ~22:05). Main green. Tonight's open branches were all written **without compiling** (container busy, user
09-26: "write all the PRs now, build when the backtest completes").

## State in one paragraph

The 26y walkthrough of `f2-fills-faithful-s0` (both fill fixes on; 132.78 % vs the null's 457.01 %, mostly
path divergence) produced issues #2973–#2977. Running those down found a **P0 stop defect (#2982)**: the
trailing-stop raise candidate is `min(raw correction low, ADJUSTED 30-wk MA)`
(`weinstein_stops.ml:276` via `stops_runner._compute_ma_and_stage`). On any name whose later splits or
dividends shrink its adjusted history, the candidate is the shrunken MA and the ratchet cannot fire: 0/73
trades held ≥ 13 wk raised at close/adj ≥ 1.5, vs 50 % at < 1.02. A 724-trade replay reproduces the run with
the adjusted MA (704/724), not with a consistent one (592/724), within every era. **Every stop-width /
stop-raise / exit-stack verdict so far was measured on that system.** The fix is not an obvious win: under
a consistent MA, 33 later-hit raises exit median +0.3 % / p10 −14 % vs actual — the accidental no-ratchet may
have protected the tail. It must be measured.

## Merged tonight

- #2979: salt-0 analysis + decision walkthrough + investor-preset queue (qc-results, one rework).
- #2980: `review_pack.sh --no-container` sed noise (#2978). Structural + behavioral QC ran **without dune** —
  CI authoritative, shell test on the host.

## P0 — build, gate and merge the five write-only branches (container free after salt 2)

All pushed to origin with no PR yet. Each has a jj workspace under `.claude/worktrees/jjws-*` and an
"Unverified — compile risks" list in the session transcript. Build **one at a time** in its workspace
(`docker exec … cd /workspaces/trading-1/.claude/worktrees/jjws-<name>/trading && dune build @fmt; dune fmt;
dune build && dune runtest`). Fix compile errors, verify goldens unchanged, open the PR, then QC in waves of ≤ 3
(structural first).

| branch | issue | what | watch |
|---|---|---|---|
| `feat/stop-decision-audit` (2 commits) | #2977 | per-position stop-decision record in `trade_audit.sexp` | early behavioral review done; `trade_audit.ml` at 299 lines; record size ~34k rows / ~10 MB, measure it |
| `feat/split-corpus` | #2973 | 7 real split windows + first cross-consumer suite; audit gains `adjusted_close_at_decision` | 45 files; `trade_audit.ml` exactly 300; `_entry_decision_of_event` exactly 50 lines |
| `fix/stop-raise-count` | #2974 | `n_stop_raises` off-by-one + silent tightening moves (log only) | `trades.csv` `entry_stop` / `exit_stop` / `max_stop` / `n_stop_raises` change; no golden pins them |
| `feat/suspend-tickets-bearish` | #2976 | `entry_ticket_macro_suspend` (Off / On_bearish_macro / On_index_stage4) | re-issued ticket gets a NEW position_id + no audit entry → carry or link the original; the "closed list of cancel reasons" docstrings go stale; ~1,100 lines |
| `feat/stop-basis-flags` (3 commits) | #2982 #2974 | `stop_ma_same_basis`, `correction_must_follow_peak`, `tightened_can_ratchet` + `tightened_min_reaction_pct` (reaction-low rule, user choice (a)) | `weinstein_stops.ml` at 492/500; `goldens-affected` may flag the 0.08 default as AFFECTS-ALL → paired run by hand + `paired-run-done` |

Expect rebase conflicts in `stops_runner.ml`, `trade_audit.ml{,i}` and `audit_recorder.ml{,i}`
(#2977 / #2973 / count-fix / stop-flags all touch them). Merge #2977 first.

## P1 — run queue after the merges

See `dev/experiments/investor-preset-2026-09-26/QUEUE.md` §"Run order after the 2026-09-26 code wave":

1. `f1-stoplimit-fresh` s0.
2. One chain: 5y investor preset vs hybrid (×3 salts) plus the 5y flag screen (items 9a–9e).
3. `stop_ma_same_basis` 26y × 3 salts, V6-paired.

Also: the obvious-fixes verdict PR (s0/s1/s2 + f1 per-arm `results/`, Fix A vs Fix B attribution); run
`perf_long_cells.sh update` on `/tmp/fixes-run/chain-A.log`.

## P2

- #2981 pause/resume investigation.
- #2984 live broker stop only on UpdateRiskParams — before any live wiring.
- #2408 is blocked by #2982.
- #2975 rename the audit's `suggested_stop` proxy.
- #2983 late-Stage-2 tighten never enforced (default-off dial).
- Walk the remaining years (2000–20, 2024–26) with `walk.sh`.

## Process notes from tonight

- **Write-only phase works.** Agents write + push with no dune while a backtest holds the container;
  an advisory no-dune behavioral pre-review on the draft caught 5 SHOULD-FIX items before any build.
- Agents in isolated worktrees cannot `jj git push` or Edit into `jjws-*`: they `git push <commit>:refs/heads/…`
  and `cp`. Run `jj bookmark track <b>@origin` before pushing from the dispatcher.
- `gh pr merge` refuses a PR that is BEHIND main (strict checks): `gh pr update-branch`, wait for CI, merge.
