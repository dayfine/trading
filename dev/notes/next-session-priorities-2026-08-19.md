# Next-session priorities — 2026-08-19

**Supersedes** `next-session-priorities-2026-08-18.md`.

## Start here

1. **Cross-check the wall clock against `origin/main` before trusting anything.**
   ```sh
   date '+%m-%d %H:%M'
   git log --date=format:'%m-%d %H:%M' --pretty='%ad %h %s' -8 origin/main
   ```
   This session stalled **~11 hours** (01:17 → 12:24 PDT) on an **expired
   login** — a *second*, distinct stall class from the 08-16 permission-prompt
   stall, and one that allowlisting cannot prevent. The container sat idle 8
   hours and the cron merged two PRs I was holding. Run this check on **every
   resume**, not once at ramp-up. See
   `memory/feedback_two_stall_classes_check_clock.md`.
2. `cat /tmp/clock26-chain.log` — the X1 arm (below) was launched 12:55 and
   survives a session boundary.
3. `sh dev/scripts/pr_gate_status.sh`.

## In flight

- **[X1] clock-26-ALONE arm — COMPLETE.** Three salts returned
  **513.42 / 434.06 / 377.73** against the null's **265.44 / 281.71 / 397.95**:
  mean gap +126.7pp, 8 of 9 pairwise, but the distributions **touch** and the
  exact rank test gives **p = 0.100**. Promising, not established. Spec
  `dev/experiments/ttl-retest-2026-08-16/specs/ttl-retest-06-clock26-only.sexp`
  (committed in this PR).
  ⚠ **Read the within-run per-bucket P&L, not the top line.**
  `dev/experiments/ticket-funding-cohort-2026-08-18/rest_time_pnl.sh` on the
  arm's own `trade_audit.sexp` + `trades.csv`. The 132.5pp null is a
  *between-run* figure and does not bound a *within-run* cohort accounting.
  **Next:** the confirmation grid, ≥3 cells with one spanning a pre-2009 macro
  regime. A user-directed default flip to 26 is in progress separately and is
  explicitly NOT gated on that grid.
- **PR #2376** — TTL re-screen REJECT + ledger. Needs the three gates.

## Open work, graded

| | task | impact | complexity | urgency |
|---|---|---|---|---|
| **P2** | live picks skip the 15% stop-width gate — **user decision** | HIGH | LOW to surface | HIGH |
| **F1** | build G3 `reserve_cash_for_resting_tickets` | HIGH | MED | MED |
| **F2** | decompose the cancel population | MED | LOW | MED |
| **S2** | pin AXTI entry construction as a unit test | LOW-MED | LOW | LOW |
| **S1** | `stop_anchor_at_entry_base` surface | MED-HIGH | HIGH | LOW |
| **H1** | attack the ~808s per-run floor | HIGH long-run | HIGH | LOW-MED |

### P2 — the live/backtest gate divergence (awaiting the user)

`generate_weekly_snapshot` **never applies `Stop_width_mode.gate`** — no
reference to `max_stop_distance_pct` anywhere under
`trading/trading/weinstein/snapshot/`. So the published picks include candidates
the backtested strategy drops with `Stop_too_wide`. On 2026-08-14: **INVX 17.6%,
DMLP 18.1%, NOV 22.1%, E 25.0%** — 4 of 20. Confirmed independently: an arm-B
diagnostic with `Demote_over_max` armed returned a **byte-identical** candidate
set, i.e. the flag is unread on this path and the A/B could not have been
informative.

The questions are in the published report itself for the user to comment on.
**Do not change it unilaterally** — the gate selects against fast movers off deep
bases, which is the population the record arm profits from
(`project_max_stop_filters_structural_stops`).

### F1 — G3, the seam is one line

Design: `dev/plans/g3-reserve-cash-design-2026-08-18.md`.
`Entry_audit_capture.check_cash_and_deduct` already enforces cash discipline
*within* a tick; the leak is *across* ticks, because `entry_walk.ml:168`
re-seeds `spendable` from `portfolio.cash` every Friday and a ticket resting
since week N has taken no cash. Subtract the `Entering`-state longs' designed
cost, behind a default-off `reserve_cash_for_resting_tickets`.
**Verify the fill-vs-`on_market_close` ordering first** — that is the one real
correctness risk and it is a unit test, not a backtest.

## What this session settled

| | |
|---|---|
| **#2376** | **TTL re-screen REJECT.** Draws 176.36 / 174.83 / 182.28 vs the null's 265.44 / 281.71 / 397.95 — no overlap, worse maxDD. Tripwire reproduced 281.707836178685 exactly. |
| | **The why:** the re-screen is a de-facto **22-week cap** (max fill age 865wk → 22wk) that kills the 5-13wk profit band (+7,511 → −2,271/trade, −45% realized). **Condition-based and time-based cancellation select opposite populations** — every time bound cuts a net-*losing* cohort, while the re-screen cuts pullback-then-resume winners, which *is* the base-building pattern. Spread 132.5pp → 7.45pp: the dispersion was the tail. |
| **#2371** | Ticket-funding cohort measured: **not a near-miss population** (p50 shortfall 52%, only 5.1% within 5% of fundable, 63% arrive in bursts). Reorders the axes — G3 first, G2b second with min-size-fraction as *the* dial, G2a last. |
| | Also: the demoted-wide cohort is **derivable** from persisted fields (no schema field), and stop width is **bimodal by construction** (`Buffer_fallback` 2.3% vs `Support_floor` 13.2%) — reproduced live in the 08-14 picks. |
| **#2368** | TTL narrowing, **plus a correction to my own claim**: my "mis-join" diagnosis was refuted in QC and the refutation is right — a re-pairing preserves the total, and the totals move (+141,295) with differing n. Correct calibration is "not reproducible", not "mis-joined". |
| **picks** | 2026-08-14 published. Fetch 3,174/3,174 0 errors; warehouse 3,174/3,174 verified; validator 0 errors / 1 known FBRX warning. |

## Process notes worth keeping

- **A stall and a killed waiter look identical in the log.** When a background
  waiter reports "completed", check whether the *chain* is still alive
  (`pgrep -f <script>`) before concluding anything died.
- **Check whether a committed spec still asks the question you want.** The
  committed `03-ttl26` arms the re-screen *and* the clock; after the re-screen
  REJECT that arm is confounded and would have burned 1.5h. A single-knob diff
  from the null is the spec that answers it.
- **The picks pipeline needs `EODHD_API_KEY` passed through explicitly.** It
  lives in the **host** env (`~/.zshenv`), not the container env and not
  `trading/analysis/data/sources/eodhd/secrets`. Use
  `docker exec -e EODHD_API_KEY="$EODHD_API_KEY"`. Full pipeline is ~15 min:
  fetch (3 min, 12-way parallel) → warehouse (9 min) → generate → render.
- **`portfolio.sexp` is still the $100k template** (last touched 07-24), so all
  sizing is template sizing and no held-position stops were reviewed.
