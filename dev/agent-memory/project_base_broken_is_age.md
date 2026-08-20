---
name: project-base-broken-is-age
description: "#2407 NO BUILD: 79 of the 89 fills resting >26wk had already broken their 8-week base low, so the long-but-pristine cohort the structural rule would rescue is 10 fills / +17,678 / 0.76% of P&L. Age and structure are the same variable at this cadence. Real finding: dose-response in breach DEPTH (+3,092/trade shallow → -1,700 deep)."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7959dddf-3101-4cab-8f02-c90b77a7d8fd
  modified: 2026-08-20T01:14:19.992Z
---

**"Cancel when the base breaks" is the clock with extra steps.** Measured on the
26y record base (`ttl-retest-00-null` at pinned `59b26c3bf`, tripwire
`total_return_pct 281.707836178685`, 1,147 round trips over 1,146 `position_id`s).

#2407's claim was that a structural test **dominates** the clock by keeping the
long-but-valid bases age destroys. That population is **10 fills, +17,678,
0.764%** of the run's 2,314,952 — and half of them lost money, because **79 of
the 89 fills resting >26wk had already broken their 8-week base low.**

| rule | cuts | cohort P&L |
|---|---:|---:|
| clock (rest > 26wk) | 89 | **−349,132** (reproduces the committed 08-16 figure exactly) |
| `broken_8w` | 131 | −222,667 |
| …also >26wk | 79 | −366,810 |
| …**outside** >26wk | 52 | **+144,142** (cutting these costs money) |

## The finding that IS real: breach DEPTH, not breach

| breach threshold | n | per trade |
|---|---:|---:|
| below the ticket's own stop | 339 | **+3,092** |
| below the 4-week base low | 195 | +1,641 |
| below the 8-week base low | 131 | **−1,700** |

Monotone. A shallow dip below a resting ticket's own stop **beats the average**
(held: +1,572) — the re-screen REJECT's lesson again: a pullback that resumes
*is* base-building. Only a break of the 8-week low marks a failed base. Any
future entry-quality work should use the **8-week base low** as its structural
test, never the ticket's own stop.

Robustness: minus the top 3 trades, `broken_stop` goes +1,048,334 → **−65,575**
and `broken_4w` +320,073 → **−160,671**; `broken_8w` goes −222,667 →
**−587,105**. Both shallow flags *survive* minus-top-1 (+387,087 / +116,235) and
flip at three — their sign rests on a handful of trades, not on one. Only the
deepest flag's sign is untouchable by a tail argument.

## Transferable

- **Pre-register against the INCUMBENT, not against zero.** My pre-registered
  rule ("cohort large and negative ⇒ build") was satisfied by `broken_8w` at
  −9.6% of P&L, and was still the wrong criterion: the claim under test was
  "dominates the clock". Name the comparison quantity — here the rescue
  population — before running.
- **Two variables that co-move at the sampling cadence are one variable.** A
  weekly-cadence base that takes >26 weeks essentially always breaks its own
  8-week low somewhere in that span. "Cut on the right variable instead" only
  helps when the variables actually separate; check the cross-tab **first**, it
  costs one query.
- Closes the "age is the wrong discriminator" line from
  [[project-stale-order-fills-are-not-an-edge]]. The clock's remaining risk is
  tail-lottery variance in any one window, which is a confirmation-grid problem
  ([[project-promotion-confirmation-grid]]), not a discriminator problem.

## `position_id` is the right join key but NOT a unique one

`trades.csv` had 1,147 rows over **1,146** ids — `FARM-wein-914` carries two
round trips. Keying P&L into an awk array by id overwrote one with the other:
total overstated by **+3,750.90**. Sum per id, and warn on any id with >1 round
trip. Qualifies [[feedback-position-id-is-the-only-join-key]]: *only valid* ≠
*unique*.

The tell was visible and explained away — two totals off the same file differed
by 3,751 and I recorded it as my own arithmetic slip instead of chasing it.
qc-behavioral on #2417 found it. **An unexplained discrepancy between two
computations of the same quantity is a defect until proven otherwise.**

## Instrumentation trap this uncovered

`Trade_audit.entry_decision.entry_date` is the **PLACEMENT** date — identical to
`ticket_lifecycle.placement_date` on all 1,466 records — while the same rows
carry `ticket_age_weeks_at_fill` up to 865. **The fill date is `trades.csv`'s
`entry_date`.** Using the audit's date for both ends of the rest window makes it
empty, and every ticket then reports base-HELD: a clean, plausible, entirely
false null. The tables looked fine; what exposed it was `placement == entry` on
every row sitting two fields from a non-zero age.

Record: `dev/experiments/base-broken-2026-08-19/` (incl. per-trade `joined.tsv`),
issue #2407. Related: [[project-condition-vs-time-cancellation]],
[[project-ttl-is-a-tail-lever]], [[feedback-perturb-before-believing-a-cohort-split]].
