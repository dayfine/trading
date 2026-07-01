---
name: project_decision_audit_records_directive
description: User wants per-screen (weekly) auditable decision records — funded AND high-ranking screened-out/cash-rejected near-misses — to reason about selection soundness and find better levers
metadata: 
  node_type: memory
  type: project
  originSessionId: 0c7858d2-833f-4476-81e6-39b51c91c245
---

2026-06-29 user directive (AFK overnight). Beyond the funded trades, the user
wants **screen-by-screen (weekly — screening is Friday-only per
`weinstein_strategy_screening.ml` `is_screening_day_view`) auditable records**
that also capture the **high-ranking candidates that were screened out / missed**
(the cash-rejected `alternatives`), not just the trades taken. Purpose: reason
about the soundness of the selection/decision-making and identify more optimal
options.

**Why:** the tiebreak/selection lever bites overwhelmingly at the CASH boundary
(~97% of entry decisions cash-constrained; ~5 fundable slots vs up to 20
screened, `max_long_exposure 0.70`/`max_position 0.14`). To judge whether
selection is sound, we must see the *near-misses* alongside the *takes* per
screen — were the funded ~5 actually better than the cash-rejected ones?

**How to apply:** the data is ALREADY captured — `Audit_recorder.entry_event`
carries `alternatives : alternative_input list` (cash-rejected candidates +
`skip_reason`) and `record_cascade_summary`. The gap is a *per-screen readable
report* surfacing funded + near-miss candidates with scores/features. Check
existing `trading/trading/backtest/decision_grading/` + `trade_audit_report/`
infra first (much may exist). Pairs with [[project_cascade_selection_inversion]],
[[project_screener_alphabetical_tiebreak]], [[project_edge_is_the_fat_tail]].

**Companion idea (same convo):** noise-floor control tiebreaks (reverse-alpha,
symbol-length, deterministic hash≈random) to bracket selection noise — if all
uninformative sorts cluster and RS/earliness sit inside, "no sort beats unbiased
sampling" is proven + quantified.
