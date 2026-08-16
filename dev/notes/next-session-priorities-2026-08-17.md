# Next-session priorities — 2026-08-17

**Supersedes** `next-session-priorities-2026-08-16.md`.

## Start here

1. `gh run list --branch main --workflow CI --limit 1` — main was green at the
   #2349 merge (`59b26c3bf`).
2. `sh dev/scripts/pr_gate_status.sh` — the gate loop is the default work item.
3. **`cat /tmp/ttl-retest-chain.log`** if the TTL re-test was launched.

---

## What the 08-16 session settled

Three of the five queued defects are **closed**, and one of them is closed by
being **refuted**. The queue that came into this session was ordered by a wrong
premise; the corrected order is in the status banner at the top of
`dev/plans/entry-anchor-and-ttl-2026-08-15.md`.

| | was | now |
|---|---|---|
| **F** (artifacts can't answer basic questions) | order 1 | **re-scoped and shipped** as G1, PR #2348 |
| **C + E** (one knob arms two mechanisms) | order 2 | **shipped**, PR #2349 (merged) |
| **A** (the entry anchor goes stale) | order 3, impact *high* | **REFUTED**, PR #2350 (merged) |
| **D** (the 4-week clock cuts the best band) | order 4 | specs ready, PR #2353; run pending |
| **B** ("prefer other candidates" as a rejection) | order 5 | **shipped**, PR #2352 |
| **G2/G3** (tickets destroyed on a cash shortfall) | — | **new**, plan written |

### The two findings that reordered everything

**1. A resting ticket that triggers into a cash-short book is destroyed, not
retried, and leaves no trace.** (`dev/notes/ticket-death-on-cash-2026-08-16.md`)
The AXTI ticket *did* trigger and the engine *did* fill it, at 2.7475 — inside
the 2.7642 do-not-chase cap. The portfolio then refused it (needed \$124,039, had
\$16,531) and the ticket was deleted. **~25% of would-be entries die this way** in
every universe and period tested, and `ticket_age_weeks_at_cancel` was written
**zero times per run**, so 26% of placements resolved to nothing in the artifact.
Shortfalls as small as **\$397 on \$138,244 (0.3%)** kill a ticket outright.

**2. The armed entry anchor cannot go stale, and the stop is what excludes the
crash-recovery cohort.** (`dev/notes/entry-anchor-defect-a-refuted-2026-08-16.md`)
At `entry_anchor_local_range_weeks = 4` the anchor is a 4-**bar** window, so it is
history-independent — verified bit-identical on `suggested_entry`,
`local_range_top`, `ma_value` and `installed_stop` between a 26-year and a
2.5-year run. AXTI's E is **2.71 everywhere**, and it is rejected **21×** by
`Stop_too_wide`. The 4.05 figure came from an arm with the knob at its `0`
default. The comparison was armed-vs-unarmed **config**, mislabelled as
long-vs-short **window**.

### And one verdict

**Nearfloor is NOT promoted.** The confirmation grid
(`dev/experiments/nearfloor-confirmation-grid-2026-08-16/results.md`) returns
**0 of 3 cells clearing their own null on return**; sp500 × 2000-2026 shows no
effect at all and top-3000 × 2010-2026 is a −69.2pp loss at 2× its null. The
transferable why: it is a **crash-depth dial, not a stop dial** — it pays only
where deep prior lows are common (broad universe) *and* crashes arrive
(bear-containing window), and is a plain fat-tail tax everywhere else. Keep as a
breadth-conditional preset axis; **do not retire the flag**.

---

## P0 — finish the TTL re-test (defect D)

Everything is staged; it needs a build and ~6 hours.

```sh
# the pinned worktree already exists at the #2349 merge commit
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/.claude/worktrees/sweep-ttl-retest/trading && eval $(opam env) && dune build'
sh /tmp/ttl-retest-run.sh          # resumes; skips any arm with a RESULT line
cat /tmp/ttl-retest-chain.log
```

Six arms, single salt each, specs in `/tmp/ttl-retest-specs` (and PR #2353).
**Read them against the 132.5pp null** from cell 00's three salts — nothing
smaller is interpretable at this scale. **Cell 00 is a tripwire, not a datum: it
must return 281.71 exactly**, or the binary moved and the comparison is void.

The two arms worth the run are the ones the knob split made expressible:
`01-rescreen-only` (the book-supported half alone, clock unbounded) and
`05-clock156-only` (the defect-E absurdity bound alone). The standing prior is
that the clock *number* is a free dial — ttl4 vs core was +0.5pp and ttl8 vs ttl4
was 35pp, both inside the null.

**No agents while it runs** (`container-capacity-scheduling.md`): a 26y top-3000
run holds ~2.2-2.4 GB for an hour, and an OOM kill is silent — `<no result>`, an
empty child log, no stack.

## P1 — the PR gate loop

`sh dev/scripts/pr_gate_status.sh`. Open at handoff: #2348 (behavioral pending),
#2352, #2353, plus the orchestrator's #2351 / #2339 / #2338.

⚠ **The scheduled orchestrator runs QC too**, and it collided with this session's
dispatches: three QC agents plus the cron run contended for one dune lock, and
the losing agent posted a **NEEDS_REWORK whose stated reason was "infrastructure
issue, NOT a code issue"** on a PR whose gates were green eight minutes earlier at
the same SHA. Before treating a NEEDS_REWORK as real, check whether it ran H2/H3
at all. Count the orchestrator's run against the 3-agent cap.

## P2 — G2/G3, once G1 has landed and the cohort is measured

`dev/plans/ticket-funding-2026-08-16.md`. Three *independent* axes, not one fix:
re-offer the order after a rejection; size to available cash; reserve at
placement. Order of operations matters — **measure the cohort from the artifact
first** (G1 makes that possible), because the top-line cannot resolve anything
under 132.5pp.

Prediction worth recording before the fact: the retry axis (G2a) is the one most
likely to fail, and for a known reason — it enters later and worse, and the
do-not-chase cap then refuses the retry, which is the entry-side fat-tail tax
`project_sim_entry_stoplimit_reject` already found.

## P3 — carried

- **Task 20** — pin the dissections as tests. Note the reframing: a
  `goldens-small` scenario **cannot** reproduce these decisions (a small universe
  changes ranking, sector RS and the macro gate — recorded in the diagnostic
  README). What is actually pinnable is the **unit-level** entry construction:
  AXTI's real bars → `local_range_top = 2.70` → `E = 2.71` → the width gate's
  verdict under each stop config. That needs a committed bar fixture, not a
  scenario.
- **#2349 review notes** — the `.mli` claims the re-screen's reason wins when
  both cancels would fire, and no test puts them in contention; 40 archived
  specs under `dev/experiments/` still name the retired `entry_order_ttl_weeks`
  and are now un-runnable (no build impact — decide migrate-vs-provenance and
  write it down).
- **#8** recompute async `exit_trigger` groupings against a post-fix run.
- **#10** the 808s per-run floor.
- **`stop_anchor_at_entry_base` deserves its own surface** — it is the one flag
  demonstrated to change AXTI's admission, `Nearest` alone does not, and it has
  never been run as an axis in its own right.

---

## Process notes from this session

- **A `grep -c SYMBOL trade_audit.sexp` counts alternatives_considered rows.**
  The 1/4/5 AXTI ticket table was that artifact; the real counts were 0/0/1, and
  the difference reversed which mechanism was doing the work. Count with
  `grep -c '(symbol X) (entry_date'`.
- **Before ranking an "X is stale/wrong" defect, ask whether the quantity is a
  function of the thing being varied.** A 4-bar window is not a function of run
  length, and that was knowable from the config before any run.
- **`jj` snapshots into `@` continuously**, so anything written after a push
  lands in the pushed commit. Do `jj new` immediately after every push, or plan
  on splitting commits by hand (done three times today).
- **Two structural reviews at the same SHA can disagree** when one of them could
  not run the build. The one that ran the gates wins; say so in a dispositioning
  comment rather than reworking.
