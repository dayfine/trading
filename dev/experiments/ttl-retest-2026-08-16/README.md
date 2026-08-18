# TTL re-test — defect D, redesigned after checking the motivating table

Defect **D** of `dev/plans/entry-anchor-and-ttl-2026-08-15.md`, on the ladder-v4
cell-00 base (top-3000 × 2000-2026), using the two F2 fields PR #2349 split
apart.

> **The original 6-arm design in this directory is not what runs.** Two checks
> prompted by qc-behavioral on #2353 changed it: the motivating rest-time table
> does not transfer to this base, and — decisively — **every clock arm's
> predicted effect is an order of magnitude below the null**, so four of the six
> arms could not have answered anything. The specs are all committed; only the
> chain's arm list narrowed.

## What the motivating table said, and what this base actually says

The plan's rest-time table is from **cell 13** (`Range_top_breakout` + `Nearest`,
953 trades). Rest time is directly downstream of the entry-anchor basis, so it
was worth checking against the base the re-test actually runs. Cell 00's own
1,145 filled tickets, joined `position_id` → `ticket_age_weeks_at_fill` →
`pnl_dollars`:

| bucket | n | realized pnl | pnl/trade |
|---|---:|---:|---:|
| wk 0-1 (≤14d) | 696 | 679,738 | 977 |
| wk 2-4 (15-35d) | 167 | **−201,330** | −1,206 |
| **wk 5-13 (36-98d)** | 136 | **1,596,587** | **11,740** |
| wk 14-26 | 58 | 3,254 | 56 |
| wk 27-52 | 29 | 11,622 | 401 |
| wk 53-156 (1-3y) | 35 | **−220,314** | −6,295 |
| **wk >156 (>3y)** | 25 | **+304,101** | **+12,164** |

**Confirmed:** the 5-13-week band is the profit band on this base too — 1.60M on
136 trades at 11,740 each — and a 4-week clock cuts it entirely. The `{13, 26,
52}` axis is right.

**~~Refuted:~~ WITHDRAWN 2026-08-18 — the per-bucket P&L above is a mis-join.**

The table was built over a **pre-#2317 artifact**, whose
`ticket_age_weeks_at_fill` can only read 0 or 1 (the 7-day date-proximity
reach-back), so its ages must have come from a symbol/date match instead — which
mis-pairs whenever one symbol carries more than one ticket.

Re-measured on `ttl-retest-00-null`, the same config on the same base but a
**post-#2317 tree**, joined on `position_id` (1,147 of 1,147 round trips
joined, max fill age 865 weeks):

| bucket | n here | P&L here | n above | P&L above |
|---|---:|---:|---:|---:|
| ≤1wk | 698 | +1,710,291 | 696 | +679,738 |
| 2–4wk | 166 | −149,906 | 167 | −201,330 |
| 5–13wk | 136 | +1,021,434 | 136 | +1,596,587 |
| 14–26wk | 58 | +82,266 | 58 | +3,254 |
| 27–52wk | 29 | −148,226 | 29 | +11,622 |
| 1–3yr | 35 | +16,612 | 35 | −220,314 |
| **>3yr** | 25 | **−217,518** | 25 | **+304,101** |

The **counts match bucket for bucket** while the P&L is redistributed — the
signature of a join that finds the right tickets and attaches the wrong money to
them. Only the keyed column can be trusted.

So defect **E**'s premise is **not** refuted: the >3yr population is
money-losing here too (−217,518 on 25 trades, −8,701 each, 28% winners), with
the worst a ticket that rested **380 weeks** to lose 39,827 and the longest
resting **865 weeks — 16.6 years**. The 1–3yr bucket, named above as the real
loss-maker, is in fact mildly positive (+16,612).

`entry_order_max_rest_weeks` still shipping at `0` remains correct — a default
must be the pre-existing no-op regardless (`experiment-flag-discipline.md` R1) —
but the *reason* recorded here for preferring 0 over 156 does not hold.

## Why four of the six arms were dropped

Turning the table above into gross attribution, the population a clock at N
weeks removes:

| clock | drops | gross effect | as % of the ~2.8M run |
|---|---|---:|---:|
| 13w | wk 14+ | −98,663 | ~−9.9pp |
| 26w | wk 27+ | −101,917 | ~−10.2pp |
| 52w | wk 53+ | −83,787 | ~−8.4pp |
| 156w | wk >156 | −304,101 | ~−30.4pp |

**The null on this base is 132.5pp.** Every clock arm's predicted effect is 4-13×
smaller than the noise floor, so a single-salt clock arm cannot come back with an
interpretable number in either direction — and neither could four of them. (Gross
attribution is also not the counterfactual: cancelling a ticket frees capital for
something else, so these are upper bounds on the magnitude, which only makes the
point stronger.)

### ⚠ This section's arithmetic inherits the mis-join — corrected 2026-08-18

The four gross-effect figures come from the withdrawn table, so they are wrong
too. Recomputed on the keyed join (arm 00, `position_id`, max fill age 865wk):

| clock | fills cut | realized P&L of the cut cohort | direction if removed |
|---|---:|---:|---|
| 13w | 147 | −266,866 | **+11.5%** of realized |
| **26w** | 89 | **−349,132** | **+15.1%** of realized |
| 52w | 60 | −200,906 | **+8.7%** of realized |
| 156w | 25 | −217,518 | **+9.4%** of realized |

Every bound removes a **net-losing** cohort, and the largest is 26 weeks, not
156. More importantly the *framing* above is wrong: this is **within-run
accounting of the arm's own trades**, not a difference between two runs, so the
132.5pp between-run null does not bound it. The null argument that retired four
arms does not apply to the metric that can actually resolve them — which is the
metric this README itself named as the one that would ("what would resolve them
is a **different metric** — per-bucket realized P&L on the arm's own trades").

**What stands:** narrowing *this* chain to 4 arms is still right, because the
chain was already launched and the re-screen question is genuinely the one it can
answer with three salts. **What does not:** "the clock axis cannot return an
interpretable number." It can, on this metric, and it should get a run.
Still gross, not net — cancelling a resting ticket frees capital the walk
redeploys, and that replacement's P&L is unmeasured.

The **re-screen** is different. It cancels on stage / sector / macro flips rather
than on elapsed time, so its population is not bounded by the rest-time table and
its effect is genuinely unknown. It is the one question this budget can answer,
and it is the one the #2349 split was built to make askable.

## What runs

| # | spec | rescreen | clock | salt |
|---|---|---|---|---|
| 1 | `00-null` | false | 0 | 0 |
| 2 | `01-rescreen-only` | true | 0 (unbounded) | 0 |
| 3 | `01-rescreen-only` | true | 0 | 1 |
| 4 | `01-rescreen-only` | true | 0 | 2 |

~4 hours. The re-screen arm gets **three salts** so it has a distribution rather
than a draw; it is compared against cell 00's already-measured three
(**265.44 / 281.71 / 397.95**, mean 315.0, spread 132.5pp) from
`dev/experiments/ladder-v4-seeded-2026-08-14/results.md` — same base, same
window, same universe, same warehouse.

Run 1 is a **determinism tripwire, not a datum**: post-#2279 the runs are
deterministic and the default path is untouched by #2348/#2349, so it must return
**281.71** exactly. Any other value means the binary moved, the borrowed null is
invalid, and the whole comparison is void — stop there.

**Read it as a distribution, not a mean.** Three draws each is not power; the
honest question is whether the re-screen's three draws separate from the null's
three, the way [nearfloor's trade count and maxDD did and its return did not](../nearfloor-confirmation-grid-2026-08-16/results.md).

## The clock arms, deferred rather than abandoned

`02-ttl13`, `03-ttl26`, `04-ttl52` and `05-clock156-only` stay committed here,
runnable, and correct. They need either a cheaper harness (the 808s per-run floor
is a standing item) or a metric with a tighter noise floor than total return —
per-bucket realized P&L on the arm's own trades would resolve a 10pp effect that
the top line cannot.

**That metric now exists and has been run** (2026-08-18):
`dev/experiments/ticket-funding-cohort-2026-08-18/rest_time_pnl.sh`, which joins
on `position_id` and refuses any pre-#2317 artifact. On arm 00 it says every
clock bound removes a net-losing cohort, 26 weeks largest. The clock arms are
therefore **worth running**, and `03-ttl26` is the one to run first — the
opposite priority to what the (mis-joined) table above implied.

Also missing by construction, and worth adding whenever they do run: the
composite **`(rescreen = true, clock = 156)`**. `weinstein_strategy_config.mli`
names ~156 weeks as the candidate value that "earns the default only through the
defect-D re-test", and the candidate is the composite — so as originally
specified this re-test could not have earned 156 its default even in principle.
Given the **corrected** table, the ranking flips: `(true, 26)` is the
composite to run — 26 weeks cuts the largest net-losing cohort (89 fills,
−349,132) — and `(true, 156)` is now defensible on its own evidence rather than
being the bound that "cuts a profitable population". The `(true, 52)` suggestion
was reasoning off the mis-joined 1-3yr / >3yr figures and should be ignored.

## Running

Specs are duplicated to `/tmp/ttl-retest-specs/` deliberately: a long chain must
read its inputs from outside the repo, because `jj new` deletes uncommitted repo
paths out from under a running run (`sweep-hygiene.md`).

Requires a build carrying #2349 — the field names do not exist before it, and
`Overlay_validator` fails loudly on an unknown key rather than silently running
the baseline (the #1051 hazard).

```sh
sh /tmp/ttl-retest-run.sh      # resumes; skips any arm with a RESULT line
cat /tmp/ttl-retest-chain.log
```

Pinned worktree `.claude/worktrees/sweep-ttl-retest` at the #2349 merge commit.
One run at a time, and **no agents while it runs** — a 26y top-3000 run holds
~2.2-2.4 GB for an hour and an OOM kill is silent (`<no result>`, empty child
log, no stack).
