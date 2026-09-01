# Blind-judge screen — the stop-anchor question (#2389 / #2408) — 2026-09-01

**Question screened:** for an E-anchored breakout where the support-floor
machinery finds structure only FAR below the entry, does a book-reading judge
(a) install the flat 4-6% §5.3 stop (treating "no NEARBY prior peak" as
satisfied — the `stop_anchor_at_entry_base` reading), (b) anchor to the
distant structure, or (c) refuse the trade? This gates any promotion reading
of the sa2408 anchor=on arms
(`dev/experiments/stop-anchor-surface-2026-08-31/`).

Per the `blind-judge` skill: this is a SCREEN, not a verdict. It cannot
promote/reject `stop_anchor_at_entry_base` or any mechanism.

## Setup

`weekly_bars_dump -blind` series (260w, warehouse
`snap_top3000_dedup_v5thin_adj`, prices unrescaled, symbol/date identities
stripped, neutral filenames), fresh-context LLM judges given ONLY the rule
card (verbatim from the skill) + one table each. Cohort: 4 disputed
`Stop_too_wide` decliners (AXTI@2025-06-27, AXTI@2025-08-22 — the E=2.71
week, SKYW@2023-03-17, BPT@2022-01-21), 2 controls (XRX@2019-02-15 — a
faithful-arm PLACED fill; INTC@2022-09-30 — an obvious Stage-4 decline).
Repeats: N=3 on AXTI×2 + XRX, N=2 on SKYW/BPT/INTC (reduced from the
protocol's 3 for the unambiguous cases — recorded deviation). No RS/macro
control class was constructed (none needed — see below — but the protocol
caveat stands). Operator keys in scratchpad `bj-keys/`; judge dir contained
only blinded tables.

## Self-consistency (the gating number)

**14/14 calls: `no_ticket`. Per-case unanimity 6/6.** Stage and
volume-verdict fields agreed across reps in every case except minor
volume-confirms wobble on AXTI@2025-06-27 (no/no/unknown). Trigger/stop
levels, where priced, clustered tightly (AXTI@2025-08-22: trigger 2.85-2.90;
stop 1.78-1.98). Judge-vs-judge agreement is not the limiting factor for
this cohort.

## Comparison table

| case | ours | judge (majority) | category |
|---|---|---|---|
| AXTI@2025-06-27 (disputed) | declined `Stop_too_wide` | no_ticket 3/3 | agree-decline |
| AXTI@2025-08-22 (disputed) | declined `Stop_too_wide` | no_ticket 3/3 | agree-decline |
| SKYW@2023-03-17 (disputed) | declined `Stop_too_wide` | no_ticket 2/2 | agree-decline |
| BPT@2022-01-21 (disputed) | declined `Stop_too_wide` | no_ticket 2/2 | agree-decline |
| XRX@2019-02-15 (control) | PLACED (filled, +15%) | no_ticket 3/3 | **we-placed-judge-declines** |
| INTC@2022-09-30 (control) | (stage-4, no ticket) | no_ticket 2/2 | agree-decline |

`we-declined-judge-places` count: **0/4** — no over-exclusion flag on the
ladder-v3 monsters at this cohort size. (The judge's structural
permissiveness bias — no RS/macro context — is moot here since it never
placed; the bias only inflates place-rates.)

## The #2389 answer (the screen's actual payload)

**In all 13 reasoning traces that priced risk, the judge anchored the initial
stop to the REAL structural floor — the base/correction low, rounded below
round numbers — never to a flat 4-6% band.** Examples: AXTI@2025-08-22 stops
at 1.98 / 1.78-1.79 ("below the 1.80-1.85 lows and the $2 round number"),
computing 30-38% risk; BPT at the 3.40-4.95 base lows (30-50% risk); XRX at
the ~19 crash low (~35-38%). Not one rep invoked "no nearby prior peak →
flat stop" for a far-structure shape. The judge's operational reading of
§5.1 for "structure exists but is FAR": far structure = large risk = **prefer
other candidates** — refuse, don't re-anchor.

**Implication for the sa2408 anchor=on arms:** their +55-78pp paired effect
at on-b0.92 is a real measured return effect on that cell, but this screen
says the mechanism is an **adaptation**, not a faithful reading — a blind
book-reader confronted with the exact disputed shape refuses the trade rather
than installing a nearby flat stop. Any promotion case must therefore argue
W2-adaptation grounds explicitly (as clock-52 argued outer-bound adaptation),
not book-faithfulness. It also re-confirms ladder-v3's
`project_faithful_ticket_structural_exclusion` from the outside: a faithful
process really does exclude these monsters.

## The one divergence worth following

**XRX@2019-02-15 (we-placed-judge-declines, 3/3 consistent):** the judge
declines our filled entry — V-shaped 6-9-week rebound, no base, decision-week
volume below prior-4-week average, structure-anchored risk ~35%. Two live
hypotheses, undecidable from a screen: (a) our screener over-admits
crash-rebound continuation shapes (no base-quality requirement); (b) the
judge is systematically stricter than the book intends (it graded overhead
"C" everywhere and priced stops off deep floors even for a modest pullback
shape). n=1 placed control — the follow-up that would discriminate is a
wider placed-control cohort (5-10 fills across years) plus a
`trade-dissection` of the XRX admission. Until then this is a flag, not a
finding.

## Calibration statement

Permitted conclusion drawn: **no over-exclusion signal on the disputed
cohort (0/4 at 100% judge self-consistency); the far-structure stop question
resolves toward refuse-not-reanchor in every trace.** Not concluded: that
our gate is "right", that anchor=on is bad (its return effect is real and
salt-robust on the measured cell), or anything promote/reject. The judge is
one prompt-sensitive reader; the cohort is 6 cases; the placed-control class
is n=1.

Artifacts: blinded tables + operator keys in the session scratchpad
(`bj-judge/`, `bj-keys/`); raw JSON verdicts in the session transcript.
Related: `project_faithful_ticket_structural_exclusion`,
`project_fallback_stop_half_book_band`, weinstein-book-reference.md §5.1/§5.3.
