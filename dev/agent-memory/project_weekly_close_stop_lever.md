---
name: project_weekly_close_stop_lever
description: "Lens-driven stop improvement (user insight 2026-06-19): the decision-grading insurance decomposition showed stop_loss forgoes MORE upside (+30-33%) than disaster dodged (-19%) → whipsaw-dominated → real improvement room. Confirmed the live stop is an intraday GTC stop on bar.low (shakeout-sensitive); Weinstein L3 = weekly-CLOSE confirmation is the faithful fix. Build as default-off `stop_trigger_on_weekly_close` flag → lens-screen → WF-CV → grid. Plan: dev/plans/weekly-close-stop-2026-06-19.md."
metadata: 
  node_type: memory
  type: project
  originSessionId: 06e3a32c-0461-446d-9867-17df83bd1d6d
---

**User insight (2026-06-19), off [[project_next_lever_decision_grading]] deep stop read:** the
insurance decomposition (PR #1652) showed `stop_loss` mean upside-foregone
(+32.7% bull / +29.9% deep) **exceeds** mean disaster-dodged (−18.9% / −19.5%) →
net per-decision −9.4% / −6.2%. The user's point: *that gap is improvement room*
— the stop is whipsaw-dominated. My earlier "don't touch stops" caveat was about
*removal* (lens blind to portfolio ruin-insurance); it does NOT preclude *tuning*.

**Confirmed mechanism (code):** the live stop is a **GTC broker stop checked
every day on `bar.low_price`** (`stops_runner._trigger_fill_price` → bar low;
`Weinstein_stops.check_stop_hit` = `low_price ≤ stop_level`; runner comment "the
GTC stop sits in the market every day"). So an intra-week shakeout *wick* below
the stop fires the exit even when the week CLOSES back above — the shakeout. A
deliberate broker-realism model, not a bug.

**The faithful lever:** Weinstein L3 (book §Stop-Loss Rules; the qc-behavioral L3
contract) = trigger on the **weekly CLOSE** below the stop, not the intra-week
low. Directly recaptures the foregone upside. Spine item #5 (stop below base/MA)
untouched — only the *trigger confirmation* changes (itself the book's rule) → a
faithful dial, not a spine change.

**Build = default-off flag** `stop_trigger_on_weekly_close : bool [@sexp.default
false]` on the stops config (`experiment-flag-discipline` R1 default reproduces
current intraday-GTC bit-for-bit; R2 axis-able). When on: non-Friday = no
intraday check; Friday = trigger on `close_price` vs stop (close-based
`check_stop_hit` variant). Touches `weinstein/stops` + `stops_runner` (feat-weinstein
scope; the stops state machine's `update`/`Stop_hit` path also needs the flag).

**HONEST RISK to measure:** weekly-close trades whipsaw-avoidance for DEEPER fills
on genuine Stage-4 breaks (Friday close ≪ intraday stop fill). The foregone upside
is partly the fat-tail recovery → a looser exit recaptures it but also rides real
collapses further down. Per-decision improvement ≠ portfolio improvement.

**Disciplined arc:** default-off flag (TDD) → **lens screen** (re-run deep
1998-2026 + 2011 Cell-E with flag on, re-grade via `decision_grading`: does
stop_loss upside-foregone shrink while disaster-dodged holds + net improve? +
top-level return/Sharpe/MaxDD vs long-only deep) → if promising, **WF-CV**
(`((flag stop_trigger_on_weekly_close)(values (true false)))` + Deflated Sharpe) →
**promotion grid** (`promotion-confirmation.md`, ≥3 cells incl. bear-regime)
before flipping default. This is a tail-PRESERVING holding-discipline lever
([[project_edge_is_the_fat_tail]]), NOT the entry/swap-selection dead end
([[project_accuracy_is_unreachable_diversify_instead]]).

**STATUS 2026-06-19 — BUILT (#1655, default-off) + SCREENED + REJECTED.**
- Built the `trigger_on_weekly_close` flag (PR #1655 MERGED, default-off, 33 stops
  tests + 2 new, all goldens bit-identical, both QC APPROVED; needed a `Stop_nudge`
  extraction to stay under the file-length cap).
- **Lens screen — NO-BUILD / no-promote, decisively WORSE in BOTH regimes:**
  deep 1998-2026 +1934.5%/48.7%DD → flag-on +1477.3%/43.8% (−457pp for −5pp DD);
  2011 bull +790.5%/29.2% → flag-on +376.4%/**34.2%** (return HALVED + DD UP). The
  flag works (−230/−105 fewer stops = whipsaw exits removed, not a no-op) but
  decision-level stop got worse on every axis (net value-add −6.2→−7.3 deep /
  −9.4→−11.9 bull; capture −2.83→−8.40 2011; even disaster-dodged SMALLER, worse
  fills).
- **The transferable WHY:** the whipsaw is real but NOT recapturable by a looser
  trigger — (1) the strategy already re-enters recoverers (laggard/re-screen), so
  removing the whipsaw exit doesn't add upside back; (2) weekly-close just holds
  genuine breakdowns to Friday = deeper fills + losers-run-longer, exactly
  backwards for a fat-tail/momentum strategy. The intra-bar GTC "cut fast" stop is
  DOING ITS JOB; the per-decision "forgo > save" is the STRUCTURAL PREMIUM of the
  fat-tail edge, not a fixable inefficiency. **Closes the stop-tuning thread**;
  tightens [[project_edge_is_the_fat_tail]] / [[project_accuracy_is_unreachable_diversify_instead]]:
  holding-discipline tweaks that touch cut-losers-fast BACKFIRE.
- Phase-4 WF-CV correctly SKIPPED (uniformly worse → promising-only gate not met).
  Flag stays default-off as a REJECT axis on main. Writeup:
  `dev/experiments/weekly-close-screen-2026-06-19/FINDINGS.md`.

**STOP-QUALITY LEVERS BEYOND WEEKLY-CLOSE (user 2026-06-19: "still things to
explore in stop quality").** Weekly-close was ONE lever (trigger basis) and
failed for a SPECIFIC reason (holds genuine breakdowns to Friday = deeper fills).
That does NOT exhaust stop quality. The lens-aligned levers it does not touch:
1. **Volatility/ATR-scaled stop distance** — the live stop is a FIXED 8% buffer
   (`installed_stop_min_pct=0.08`) regardless of the name's volatility; a high-vol
   name gets whipsawed by the same buffer that fits a low-vol name. The code
   itself flags this TODO (`stop_types.config.min_correction_pct` doc: "Future
   improvement: derive this threshold from the security's volatility"). Scaling
   the buffer to the name's noise cuts whipsaw WITHOUT holding breakdowns deeper
   (weekly-close's fatal flaw). **Strongest remaining stop-quality lever** —
   attacks the whipsaw at its source (buffer mis-sized to volatility), keeps the
   fast intra-bar cut. Default-off `vol_scaled_stop` flag → lens screen → WF-CV.
2. **Post-stop re-entry** — keep the fast intra-bar stop, but explicitly re-buy a
   stopped name if it re-breaks out within N weeks (recapture the recoverers the
   lens found). Weinstein "Trader's Way" continuation re-entry. Distinct from the
   incidental laggard/re-screen re-entry.
Both UNTESTED. Vol-scaled is the better bet (the whipsaw is buffer-vs-volatility
mismatch; weekly-close failed by changing WHEN not HOW-FAR).

**STATUS 2026-06-19: vol-scaled stop BUILT + MERGED #1662.** Default-off
`Weinstein_stops.config.vol_scaled_stop_atr_mult : float [@sexp.default 0.0]`
(+ `vol_scaled_stop_atr_period [@sexp.default 14]`). When `> 0.0`, the minimum
installed-stop distance becomes `Float.max(installed_stop_min_pct, mult *
ATR/entry)` via new pure primitive `Weinstein_stops.Vol_scaled_stop`
(ATR from `analysis/technical/indicators/atr`); only ever WIDENS the floor
(never narrows below 8%, never loosens a trailing stop), `max_stop_distance_pct`
15% cap still rejects after; `<= 0.0` bit-identical. Wired per-candidate via
`entry_stop_distance.ml`. Searchable nested axis; NOT wired into any preset.
NEXT = lens-screen `vol_scaled_stop_atr_mult` ∈ {1.0,1.5,2.0}: does stop
upside-foregone shrink while disaster-dodged holds (the asymmetry weekly-close
failed)? Promising → WF-CV + grid. **Weekly-close (`trigger_on_weekly_close`,
#1655) stays REJECTED.** Post-stop re-entry still untested.
