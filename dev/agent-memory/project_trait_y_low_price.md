---
name: project-trait-y-low-price
description: "Low price lifts monster rate 2-4x, win rate flat; price tiebreak closed: binding CLOSE-AXIS (#3602) + confirm NO-BUILD (#3610: C2 top-1000 FAIL, C1 replays 26y half); gap = few sub-top-1000 names"
metadata:
  node_type: memory
  type: project
  originSessionId: 249246cf-fc3d-457f-8536-5d3b905a45a5
  modified: 2026-11-13T09:27:18.452Z
---

User challenge (11-12): screens on our own trades can't rule out a trait Y that finds monsters better. Built the
unconditional population host-only (scratch `monster/`: PREREG.md written before results, `mscan.awk`,
`ytrait2/3.awk`; not committed): every weekly close > 26-wk high on >= 2x 4-wk volume, close > rising 30w WMA,
raw close >= $5, PIT top-3000 member (pit-v12 yearly lists), one event per symbol per 26 weeks. Outcomes:
monster = 2x within 52 wk (7.7 %); ride = return to the first weekly close below the WMA (cap +190 % = p99.5,
amendment 1, after VPI/NDN/TRA/LDG/LAF vendor-splice errors swamped means). Cut-offs fixed on 2000-12, held out 2013-25.

- Heat traits (vol26, ext, ret26, depth, ath gap) raise the monster rate 2-3x but lower win rate / EV in one half.
- **Low price passes**: monotone; $5-8 monster 21 % / 20 % (vs 4-6 % above $33), capped mean ride +8.1 / +8.6 %
  (population +1.7 / +3.1); win rate flat 39 % in every band; wider spread (p25 -18 / p75 +19 vs -11 / +8).
  "Far below ATH" passes narrowly (13-25 EV edge within noise).
- Strategy under-samples it: 11 % of our trades <= $14 vs 17 % of breakouts; 60 % > $33 vs 50 %. Our <= $14 slice
  earns +1.22 NAV-%/trade but minus ADSK/APPS/ADMA only +0.10 (tail-driven, not independent evidence).
- Funnel (v1 monster file, 08-23): low-priced monsters die more at the breakout gate (51-52 % vs 34 % > $33) and are
  admitted less (3.2-3.7 % vs 5.1 %); per-drop sub-reason is not recorded (needs candidates.sexp instrumentation).

**Why it matters:** first trait in the program that shifts the tail without the heat trade-off.
**How to apply:** not a filter -- a candidate ranking/gate change; book has no price rule (Ch. 5 big winners are often
low-priced: W2 justification needed). Next: find which breakout sub-gate drops low-priced monsters; then a
default-off variant + K=5 paired 26y run; check capacity (ADV at late-run NAV) and the cash-displacement law
([[project_floor_and_refresh_screens]] SN). Related: [[project_monster_funnel_top_of_funnel]],
[[project_accuracy_is_unreachable_diversify_instead]].

**11-13 K=5 26y test (#3587 Price_band_seeded, pre-reg #3588 at 1034b458e, results #3595): NOT LIVE as written.**
The ≤ $14 entry share was 1.219× S's against a 1.3× bar, so no return read was made. The proxy was mis-set: the band
order changes the top-20 on 67 % of the Fridays both arms record, mostly by demoting ≥ $33 names (59.3 % → 51.7 % of
entries); no price cut-off reaches 1.3×. Described only: P beat S in 5/5 seeds (median Δ ln +0.348). That is about
2.2–2.4 SD under a shared-draw bound (one-sided p ~0.01–0.02 on a normal curve, ~0.04 on t4 with five values per arm), since the five P cells share one fixed cross-band order; 1/252 is a floor. Max DD
was +5.6 pp deeper (arm medians) and the Ulcer index higher in 5/5. The gap is the one-arm positions: about 70 %
comes from 2010-12 entries (MERC, ATML, WAL, DINO, REGN; P 4-5 seeds vs S 0-1) plus ADMA 2023 (P 5/5 vs S 3/5), and
2018-23 runs against P in 5/5. **Lesson:** set liveness from the per-decision binding rate, never a downstream
share × multiplier (same error as floor-nearest). **Next (user 11-13):** one S k0 cell with `--emit-candidates`, giving
the exact binding rate plus the breakout sub-gate that drops cheap monsters. Only then decide on a fresh pre-registration
and broad-vs-broad confirmation cells (2013-26, top-1000).

**11-14 binding diagnostic (pre-reg #3597 at c0991e023, read #3602): CLOSE-AXIS (Rule 1 branch 3), keep-as-axis;
Rule 2 NO CONCLUSION (immaterial).** One S-k0 cell with `--emit-candidates` (byte-identical to #3595 pb-S-k0), re-ranked
offline under Price_band_seeded. The cut sits inside a score tie on 84 % of open dates; the band order changes the top
20 on 69 % (both halves); 91 % of names cut are ≥ $33, every name promoted < $33. Promoted names double 3.07× as often
(205 monsters) but their capped 30w-WMA ride ties (+4.0 vs +4.1 %: higher p90, deeper p10, lower win rate). Branch 3
fired on that −0.1 pp, a zero a read defect also touches (2025-26 truncated swaps classed delisted: fwd.awk STORE_END =
latest bar of an uneven store), so CLOSE vs PARK is a coin flip; FRESH was out of reach (L2 0.953 < 1.5); both spend
no cells. **Why:** 95 % of top-20 slots never fund (`No_structural_stop`; cheap names worst, 3.0 vs 5.8 %), so 1,744
swaps re-draw only 84 tickets in 26 y ≈ one expected doubler ≈ 0.10-0.18 log: under the 0.2 floor and 30-50 % of
#3595's +0.348; the rest is one shared draw (seed 0: MERC 2010-11-12 and ADMA 2023-08-18 were cut swaps P placed --
MERC's "unresolved channel" was the cut). Breakout-phase loss of cheap monsters is `Stage_setup` at lift ≤ 1: breadth,
not anti-selection. **How to apply:** no more ordering/tiebreak levers on price, no band-edge sweep; a re-order reaches
the book through ~5 % of its swaps (funnel law, as floor/refresh/top-N). `--emit-candidates` costs ~0 wall, +3.3 GB RSS.
#3598 (C1 2013-26, C2 top-1000) is read on its own rule; an ESCALATE there meets this CLOSE-AXIS and goes to the user.

**11-14 confirmation cells (pre-reg #3598 at 04ca2ff0b, read #3610): NO-BUILD (C1 INCONCLUSIVE, C2 FAIL), keep-as-axis;
no more cells without a new mechanism argument.** Both cells live (lists differ on 62 % / 58 % of Friday-pairs, ≥ $33
signature 82 / 75 pp). C2 (top-1000, 2000–26): median Δ ln −0.280, 1/5 positive. C1 (top-3000, 2013–26): +0.139 (3/5)
< δ 0.20, DD +3.83 pp, trim 1/5. **Why:** #3595's +0.348 was a few cheap names below the top 1,000 by dollar volume
(+197 of +205 pooled points, 5/5 seeds, cuts 500–2,000; MERC/WAL/DINO/REGN/ADMA not in the top-1000 lists),
replicated across seeds. On top-1000 a seventh of the promoted names are cheap (vs 2/5), the visible cut swaps net ~0,
and the draw went to S (TSLA; AVGO via a fill-time cash rejection). C1 replayed #3595's 2013–26 half: Seeded hashes
seed|date|ticker and sizes are NAV fractions, so same-seed paths re-synchronise (identical positions from 2015–19, all
by 2023) and C1's Δk matched #3595's increment seed by seed (ADMA cut lottery, SAGE cash lottery, k0/k3). **How to
apply:** the price-order axis is closed; a nested window on the parent's seeds re-measures the parent after 2–6 y, so
period cells must be disjoint; top-N-cut levers' top-3000 gains sit in the lower 2,000 names, so run the top-1000 cell
early (cf. cap 40). Found a #3109 specimen: CERN 2013-07-01 phantom 2:1 rescale in C2 S-k0 (+9.9 % NAV day).
