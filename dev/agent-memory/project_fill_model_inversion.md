---
name: fill-model-inversion
description: "Fill-model program CONCLUSION 2026-08-06: the record is a DIFFERENT coherent rule (market entry + deep floor), not a flattered book ticket — book ticket honest ≈ +280% vs record +8,367%; AXTI unreachable under book ticket from either side"
metadata: 
  node_type: memory
  type: project
  originSessionId: b2f0f179-e194-4bcc-956f-27560b15d067
---

Eight-arm 26y ladder (notes: fullbook-ladder-2026-08-06 + localtop-deepdive +
honest-ladder): the +8,367% record rule = market entry after weekly Stage-2
close + DEEP structural floor stop + extension insurance — a coherent,
live-executable rule. Every book-ticket variant (resting stop @ E, band 2,
base-anchored stop per #2219) lands +180%..+500% honest; best risk profile =
fullbook-graded (+287%, MaxDD 23.2%). SPY-TR ≈ +687% same window.

**AXTI closes the argument**: 76% of the record in one trade; under the book
ticket it is unreachable BOTH ways (deep floor → Stop_too_wide gate ×24;
#2219 base stop → stopped out next day at +0%/−3%, twice). The wedge = (1)
sub-E base/pullback fills, (2) deep floors surviving noise that kills tight
base stops, (3) monster rides — three fat-tail channels, one law
[[project_edge_is_the_fat_tail]].

**OPEN USER DECISION**: (A) align live tickets to the record rule
(market/limit-at-open + deep floor stops) — honest match to +8,367% basis,
worse DD (37 vs 23), extreme concentration (1 trade = 76%); or (B) re-base
records to the book ticket (~+280%/DD 23%). All flags
(enable_sim_entry_stoplimit, sim_entry_trigger_at_suggested,
entry_anchor_local_range_weeks, stop_anchor_at_entry_base) default-off, R2
axes; promotion only via WF-CV + grid. ELI corrupt-bar lesson: stop-fill
models trigger on phantom zero-volume highs — arm spike filter for stop runs.
[[entry-trigger-decision]] [[bke-order-diagnosis]]

**2026-08-07 UPDATE — the A/B is CONFOUNDED by a stop-gate axis (reframes it).**
Deep-dive trace (notes: fill-model-fix-findings-2026-08-07): (1) record fills at
the **Friday weekly close** it decides on (entry_audit_helpers.ml:49-51) — a
realism gap, not a bar_reader lookup (Market entry; fill set in engine matching
→ Fix#1 is a cross-cutting engine change). (2) book's E floats up weekly
(screener recomputes breakout_price) → it **chases the extension** (BDLN 79.81
Mar vs record 50 Jan) → Fix#2. (3) **Deep stops = the edge** and are a SEPARATE
axis entangled in the comparison: control/cap15/trigonly all carry 94%-wide
support-floor stops under an UNLIFTED 15% gate; only stop_anchor_at_entry_base
(a book flag) caps them. Ablation 1b-wide-stops proves the gate DOES reject wide
stops unless lifted — yet no committed staging scenario lifts it. So either (a)
committed record-convention doesn't reproduce the record (re-run recipe broken),
or (b) support-floor bypasses the gate — distinguished only by a trade_audit
regen (deferred, disk). **Consequence: the +8,367 vs +287 gap is NOT fill-timing
alone — the honest re-run must HOLD THE STOP GATE FIXED across both arms.**
ALL MERGED 2026-08-07: V12 invariant (installed stop ≤ gate, #2236 — standing
guard; #2229 died to GitHub's base-branch-delete auto-close, lesson: retarget
child PR base BEFORE merging its parent with --delete-branch) + faithfulness
harness (#2230, per-year whipsaw/hold/stop-width + 2-arm divergence, reproduces
the manual numbers; QC added parse_trades/run-branch pins) + docs #2227. Whipsaw signature:
record 0-16%/yr ≤3d-stopouts vs book 39-59%. [[edge-is-the-fat-tail]]

**2026-08-07 PM — CONFOUND RESOLVED: metric artifact, not (a)/(b).** Regen of
the committed control scenario = **bit-identical** to the record (+8,366.8%,
1122 trades) → recipe/configs sound. V12 on regen audit: only 29/1122 (2.6%)
violations, all 15-20% decision-close→fill-price drift; gate fires in-arm (CRA
Stop_too_wide). The "62%>15% / max 94%" was `stop_initial_distance_pct`
measured vs **suggested_entry (chased E)**, not the fill (trade_context.ml:171).
WDC specimen: E 14.57 / floor-stop 4.44 / fill 4.75 → 6.5% vs fill (compliant),
69.5% vs E (the fake "deep stop"). **Record stops ≈ gate-compliant vs cost; the
edge is the FILL BASIS**: market@close ≪ chased E (3× cheaper, 3× shares,
stop-near-basis) — record enters WITHOUT price reaching suggested E. Stop-gate
axis dissolves as confound; A/B isolates to fill basis. Fix#2 (no-chase E)
directly narrows the arms; Fix#1 cleans the 29 drift cases. Follow-up: add
fill-basis stop-distance col (V11's 250 hits = same E-basis artifact).
