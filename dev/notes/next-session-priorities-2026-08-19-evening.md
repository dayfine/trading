# Next-session priorities — 2026-08-19 evening

**Supersedes** `next-session-priorities-2026-08-19-pm.md`. The PM doc's active
queue is largely resolved: E1 is answered, E4 is answered, and both answers
reverse the reading the PM doc carried.

## Start here

```sh
date '+%m-%d %H:%M'; git log --date=format:'%m-%d %H:%M' --pretty='%ad %h %s' -8 origin/main
sh dev/scripts/pr_gate_status.sh
```

## What this session settled

### E1 (#2404) — the entry cap: the 1-year result was a horizon artifact

Same axis, same base, same tree; only `test_days` 365 → 1095 (5 disjoint folds
2010→2024, 30 fold-arm runs, 1543s).

| cap | Return μ | Sharpe μ | MaxDD μ | Calmar wins /5 |
|---|---:|---:|---:|---:|
| 1.0 | 43.76 | 0.961 | 14.38 | 2 |
| **2.0 = baseline** | **45.49** | **0.998** | 14.42 | 0 (null cell, bit-identical) |
| 5.0 | 37.52 | 0.837 | 14.02 | 1 |
| 10.0 | 39.62 | 0.908 | **12.60** | 2 |
| 15.0 | 39.54 | 0.907 | **12.60** | 2 |

**Every variant fails the 3-of-5 Calmar gate.** `1.0` — which won Calmar 13/16
and MaxDD 15/16 at one-year folds — is now *below* baseline on return, Sharpe
and Calmar. The drawdown story **inverts**: lowest mean MaxDD is now the loose
caps. A no-fill forgoes the whole subsequent run and a 1-year fold truncates it;
fold-004 alone costs `1.0` −10.9pp. PR #2413,
`project_entry_cap_horizon_reversal`.

**Open decision for the user:** both horizons rank live's `15.0` below `2.0`, so
the cheap fidelity fix is **moving live 15 → 2**, not re-pinning 27 goldens to
15. Commented on #2403. Note the two sides differ in mechanism but not in
decision — live *suppresses* a candidate past the cap (keeping a watch row),
the sim makes it the StopLimit limit price so there is no fill.

### E4 (#2407) — "cancel when the base broke" is the clock with extra steps

Fresh 26y × top-3000 run at pinned `59b26c3bf`; **tripwire exact**
(`total_return_pct 281.707836178685`, 1147 trades), 1147/1147 joined on
`position_id`.

| rule | cuts | cohort P&L |
|---|---:|---:|
| clock (rest > 26wk) | 89 fills | **−349,132** (reproduces the committed 08-16 figure) |
| `broken_8w` | 131 fills | −222,667 |
| …also >26wk | 79 fills | −366,810 |
| …**outside** >26wk | 52 fills | **+144,142** |

The population #2407 exists to rescue — long rest, base intact — is **10 fills
worth +17,678, 0.764% of P&L**, half of them losers, because **79 of the 89
long-rest fills had already broken their 8-week base low**. NO BUILD. PR #2417,
`project_base_broken_is_age`.

**What is real:** a dose-response in breach *depth* — below the ticket's own
stop +3,092/trade, below the 4wk low +1,641, below the 8wk low −1,700. A shallow
dip beats the average (held: +1,572); only the 8-week break marks a failed base,
and only its sign survives removing the top 3 trades. Any future entry-quality
work should use the **8-week base low**, never the ticket's own stop.

**Consequence for #2405 (clock re-flip):** the main objection to the clock is
gone — it is not cutting blindly across two populations. Its remaining risk is
tail-lottery variance in any one window, which is the confirmation grid
`simulation.md` already owes (R-1's macro-diverse cell), not a discriminator
problem.

### Also landed

| | |
|---|---|
| **#2411** | entry-cap axis + PM handoff (merged) |
| **#2414 / #2416** | `_index.md` and `simulation.md` both still described the clock-26 promotion as live after #2397 reverted it — including a "new specs now run at 26, pin explicitly" note that was actively wrong |
| **#2415** | committed memory snapshot refreshed; `MEMORY.md` compacted 19.5 KB → 17.4 KB |
| **#2412** filed | `fold_actual` carries no trade count / max single-trade P&L, so fewer-positions-vs-better-picks is unanswerable from any WF surface |
| **#2410** closed | cancel decomposition moot at defaults, already answered by the rest-time table |

## The queue

| | task | state |
|---|---|---|
| **#2412** | add `total_trades` + max single-trade P&L to `fold_actual` | small harness PR; unblocks the question E1 could not answer |
| **E2** #2403 | goldens track live config + declare deviations | structural half (shared base + `deviates_from_live` + linter) stands alone; the re-pin half is now a **user decision on which side moves** |
| **E3** | flip `enable_sim_entry_stoplimit` default-on | user-directed; still needs E2 |
| **#2405** | clock-26 re-flip | needs the confirmation grid, ≥1 macro-diverse cell — not a new discriminator |
| **P2** | live picks skip the 15% stop-width gate | user decision, questions already in the published report |

Backlog unchanged: **#2408** (stop-anchor surface), **#2409** (archetype
taxonomy, premise weakened), **D1b** on **#2380**.

## Process notes that cost or saved real time

- **A memory-guard abort is not always a real shortage.** The 26y run refused to
  launch at "3987MiB free, need 4096" right after a backtest finished — the
  container's `MemUsage` was mmap'd page cache, not anonymous memory.
  `docker restart trading-1-dev` dropped it to 3.5 MiB with the warehouse and
  every prior output intact.
- **A build marker must live on the side that writes it.** `touch "$WORK.built"`
  ran on the host while `$WORK` existed only in the container; under `set -e` it
  killed the chain *after* a successful 90-second build.
- **`Trade_audit.entry_decision.entry_date` is the PLACEMENT date**, identical to
  `ticket_lifecycle.placement_date` on all 1,466 records, while the same rows
  carry `ticket_age_weeks_at_fill` up to 865. **The fill date is `trades.csv`'s.**
  Using the audit date for both ends of a rest window makes it empty and every
  ticket then reads base-HELD — a clean, plausible, entirely false null.
- **`[@sexp.option]` renders `Some v` as `(field v)`** and omits the field for
  `None`; a plain `t option` renders `(field (v))`. Reading the first with the
  second's pattern yields `-` on every row and looks like "the feature was off".
- **Blank `position_id` silently halves a population** — 563 of 1,136 rows on the
  2026-08-12 artifacts. `measure.sh` now warns instead of printing a table over
  half the data.
- **Pre-register against the incumbent, not against zero.** E4's pre-registered
  rule ("cohort large and negative ⇒ build") was satisfied by a mechanism that is
  dominated by the thing it was supposed to replace. Name the comparison
  quantity — here the rescue population — before running.
- **`position_id` is the right join key but NOT a unique one.** `trades.csv`
  carried 1,147 round trips over 1,146 ids (`FARM-wein-914` twice), and an
  assignment-style awk join overwrote one P&L with the other — a +3,750.90
  overstatement. Sum per id; warn on any id with more than one round trip.
- **An unexplained gap between two computations of the same quantity is a defect
  until proven otherwise.** That join bug announced itself as a 3,751 discrepancy
  between two totals off one file, and I recorded it as my own arithmetic slip
  and moved on. qc-behavioral found it two hours later.
- **The gate script could mark a gate green that never ran.** A *structural*
  review containing a `### Notes for Behavioral QC` heading satisfied the
  behavioral matcher, printing `pass / ok / ok  MERGE` on #2417 with
  qc-behavioral undispatched. Fixed + regression-tested in #2419 — worth knowing
  because the autonomous merge path reads that script.
