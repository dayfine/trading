# sp500-2019-2023 trade-quality findings — 2026-04-30 (post G7-G9)

After G1-G5 + G7-G9 closed and shorts re-enabled (PR #711), the
sp500-2019-2023 backtest produces structurally clean output:

- 0 force-liquidations (G4 mechanism not firing as primary)
- portfolio_value never goes negative
- Stops fire correctly (G7/G8/G9 sign + sizing fixes hold)
- Position sizing ≤ 30% of portfolio at entry

But the **trade quality is poor**. A fresh rerun on 2026-04-30 evening
(`dev/backtest/scenarios-2026-04-30-150622/sp500-2019-2023/`) shows:

- 30 closed round-trips, 14 wins / 16 losses (46.7 % WR)
- Total realized −$13,869 / total return CAGR +0.95 %
- **17 of 30 trades held exactly 3 days** (57 %)
- Avg holding 40.4 days (skewed by 3 long holds: KO 270d, HD 333d, JPM 178d)
- Zero short trades (G6 non-determinism: PR #711 had 4 shorts; this rerun has 0)

The previous "clean run" PR #711 reported similar shape (32 trades,
−0.01 % return, 0 force-liqs). The mechanics are correct; the **behavior
is wrong** — the strategy is over-trading on noise.

## Findings

### G11 — Stop-update cadence: trail moves daily, not weekly

**Symptom**: 17 of 30 trades held exactly 3 days. Pattern: enter
Monday, stop-out Thursday at small profit or small loss.

**Authority**: `docs/design/weinstein-book-reference.md` §Stop-Loss
Rules. Weinstein's trail moves only on **weekly close** — when a
weekly bar confirms a new pivot above the prior pivot, raise the stop
to just below the new pivot. The book intentionally uses this
infrequent-update cadence so day-to-day noise doesn't get cut by tight
stops.

**Hypothesis (to verify)**: `Stops_runner.update` is invoked on every
daily bar, not just Friday close. Each daily up-bar can shift the
trail above entry, then any small daily pullback fires the stop. Even
if the *trigger* condition is correct (price ≤ stop_level, which
happens any time), the *update* cadence determines how aggressive the
trail is.

**Distinction**: trigger ≠ update.
- Trigger: continuous. Weinstein uses GTC stop orders that fire
  whenever price crosses. This is fine.
- Update: should be weekly. Current implementation appears to be
  daily.

**Fix shape**: add a `stop_update_cadence` config flag with values
`{Daily, Weekly}`. Run sp500 both ways, compare metrics + 3-day-stop
rate. Expected: weekly-update produces fewer noise stops + longer
holding periods + closer to book reference behavior.

**Reproducer trades** (all from `scenarios-2026-04-30-150622`):

| Symbol | Entry | Exit | Days | PnL$ | Note |
|---|---|---|---:|---:|---|
| MSFT | 2023-02-18 | 2023-02-22 | 4 | −$2,078 | Stopped at slight loss |
| JNJ | 2019-06-22 | 2019-06-25 | 3 | +$1,510 | Stopped at +1.28 % profit |
| JNJ | 2019-12-07 | 2019-12-10 | 3 | +$1,148 | Stopped at +0.96 % profit |
| AAPL | 2019-04-13 | 2019-04-16 | 3 | +$139 | Stopped at +0.13 % (essentially break-even) |
| HD | 2019-04-06 | 2019-04-09 | 3 | +$812 | Stopped at +0.70 % |

The "+0.13 %" AAPL exit is the smoking gun: the trail moved
~0.13 % above entry within 3 daily bars, then a single down-tick
triggered the stop.

**Owner**: `feat-weinstein` — `stops_runner.ml` cadence guard.

### Cascade re-firing within days of stop-out

**Symptom**: Same symbol re-entered immediately after a stop-out, often
within the same week.

**Reproducer trades**:

| Symbol | First entry | First exit | Re-entry | Re-entry exit |
|---|---|---|---|---|
| AAPL | 2019-04-06 | 2019-04-09 (stop) | 2019-04-13 | 2019-04-16 (stop) |
| HD | 2019-04-06 | 2019-04-09 (stop) | 2019-04-13 | 2019-04-16 (stop) |
| JNJ | 2019-06-22 | 2019-06-25 (stop) | 2019-06-29 | 2019-07-02 (stop) |
| JNJ | 2019-11-30 | 2019-12-03 (stop) | 2019-12-07 | 2019-12-10 (stop) |
| HD | 2020-05-23 | 2020-05-27 (stop) | 2020-05-30 | 2020-06-12 (stop) |
| CVX | 2022-10-29 | 2022-11-01 (stop) | 2022-11-05 | 2022-11-10 (stop) |

**Hypothesis**: The screener cascade re-evaluates on every Friday and
fires a fresh entry if the breakout signal is still present, regardless
of whether the same symbol was just stopped out. There's no
"cooldown" or "post-stop-out exclusion list" preventing the cascade
from immediately re-firing on the symbol that just whipsawed.

**Authority**: `docs/design/weinstein-book-reference.md` §Buy-Side
Rules implies that a stopped-out trade indicates the breakout was
false. Re-entry should require the symbol to *re-establish* the
breakout setup (typically: pull back into Stage 1, form a new base,
break out again). The book does not prescribe a specific cooldown
period, but the implication is "don't churn."

**Fix shape**: per-symbol post-stop-out cooldown — after a stop-out,
exclude the symbol from cascade for N weeks (e.g., 4 weeks = ~1
month). Configurable. May need to be combined with a "re-base"
detection (require the price to dip below the prior breakout level
and re-emerge) for full book conformance.

**Owner**: `feat-weinstein` — `screener` cascade gates.

### Empty `exit_trigger` rows in trades.csv

**Symptom**: 2 of 30 trades have empty `exit_trigger` — JPM 2019-05-04
and HD 2021-03-27.

These exits did NOT go through the stop machinery. They could be:
- End-of-period forced close at scenario end (HD 2021-03-27 → 2022-02-23
  is 333 days, exits before end of 2023; doesn't fit)
- Stage-transition exit (Stage 2 → Stage 3/4 detected; strategy emits
  Sell)
- Strategy-level decision exit (e.g., position size adjustment that
  closes one position to free margin)

**Hypothesis**: stage-transition or strategy-level exits don't tag
`exit_trigger`. Reconciler can't classify them; report consumers can't
distinguish from stop_loss exits.

**Fix shape**: Audit every place an exit Position transition is emitted
and ensure each one tags `exit_trigger` with a discriminator
(`stage_exit`, `force_liquidation`, `stop_loss`, `manual`,
`end_of_period`, etc.). This is a small wiring task; mostly a search
+ enumerate effort.

**Owner**: `feat-weinstein` (strategy emits exits) +
`feat-backtest` (writer fills the column).

### G6 non-determinism in production (already tracked)

PR #703 captured G6 with forward-guard test + investigation note.
The two reruns prove it's reproducing in production:

- PR #711 run: 32 trades, 28L+4S, +37.5 % WR
- 2026-04-30 evening rerun: 30 trades, 30L+0S, +46.7 % WR

Same code, same config, different outputs. Root cause:
`create_order._generate_order_id` uses `Time_ns_unix.now()` ns prefix
→ Hashtbl bucket variance → divergent fill order. Fix surface is
core `Orders` module; deferred per A1 watch-list scope.

The 4 shorts that fired in #711 disappeared in this rerun — not a new
bug, just a different draw from the same non-deterministic
distribution.

## Sequencing

Suggested order to address:

1. **G11 (stop-update cadence)** — biggest behavioral lever. Add
   config flag, run experiment, compare. If weekly-update fixes 3-day
   noise, that's a major quality improvement.

2. **G10 (UnrealizedPnl mislabel)** — small fix, fixes the summary
   stream that all reports consume. Already filed (task #15).

3. **PR #707 trail-tightness review** — verify that #707's
   `correction_observed_since_reset` gate didn't accidentally
   over-tighten. Compare stop trajectories pre/post.

4. **Cascade post-stop cooldown** — second-largest lever.

5. **exit_trigger column completeness** — small writer fix.

The first three are likely the highest-leverage items. After G11 and
G10 land, re-pin sp500 baseline to whatever the corrected behavior
produces.

## What this is NOT

- Not a regression of G7/G8/G9. Those fixes are intact and verified.
- Not a strategy-level "Weinstein doesn't work" finding. The book is a
  weekly framework; the simulator currently runs the trail
  daily-effective. Once cadence is fixed, the strategy may behave per
  book.
- Not a force-liquidation issue. G4 is not firing. The 3-day stops
  are pure trail-noise from the per-position machinery.
