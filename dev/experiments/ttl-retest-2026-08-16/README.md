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

**Refuted:** defect **E**'s premise. On cell 13 the >3yr population was 20
trades, 13 losers, −154,006 and "upside-free"; on cell 00 it is **25 trades,
+304,101, the second-highest per-trade bucket in the run**. The loss-maker here
is the **1-3yr** bucket (−220,314), not the >3yr one. So "unbounded is genuinely
wrong at the extreme" is a cell-13 fact, not a general one, and a 156-week bound
would cut a *profitable* population on this base. That is exactly why
`entry_order_max_rest_weeks` shipped defaulting to `0` rather than to 156.

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

Also missing by construction, and worth adding whenever they do run: the
composite **`(rescreen = true, clock = 156)`**. `weinstein_strategy_config.mli`
names ~156 weeks as the candidate value that "earns the default only through the
defect-D re-test", and the candidate is the composite — so as originally
specified this re-test could not have earned 156 its default even in principle.
Given the table above, the more interesting composite may be
`(true, 52)`, which cuts the −220,314 1-3yr bucket while keeping the +304,101
tail.

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
