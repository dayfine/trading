# Corrected-bundle 26y — the §4.2 fill-week gate is the binding constraint at scale (2026-08-21)

Second 26y run of the arc-faithful bundle, now with all four overrides
(`initial_stop_buffer 1.0` included, merged #2452). Same window
(2000-01-01 → 2026-06-26), universe (top-3000-2000), warehouse, and runner as
the pre-correction run. Artifacts:
`dev/experiments/inspect-6mo-2026-08-21/results/arc26y-corrected-*`
(pre-correction record: `arc26y-precorrection-*`).

| | pre-correction (3 overrides) | corrected (4 overrides) |
|---|---:|---:|
| total return | −40.1% | **−62.4%** |
| trades | 3,172 | 3,029 |
| mean hold | 7.6d | 9.3d |
| MaxDD | 90.3% | 67.7% |
| Sharpe | — | −0.26 |

## What may NOT be concluded

**The −40.1 vs −62.4 delta (22pp) sits inside the 132.5pp 26y return noise
floor on this base** (`project_ladder_v4_null_278pp` discipline). The stop
correction cannot be said to have helped or hurt at 26y from these two runs.
The 6-month `bookstop` result (−4.17% → +4.83%) does not transfer to a 26y
claim either — the same horizon trap as
`project_entry_cap_horizon_reversal`.

## What the anatomy DOES establish (structural, not a paired-difference claim)

Exit mix of the corrected run:

| exit | n | P&L |
|---|---:|---:|
| volume_eject | **2,192 (72%)** | +$354,957 |
| stop_loss | 668 | **−$2,194,178** |
| laggard_rotation | 154 | +$1,286,464 |
| extension/stage3/liquidity/open | 15 | +$135,692 |

1. **The stop fix arrived as designed** — modal `stop_initial_distance_pct`
   0.0400 on 1,764 of 3,029 trades. The mechanism verified in the 6-month arm
   behaves identically at 26y.
2. **The §4.2 fill-week volume gate ejects 72% of all entries over 26 years.**
   Its leg nets +$162/trade — noise — while the stop leg pays full price.
   Yearly P&L is negative in 19 of 27 years: a steady structural bleed, not a
   regime accident. The book's premise for the eject ("sell it for a fast
   profit when it advances... which it will usually do") does not pay on the
   broad universe at scale; 2019H1's ≈0 eject cost (`bothfix` arm) was the
   regime exception.
3. **`laggard_rotation` remains the only large profit channel** (+$1.29M),
   consistent with `project_trade_forensics_2026_06_12`.
4. Both runs sit ~350pp below `fullbook-graded`'s recorded +287% — far outside
   the null. The bundle as a whole transforms the system into a
   week-scale scalper; that claim is robust even where the intra-bundle
   deltas are not.

## Where this leaves the arc (decision points, not recommendations)

- **Axis-1 reading:** the features are now built, verified, and behaving as
  specified — including the faithful §4.2 gate doing exactly what the book
  says. "Faithful and profitable diverge here" (user, 2026-08-20) is now
  quantified at scale: the faithful reference implementation loses ~62% over
  26y while the non-book record convention makes +287%.
- **The licensed dial:** `weinstein-faithful-core.md` explicitly licenses
  *numeric thresholds tuned for the modern regime* as a dial. The volume
  config's `strong_threshold` (2×) is a real config field — a
  `Variant_matrix` axis today ({1.2, 1.5, 2.0} would answer whether the 2×
  weekly bar is era-appropriate for a broad modern universe) — as is the
  eject-timing nuance (book sells into the advance; runner sells next open).
- **Not proposed:** weakening the gate by default, or reading any intra-bundle
  22pp delta as signal.
