# virgin-crossing 28y pair runs — lever works standalone, does not rescue w30 (2026-07-18)

Decision input #2 for the `w_overhead_supply` promotion (follows
`resistance-supply-rolling-start-2026-07-18.md`). Two 28y single-path pair
runs on the dedup-v3 warehouse, record-convention base:

| config | terminal | return | Sharpe | MaxDD | AXTI redemption taken? |
|---|---:|---:|---:|---:|---|
| baseline (certified ref) | $80.1M | +7,914% | 0.83 | 32.3 | n/a (original $2.18 entry) |
| vc-only, #1997 as merged (run 1) | $78.7M | +7,768% | 0.82 | 31.1 | n/a (held through) |
| w30+vc, #1997 (run 1) | $17.7M | +1,673% | 0.72 | 30.1 | **NO** |
| vc-only, + #2002 fix (run 2) | **$88.2M** | **+8,718%** | 0.83 | 31.2 | n/a (held through) |
| w30+vc, + #2002 fix (run 2) | $21.6M | +2,059% | 0.75 | **27.0** | **NO** |

Run dirs: `trading/dev/backtest/scenarios-2026-07-18-{162237,203816}/`.

## Run 1 → the own-week-high artifact (#2002)

Run 1 proved `is_virgin` structurally unsatisfiable at redemption: the
sketch's `max_high_520w` includes the current week's own high, so a
close-anchored breakout can never clear it while the stock climbs (AXTI
2026-01-06: close 20.17, max 20.345 = its own week's high, `hist_sum = 0`).
Fixed by #2002: re-admission arm = `is_virgin || is_clear_of_supply`
(all histogram bins zero = zero measured overhead mass).

## Run 2 findings

1. **Standalone value (single-path)**: vc-only beats baseline +10%
   terminal at equal Sharpe and lower DD. Stale-but-supply-clear
   re-admissions are additive on this path — WF-CV surface launched
   (`test_data/walk_forward/virgin-crossing-flag-BROAD-2000-2026.sexp`,
   results `/tmp/sweeps/vc-flag-broad/`) to make this decision-grade.
2. **Does NOT rescue w30**: w30+vc ≈ bare w30 ($21.6M vs $20.9M); AXTI
   still never re-admitted under w30. Root cause is now the SCORE, not
   admissibility: a redeemed name sits at/below `max_high_130w` (its own
   run keeps setting it), so `analyze` returns the `recent_far_floor`
   (0.4) → resistance points 30×(1−0.4) = 18/30 → it loses the
   cap-20/cash race to supply-clear peers. The floors are exactly lever
   (c)'s axis (`stale_old_floor` — and this evidence now implicates
   `recent_far_floor` too for the redeemed-cohort case).
3. DD note: w30+vc has the best MaxDD of any 28y config yet (27.0%).

## Where this leaves the promotion decision

- Bare w30: distribution says median-better/DD-better with a systematic
  recovery-window left tail (~25% of starts, −6..−9pp/yr).
- w30+vc: does not repair the tail (floors block at ranking).
- vc-only: promising standalone (+10% single-path), WF-CV pending.
- Coherent next lever: floor-axis surface (lever c, widened to include
  `recent_far_floor`) × vc — the mechanism that would let redeemed names
  rank fairly under w30.

No default flips; everything stays axis-only pending WF-CV + grid per
`promotion-confirmation.md`.
