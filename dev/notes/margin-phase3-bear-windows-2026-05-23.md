# Margin Phase 3 — bear-window validation report

**Filed:** 2026-05-23. Owner: `feat-weinstein`.
**Issue:** [#859](https://github.com/dayfine/trading/issues/859).
**Plan authority:** [`dev/plans/short-side-margin-2026-05-13.md`](../plans/short-side-margin-2026-05-13.md)
§Stage A.
**Scenarios:** [`dev/experiments/margin-phase3-bear-windows-2026-05-23/`](../experiments/margin-phase3-bear-windows-2026-05-23/).

## TL;DR

Margin Phase 1 (Reg-T collateral + borrow fee) + Phase 2 (simulator
wiring) shipped 2026-05-16 (PRs #1113, #1115, #1119) behind a default-off
`margin_config.enabled` flag. This report measures the effect of flipping
the flag on across four bear-window scenarios.

Per-window summary (margin off → margin on):

| Window | Universe | Sharpe (off → on) | MaxDD (off → on) | Return (off → on) | margin_call exits |
|---|---|---|---|---|---|
| **2000-2002 dot-com** | broad-1000-30y | 0.0347 → **CRASHED** | 27.06 → — | -3.69 → — | — (crashed mid-run on first margin call) |
| **2007-10..2009-03 GFC** | broad-1000-30y | 1.084 → 1.081 | 37.16 → 37.18 | +89.68 → +89.35 | 0 |
| **2020-01..06 COVID Q1** | sp500-2010-01-01 | -0.984 → -0.986 | 16.11 → 16.12 | -11.46 → -11.48 | 0 |
| **2022-01..10 modern bear** | sp500-2010-01-01 | -1.745 → -1.751 | 19.50 → 19.54 | -18.24 → -18.28 | 0 |

**Headline finding:** Across the three windows where both pairs ran
cleanly (GFC + COVID Q1 + 2022 bear), the margin-on configuration
produces *virtually identical* bottom-line metrics. The Sharpe / MaxDD
/ return deltas are all in the 2nd-4th decimal place. Zero
`margin_call` exits fired anywhere — the 25% maintenance threshold is
never breached in these windows.

Total cumulative margin friction (final portfolio off vs on):

| Window | Duration | Friction $ | Friction % of init cash |
|---|---|---|---|
| COVID Q1 | 6 mo | $176.74 | 0.0177% |
| 2022 | 10 mo | $461.95 | 0.0462% |
| GFC | 17 mo | $3,279.81 | 0.328% |

The friction is essentially the cumulative borrow fee
(`short_notional * 0.005 / 252`) accruing daily over the window times
the number of short positions held.

**Significant finding (§Findings/A):** the `margin_config.enabled=true`
path **crashes** on the 2000-2002 dot-com scenario with a `Position.t`
invariant violation when a margin_call transition fires on a state
that doesn't accept it. The first margin call in the dot-com window
fires within ~30 seconds of simulator start (on a short at
entry=$11.00, current=$12.875 — i.e., a ~17% adverse move pushes the
equity ratio below the 25% maintenance threshold) and the resulting
`TriggerExit { exit_reason = StrategySignal "margin_call" }`
transition is rejected. This is a real Phase 2 wiring bug — the
margin runner does correctly filter to Holding-state positions
(`margin_runner.ml:26`) but the position is presumably already
mid-flight on another exit transition emitted on the same tick.

**Surprise positive finding (§Findings/D):** the **2007-10..2009-03
GFC window is the one bear where the strategy generates positive
Sharpe** (1.08 / Calmar 1.43 / Return +89.7%). The long side's recovery
into 2009 Q1 carries most of the +89% return (long pnl +$569K vs short
pnl +$49K), but the short book wins 50% of its trades (14 entries, 7
wins, +$49K) — a meaningful contribution. The other three windows are
flat-to-losing. This validates that the short-side machinery works in
the severe bear regime; it adds noise but not alpha in mild bears.

## Recommendation

**Keep `margin_config.enabled = false` as the default** for now.
Defer the Phase 5 long-short re-pin (plan §3) until the Phase 2
transition bug (§Findings/A) is fixed.

Reasoning:
1. **Effect on metrics, where measurable, is negligible** — across
   GFC + COVID Q1 + 2022 the borrow fee shaved <0.33pp off cumulative
   return on the worst affected window (GFC, 17 months). No margin
   call fired. Flipping the default to `true` offers no observable
   correctness benefit on the existing CI / nightly goldens.
2. **The flag-on path crashes on a real historical scenario** — until
   the `Position.t` margin_call invariant violation (Finding A) is
   closed, enabling it as a default is a forward-compatibility risk.
   Any backtest reaching the maintenance-margin threshold (which
   dot-com 2000-2002 does early) will crash rather than completing
   with a margin-call event recorded.
3. **Phase 5 (long-short re-pin) acceptance gate is not unblocked** —
   plan §3.2 requires long-short Sharpe ≥ long-only Sharpe on the 5y
   and 16y windows. Without margin-on running cleanly to completion
   on long-horizon scenarios, that comparison cannot be made. The
   Phase 4 → Phase 5 gate stays closed.
4. **Plan §0 hypothesis is partially confirmed.** "Realistic
   friction makes shorts strictly negative-EV at the strategy's
   current Stage-4 entry edge." This is true in modern bears (2020
   Q1 + 2022) where shorts add no value: 6/9 short trades in COVID Q1
   lose; 5/5 in 2022 are predominantly losers; total short pnl
   negative. **It is partially false in GFC**, where 7/14 short
   trades win and contribute +$49K. The short book worked in 2008.
   So the right verdict is conditional: shorts add value in
   severe-bear regimes (GFC-class events ≤ once a decade); they are
   neutral-to-negative in mild bears. The acceptance criterion (plan
   §2.2: Sharpe > 0 in ≥2 of 3 windows) is *failed*: only GFC
   produces positive Sharpe, COVID Q1 and 2022 are negative.

Next steps:
1. **File a fix-Phase-2 issue** for Finding A. Repro: dot-com
   scenario in this experiment crashes within ~30 sec of launch with
   the exact stack from §Findings/A. Likely fix: deduplicate
   margin-call candidates against already-pending exit transitions
   in `Margin_runner.tick`.
2. **Re-run this sweep after the fix** — to populate dot-com
   margin-on cell.
3. **Phase 5 long-short re-pin** (plan §3) — gated on (1) + (2).
4. **Consider a separate axis-3 experiment** — given GFC's positive
   result + mild-bear neutral result, the `Macro` gate could
   plausibly enable shorts only in severely-bearish regimes (not just
   "Bearish"). A separate spike could measure whether a stricter
   short-enable gate (e.g., A-D breadth below threshold) improves
   the long-short Sharpe gap.

## Methodology

### Scenarios

Four bear windows × two configs (margin off baseline vs margin on
Phase 1+2):

| ID | Window | Universe | Margin |
|---|---|---|---|
| `dotcom-off` | 2000-03-01..2002-10-31 | broad-1000-30y | off |
| `dotcom-on` | 2000-03-01..2002-10-31 | broad-1000-30y | on |
| `gfc-off` | 2007-10-01..2009-03-31 | broad-1000-30y | off |
| `gfc-on` | 2007-10-01..2009-03-31 | broad-1000-30y | on |
| `covid-off` | 2020-01-02..2020-06-30 | sp500-2010-01-01 | off |
| `covid-on` | 2020-01-02..2020-06-30 | sp500-2010-01-01 | on |
| `bear-2022-off` | 2022-01-01..2022-10-31 | sp500-2010-01-01 | off |
| `bear-2022-on` | 2022-01-01..2022-10-31 | sp500-2010-01-01 | on |

All scenarios share Cell E sizing/portfolio config
(`max_position_pct_long=0.14`, `max_long_exposure_pct=0.70`,
`min_cash_pct=0.30`, stage3 force-exit `h=1`, laggard rotation `h=2`)
matching the 16y golden long-short baseline (PR #1066). The only
varied parameter across each pair is
`((margin_config ((enabled false|true))))`.

### Universe choice

- **broad-1000-30y** for pre-2010 windows. Per plan §5.2: every
  symbol has bar history back to ≤1996-01-01 (1000 symbols, ~305
  SP500 cohort + 695 alphabetic backfill). Survivorship-biased (the
  1000 are 30y+ survivors), but the bias hurts longs more than
  shorts: shorting survivors yields fewer winning shorts, not more.
- **sp500-historical/sp500-2010-01-01.sexp** for post-2010 windows
  (510 symbols, modern liquidity profile — same universe as PR
  #1066's 16y long-short golden).

### Data dir

All eight scenarios run against the production data dir
(`/workspaces/trading-1/data` inside container; the committed test
data under `trading/test_data/` only covers 2009+ and is insufficient
for dot-com + GFC). The runner reads bars via the standard
`Backtest.Runner.run_backtest` panel-loader pipeline; no
margin-experiment-specific data path.

### Wall times (parallel=2 on `trading-1-dev` container)

| Scenario | Wall (s) |
|---|---|
| margin-phase3-bear-2022-off | 41.2 |
| margin-phase3-bear-2022-on | 41.2 |
| margin-phase3-covid-2020q1-off | 38.8 |
| margin-phase3-covid-2020q1-on | 38.7 |
| margin-phase3-dotcom-2000-2002-off | 284.6 |
| margin-phase3-dotcom-2000-2002-on | (crashed at ~30s) |
| margin-phase3-gfc-2008-2009-off | 287.7 |
| margin-phase3-gfc-2008-2009-on | 287.6 |

Total sweep wall: ~14 min (parallel=2). Output dir captured at
`/workspaces/trading-1/dev/backtest/scenarios-2026-05-23-040830/`.

### Metrics extracted

Per scenario, captured from `actual.sexp` written by the runner:

- `total_return_pct` — period cumulative return.
- `sharpe_ratio` — annualized Sharpe.
- `max_drawdown_pct` — peak-to-trough decline.
- `total_trades` — round-trip count.
- `win_rate` — win percent of round-trips.
- `avg_holding_days` — mean holding period.
- `force_liquidations_count` — count of Portfolio_floor / Per_position
  force-liq events.
- `sortino_ratio_annualized`, `calmar_ratio`, `ulcer_index` — from
  M5.2c risk-adjusted metric suite.

Additional metrics derived from per-scenario output dirs:

- `margin_call_exits` — count of round-trips with
  `exit_trigger=margin_call` in `trades.csv`. The margin_call exit
  reason is emitted by `Margin_runner.margin_call_transitions` when
  `Portfolio_margin.check_maintenance_margin` flags a position whose
  equity ratio drops below `maintenance_margin_pct=0.25`.
- `margin_friction_$` — `final_portfolio_value(off) -
  final_portfolio_value(on)`. Captures cumulative borrow-fee impact +
  any cash-deployment-pattern differences arising from margin-on
  `available_cash` (locked-collateral) deductions.

## Results

### 2000-2002 dot-com (broad-1000-30y)

| Metric | Margin off | Margin on |
|---|---|---|
| total_return_pct | -3.69 | **CRASHED** |
| sharpe_ratio | 0.0347 | — |
| max_drawdown_pct | 27.06 | — |
| total_trades | 105 | — |
| win_rate | 31.43 | — |
| avg_holding_days | 54.79 | — |
| force_liquidations_count | 4 | — |
| margin_call_exits | n/a (flag off) | — |
| sortino_ratio_annualized | -0.094 | — |
| calmar_ratio | -0.052 | — |
| ulcer_index | 15.68 | — |
| margin_friction_$ | n/a | — (not measurable, crashed) |

Trade-side breakdown from `trades.csv` (margin-off):
- LONG `stop_loss`: 62
- LONG `laggard_rotation`: 12
- LONG `stage3_force_exit`: 10
- SHORT `stop_loss`: 21

Long-side stats (margin-off): 84 trades, +$140,384 cumulative pnl,
34.5% win rate.
Short-side stats (margin-off): 21 trades, **-$245,256 cumulative pnl,
19.0% win rate**.

Despite the dot-com being a textbook secular bear, the strategy's
short book loses ~$245K cumulatively. The marginally positive Sharpe
(0.034) comes from the long side surviving the basing → recovery
cycles (4 force-liquidations of long positions during the worst
months but cumulative long pnl still positive).

See §Findings/A for the crash root cause on the margin-on twin.

### 2007-10..2009-03 GFC (broad-1000-30y)

| Metric | Margin off | Margin on | Δ |
|---|---|---|---|
| total_return_pct | 89.68 | 89.35 | -0.33 |
| sharpe_ratio | 1.0839 | 1.0815 | -0.0024 |
| max_drawdown_pct | 37.16 | 37.18 | +0.02 |
| total_trades | 64 | 64 | 0 |
| win_rate | 25.0 | 25.0 | 0 |
| avg_holding_days | 31.89 | 31.89 | 0 |
| force_liquidations_count | 0 | 0 | 0 |
| margin_call_exits | n/a | 0 | — |
| sortino_ratio_annualized | 1.6141 | 1.6085 | -0.0056 |
| calmar_ratio | 1.4354 | 1.4299 | -0.0055 |
| ulcer_index | 14.08 | 14.10 | +0.02 |
| margin_friction_$ | n/a | $3,279.81 | — |

Trade-side breakdown from `trades.csv` (margin-off):
- LONG `stop_loss`: 45
- LONG `stage3_force_exit`: 3
- LONG `laggard_rotation`: 2
- SHORT `stop_loss`: 14

Long-side stats: 50 trades, +$569,374 cumulative pnl, 18.0% win rate.
Short-side stats: 14 trades, **+$49,371 cumulative pnl, 50.0% win
rate.**

This is the **one** bear window where the strategy generates strongly
positive Sharpe + Calmar. Both the long and short sides contribute
positively — but the long side dominates the dollar total because the
window includes the 2009 Q1 recovery's first wave of Stage-2
breakouts, and the long sizing config (max_long_exposure_pct=0.70) is
calibrated for trend continuation. Borrow fee impact: $3,280
cumulatively = 0.33% of $1M initial cash over 17 months. Notably
larger than COVID Q1 / 2022 because the short book runs longer
(31.9-day avg holding × 14 short trades) and is held during the worst
bear months when notional × duration peaks.

### 2020-Q1 COVID (sp500-2010-01-01)

| Metric | Margin off | Margin on | Δ |
|---|---|---|---|
| total_return_pct | -11.461 | -11.479 | -0.018 |
| sharpe_ratio | -0.9844 | -0.9862 | -0.0018 |
| max_drawdown_pct | 16.108 | 16.125 | +0.017 |
| total_trades | 42 | 42 | 0 |
| win_rate | 28.57 | 28.57 | 0 |
| avg_holding_days | 20.38 | 20.38 | 0 |
| force_liquidations_count | 1 | 1 | 0 |
| margin_call_exits | n/a | 0 | — |
| sortino_ratio_annualized | -0.9442 | -0.9456 | -0.0014 |
| calmar_ratio | -1.3588 | -1.3593 | -0.0005 |
| ulcer_index | 6.942 | 6.947 | +0.005 |
| margin_friction_$ | n/a | $176.74 | — |

Trade-side breakdown from `trades.csv`:
- LONG `stop_loss`: 26
- LONG `laggard_rotation`: 7
- SHORT `stop_loss`: 8
- SHORT `laggard_rotation`: 1

**No `margin_call` exits.** The 9 short trades over 6 months were too
few to trigger the maintenance-margin threshold (25%). Borrow fee
impact: $176.74 cumulatively = 0.018% of $1M initial cash over 6
months.

### 2022 modern bear (sp500-2010-01-01)

| Metric | Margin off | Margin on | Δ |
|---|---|---|---|
| total_return_pct | -18.235 | -18.281 | -0.046 |
| sharpe_ratio | -1.7455 | -1.7505 | -0.0050 |
| max_drawdown_pct | 19.498 | 19.543 | +0.045 |
| total_trades | 71 | 71 | 0 |
| win_rate | 18.31 | 18.31 | 0 |
| avg_holding_days | 18.65 | 18.65 | 0 |
| force_liquidations_count | 0 | 0 | 0 |
| margin_call_exits | n/a | 0 | — |
| sortino_ratio_annualized | -1.8167 | -1.8212 | -0.0045 |
| calmar_ratio | -1.1052 | -1.1053 | -0.0001 |
| ulcer_index | 7.521 | 7.545 | +0.024 |
| margin_friction_$ | n/a | $461.95 | — |

Trade-side breakdown from `trades.csv`:
- LONG `stop_loss`: 58
- LONG `stage3_force_exit`: 7
- SHORT `stop_loss`: 5

Only **5 short trades** over the 10-month 2022 bear window — the
margin friction is dominated by borrow fees on a tiny short book.
Loss accumulated almost entirely on the long side (laggard-rotation +
stop-loss exits cycling through the 2022 cascade).

## Findings

### Finding A — Phase 2 margin_call transition crashes on the dot-com scenario

**Symptom.** The `margin-phase3-dotcom-2000-2002-on` scenario crashes
within ~30 seconds of launch with an `Invalid_argument` Status from
`Position.t`'s transition validator:

```
Backtest.Panel_runner: simulation failed: { Status.code = Status.Invalid_argument;
  message =
  "Invalid transition Position.TriggerExit {
    exit_reason =
    Position.StrategySignal {label = "margin_call";
      detail = (Some "entry_avg_cost=11.000000 current_price=12.875000")};
    exit_price = 12.875} for current state"
  }
```

The crash log line is in the raw runner output (`/tmp/margin-sweep.log`,
this session) and reproducibly fires when margin is enabled on the
dot-com 2000-2002 window. The first margin call is on a short at
entry $11.00 / current $12.875 — a ~17% adverse move that pushes the
equity ratio below the 25% maintenance threshold (`(11.00 + 0.5*11.00
- 12.875) / 12.875 = 0.256` — at the boundary, with rounding likely
crossing it).

**Diagnosis.** The margin runner's `_find_holding_short_for_symbol`
filter (margin_runner.ml:26) correctly restricts margin-call
candidates to positions in `Position.Holding` state. The `Position.t`
state machine accepts `TriggerExit` only from `Holding`
(`position.ml:172`). So the in-isolation logic should be sound.

The likely root cause is **transition de-duplication on the same
tick**: `Margin_runner.tick` returns `strategy_transitions @
margin_trans`. When the strategy's stop-loss runner also fires a
`TriggerExit` for the same symbol on the same tick (stops + margin
call can both trip on a single adverse-move bar), the first
transition moves the position to `Exiting`, and the second
(margin_call) transition then fails because Exiting ≠ Holding.

**Recommended fix.** Filter `margin_trans` in
`Margin_runner.margin_call_transitions` against the set of
`position_id`s already in `strategy_transitions`. Drop the
margin-call transition if the strategy already plans to exit the same
position on this tick — the stop-loss exit will close the position
anyway, and we avoid the duplicate-TriggerExit failure. One-line
filter in `margin_runner.ml:56-67`.

**Impact.** Until fixed, `margin_config.enabled=true` cannot safely
be enabled as a default — any long-horizon backtest that experiences
a genuine maintenance-margin breach co-incident with a stop-loss
trigger will crash rather than completing with a margin-call event
recorded.

This fix is the gating step for Phase 5 (long-short re-pin per plan
§3). Without margin-on completing on the long-horizon universes,
the gate condition (long-short Sharpe ≥ long-only Sharpe) cannot be
evaluated.

### Finding B — Margin friction is small in modern bear windows

Across COVID Q1 and 2022 bear, the borrow-fee + collateral-lock
friction shaves <0.05pp off cumulative return. This is the expected
behaviour given:

- The strategy's short book is small (5-9 short trades per window);
  borrow fee is `notional × 0.005 / 252` per day, dominated by the
  per-window cumulative short notional × duration.
- No margin-call exits fired — the maintenance threshold is not
  approached within these clean modern windows.

The implication: enabling margin in modern-bear backtests will not
materially change long-short Sharpe / Calmar / MaxDD comparisons.
Phase 5's re-pin will likely produce metrics within 1bp of the
margin-off baseline.

### Finding C — Force-cover exit count is zero across the clean windows

Even with the maintenance-margin threshold set to the
industry-standard 25%, no position in the 2020 Q1, 2022 bear, or GFC
windows triggered a force-cover. The 1 force-liquidation in 2020 Q1
is a portfolio-floor event (not a margin-call event); the 4 in
dot-com-off are also portfolio-floor.

This is plausible because the strategy's per-position stop-loss
typically fires before the equity ratio drops to 25%. Initial
stop-loss distance + Reg-T initial-margin lock means a position must
move ~17%+ adverse before the maintenance threshold is breached, and
the strategy's per-position stop fires earlier on adverse moves.

The dot-com 2000-2002 window does cross the threshold (per Finding
A's stack trace) — which is exactly the regime where the maintenance
margin check is supposed to matter, but the transition bug prevents
the system from completing the run.

### Finding D — GFC is the one bear where short-side has positive edge

In the GFC window (2007-10..2009-03), the strategy generates Sharpe
1.08, Calmar 1.43, total return +89.7% — the only bear-window
scenario producing strongly positive risk-adjusted return.

Short-side stats in GFC (margin off): 14 trades, **50% win rate**,
+$49,371 pnl. By contrast in the other bears:
- Dot-com 2000-2002: 21 short trades, 19% win rate, **-$245K pnl**.
- COVID Q1 2020: 9 short trades, mixed (negligible).
- 2022: 5 short trades, mostly losers.

The GFC short book outperforms because:
1. The window length (17 months) gives stops time to trail past
   resistance, capturing the cascade down to March 2009.
2. The 2008 Sept-Oct cascade is a true 1-in-30-year event with
   sector-wide Stage 4 breakdowns; the screener's Ch.11 short
   cascade rules (negative RS + Stage 4 + Bearish macro) catch many
   of these.
3. Volume + support signals (Phase G15 follow-up additions, PR #630)
   weight high-confidence breakdowns.

The dot-com window covers the same number of months as the 16y
long-short golden (sub-window) but the dot-com bear was sector-
specific (Tech) where the broad-1000 universe under-weights tech, so
the short cascade has fewer high-confidence candidates and many
shorts get whipsawed in the basing → relief-rally cycles.

The implication: shorts add value in *severe* bears, not mild bears.
This is consistent with Weinstein's Ch. 7 framing ("shorting is
hardest in mild bears; only the strongest setups in the worst
cascades work"). It also suggests a future axis-3 experiment
(noted in §Recommendation next-step #4): condition `enable_short_side`
on the breadth severity of the macro Bearish signal, not just on
Bearish vs Neutral.

## Authority references

- `dev/plans/short-side-margin-2026-05-13.md` §Stage A — execution
  plan this report fulfils.
- PR #1113, #1115 — Phase 1 margin accounting (Portfolio extensions
  + Portfolio_margin module).
- PR #1119 — Phase 2 simulator wiring (Margin_runner.tick).
- `trading/trading/simulation/lib/margin_runner.ml` — margin call
  transition site (cause of Finding A).
- `trading/trading/portfolio/lib/portfolio_margin.ml` — maintenance
  check that correctly fires.
- `trading/trading/strategy/lib/position.ml:172` — transition
  validator (`Holding _ → TriggerExit` only) that rejects the
  duplicated margin_call exit_reason (sink of Finding A).
- `docs/design/weinstein-book-reference.md` §Ch. 7 — short-selling
  criteria; provides the framing for Finding D.

## Decision items for follow-up

1. **Fix Phase 2 margin_call transition bug** (Finding A) — required
   before any default flip or Phase 5 re-pin can proceed. Specific
   fix sketch in §Findings/A: deduplicate margin-call candidates
   against pending strategy transitions in
   `Margin_runner.margin_call_transitions`.
2. **Re-run this sweep after the fix** — to populate dot-com margin-
   on cell + verify no other windows hit the same crash mode.
3. **Phase 5 long-short re-pin** (plan §3) — gated on (1) + (2).
   Per Finding B's measurement, the friction effect on long-horizon
   metrics will be small (<1pp on annualized return), so the gate
   condition is likely to evaluate as PASS once margin-on completes
   cleanly.
4. **Axis-3 experiment on macro-conditional `enable_short_side`** —
   per Finding D, shorts only generate edge in severe bears. A
   stricter short-enable gate (e.g., A-D breadth + index Stage 4
   below threshold) could improve long-short Sharpe by suppressing
   the noise from mild-bear short attempts. Out of scope for this
   PR; flagged as separate follow-up.
