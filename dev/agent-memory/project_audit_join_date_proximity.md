---
name: project-audit-join-date-proximity
description: "51% of trades.csv rows lose all four audit-derived columns because the audit join is 7-day date-proximity; the \"ticket age capped at ~1 week\" caveat is circular, an artifact of that window."
metadata: 
  node_type: memory
  type: project
  originSessionId: f38d1024-5259-467e-95cf-9aa2c8fe4ddb
  modified: 2026-08-14T01:29:37.951Z
---

`Trade_context._lookup_audit_for_trade` joins audit records to trades by
`(symbol, entry_date)` with a **7-day** proximity fallback
(`_audit_lookup_window_days`). Measured 2026-08-13 on a 288-trade run:
**147 rows (51%) lose the join**, and `entry_stage`,
`stop_initial_distance_pct`, `position_id`, `stop_fill_distance_pct` are
empty on *exactly the same rows* — one join failing, not four column bugs.

For all 147: the symbol has audit records, all candidates precede the trade,
and none is within 7 days. Mean gap to the nearest prior record **96.7 days**,
max **1322**.

**The circular caveat.** Ladder-v4 spec headers say "ticket-age-at-FILL is
structurally capped at ~1 week until the position_id join lands". That cap is
the join window reflected back: a ticket resting longer has no audit record
within 7 days of its fill, so it never appears as an aged ticket — it appears
as an empty row and drops out. Any audit-derived statistic computed over
trades.csv before the fix was computed on the ~49% that filled promptly, which
is the **opposite end** of the distribution from the resting-ticket behaviour
the entry-ticket program is trying to measure. Treat every such number as
suspect, not merely noisy.

Widening the window is the wrong fix — at a 96-day mean gap "most recent
record within the window" stops being identifiable and would silently attach
the wrong decision. The key exists on both sides (audit has
`entry.position_id`; the simulator has position ids) but
`Round_trip_pairing.trade_metrics` carries none, so it is lost at pairing.
trades.csv's own `position_id` column is an *output* of the join, not an
input.

**It wrote WRONG values, not just empty ones.** Post-fix re-run of the same
async spec (PR #2317): population 49.0% → 100.0%, and `trades.csv` cols 1-10 +
equity_curve + summary + actual.sexp all **identical** — reporting-only, no
trade moved. But three stop-info-derived columns changed: `entry_stop` /
`exit_stop` on 9 rows and **`exit_trigger` on 49**, all previously unjoined —
while only **29** had been *empty*. With no position_id the fallback took
`stop_first_by_symbol`, the FIRST stop_info for that symbol regardless of round
trip, so any symbol traded more than once had later trades inherit the first
trade's trigger and stops. Distribution moved stop_loss 187→198,
laggard_rotation 72→89, and **stage3_force_exit 0→1 — an exit mechanism showed
zero firings purely because its trades lost the join.**

So any grouping of async-config trades by `exit_trigger` is **suspect, not
merely incomplete** — including the "laggard rotation = profit channel" reading
in [[project_trade_forensics_2026_06_12]] (+24% laggard exits here). Recompute
against a post-fix run before citing.

Diagnosis: `dev/notes/audit-join-root-cause-2026-08-13.md` (PR #2316).
Fix: PR #2317. Closes carried-forward #18 and #4 — they are one bug.

Related: [[project_faithful_ticket_structural_exclusion]],
[[feedback_always_dissect_before_reporting]].
