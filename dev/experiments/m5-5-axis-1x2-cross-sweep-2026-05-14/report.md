# M5.5 axis-1 × axis-2 cross-sweep — **DESTRUCTIVE interaction**

## TL;DR

**Combining axis-1 + axis-2 is WORSE than either alone, and worse than
baseline.** The two levers target the same mechanism (stop distance) and
combining them over-widens the effective stop, causing positions to linger
into deeper losses.

**Recommendation: promote axis-2 ALONE (`min_correction_pct = 0.10`). Drop
axis-1's `installed_stop_min_pct = 0.08` from consideration — axis-2
dominates it on every metric.**

## Cells (3)

Over 5y `sp500-2019-2023.sexp` (main, shorts on):

- `baseline` — defaults
- `axis-2-only` — `stops_config.min_correction_pct = 0.10` (PR #1083 winner)
- `combined` — `installed_stop_min_pct = 0.08` (PR #1079 winner) + `min_correction_pct = 0.10`

## Results

| Cell | Return | Trades | WR | Sharpe | MaxDD | Calmar | AvgHold |
|---|---:|---:|---:|---:|---:|---:|---:|
| baseline | 50.66% | 264 | 37.50% | 0.56 | 21.56% | 0.40 | 40.78d |
| **axis-2 only** | **93.76%** | 195 | 36.41% | **0.88** | **18.36%** | **0.77** | 56.05d |
| **combined** | **47.38%** | 176 | 37.50% | **0.50** | **31.24%** | **0.26** | **69.24d** |

## Δ from baseline

| Metric | axis-2 only | combined |
|---|---:|---:|
| Return | **+43.10** pp | **−3.28** pp |
| Sharpe | +0.32 | **−0.06** |
| MaxDD | **−3.20** pp (improves) | **+9.68** pp (worsens) |
| Calmar | **+0.37** | **−0.14** |
| AvgHold | +15.27d | +28.46d |

## Mechanism

Axis-1 (`installed_stop_min_pct`) floors the installed-stop distance at 8%.
Axis-2 (`min_correction_pct`) widens the support-floor detection threshold,
which in turn pushes the support-floor-derived stop further away.

When applied INDEPENDENTLY:
- Axis-1 alone (#1079): installed stop floor binds, support-floor stops
  unchanged. Modest widening, modest lift (Calmar +0.13), MaxDD rises.
- Axis-2 alone (#1083): support-floor stops widen, installed-stop floor is
  default (0.0) so doesn't bind. Holding periods lengthen organically;
  fewer false stop-outs. Big lift (Calmar +0.37), MaxDD IMPROVES.

When applied TOGETHER:
- BOTH push effective stop further from entry. Effective stop is roughly
  `max(installed_stop_min_pct, support_floor_distance)`. With both widened,
  positions hold much longer (avg-hold 69d vs 56d / 41d).
- BUT — losers also hold longer. Per-loss-event size grows. MaxDD jumps
  10pp to 31.24% while total return collapses 46pp to 47.38%.
- Net: the asymmetry that made axis-2-alone profitable (winners ride
  proportionally, losers stop fast enough) is destroyed by overlaying
  axis-1's installed-stop floor.

## Key takeaway

**The two levers are NOT additive — they're competing solutions to the same
problem (stop distance).** Axis-2's mechanism is the more elegant one
(adaptive to support-floor, scales with volatility); axis-1's mechanism is
the blunt instrument (hard floor).

**Drop axis-1 (`installed_stop_min_pct = 0.08`).** Continue with axis-2
alone.

## Follow-up

1. **Validate axis-2 cell-010 on 10y + 16y** before locking in (same
   protocol as #1081 did for axis-1's 0.08).
2. **Sweep axis-3** (`min_score_override`) — this is the only remaining
   axis from #1064's design that has NOT been measured. It targets a
   different mechanism (cascade gate, not stop distance) so MAY compose
   additively with axis-2. Cross-sweep axis-2 × axis-3 if both show lift
   individually.
3. **Re-pin Cell E defaults** with `min_correction_pct = 0.10` once 10y/16y
   validation passes.

## Reproduction

Cell shapes (rebuild from `sp500-2019-2023.sexp` + appropriate overlay):

```sexp
;; axis-2-only
(config_overrides
 (... existing Cell E overrides ...
  ((stops_config ((min_correction_pct 0.10))))))

;; combined (this is the LOSING cell — do NOT promote)
(config_overrides
 (... existing Cell E overrides ...
  ((screening_config ((candidate_params ((installed_stop_min_pct 0.08))))))
  ((stops_config ((min_correction_pct 0.10))))))
```

Output: `dev/backtest/scenarios-2026-05-14-013947/`.
