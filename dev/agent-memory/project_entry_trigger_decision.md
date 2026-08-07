---
name: entry-trigger-decision
description: "USER DECISION 2026-08-05: entry orders must be book-faithful — resting StopLimit at screener E, not close-anchored (Step 0 = option b); plus execution-faithfulness audit directive"
metadata: 
  node_type: memory
  type: project
  originSessionId: b2f0f179-e194-4bcc-956f-27560b15d067
---

2026-08-05 user decision closing the fill-model arc
([[bke-order-diagnosis]], plan `dev/plans/gtc-breakout-orders-2026-08-05.md`
Step 0 = option (b)): **sim entry orders must follow the book — StopLimit
resting at the screener's `suggested_entry` E** (with the do-not-chase band),
not the G14 close-anchored trigger. Build: `sim_entry_trigger_at_suggested`
default-off flag (sizing at E; split-safety verified vs the G14 rationale),
then re-derive the fill ladder honestly + WF-CV before any record re-basing.

**Second directive (same session, verbatim intent):** trade audit must cover
EXECUTION QUALITY/FAITHFULNESS — per-trade designed-order (type/trigger/band)
vs actual fill (`fill_vs_trigger_pct`, `fill_within_band`, `faithful` flag),
surfaced in trade_audit_report with a %-faithful summary. Rationale: the G14
close-trigger divergence sat invisible for months because nothing audited
fills against the designed ticket; BKE-at-18 would have been flagged on day
one.

Context: the 2026-08-04 ladder (market 84.7× / stop-Day 29.5× / cap15 42.1×)
measured close-triggered arms — NOT E-anchored; honest E-based numbers don't
exist yet. Records may re-base materially once they do; that follow-on
decision stays with the user. [[sim-entry-stoplimit-reject]]
