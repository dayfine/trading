# Weekly-close stop — lens screen: NO-BUILD / no-promote (2026-06-19)

Phase 3 of the overnight arc. Screened the `trigger_on_weekly_close` dial (PR
#1655, default-off) against the long-only Cell-E baselines in two regimes —
deep 1998-2026 (multi-regime) and 2011-2026 (bull). The hypothesis (from the
decision-grading insurance decomposition + user insight): the stop is
whipsaw-dominated, so a weekly-close trigger should recapture foregone upside.

## Result — decisively WORSE in both regimes

| window | config | return | trades | MaxDD |
|---|---|---|---|---|
| deep 1998-2026 | baseline (intra-bar stop) | +1934.5% | 1061 | 48.7% |
| deep 1998-2026 | **weekly-close** | +1477.3% | 831 | 43.8% |
| 2011-26 bull | baseline (intra-bar stop) | +790.5% | 671 | 29.2% |
| 2011-26 bull | **weekly-close** | +376.4% | 566 | **34.2%** |

- Deep: −457pp return for only −5pp MaxDD (worse return/MaxDD: 39.7 → 33.7).
- Bull: return **halved** (−414pp) AND **MaxDD up 5pp** — strictly worse on both.

The flag works (−230 / −105 fewer stops = the intra-week whipsaw exits
eliminated, not a no-op). But fewer stops did not help.

## Decision-level (grade horizon 26w) — the stop decision got worse on every axis

stop_loss group, baseline → weekly-close:

| metric | deep base | deep wclose | 2011 base | 2011 wclose |
|---|---|---|---|---|
| n stops | 746 | 496 | 440 | 334 |
| mean realized | −1.2% | −2.7% | −2.8% | −5.3% |
| net value-add | −6.2% | −7.3% | −9.4% | −11.9% |
| mean capture | −3.64 | −3.49 | −2.83 | **−8.40** |
| disaster dodged | −19.5% | −19.5% | −18.9% | **−12.8%** |

Weekly-close gives WORSE realized, WORSE net value-add, and (2011) WORSE capture
AND *less* disaster dodged — because the stop now fills at the Friday close after
riding the breakdown deeper, so the "dodge" measured from that worse exit is
smaller.

## The transferable WHY (the valuable output)

The whipsaw the lens measured is **real but not recapturable by a looser
trigger**, for two compounding reasons:

1. **The strategy already re-enters recoverers.** The intra-bar stops that "whipsaw"
   fire mostly on names that dip then recover — and laggard-rotation / weekly
   re-screening *buy them back*. So eliminating the whipsaw exit does NOT add the
   upside back (we'd have re-bought anyway); it only removes the fast loss-cut.
2. **Weekly-close makes us hold genuine breakdowns to Friday** = deeper fills on
   real Stage-4 collapses and losers-run-longer. In a momentum / fat-tail
   strategy that is exactly backwards: the edge needs losers cut fast and winners
   ridden; weekly-close does the opposite on the loss side.

So the intra-bar GTC stop's "cut fast, intraday" is **doing its job** — the
per-decision "forgo more upside than disaster dodged" is the *inherent cost* of a
fat-tail strategy where most stopped names are noise that recovers, and the
system's correct response is the **existing re-entry**, not a looser stop. The
stop earns its keep as rare genuine-collapse insurance, and the intra-bar trigger
delivers that better than weekly-close.

This **closes the stop-tuning thread** and tightens the program's spine
(`project_edge_is_the_fat_tail`, `project_accuracy_is_unreachable_diversify_instead`):
holding-discipline tweaks that touch the cut-losers-fast mechanism **backfire**.
It also re-frames the (a) deep stop finding: the stop's per-decision negativity is
not a fixable inefficiency — it's the structural premium of the fat-tail edge.

## Verdict + disposition (screen-rigor calibrated)

- This is a **read-only screen across 2 regime windows + a decision-level grade**.
  Top-level, decision-level, AND both regimes agree: weekly-close is worse. That
  is sufficient for a **no-promote DECISION** — the dial stays **default-off** (as
  merged in #1655), recorded as a **REJECT axis**.
- **Phase-4 WF-CV is correctly skipped**: a mechanism that is decisively worse on
  both the full multi-regime window and the bull window, at both the top and
  decision level, does not warrant a walk-forward sweep (the promising-only gate
  in `dev/notes/overnight-plan-2026-06-19.md` is not met). WF-CV could not
  rehabilitate a uniformly-worse mechanism.
- The flag remains a valid, tested, default-off axis on `main` — available if a
  future, differently-motivated hypothesis wants it — but it is not promoted and
  not recommended.
