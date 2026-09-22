# Next-session priorities — 2026-09-23 (supersedes 2026-09-22)

Written ~12:30 PT 2026-09-22 at the end of the 09-21/22 autonomous session. Main green. **Container idle** (lane A finished
09:53 PT; `sweep-funnel` worktree, `/tmp/funnel-run` and the 945 MB `candidates.sexp` removed; `/tmp/sweeps/top-of-funnel`
kept, 70 MB). Open PR: **#2906** (results-only QC lane) — MERGED 12:36 PT (`76ea296f4`); #2902 closed; nothing open.

## State in one paragraph

The **top-N capacity arm is done: ACCEPT(mechanism) by the pre-registered rule, NOT promotable** (#2900 merged, ledger
`2026-09-22-top-of-funnel-capacity.sexp`, memory `project_top_n_capacity_verdict`). Two of three salts clear realised AND
Calmar (s0 237 vs 457 % fail; s1 304 vs 188 clear; s2 330 vs 152 clear), but the level is a salt lottery on both sides — the
arm-only cohort is the same size every salt (~36 % of the book) and flips sign with which draw holds the year's monsters
(2020 + 2025 in the null at s0, ECHO in the arm at s1). The one plausible robust property is dispersion (arm 237–330 % vs
null 152–457 %, maxDD 43.8–44.7 vs 40.6–53.0; n = 3). **Mechanism: the leak is slot policy, not screener capacity** — d0
shows the cap binds in 99.1 % of weeks, yet ~5 slots fill ~28 entries/yr, and 46 % of the arm's extra entries were names
the null had admitted and never filled. Default `max_buy_candidates` stays 20. Harness this session: perf tiers timed
the all-eligible diagnostic (#2894; nightly walls −82 %, logged), usage cuts (#2902: rampup compact-at-150k rule,
behavioral brief scoping, results-only lane #2906), Codex review budget + A/B log (#2907), Codex shipped #2908/#2909.

## P0 — nothing blocking. Pick one of the P1s.

## P1 — next work, in order

1. **Slot-fill ordering screen (the transferable why of #2900).** When the admitted list exceeds the open slots, what
   fills first is whichever resting order triggers first, alphabetical among score ties (`project_screener_alphabetical_tiebreak`).
   Pre-register a screener-ordering dial (score → RS → volume ratio; book spine item 7 supports RS for selection) as a
   default-off config field + `Variant_matrix` axis (`experiment-flag-discipline.md` R1/R2), then a 3-salt PIT-band arm
   against `a0-pit-null-s{0,1,2}-v11`. Rule: realised AND Calmar at ≥ 2/3 salts, AND the arm-only cohort must not be a
   pure re-draw (pin the mechanism read: share of arm-only entries that were null-admitted-never-filled must FALL).
   Chain template: `top-of-funnel-2026-09-21/chain-funnel.sh` (cap 12,000, guard 60,000 s sized from 4h48m cells).
   Read with `paired.sh` + `join.awk` (needs a d0-style `--emit-candidates` cell for the null — 7h25m / 7.6 GB, run it
   as its own cell, never on a verdict cell).
2. **Top-N confirmation grid, only if someone wants the dispersion claim tested** (`promotion-confirmation.md`):
   {30, 40, 60} × a 2019–2025 sub-window on the same schedule × a top-1000 schedule cell; promote a value only if the
   tighter salt band holds in ≥ 2 of 3 cells. Level gains are not the criterion. Cheaper than (1); lower value.
3. **Perf weekly follow-through** (`perf-review-weekly.md`, ~2 h, Monday): read the 09-28 `perf-weekly` table (the 09-21
   run was pre-#2894) — the 15y sp500 cells should read ~364–408 s; **close #2895** on PASS; log it in
   `dev/status/backtest-perf.md`. Then #2896 (PIT-warehouse smoke cell, local-only). Nightly 09-22 baselines are logged.
4. **#2915** (SPY bars end 2026-05-01 → weekly-start sweep CAGRs annualize over dead calendar) — queued for Codex.
5. **PIT warehouse rebuild with #2862's twin guards** — unchanged from 09-22, operational.

## Codex queue

Codex ran a cycle overnight and shipped #2908 (#2886) and #2909 (#2899); #2847 closed too. Queued: **#2915** (P2). Candidate
after that: `build_snapshots -twin-only`.

## Ops notes — read these

- **The GHA orchestrator (`claude[bot]`) is live and double-dispatches on local PRs.** On 09-22 it reviewed, reworked
  (iteration 1 on #2907, which broke CI) and merged (#2908, #2914-class) while local QC agents were on the same PRs.
  Before dispatching QC locally, `gh api repos/dayfine/trading/pulls/<N>/reviews` — if a review landed in the last
  ~30 min that is not yours, wait for the orchestrator's loop rather than double-running (`gha-local-coordination.md`).
- **A same-tip re-review never clears a NEEDS_REWORK**: rework-then-approve at one SHA reads `unclear`, terminal in
  `pr_gate_status.sh`. Decide BEFORE dispatching: tip-moving commit (re-run both gates) or `--admin` with an adjudication
  comment (done for #2900's body-only CP2). `feedback_qc_false_positive_needs_tip_move`.
- **"no checks" on a fresh push = check `mergeStateStatus` first.** DIRTY (merge conflict) creates no pull_request run;
  re-pushing SHAs is inert. `jj rebase -b <bookmark> -d main@origin`, resolve EVERY commit in the branch (a resolved tip
  over a conflicted parent is refused by `jj git push`), push.
- **`jj new` immediately after every push.** Writing before it snapshots into the previous commit and `jj describe`
  overwrites that message (bookmark "moves sideways") — happened once on #2900, recovered with a combined message.
- **Results-only lane (#2906, once merged):** `pr_gate_status.sh` routes `dev/experiments/`-only PRs to one gate,
  `qc-results` (`.claude/agents/qc-results.md`, no dune); NEXT-ACTION `dispatch qc-results`. Use it for the next
  experiment PR instead of the pair.
- **Codex sampling is on by default** (#2907): `codex_review.sh <PR>` reviews only 25 % of tips (deterministic) and ≤ 3/day;
  `--force` or `review/codex-*` labels bypass. At MERGE of a sampled PR run `codex_agreement_row.sh <PR> --append`.
- Host free 34 GB, Docker.raw 31 GB. 58 stale `worktree-agent-*` local branches remain harmless.
