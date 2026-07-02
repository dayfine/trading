# Refreshed 2026-H1 weekly picks — coherence + follow-up analysis (2026-07-01)

Analysis of the `prior_stage`-fixed weekly series (`dev/weekly-picks/5a2689cb4/`,
26 weeks, #1821). Follow-up is **qualitative** (did the Stage-2 trend hold / was the
MA bumpy) — not return %. Traced each pick's stage trajectory 6 weeks forward with
the chained classifier (`stage_dump`), data floor 2026-06-30. Ran off a fetch of the
368 unique picked symbols (gitignored scratch; regenerable).

## Coherence — a weekly breakout feed, not a stable watchlist

- **368 unique long-picked symbols** across 26 weeks; **89% (326) appear in exactly
  one week**; ~0% week-over-week persistence (a fresh A+ breakout reappears in zero
  later weeks).
- **Driver:** the volume gate (`is_breakout_candidate` requires a volume surge). A
  stock is surfaced in its breakout-with-volume week and drops out the next when
  volume normalises — even though it's usually still Stage 2. So the screen is an
  **entry-timing action feed**, not a persistent "names in Stage 2" list.
- Not incoherence: a handful age correctly (AEVA A+→early over 4 weeks); the churn is
  *real fresh breakouts each week*, and a majority confirm (below).

## Follow-up — did the trend hold? (6-week forward window)

| outcome | all picks | early-S2 | A+/fresh |
|---|---|---|---|
| CONFIRMED-smooth (stayed S2, ≤1 flip) | 62% | 75% | 60% |
| confirmed-BUMPY (S2 but choppy) | 2% | 1% | 2% |
| topped → S3 | 10% | 4% | 12% |
| faded → S4 | 11% | 10% | 11% |
| recent (<3wk fwd data) | 14% | 10% | 15% |

Excluding the too-recent: **~72% confirmed, ~13% failed (S4), ~12% topped (S3), ~2%
bumpy.** Failures are **clean breakdowns/tops, not choppy oscillation** — the MA is
rarely bumpy. **Early-Stage2 confirms more (75%) than fresh A+ breakouts (60%)** —
the fresh breakout is the highest-variance moment (~1 in 4 fails or tops); the aged
early-S2 has already survived initial confirmation.

## Regime cut — confirmation is regime-sensitive (Weinstein-coherent)

| regime | long picks | confirmed | topped | failed |
|---|---|---|---|---|
| Jan–Feb (strong but late/topping) | 179 | 65% | 16% | 16% |
| March (pullback) | **20** | 60% | 10% | **25%** |
| Apr–Jun (recovery) | 159 | **83%** | 8% | 9% |

- **Apr–Jun confirms best (83%)** — breakouts caught at a trend's *dawn* have room to
  run. **Jan–Feb worst among bull months (65%, 16% topped)** — late in a mature run
  that rolled into March. Picks-near-a-top fail more; picks-at-a-turn confirm more.
- **Macro gate visibly works:** March had only **20** longs (vs 179/159) — the
  bearish tape suppressed longs — and those failed most (25% → S4).

## Examples (stage trajectory from pick date)

```
✓ MLAB  01-02 A+fresh:  S2 S2 S2 S2 S2 S2 S2 S2 S2        clean multi-month ride
✓ BKSY  01-23 A+fresh:  S2 ... S2 through 03-20           held S2 through the March drop
✗ AIG   01-02 A-early:  S2 S2 S3 S3 S4 S4 S4 S1           topped in 2wk, broke down
✗ KARO  02-13 A+fresh:  S2 S3 S3 S3 S4 S4 ...             FALSE breakout: S3 the next week
~ SPGI  01-09 A-fresh:  S2 S2 S2 S2 S3 S3 S3 S4           4 good weeks then rolled over
~ CCS   01-30 A+fresh:  S2 x6 ... S3 03-13 S4 03-27       confirmed, topped in the March drop
```

Failures cluster at the market top / into the March pullback, not randomly — the
regime pattern is visible at the single-name level.

## Open observation — the screen over-produces vs executable capacity

~20 long picks/week (cap `max_buy_candidates`) ≈ ~60–80/month in active tapes, and
89% are non-recurring. A real portfolio funds ~5/week (cash-constrained — the
decision-audit found ~97% of decisions cash-bound). So the screen surfaces far more
than is actionable. Post-fix this is *less* of a problem than it was: ranking by
score now puts the genuine A+ fresh breakouts first, so the cash-constrained top-5
are the highest-conviction names (vs the old alphabetical top-5). Candidate
improvements: (a) tighten the surfaced/displayed list to actionable size (top-N by
score / A+-only) — trivial config; (b) the capacity/concentration lever (fund
more-smaller vs fewer-larger among the surplus quality picks —
`project_capacity_concentration_surface`); (c) distinguish new-entry vs already-held
in the feed. See the discussion following this analysis.
