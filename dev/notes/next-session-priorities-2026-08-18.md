# Next-session priorities — 2026-08-18

**Supersedes** `next-session-priorities-2026-08-17.md` (which was written before
the 08-16 session's own results landed, and before a 44-hour stall).

## Start here — in this order

1. **`cat /tmp/ttl-retest-chain.log`** — a 4-run chain was launched 2026-08-17
   21:45 PDT and was still running at hand-off. It is `nohup`'d and survives the
   session boundary. **Read the first RESULT line before anything else** (below).
2. `gh run list --branch main --workflow CI --limit 1` — main was green at
   `7b6b63e2e`.
3. `sh dev/scripts/pr_gate_status.sh` — #2368 and #2369 were open at hand-off.

---

## ⚠ Read this before trusting the wall clock

**A single un-allowlisted Bash command stalled the previous run for ~44 hours**
(2026-08-16 01:50 → 2026-08-17 21:45 PDT). Nothing executed in that window; only
the GHA cron made progress, merging 8 PRs including two follow-ups to my own
work. The stall is **invisible from inside the session** — nothing distinguishes
"the last command took 44 hours" from "the last command just finished".

- `.claude/settings.local.json` now allowlists `gh`, `docker` (beyond `exec`),
  `cd`, the read-only shell toolkit, `cp`/`mv`, and `dev/scripts/…` — PR #2369.
  `rm` is scoped to `.claude/worktrees/…` and `/tmp/…`; script execution to
  `/tmp/…` and `dev/scripts/…`. Nothing blanket.
- **At ramp-up, cross-check the clock against external state:**
  `git log --date=format:'%m-%d %H:%M' --pretty='%ad %h %s' -8 origin/main`
  against your own last merge. If the cron moved main by a day and you have no
  record of it, you were asleep.

---

## P0 — the TTL re-test chain (finish, then read)

```sh
cat /tmp/ttl-retest-chain.log      # progress + results
pgrep -f ttl-retest-run.sh         # alive?
sh /tmp/ttl-retest-run.sh          # resume — skips any arm with a RESULT line
```

Four runs, ~1h each, from pinned worktree `.claude/worktrees/sweep-ttl-retest`
at `59b26c3bf`. Specs in `/tmp/ttl-retest-specs/` (committed copy in
`dev/experiments/ttl-retest-2026-08-16/specs/`, chain script also committed as
that directory's `run.sh`).

| # | arm | rescreen | clock | salt |
|---|---|---|---|---|
| 1 | `00-null` | false | 0 | 0 |
| 2-4 | `01-rescreen-only` | true | 0 | 0, 1, 2 |

**Run 1 is a tripwire, not a datum.** The default path is untouched by #2348 /
#2349, and runs are deterministic post-#2279, so it must return **281.71**
exactly. **Any other value voids the whole comparison** — the null being
borrowed from the 08-14 seeded run only holds if the binary reproduces it. Stop
and diagnose rather than reading the rescreen arms.

**Then compare the three rescreen draws against cell 00's own three:
265.44 / 281.71 / 397.95** (mean 315.0, spread **132.5pp**). Read it as a
distribution, not a mean — three draws is not power. The question is whether the
rescreen draws *separate* from the null's, the way nearfloor's trade count and
maxDD did and its return did not.

The chain also logs `rejected_fills=N` per arm (the ~25% silent ticket-death
population), which is worth recording even though nothing acts on it yet.

### Why only 4 arms, not the 6 committed

Both reasons are in `dev/experiments/ttl-retest-2026-08-16/README.md` and PR
#2368, and one of them **refutes a premise in the plan**:

- Re-derived the motivating rest-time table on cell 00's own 1,145 filled
  tickets. The **5-13 week profit band confirms** (1,596,587 on 136 trades), so
  the `{13, 26, 52}` axis is right. But the **>3yr bucket is +304,101 here**
  (25 trades, +12,164/trade — second-highest per-trade in the run) against cell
  13's −154,006 "upside-free". So **defect E's premise is cell-specific**, and a
  156-week bound would cut a *profitable* population on this base. The
  loss-maker here is the **1-3yr** bucket (−220,314).
- Every clock value's gross effect is **8-30pp against a 132.5pp null** — 4-13×
  below the noise floor. Four arms could not have returned an interpretable
  number in either direction.

The clock specs stay committed and runnable. What would resolve them is a
**different metric** — per-bucket realized P&L on the arm's own trades — not the
top line. Also still missing: the composite `(rescreen = true, clock = 156)`,
which is the value `weinstein_strategy_config.mli` says the defect-D re-test must
qualify; given the table above, `(true, 52)` may be more interesting (it cuts the
−220,314 1-3yr bucket while keeping the +304,101 tail).

## P1 — close out the two open PRs

- **#2368** (docs: the narrowing above) — needs gates. It adds `.sexp` + `run.sh`
  under `dev/experiments/`, so not docs-only under `pr-merge-gates.md`.
- **#2369** (the allowlist + memory snapshot) — config + docs.

⚠ **The scheduled orchestrator runs QC too**, and it collided with the 08-16
dispatches: three QC agents plus the cron contending for one dune lock produced a
`NEEDS_REWORK` whose own stated reason was *"infrastructure issue, NOT a code
issue"*, on a PR green at the same SHA eight minutes earlier. Count the cron
against the 3-agent cap, and check whether a `NEEDS_REWORK` actually ran H2/H3
before treating it as real.

## P2 — the queue the 08-16 session left

- **G2/G3** — `dev/plans/ticket-funding-2026-08-16.md`. A triggered ticket the
  book cannot fund is destroyed, not retried; **~25% of would-be entries**, and a
  **\$397 (0.3%)** shortfall is enough. Three independent axes (re-offer /
  size-to-available / reserve-at-placement). **Measure the cohort from the
  artifact first** — G1 (#2348) made that possible — because the top line cannot
  resolve anything under 132.5pp. Recorded prediction: the retry axis is the one
  most likely to fail, and for a known reason.
- **Make the demoted-wide cohort greppable** before `Demote_over_max` (#2352) is
  swept. Today a wide-but-under-ceiling entry traces as `"Pass"` with
  `sized_down_wide_stop = false`, so the population is unattributable in the
  audit. Needs a third trace outcome or an audit field — a schema decision.
- **`stop_anchor_at_entry_base` deserves its own surface.** It is the one flag
  demonstrated to change AXTI's admission; `Nearest` alone does not, and
  `Nearest` just failed its promotion grid 0-of-3.
- **Task 20** — pin the dissections as tests. Note the reframing: a
  `goldens-small` scenario **cannot** reproduce these decisions (a small universe
  changes ranking, sector RS and the macro gate). What is pinnable is the
  **unit-level** entry construction: AXTI's real bars → `local_range_top = 2.70`
  → `E = 2.71` → the width gate's verdict under each stop config. Needs a
  committed bar fixture, not a scenario.
- **#8** recompute async `exit_trigger` groupings post-fix. **#10** the 808s
  per-run floor.

## What the 08-16 session settled (all merged)

| | |
|---|---|
| **#2346** | nearfloor confirmation grid — **0 of 3 cells** clear their own null → **not promoted**. It is a *crash-depth dial*, not a stop dial: it pays only on broad universe × bear-containing window. Keep as a breadth-preset axis; **do not retire the flag**. |
| **#2348** | G1 — portfolio-rejected tickets now resolve in `trade_audit.sexp` (`cancel_reason` + age). Previously **zero** cancels recorded per run, 26% of placements unaccounted. |
| **#2349** | C+E — the TTL knob split into `enable_entry_ticket_rescreen` + `entry_order_max_rest_weeks`; 24 specs migrated behaviour-preservingly. |
| **#2350** | **A refuted** — the armed 4-week anchor is a 4-*bar* window and history-independent (bit-identical across 26y and 2.5y runs). AXTI's E is 2.71 everywhere; it is rejected **21×** by the **stop-width gate**. The 4.05 figure was an unarmed-anchor arm. |
| **#2352** | B — `Demote_over_max`, §5.1 as a rank demotion. Default-off. |
| **#2355** | TTL cancel precedence pinned + 40 archived specs migrated (`dev/experiments/MIGRATIONS.md`). |
| **#2357**, **#2364**, **#2365** | docstring corrections + the cancel-reason closed-list test (the last two were the cron's). |

## Process notes worth keeping

- **A `grep -c SYMBOL trade_audit.sexp` counts `alternatives_considered` rows.**
  The AXTI "1/4/5 tickets" table was that artifact; real counts were 0/0/1, and
  the difference reversed which mechanism was doing the work.
- **Before ranking an "X is stale/wrong" defect, ask whether the quantity is a
  function of the thing being varied.** A 4-bar window is not a function of run
  length, and that was knowable from the config before any run.
- **Convert a motivating table into a predicted effect size and compare it to
  the null before spending hours on it.** That check killed 4 of 6 arms here and
  refuted a plan premise on the way.
- **`jj` snapshots into `@` continuously**, so anything written after a push
  lands in the pushed commit. `jj new` immediately after every push, or plan on
  splitting commits by hand (done three times on 08-16).
