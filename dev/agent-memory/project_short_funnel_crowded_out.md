---
name: project_short_funnel_crowded_out
description: "CORRECTION to the (c) long-short no-build (2026-06-19): shorts are NOT anemic because the signal is rare or bad — the cascade OFFERS 1,662 short candidate-slots over 28y but only 37 ENTER (2%), with ZERO short fills rejected. Shorts are crowded out at the entry stage: candidates are appended after longs (buy_candidates @ short_candidates) and the entry walk exhausts capital/exposure on longs first, so shorts are never reached. Untested lever = a RESERVED SHORT SLEEVE (dedicated short exposure budget). 'We're not doing shorts effectively' is TRUE — it's a capital-allocation problem, not a signal problem."
metadata: 
  node_type: memory
  type: project
  originSessionId: 06e3a32c-0461-446d-9867-17df83bd1d6d
---

**Amends [[project_short_side_reprioritize]] and the (c) long-short screen
(`dev/experiments/decision-grading-longshort-2026-06-18/`).** The (c) verdict
("short leg anemic, 37 trades/28y, ~breakeven → no-build") was correct about the
SYMPTOM but wrong about the CAUSE. User pushed 2026-06-19: "maybe we are not doing
shorts effectively?" — correct.

**Short funnel (deep 1998-2026 long-short run, cumulative candidate-slots across
1,425 Fridays, from trade_audit.sexp cascade_summaries):**
- macro-admitted 689,246 → breakdown (Stage-4) 90,429 → RS hard gate 12,721 →
  grade 9,620 → **top-N offered 1,662 → actually ENTERED 37 (2%)**.
- **0 short (Sell) fills rejected** (11 long Buy rejections). So shorts that were
  ATTEMPTED all succeeded — the 1,662→37 collapse is shorts being **never
  reached**, not rejected.

**Mechanism:** `_screen_universe` concatenates `buy_candidates @ short_candidates`
(longs FIRST); the entry walk consumes capital + the `max_long_exposure 0.70` /
`min_cash 0.30` budget on longs before reaching the appended shorts. Shorts only
enter (37×) in deep-bear weeks when longs got stopped out and freed room. So the
short leg is **crowded out by entry ordering + the long exposure budget**, NOT by
signal rarity, signal quality, or cash rejection.

**Untested lever = RESERVED SHORT SLEEVE:** a dedicated short exposure budget
(e.g. reserve X% of capital/exposure for shorts, sized + walked independently of
the long book) so shorts get capital regardless of long demand. Weinstein-faithful
(he runs long+short simultaneously in bear markets). Default-off config
(`experiment-flag-discipline`); screen with the decision-grading lens (do the now-
numerous shorts add a real offsetting/DD-reducing leg?) → WF-CV → grid. This is a
PORTFOLIO-ALLOCATION lever (structural diversification, the live class per
[[project_edge_is_the_fat_tail]] / [[project_accuracy_is_unreachable_diversify_instead]]),
NOT a selection tweak — distinct from loosening the cascade (which would violate
the Ch.11 spine).

**Calibration (mechanism-validation-rigor):** CONFIRMED = 1,662 offered / 37
entered / 0 rejected. INFERRED (well-supported, not yet isolated) = the binding
constraint is long-first ordering + exposure budget; a reserved-sleeve build +
screen is the test. Do NOT re-conclude "shorts work" until the sleeve is screened.

**STATUS 2026-06-19:** diagnosis done (read-only). Reserved-short-sleeve = NOT
built. Candidate next lever alongside vol-scaled stop ([[project_weekly_close_stop_lever]]
§stop-quality-levers-beyond-weekly-close).

**STATUS 2026-06-19: BUILT + MERGED #1659.** Default-off
`Weinstein_strategy_config.short_sleeve_fraction : float [@sexp.default 0.0]`.
When `> 0.0`, `entries_from_candidates` partitions the per-Friday cash budget into
a reserved short-only budget (`fraction * portfolio_value`) walked independently
of the long book (two `remaining_cash` refs, shared `short_notional_acc` /
`sector_exposure_acc` so caps still bind); `<= 0.0` bit-identical. Tests confirm
the crowd-out (3 longs exhaust cash → 0 shorts) flips to a short entering at
fraction 0.3. Searchable nested `Variant_matrix` axis; NOT wired into any preset.
**The build only proved shorts now ENTER — it did NOT prove they HELP.** NEXT =
lens-screen `short_sleeve_fraction` ∈ {0.1,0.2,0.3} via `decision_grading`: do the
now-numerous shorts add a real offsetting/DD-reducing leg, or churn at ~breakeven
(the (c) symptom)? Real offset → WF-CV + grid; else record no-build-with-why
(capital reserved for a non-paying leg = drag) and keep default-off.
