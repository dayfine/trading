# Extension-episode event-level screen — FINDINGS (2026-07-11)

P0 of `next-session-priorities-2026-07-12.md`: does a held-position
**extension stop** (once weekly close/MA ≥ K, trail t% below the post-trigger
peak weekly close) deserve a build as a default-off axis? Read-only paired
counterfactual screen per `.claude/rules/mechanism-validation-rigor.md`
(screen-rigor procedure followed; checklist at the bottom).

Tool: `analysis/scripts/extension_screen/` (committed with this writeup).
Inputs: the two current-basis deep runs — honest-tradeable-ext (top-3000 PIT,
2000-2026, end 2026-06-26; 1143 LONG episodes incl. 2 open) and
sp500-2010-2026 (Batch C flip-basis, 587 episodes). Surface swept:
K ∈ {1.5, 1.75, 2.0, 2.25, 2.5, 3.0} × trail ∈ {10, 15, 20, 25}%.
Raw rows: `deep-ht-ext.csv`, `sp500-2010-2026.csv` (one row per
episode × K × trail where the episode ever triggers K).

## Estimand → proxy → gap

The mechanism changes the realized P&L of extension episodes by replacing
their natural exit with a trail exit after the trigger. The screen replays
each episode's own weekly bars (the strategy's WMA-30 basis via
`Sma.calculate_weighted_ma`, same as `Stage.default_config`) and computes the
per-event exit delta. Gaps, both named: it cannot model **re-entry** after a
trail exit nor **redeployment** of freed cash (both understate the
mechanism's benefit); for the two **open** episodes (AXTI, VSAT) the "actual"
side is an unrealized terminal mark, so their deltas are mark-timing
statements, not realized P&L (reported separately below).

## Headline findings

### 1. Extension events are RARE — this can never be a fold-metric lever

| K (close/WMA30) | triggered episodes (of 1730 combined) |
|---|---|
| 1.5 | 36 (2.1%) |
| 1.75 | 17 (1.0%) |
| 2.0 | 11 (0.6%) — 9 closed + AXTI/VSAT open |
| 2.25 | 4 |
| 2.5 | 2 (DDD, AXPH) |
| 3.0 | 1 (DDD) |

~1% of episodes per quarter-century of trading. A WF-CV on this axis would
have zero power (most folds contain no event) — the mechanism is a
**tail-insurance dial** (catastrophic-stop class), not a performance knob.
Note the basis correction: on the strategy's own WMA-30, AXTI's max
extension is **2.41×**, not the eyeballed "2.5-3×" from the 07-10 reflection
(that was an SMA-flavored read) — the spec'd 2.5-3.0 thresholds fire on
essentially nothing but DDD.

### 2. Tight trails (10-20%) tax the monsters — the fat-tail law at event level

Closed episodes at K=2.0 (realized-vs-realized, deduping the NLS/BFX
rename-twin the run held as two positions):

- trail 10%: net ≈ **−$0.4M** raw (+$1.5M deduped, of which DDD is +$2.96M —
  i.e. **negative without DDD**). Signs: 6+/2−, but dollars are decided by
  two events (DDD +$2.96M vs NLS/BFX −$1.85M).
- trail 25%: net ≈ +$2.9M — **entirely DDD**; median |delta| collapses
  toward 0 (25% trail ≈ never fires before the natural exit).
- The negative rows are all "**fired on the on-ramp**": NLS trail-10 exits
  2020-05-08 @ $5.44 on a >10% weekly-close dip, then the stock runs to the
  $21 natural exit. The positive rows fire near genuine blow-off tops
  (DDD 2021-02, SGID/BDLN/APWR 2000/2004 shapes). **No real-time
  discriminator separates on-ramp from top at trigger time** — the trigger
  looks identical in both.

Open episodes (mark-timing, NOT realized): AXTI at trail 10/15/20 exits
during the 2025 on-ramp ($8.93-$17.40 vs the $70.15 terminal mark:
−$34M to −$40M of mark); at trail 25% it exits 2026-05-29 @ $103.16
(+$21.5M vs mark) — that sign flips entirely on the last four weeks of data
(the June slide), i.e. exactly the single-specimen hindsight trap the
April-28 shakeout already flagged. VSAT: −$5M at 10-20%, no-fire at 25%.

### 3. Sum-level surface confirms the shape

Pooled (both runs, open included): trails 10-20% are net −$31M to −$58M at
every K ≤ 2.25; trail 25% flips to +$24M at every K ≤ 2.25 but the entire
flip is AXTI's +$21.5M mark-timing row. K ≥ 2.5 has n ≤ 2.

## Screen-rigor checklist

1. **Estimand fidelity** — paired per-episode exit replay on the strategy's
   own MA basis; gaps (re-entry, redeployment, open-marks) named above.
2. **Distribution not point-estimate** — per-event table is small enough to
   publish whole (CSV committed); every aggregate above names which single
   events drive it. No claim survives on means.
3. **Economic magnitude** — events are ~$0.1-40M each at terminal NAV scale
   (huge per event), but ~0.6-1%/26y frequency → portfolio-level expectation
   is noise-dominated; the honest-tradeable AXTI give-back measured so far
   is Sharpe −0.038 with realized delta 0.
4. **Selection bias** — the basis guard excluded 226/1143 + 99/587 episodes
   (price-basis mismatch vs the store: post-run splits/dividends, e.g. GME's
   2022 4:1). Splits correlate with big winners, so the exclusion plausibly
   REMOVES tail-tax exhibits (GME's trail exit would have fired 2020-10-30,
   deep on the on-ramp of the +$7.8M realized trade) — i.e. the bias runs
   AGAINST the tax finding we still found. Open-position rows are
   survivor-of-the-moment marks, reported separately.
5. **Surface not boolean** — 6 thresholds × 4 trails swept; response shape:
   monotone worse as trail tightens; K only thins n.
6. **Paired/event-level** — every row is a paired per-event difference;
   NLS/AXTI/DDD traced end-to-end in the text.
7. **Power** — n_effective ≈ 8-10 closed events across 41 run-years; a
   sign-test at n=9 cannot separate anything; single events decide every
   aggregate's sign. The sample cannot distinguish "trail helps at 25%"
   from "DDD happened once."

## Verdict — calibrated

**No-build DECISION for an `extension_stop` performance axis** (not a
mechanism rejection — a proxy screen cannot reject). Grounds, in order:

1. **Measured rarity**: the trigger class cannot move fold-level metrics;
   the real WF-CV test would be structurally powerless (most folds contain
   zero events), so the gap-closing pipeline cannot even adjudicate it.
2. **Standing prior re-derived, now at event level**
   ([[project_edge_is_the_fat_tail]]): tight trails fire on the parabola
   on-ramp as often as at the top, and the on-ramp exits are the expensive
   ones. This is the 9th confirmation of the winner-touching tax, and the
   first one measured on the extension-event subclass directly.
3. The only positive cell (trail 25%) is single-event-dominated (DDD closed,
   AXTI mark-timing) and 25% barely differs from the existing stop path.

**What survives**: a wide (≥25%) extension trail remains a legitimate
**tail-risk-insurance dial** in the `catastrophic_stop_pct` class (sanctioned
insurance, not alpha — per the decline-character precedent, #1695).
**User-directed 2026-07-11 PM: build it** — "no way we actually sit through
140→70, even if that would take a manual intervention"; an encoded, tested
rule beats an untested panic exit. The build (default-off
`extension_stop_config { trigger_ratio ~2.0; trail_pct 0.25 }`, weekly-close
L3 semantics, tighten-only L2, insurance-basis acceptance) is queued as P0a
in `dev/notes/next-session-priorities-2026-07-12.md`. The screen's role in
that build: it pins the width (25% survives the AXTI April shakeout and
January chop and still banks the collapse at $103; 10-20% are on-ramp
killers — do NOT build tight).

## Why it came out this way (transferable)

The extension trigger conditions on "price far above MA," which is the
signature of BOTH the on-ramp and the top of a parabola; the information to
tell them apart isn't in price/MA at trigger time (April-28 AXTI: −42%
weekly-close dip mid-parabola, then +72% more). Any tighter-than-natural
exit rule keyed to extension therefore trades a certain tax on continuing
monsters against an uncertain save on topping ones — the same asymmetry that
killed stop-tuning, harvest-rotate, and late-flag. **Forward guidance**: the
give-back concern (capture-monster #4) is CLOSED as a build target; remaining
capture levers stay ranked universe-freshness (P4) > capacity > early-cut.
Run-hygiene observation for a follow-up: the deep run held the same company
twice under rename twins (NLS/BFX) — worth a dedupe check in universe
construction.
