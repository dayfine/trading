# What we can change vs what we must design around (2026-06-12)

Synthesis of: the two rolling-start matrices (`dev/experiments/
rolling-start-matrix-2026-06-11/`), the trade-level forensics (`dev/
experiments/trade-forensics-2026-06-12/`), the structural-bar frame
(`memory/project_index_beating_structural_bar`), and the accumulated WF-CV
rejection ledger. Task: separate actionable levers from structural facts so
future sessions stop re-testing the unchangeable.

## A. STRUCTURAL — cannot be changed; design around these

1. **Sharpe's arithmetic / the skewness tax.** The strategy will not beat
   total-return SPX on median CAGR in any regime (~+1pp median edge in both a
   bull window and a bear decade, n=51 starts). Stage-based exits are
   definitionally winner-touching; cap-weighted indexing holds every
   mega-winner forever at zero cost. STOP proposing levers whose thesis is
   "capture more of the index's upside" — six winner-touching mechanisms have
   failed WF-CV; the matrices now show the ceiling itself.
2. **Concentration IS the return.** Top-5 trades = 165% of bull realized P&L;
   one ticket (AXTI) ≈ 100% of terminal bull NAV; bear-decade realized nets to
   ~zero outside the recovery-leg carry. This is Bessembinder skewness flowing
   through the strategy, not a sizing bug. Any mechanism that caps/trims/
   rotates the right tail re-fails for the same reason.
3. **Give-back is the price of the tail.** MFE>20% cohort gives back 82pp of a
   142pp average peak. Tightening exits to "capture MFE" converts the one
   thing that pays (36× rides) into mediocre banked gains — rejected
   repeatedly (hysteresis, late-flag, harvest-rotate). Treat give-back as
   COGS, not waste.
4. **Gap risk through stops.** 70% of stop exits are gap-downs costing ~2.4pp
   beyond intraday-stop fills. Weekly cadence + overnight gaps make this
   unremovable by stop placement; only entry quality/size reduce its base.
5. **Regime-dependence of per-trade edge.** Payoff ratio 4.7 (bull) vs 2.2
   (chop) at identical ~34% win rates; entry-type ranking FLIPS across decades
   (early-Stage2 +34.6%/trade post-2011, −1.9% in 2000-2011). Single-window
   tuning of entry weights is regime-fitting — the confirmation-grid rule
   exists for exactly this.
6. **The strategy's real product is distribution compression** (worst-start
   edge −4.9pp in the bear decade vs −28pp in the bull; DD halved through two
   crashes; protection delivered by entry SUPPRESSION via the macro gate, not
   by better picks). Sell it as that — a convex SPX-complement for the
   barbell — not as an alpha engine.

## B. CHANGEABLE — real levers, with priors

1. **Universe composition (in flight).** Policy layer merged (#1537-#1540);
   $-volume wired (#1542). Emit the ~top-4000 policy artifact; rerun baselines.
   Known-positive prior (breadth robustly helps: realized 3×, DD tail capped).
2. **Short-side hygiene (NEW, from forensics G5 + margin research).** The
   "long" baseline carries Stage4-breakdown shorts that are (a) net-negative,
   (b) unrealistic — no margin model, and sub-$17 shorts face 83-362%
   capital requirements (FINRA tiers; THM at $0.69 is uncarryable). Lever:
   default-off the short entries in long presets, or gate shorts on price
   ≥ ~$17 + margin-aware sizing per
   `dev/notes/long-short-margin-mechanics-2026-06-12.md` §4. LOW controversy.
3. **Laggard-rotation trigger latency.** The de-facto profit channel exits
   30/24pp below local peak (bull/bear). It is laggard-touching, not
   winner-touching, so it escapes the standing prior — eligible for a
   default-off `rs_neg_weeks` / RS-window surface under WF-CV. Skeptical
   prior anyway (it already won a keep-ON verdict as-is).
4. **Mid-regime entry bleed.** The bleed cohorts are specific: 2013-2018 and
   2006-2007 ENTRY years (negative-edge start clusters + negative realized
   year buckets). Half of stop-outs die in ≤11 days — failed breakouts.
   Diagnostic lever, not a knob: characterize what distinguishes the
   2003/2011/2020 entry vintages (post-bear base depth? breadth thrust?
   sector dispersion?) and consider a REGIME-quality gate on the breakout
   entry type only. This is entry-quality work — the one search direction the
   fat-tail principle endorses.
5. **Position-count / sizing interaction with the tail.** 14%-at-entry sizing
   plus never trimming produced a 99%-NAV single position. The tail must be
   kept, but the BARBELL (floor+engine, #1434/#1435) is the sanctioned way to
   make the resulting NAV path survivable. Allocation-level lever, not
   strategy-level.
6. **Measurement honesty (cheap, compounding).** Stale-exit flag ON for audit
   runs (G3); realized-basis + start-matrix as standard scoreboard; A1
   min-window guard; A2 fold corruption fix; G1/G2 ledger bugs. All shipped or
   queued this session.

## C. The one-sentence operating thesis

Run a breadth-maximal, entry-quality-gated Weinstein engine for its
distribution-compression and post-bear convexity, sized inside a barbell
against an index floor — and stop spending search budget on anything that
touches winners, tightens exits, or tunes entry weights to a single regime.
