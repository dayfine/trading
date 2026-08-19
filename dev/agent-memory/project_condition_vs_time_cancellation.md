---
name: project-condition-vs-time-cancellation
description: "Cancelling a resting entry ticket on CONDITION (stage/sector/macro flip) and on TIME select opposite populations — the re-screen lost 137pp by discarding pullback-then-resume winners, while every time bound cuts a net-losing cohort."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7b9bffd9-4afb-483a-9e22-50b6142eb14c
  modified: 2026-08-18T19:58:26.108Z
---

Measured 2026-08-18 (PR #2376, ledger `2026-08-18-entry-ticket-rescreen.sexp`)
on the ladder-v4 cell-00 base, 26y top-3000.

**REJECT for `enable_entry_ticket_rescreen`** — the book-supported weekly
re-screen cancel, testable on its own for the first time after #2349 split it
out of the composite `entry_order_ttl_weeks` knob.

| | draws | spread |
|---|---|---|
| null | 265.44 / 281.71 / 397.95 | 132.5pp |
| re-screen | 176.36 / 174.83 / 182.28 | **7.45pp** |

The **best** re-screen draw is 83pp below the null's **worst** — non-overlapping
distributions, which is why one window suffices to *reject* (not to promote).
MaxDD is worse too (42.2-42.9 vs 39.0). The tripwire arm reproduced
281.707836178685 exactly, so the borrowed null is valid.

## The mechanism — the transferable part

Dissected with a `position_id`-keyed rest-time join, null vs re-screen:

- **The re-screen is a de-facto ~22-week cap.** Max fill age collapses
  **865wk → 22wk**; the 27-52wk, 1-3yr and >3yr buckets go to **zero** fills.
- **It destroys the profit band.** 5-13wk goes from +1,021,434 on 136 trades
  (+7,511 each) to **−131,738 on 58** (−2,271 each). Total realized **−45%**.
- **Condition-based ≠ time-based.** On the *same* arm every time bound
  `{13, 26, 52, 156}` cuts a **net-losing** cohort. A clock removes tickets that
  rested long *without their setup changing* — stale, never resumed. The
  re-screen removes tickets whose stage/sector/macro **flipped while resting** —
  but pull-back-then-re-break **is the base-building pattern** itself, so it
  discards precisely the pullback-then-resume winners.
- **The variance collapse is itself evidence.** 132.5pp → 7.45pp. The null's
  dispersion *is* the long-rest lottery; capping rest removes the lottery and
  its positive expectancy together. Removing variance and return in one stroke
  is what taxing a fat tail looks like — 12th
  [[project-edge-is-the-fat-tail]] confirmation, and the cleanest.
- **It is not a failed no-op.** `rejected_fills` halves (262 → ~124), so the
  mechanism really does cancel tickets before they trigger into a cash-short
  book ([[project-ticket-dies-on-cash-shortfall]]). A working mechanism with the
  wrong **selection rule**.

## How to apply

- **Stop proposing condition-based cancellation of resting tickets** in any form
  — re-qualify, re-score, re-grade at trigger. The population it removes is the
  tail.
- **Time-based bounds stay open.** 26 weeks is the arm to run: it cuts 89 fills
  worth −349,132, the largest net-losing cohort of the four bounds. ⚠ The
  committed `03-ttl26` spec arms the re-screen **as well as** the clock and is
  therefore confounded — use a clock-only spec (single-knob diff from the null).
- The flag stays **default-off as an axis**: a REJECT-as-default, **not**
  do-not-revive, so Rule 4 retirement does not apply
  (`experiment-flag-discipline.md`).
- **Read the within-run per-bucket P&L, not the top line.** The 132.5pp null is
  a *between-run* figure and does not bound a within-run cohort accounting —
  conflating them is what retired four arms on a bad argument.
