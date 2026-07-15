# F-cohort forensics + MA horizon-slope gate screen — NO-BUILD (2026-07-14)

P1.5 (user-queued): the worst-quality Run D entries "look like declining /
weak long-term trends" on the new chart cards — is a longer-horizon MA-slope
gate a build directive? Data: the per-trade quality scores + embedded weekly
series of `audit_runD_charts.html` (all 1,187 record-run trades; realized-PnL
event-level, not a forward-return proxy).

## The screen (sweep, per screen-rigor)

Gate: block long entry when `(WMA30(entry) − WMA30(entry − h)) / WMA30(entry − h) ≤ th`.

| h × th | loser PnL blocked | WINNER (A/A+) PnL blocked (of $95M) |
|---|---:|---:|
| 13w × −5% | −$5M | **$65M** |
| 13w × 0 | −$17M | **$76M** |
| 26w × 0 | −$17M | **$83M** |
| 26w × +5% | −$20M | **$87M** |
| 39w × 0 | −$17M | **$83M** |

Grade × gate (26w×0): blocks 380/573 D + 130/191 F (good) — AND 56/97 A/A+
carrying $83M of $95M winner mass. **No cell in the response surface is
better than ~4:1 AGAINST.** Verdict: **NO-BUILD** — the mass/tail tradeoff
has no rescue region. (Caveat: blocking entries frees cash for other entries,
so the counterfactual isn't pure subtraction — but a 4-13:1 adverse ratio
does not survive any plausible reallocation credit.)

## The why (transferable — 11th fat-tail confirmation, sharpest form yet)

The monsters ENTER on declining long-horizon MAs: AXTI/DDD/SKYW-class winners
are crash-recovery / deep-base breakouts, where the 30-week MA is still below
its level 6 months prior at entry. The chart read ("weak long-term trend =
bad entry") is TRUE for the loss mass and CATASTROPHICALLY false for the
tail — winners and losers are indistinguishable at entry by trend context,
and the fat-tail premium is precisely payment for buying what still looks
broken. Same mechanism as the armed-resistance result the same night
(`resist520-armed-run-2026-07-14.md`): recovery breakouts carry real overhead
AND weak long-horizon trend; ANY entry filter keyed on either steers out of
the monster class.

## F-cohort defect typology (the other half of the ask)

Per-rule conformance on the record run: R1 (entry above flat-or-rising MA,
short window) and R3 (never long Stage 4) pass 100% — the spine holds.
R6 plunge-adjacent entries: 78 fails (6.5%) — known class, report-rule since
#1953. Mean rule-conformance BY GRADE is flat (A+ 95%, D 96%, F 88%): the
worst-quality cohort is overwhelmingly CLEAN whipsaw — the structural
premium, not fixable defects. The defect-mining well (twins, asset types,
MA-direction-at-entry, false virgins) appears mostly tapped on this path.

## Standing conclusion for future "better entries" proposals

This closes the trend-context-gate class ON REALIZED RECORD DATA, complement
to the 2026-07-08 all-eligible powered null (entry features don't predict
returns). New entry-side proposals must first show their blocked-winner $
share on this exact cohort (the audit HTML embeds everything needed — the
screen is a jq one-liner away).
