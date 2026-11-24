# Universe depth: pre-registration addendum (2026-11-24, written blind)

This file is written while all five seeds are still running, before any arm result exists. No RESULT or PAIR
line had been seen when it was committed: only the five tripwire MATCH lines and the preflight lines. It changes
nothing in `PREREG.md`. It settles four points that `PREREG.md` left open, which the user decided on 2026-11-24.

## A1. A U4 PASS must be traced to the deep band

`PREREG.md` sets PASS at median Δ ≥ +0.20 with at least 4/5 seeds positive. It also says that a Δ inside the 0.45-log
single-cell floor that is not traced to the lever's trades counts as no effect. For U4 vs S3, both rules apply, as
follows.

- **Trace test.** U4 is traced when, on at least 3 of the seeds where Δ > 0, the round trips in ranks 3001–4000
  (measure 4) add up to at least half of that seed's Δ, both measured in NAV % terms.
  - Knock-on effects, such as capital freed for or taken from ranks 1–3000, are reported, but they cannot carry a
    PASS on their own.
- **Walk.** The analyst walks the 5 largest deep-band contributors by name against the bars, because the band's
  sampled hard-defect rate is 2.4 %.
- **Verdict.** If the threshold is met but the trace test fails, U4 is INCONCLUSIVE.
- **Scope.** The 0.45 floor applies to single seeds. The median over five seeds may fall below 0.45 and still PASS,
  provided the trace test holds.

## A2. A defect in the top 5 caps the verdict

If the walk confirms a bar defect in any of the top-5 deep-band contributors, U4 is capped at INCONCLUSIVE. Examples
are a store-vs-warehouse disagreement like #3705, or a vendor splice.

- **Quarantine.** The defective names are quarantined, as DNGFF, HLAN, MDFI and SYNI were.
- **Rerun.** The U4 and S3 pair reruns on the affected seeds only, with the same specs, the same thresholds and this
  file's rules. The rerun's paired Δ replaces the affected seeds.
- **Why.** Subtracting the trades from Δ is not allowed: removing one name changes the whole capital path.

## A3. Confirmation cell for a U4 PASS or PAYS-WITH-RISK

The live picks do not move to top-4000 until this confirmation passes. It runs only after a U4 PASS or PAYS-WITH-RISK
(including one reached after an A2 rerun).

- **Pairs.** U4 vs S3 on the v13 lists, `initial_cash` 100000 with the live-size overrides, and the same
  `require_structural_stop` as the main run.
- **Two fresh starts,** both running to the same end date as the main run, with K=5 new seeds each (k5–k9):
  - 2009-03-02, after the GFC;
  - 2017-01-03, late cycle and the 2020s.
- **Thresholds.** Each start is judged on its own with the `PREREG.md` thresholds and A1 above. The confirmation
  passes only if **both** starts PASS or PAYS-WITH-RISK.
- **Why these starts.** A start after 2000 overlaps the main run's history. A fresh $100k start resets compounding and
  position sizes, so the capital path is new even though the market is not. Two starts in different regimes guard
  against the post-GFC small-cap bull carrying the result alone.

## A4. Follow-up if N3 PASSes

N3 stays non-promotable whatever its result, because its `Buffer_fallback` stop breaks spine item 5. Spine item 5
reads "below the base / below the MA", so if N3 comes back PASS or PAYS-WITH-RISK, the follow-up is:

1. A book check under `dev/rules/book-as-authority.md`: may the initial stop sit below the 30-week MA for a Stage-2
   breakout that has no qualifying correction? The answer is written back to `weinstein-book-reference.md`.
2. If the book supports it, a config dial "fallback = below the 30-week MA", tested as its own pre-registered K=5 arm
   against S3.

An N3 PASS only licenses that question. It is never evidence for the dial. If N3 is HARM or INCONCLUSIVE, nothing
follows.
