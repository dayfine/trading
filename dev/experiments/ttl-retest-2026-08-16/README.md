# TTL re-test — defect D, redesigned after checking the motivating table

Defect **D** of `dev/plans/entry-anchor-and-ttl-2026-08-15.md`, on the ladder-v4
cell-00 base (top-3000 × 2000-2026), using the two F2 fields PR #2349 split
apart.

> **The original 6-arm design in this directory is not what runs.** Four arms
> run: the null tripwire plus the re-screen at three salts. The clock arms are
> **deferred pending a within-run cohort metric, not retired** — read on the top
> line a single-salt clock arm cannot clear the 132.5pp between-run null, but
> that is a statement about the *metric*, not about the axis. The specs are all
> committed; only the chain's arm list narrowed.
>
> **Two corrections were applied to this file after it was first written**
> (2026-08-18), and both are marked inline below rather than silently edited:
> the motivating cell-00 rest-time table is **withdrawn** (§"What this
> establishes, and what it does not"), and the gross-effect argument built on it
> is **withdrawn** with it (§"Why four of the six arms were dropped"). The
> narrowing decision survives both, because it never depended on either — see
> §"What stands".

## What the motivating table said, and what this base actually says

The plan's rest-time table is from **cell 13** (`Range_top_breakout` + `Nearest`,
953 trades). Rest time is directly downstream of the entry-anchor basis, so it
was worth checking against the base the re-test actually runs. The **recorded**
cell-00 table — stated as **1,145** filled tickets joined `position_id` →
`ticket_age_weeks_at_fill` → `pnl_dollars`
(`dev/agent-memory/project_rest_time_pnl_is_cell_specific.md`), though its own
rows below sum to **1,146**. **⚠ This table is WITHDRAWN — see the banner
immediately after it. It is kept verbatim for the record, not as a current
figure.**

| bucket | n | realized pnl | pnl/trade |
|---|---:|---:|---:|
| wk 0-1 (0-13d) | 696 | 679,738 | 977 |
| wk 2-4 (14-34d) | 167 | **−201,330** | −1,206 |
| **wk 5-13 (35-97d)** | 136 | **1,596,587** | **11,740** |
| wk 14-26 | 58 | 3,254 | 56 |
| wk 27-52 | 29 | 11,622 | 401 |
| wk 53-156 (1-3y) | 35 | **−220,314** | −6,295 |
| **wk >156 (>3y)** | 25 | **+304,101** | **+12,164** |

**Confirmed as to sign and rank, not magnitude:** the 5-13-week band is the
profit band on this base too, and a 4-week clock cuts it entirely, so the
`{13, 26, 52}` axis is right. The *magnitudes* in the row above (1.60M on 136
trades at 11,740 each) are withdrawn with the rest of the table — the keyed
measurement below puts the same bucket at **+1,021,434 / +7,511 per trade**, a
**−575,153** move on identical n. Only the ordering is being confirmed. (#2371
§F1 states this identically.)

**~~Refuted:~~ WITHDRAWN 2026-08-18 — the per-bucket P&L above is not
reproducible from any artifact now on disk, and a `position_id`-keyed
measurement of the same nominal cell disagrees with it across the whole table.**

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

(The two columns are laid out side by side because the buckets are defined
identically, **not** because they are over the same trade set — they are not,
see reason 2 below. Read each row as *"the two measurements say this"*, not as
*"these same n trades moved."*)

### What this establishes, and what it does not

It establishes that **two measurements of the same nominal cell disagree**, and
that only one of them is reproducible from an artifact now on disk.

It does **not** establish *why*. In particular it does **not** establish that
the earlier figure is a **mis-join artifact**. An earlier draft of this file
asserted exactly that — that the ages "must have come from a symbol/date match",
that the pattern was "the signature of a join that finds the right tickets and
attaches the wrong money to them", and that "only the keyed column can be
trusted". **That diagnosis is withdrawn.** Three reasons it does not survive:

1. **A re-pairing preserves the total; these totals move.** Permuting
   `pnl_dollars` across the same round trips cannot change their sum. The
   withdrawn rows sum to **+2,173,658**, the keyed rows to **+2,314,953** — a
   **+141,295** move. No permutation of the same money produces that.
2. **A mis-join within one artifact preserves n exactly; these counts differ.**
   The withdrawn rows sum to **1,146** (against a stated 1,145); the keyed rows
   to **1,147**, which is also ladder-v4 cell 00 salt 0's trade count
   (`ladder-v4-seeded-2026-08-14/results.md`). Different trade sets is a
   *reproducibility* problem, not a *pairing* bug.
3. **The recorded provenance names the same key.**
   `dev/agent-memory/project_rest_time_pnl_is_cell_specific.md` records the
   earlier table as already joined `position_id` → `ticket_age_weeks_at_fill` →
   `pnl_dollars`. Its own record therefore **contradicts** the mis-join story
   rather than supporting it. (That memory is now stale either way — it still
   carries the +304,101 figure and the "refutes defect E" framing. Whichever of
   this PR and #2371 lands second should retire it.)

Per `.claude/rules/mechanism-validation-rigor.md` §"Verdict calibration", a
disagreement between two measurements licenses **"not reproducible"**; it does
not license a causal account of why. Sibling PR #2371
(`ticket-funding-cohort-2026-08-18`) reaches the same calibration on the same
pair of tables — *"Explicitly **not** established: that the earlier figure is a
mis-join artifact"* — and its `404 of 953` `position_id`-coverage disproof is
scoped to **cell 13 only**, so it is not evidence about either cell-00
measurement.

**Two arithmetic reasons to prefer the keyed table anyway**, neither of which
needs a causal story:

- Its bucket n's sum to **1,147**, matching both its own stated "1,147 of 1,147
  round trips joined" and ladder-v4 cell 00 salt 0's trade count. The withdrawn
  table's n's sum to **1,146** against a stated **1,145** — it does not agree
  with itself.
- Every derived row of the keyed table reconciles against its own buckets (the
  clock table below: 147 / 89 / 60 / 25 fills and −266,866 / −349,132 /
  −200,906 / −217,518 are exact partial sums, and all four percentages share
  one denominator, the table's own +2,314,953). Of the withdrawn table's four
  clock rows, **the 26w row does not**: its own wk 27+ buckets sum to
  **+95,409**, not the stated **101,917**.

So defect **E**'s premise is **not** refuted **on this measurement**: the >3yr
population is money-losing here too (−217,518 on 25 trades, −8,701 each, 28%
winners), with the worst a ticket that rested **380 weeks** to lose 39,827 and
the longest resting **865 weeks — 16.6 years**. The 1–3yr bucket, named above as
the real loss-maker, is on this measurement mildly positive (+16,612). This is a
description of *this* run's 25 long-rest trades; it is not offered as a
correction of the recorded 25, which are not the same set.

`entry_order_max_rest_weeks` shipping at `0` was correct **at the time this was
written** — a default must be the pre-existing no-op (`experiment-flag-discipline.md`
R1) — but the *reason* recorded here for preferring 0 over 156 does not hold.

> **⚠ Superseded 2026-08-18.** The default was subsequently promoted `0 → 26`
> by user decision (PR #2384), i.e. outside R1/R3. The evidence, the two
> process deviations, and the fact that the measured between-run gap sits
> *below* this base's own 132.5pp seed-noise floor are all recorded on
> `Weinstein_strategy_config.entry_order_max_rest_weeks`. The load-bearing
> argument is the within-run cohort measured in this very file: a 26-week bound
> cuts 89 fills worth −349,132.

## Why four of the six arms were dropped

### ⚠ The original argument, WITHDRAWN 2026-08-18 — kept for the record

The section below turned the withdrawn table into gross attribution. Its four
figures (−98,663 / −101,917 / −83,787 / −304,101, quoted as ~8-30pp of a "~2.8M
run") are therefore **withdrawn with it and are deliberately not restated as
current** — including in `run.sh`'s header, which used to quote them. Two of its
sentences are separately wrong on their own terms and are struck below.

> ~~Turning the table above into gross attribution, the population a clock at N
> weeks removes: 13w → −98,663 (~−9.9pp), 26w → −101,917 (~−10.2pp), 52w →
> −83,787 (~−8.4pp), 156w → −304,101 (~−30.4pp) of the ~2.8M run. **The null on
> this base is 132.5pp.** Every clock arm's predicted effect is 4-13× smaller
> than the noise floor, so a single-salt clock arm cannot come back with an
> interpretable number in either direction — and neither could four of them.
> (Gross attribution is also not the counterfactual: cancelling a ticket frees
> capital for something else, so these are upper bounds on the magnitude, which
> only makes the point stronger.)~~

Two independent errors in that paragraph, beyond the withdrawn inputs:

- **"upper bounds on the magnitude" is false.** Freed capital is redeployed, and
  the replacement can be better *or* worse than what was cancelled — so the net
  effect can be **larger** in magnitude than the gross, in either direction.
  Gross is not a bound at all. (The *direction* of the original inference did
  hold given its premise — a tighter |effect| sits even further below a 132.5pp
  null, sharpening an underpowered conclusion — but the premise does not hold,
  so the sentence is struck rather than kept.)
- **"cannot come back with an interpretable number" over-reaches**, because it
  quantifies over the wrong metric — see the correction below.

What **does** survive from it, and is restated here without the withdrawn
figures: on the **top line**, a clock arm removes a small minority of fills
(147 of 1,147 even at the widest tested cut) against a **132.5pp between-run
null**, so a single-salt clock arm is not resolvable *on total return*. #2371
states this independently.

### The corrected arithmetic — 2026-08-18

Recomputed on the keyed join (arm 00, `position_id`, max fill age 865wk):

| clock | fills cut | realized P&L of the cut cohort | direction if removed |
|---|---:|---:|---|
| 13w | 147 | −266,866 | **+11.5%** of realized |
| **26w** | 89 | **−349,132** | **+15.1%** of realized |
| 52w | 60 | −200,906 | **+8.7%** of realized |
| 156w | 25 | −217,518 | **+9.4%** of realized |

The counts and P&L above are exact partial sums of the keyed bucket table
(147 / 89 / 60 / 25 fills; −266,866 / −349,132 / −200,906 / −217,518), and all
four percentages share one denominator — that table's own realized total,
+2,314,953.

Every bound removes a **net-losing** cohort, and the largest is 26 weeks, not
156 — the **sign flips** relative to the withdrawn table, which is the
substantive change, not the magnitudes. More importantly the *framing* above is
wrong: this is **within-run accounting of the arm's own trades**, not a
difference between two runs, so the 132.5pp between-run null does not bound it.
The null argument that retired four arms does not apply to the metric that can
actually resolve them — which is the metric this README itself named as the one
that would ("what would resolve them is a **different metric** — per-bucket
realized P&L on the arm's own trades").

**What stands:** narrowing *this* chain to 4 arms is still right, because the
chain was already launched and the re-screen question is genuinely the one it can
answer with three salts — an argument that does not depend on the sign of the
>3yr bucket either way. **What does not:** "the clock axis cannot return an
interpretable number." It can, **on the within-run cohort metric**, and it should
get a run. Read on the top line it still cannot: a scenario run's
`total_return_pct` is a between-run comparison and *is* bounded by the 132.5pp
null. Still gross, not net — cancelling a resting ticket frees capital the walk
redeploys, and that replacement's P&L is unmeasured, so these figures bound
nothing; they describe the cohort that would be cut.

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
opposite priority to what the withdrawn table above implied.

**Read the arm on that metric, not on its top line.** The recommendation above is
"run `03-ttl26` and rerun `rest_time_pnl.sh` against its artifact", not "run it
and read `total_return_pct`" — the top line is a between-run comparison and is
bounded by the 132.5pp null exactly as the withdrawn section said.

Also missing by construction, and worth adding whenever they do run: the
composite **`(rescreen = true, clock = 156)`**. `weinstein_strategy_config.mli`
names ~156 weeks as the candidate value that "earns the default only through the
defect-D re-test", and the candidate is the composite — so as originally
specified this re-test could not have earned 156 its default even in principle.
Given the **corrected** table, the ranking flips: `(true, 26)` is the
composite to run — 26 weeks cuts the largest net-losing cohort (89 fills,
−349,132) — and `(true, 156)` is now defensible on its own evidence rather than
being the bound that "cuts a profitable population". The `(true, 52)` suggestion
was reasoning off the withdrawn 1-3yr / >3yr figures and should be ignored.

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
