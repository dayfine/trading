# Lever (f) age-band surfaces + sketch v5 — results (2026-07-22)

Closes the 07-20 user directive: "lever (f) and the test scenarios with it
(on top of w30 + virgin-crossing + floors-zero) before promo." Both
surfaces ran; the promotion decision is now fully evidence-backed.

## Verdict 1 — the age lever is a REJECT (ledger
`2026-07-22-leverf-age-band-surface`)

Band-weight axes on the BUNDLE base (w30 + vc + floors 0/0/0):

| variant | broad 13×2y Sharpe (wins) | sp500 26×1y w15 Sharpe (wins) |
|---|---:|---:|
| baseline (no supply arming) | .691 | .396 |
| **bundle ref — bands 1/1/1/0** | **.827 (10/13)** | .737 (19/26) |
| old-band 0.25 | .766 (8/13) | .658 (18/26) |
| old-band 0.5 | .708 (7/13) | **.774 (20/26)** |
| age-decay 1/.7/.5/.25 | .755 (8/13) | .677 (17/26) |

- **Broad (decision basis): monotone harm** from any weight on the
  measured 130-520w band; within-recent decay also loses.
- **sp500: U-shaped with a "peak" at 0.5 that does not transfer** —
  opposite sign on broad. Noise, per the floors-half precedent and the
  breadth-dependence rule.
- **Why (transferable):** floors-zero already showed
  trust-measured-EMPTY > max-skepticism; (f) adds that measured-OLD
  mass has no pricing power — multi-year bag-holders don't suppress
  broad breakouts, so weighting them is a weaker replay of the
  redeemed-cohort tax. **The age axis is closed.** The bundle's
  2011-cell regression will not be rescued by age-banding; remaining
  options for that cell are the regime-softener (lever b) or accepting
  the bull-era wash.

## Verdict 2 — sketch v5 certified at production scale (the lasting win)

The bands-1/1/1/0 broad row reproduces the 07-19 dense-era floor-axis
bundle row **to every printed decimal** (.827 / 36.17% / 14.05) on the
sparse warehouse — after the unit bit-exact property (#2027), the
6-fold walk-forward byte-cert (#2032), and the controlled dense-vs-thin
A/B re-cert (#2038), this is the final, full-scale production cert.

Infrastructure outcome (user-designed sparse storage, PRs
#2026/#2027/#2032/#2038):

| | dense v4 | thin v5 |
|---|---|---|
| top-3000 warehouse | 8.4G | **1.3G** (+2908 `.weekly` ≈ 60MB) |
| broad fold wall-time | unrunnable (D-state thrash on 7.8G VM) | **~11 min/run** |
| resistance geometry | baked at build (bucket width/count, 2× cutoff, horizon, bands) | **score-time config** (zero-rebuild axes) |

Ops lessons landed in memory: chain scripts need flock + hard stage
aborts (the 07-22 double-launch race); background-wait agent stalls;
orphaned parent dunes.

## Promotion decision — inputs now complete

Bundle evidence: sp500 grid CONFIRM / 2011 wash / rolling-start
REPAIRS the recovery tail (note `bundle-studies-results-2026-07-20.md`)
+ (f) REJECT (no further scoring refinement available on this axis).
Candidate of record: **the BUNDLE at default band weights** — exactly
the configuration whose grid+rolling-start evidence was gathered.
R3: user decides.

## Addendum (07-23) — 28y path-level corroboration

Contiguous 26.5y record-convention arms (top-3000, v5thin): promoted
bundle (bands 1/1/1/0) +8,689% / DD 30.3% remains the best arm —
old-band 0.25 → +8,096% / DD 44.3; old-band 0.5 → +4,820% / DD 38.2;
age-decay → +8,176% / DD 27.3. The fold-level REJECT holds at the
path/monster-cohort lens too (no vc-style fold-vs-path tension).
Footnote: the age-decay arm is a mild insurance-shaped trade (−500pp
return, −3pp DD single-path) — recorded, not pursued (fold-level loss
.755 vs .827). Runs: /tmp/sweeps/leverf-28y{,-rerun}; scenarios
staging-leverf-28y{,-rerun}/.
