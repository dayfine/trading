# Plan — entry anchor, TTL, and the artifacts that measure them

> **⛔ Status 2026-08-16 — the queue below has been re-ordered by evidence.**
>
> | | then | now |
> |---|---|---|
> | **F** | order 1 | **re-scoped and shipped** as G1 (PR #2348). The audit already carried `ma_value` / `close_at_decision` / `local_range_top`; the real gap was ticket *resolution* — `ticket_age_weeks_at_cancel` was written zero times, leaving 26% of placements unaccounted (`dev/notes/ticket-death-on-cash-2026-08-16.md`). |
> | **C + E** | order 2 | **shipped** (PR #2349). Two independent fields; the clock's default stays `0` until D. |
> | **A** | order 3, impact **high** | **REFUTED for every v4 arm.** The armed 4-week anchor is history-independent (verified bit-identical across a 26y and a 2.5y run); AXTI's E is 2.71 everywhere and it is rejected 21× by the **stop**. A's remaining scope is a promotion question for `entry_anchor_local_range_weeks` (default `0`), not a fix. `dev/notes/entry-anchor-defect-a-refuted-2026-08-16.md` |
> | **D** | order 4 | unchanged; now unblocked by the C+E split. |
> | **B** | order 5 | **moves to the front of the strategy work.** The 15% hard rejection is what excludes AXTI 21 times at a correct, fresh E. |
> | **G2/G3** | — | **new.** A triggered ticket the book cannot fund is destroyed, not retried; ~25% of would-be entries. |
>
> The per-defect sections below are the original text and are left unedited
> except where a section is explicitly marked.


Supersedes the ladder-v4 "which cell wins" framing. The seeded re-run
(`dev/experiments/ladder-v4-seeded-2026-08-14/results.md`) settled the cell
question: **only nearfloor clears the 132.5pp null, and it does so three ways.**
Everything below came out of dissecting *why*, and is a defect list rather than a
tuning surface.

## The graded queue

| | defect | impact | complexity | urgency | order |
|---|---|---|---|---|---|
| **F** | artifacts cannot answer basic questions | med | **low** | high | **1** |
| **C** | one knob arms re-screen cancel + clock | high | **low** | high | **2** |
| **E** | unbounded GTC → 21.7-year resting orders | low | low | low | **2** (rides with C) |
| **A** | the entry anchor E goes stale | **high** | med | high | **3** |
| **D** | the 4-week clock cuts the most profitable band | high | low | med | **4** |
| **B** | "prefer other candidates" built as hard rejection | med | med | med | **5** |

F and C are near-free, and **A is measured through F**, so they lead even though
A is the biggest.

---

## F — the artifacts cannot answer basic questions

Two gaps, both pure emission, no behaviour change:

1. **No utilization / cash series.** `equity_curve.csv` is `date,portfolio_value`;
   `open_positions.csv` is an end-of-run snapshot. Answering "are we deploying
   capital?" required reconstructing cost-basis utilization from three files by
   hand (`ladder-v4-seeded-2026-08-14/utilization-validation.md`). Add a `cash`
   or `deployed` column to `equity_curve.csv`.
2. **The audit omits the inputs E is derived from.** `trade_audit.sexp` records
   `suggested_entry`, `suggested_stop`, `installed_stop`, `stage`,
   `ma_direction`, `resistance_quality` — but **not** `ma_value`, not the close
   on the decision date, and not the resistance price E is anchored to. So E's
   provenance is unauditable from artifacts alone; establishing that BFX's E came
   from a 2019 high needed a raw-bar dump and an arithmetic inversion. The
   `trade-dissection` skill already documents this gap; close it.

**Acceptance:** the AXTI and BFX derivations in
`dev/notes/ttl-and-record-dissection-2026-08-15.md` become a query, not an
investigation.

---

## C + E — split the TTL knob, and bound it sanely

`entry_order_ttl_weeks` gates **two** mechanisms at once
(`weinstein_strategy_screening.ml:299` returns `[]` at 0 without even consulting
the re-screen predicate):

- the weekly **re-screen cancel** — cancel a resting ticket whose base has broken
  down, sector flipped, or macro flipped. **Book-supported** (§4.7 cancel
  authority, §7 weekly review).
- the **clock backstop** — cancel after N weeks regardless. The book names no
  number.

You cannot currently have the faithful half without the arbitrary one.

**And unbounded is genuinely wrong at the extreme (E).** `FUL-wein-64` was decided
2000-02-04 and filled **2021-11-01** — a resting order that survived 21.7 years.
The >3yr population is 20 trades, 13 losers, best +21,987: systematically poor and
**upside-free**, which is what distinguishes it from every other rest bucket.

**Change:** separate the two into independent config fields, and give the clock a
long default (~3 years) whose job is removing absurdity, not shaping returns.

---

## A — the entry anchor goes stale

`E = round2(entry_anchor × (1 + entry_buffer_pct))`, `entry_buffer_pct = 0.005`.

Traced on the two canonical rejections:

| | decision | close | 30w MA | close/MA | E | E from | installed_stop | stop vs MA |
|---|---|---|---|---|---|---|---|---|
| BFX | 2020-04-17 | 5.05 | 2.298 | **2.20×** | 5.58 | 5.55 high of 2019-04-18 (~50wk) | 4.3488 | far above |
| AXTI | 2025-06-27 | 2.03 | 1.801 | 1.13× | 4.05 | stale high, 2.25× MA | 1.728 | **just below** |

**AXTI is a false rejection.** Its stop is exactly where the book puts it — just
under the 30-week MA. Real risk 11-15%, inside the gate. It is rejected only
because E is a pre-crash high at 2.25× the MA. AXTI was ranked #1 and skipped
this way **24 times**.

**BFX is a defensible rejection**, and this matters for scoping the fix: the stock
had doubled in a week and sat at 2.2× its MA, where a book-placed stop below the
MA is 54% risk and the "tight" 4.3488 is 4% under a spike low with nothing beneath
it. The 15% rule is doing its job there.

⚠ So A currently rests on **one clean case**. That is a hypothesis, not a finding.
The diagnostic below is what promotes or kills it.

---

## D — re-test TTL at values that matter

P&L by ticket rest, cell 13 (942 joined trades):

| bucket | n | share | realized pnl | pnl/trade |
|---|---:|---:|---:|---:|
| ≤7d | 396 | 42.0% | 2,225,496 | 5,620 |
| 8-28d | 248 | 26.3% | 423,842 | 1,709 |
| **29-91d** | 152 | 16.1% | **1,273,096** | **8,376** |
| 92-182d | 59 | 6.3% | 404,455 | 6,855 |
| 183-365d | 32 | 3.4% | −10,173 | −318 |
| 1-3yr | 35 | 3.7% | 379,985 | 10,857 |
| **>3yr** | 20 | 2.1% | **−154,006** | **−7,700** |

**ttl4's 28-day cut lands on the lower edge of the best bucket.** The tested axis
{0, 4, 8} weeks never reached the useful range. Re-test at **{13, 26, 52}** once C
lands — the knob is already a `Variant_matrix` axis, so this is cheap.

And re-screening does **not** compensate: each fresh ticket is cancelled four weeks
later in turn. CHRW was re-screened four times after its cancel and never filled,
while ttl0's original 2022 ticket rested 1,070 days and returned +166,717.

---

## B — "prefer other candidates" is not "reject"

Book §5.1: *"If stop requires >15% risk from entry → **prefer other
candidates**."* We implement a hard exclusion with a `Stop_too_wide` skip
(`stop_types.mli:99`, which quotes the book and then rejects).

The codebase already has the faithful shape elsewhere: `overhead_supply` is a
**rank demotion, never an exclusion**.

**Not** in scope: changing the 15% threshold. It is book-derived, and on the
record arm it improves every percentile from p10 to p90 with an identical win rate
(34.4% vs 34.8%). Its entire cost is the extreme tail — one trade in 26 years.
Loosening it is a bet on outliers, not an expectancy improvement.

---

## The diagnostic that gates A

**First attempt failed by design** (2026-08-15) and the failure is worth
recording:

- A **2-symbol universe does not reproduce the decisions.** Ranking, sector RS and
  the macro gate all differ with 2 symbols instead of 3,000; the decision dates
  came out entirely different. The candidate-universe soundness argument only
  holds when *every* symbol that ever became a candidate is retained.
- **Widening the gate to 0.99 disabled the mechanism under test.**
  `stop_anchor_at_entry_base` only fires when the floor stop exceeds
  `max_stop_distance_pct`, so at 0.99 it never triggered — the anchor arm came out
  byte-identical to the nearfloor arm.

It did establish one thing: **`Nearest` is not uniformly tighter than
`Window_extreme`** — tighter on AXTI 2025-12-19 (26.22% vs 28.65%), *deeper* on
BFX 2020-01-10 (27.37% vs 2.08%). That complicates the "nearfloor fixes
crash-recovery stops" story and deserves its own look.

**Correct design (running):** real top-3000 universe, real 15% gate, window
2024-01-01..2026-06-26, three arms — core / nearfloor / nearfloor+anchor — using
**presence or absence in the audit** as the signal, since a re-anchored stop
passes the gate and the candidate then appears.

---

## Turning this session's dissections into tests

The infrastructure exists and is unused for this: `scenario_runner`,
`goldens-small/` (spec + pinned `expected`, wired into `dune runtest`), the
candidate-universe builder (#2311) and its byte-identical payoff validation
(#2319). Runs are deterministic since #2279.

Every dissection this session produced a `dev/notes` file and **left no test
behind**. Three that should become pinned scenarios:

1. **AXTI 2025-06-27** — assert `suggested_entry`, `installed_stop`, and
   `Stop_too_wide` rejection. Pins defect A, and *fails the moment A is fixed* —
   which is what makes it a useful regression test.
2. **BFX 2020-04-17** — the negative control: assert it stays rejected, so an
   A-fix does not start admitting 2.2×-MA parabolic moves.
3. **CHRW 2022→2025** — pins the TTL structural result: 1,070-day rest under
   ttl0, cancelled under ttl4, re-screened 4× and never filled.

Each is a small pinned universe over a short window — seconds to run.
