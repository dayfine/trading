# Post-run trade validation — invariants & expectations harness (2026-07-12)

User directive (interactive audit session): **"we should have some kind of
post-backtest validation to verify the invariants / expectations — so we
never make these kind of trades again."** Built as PR #1937
(`trading/trading/backtest/validation/`, report-only v1).

## Concept

A read-only **post-run validator** consumes a completed run's artifacts
(`trades.csv`, `trade_audit.sexp`, `open_positions.csv`, `stale_holds.sexp`)
plus the bar store, checks every trade against a declared list of
invariants/expectations, and emits a validation report. Two severities:

- **INVARIANT (hard)** — a violation means an engine/config/faithfulness
  bug; a run with invariant violations is not trustworthy. Eventually
  CI-gates goldens (all-zeros band) via a scenario_runner post-step.
- **EXPECTATION (soft)** — a monitored statistic. Violations are counted +
  listed, never fail the run.

The validator NEVER changes strategy behavior — it proves that armed gates
actually eliminate their defect classes, and trips on regressions and NEW
defect classes early. The same checks reuse against live weekly-pick
snapshots (deployment checklist).

## v1 checks (as built in #1937)

| id | class | check | catches |
|---|---|---|---|
| V1 | INV | every LONG entry's audit stage is Stage2 | spine S6 |
| V2 | INV | no LONG entry with macro_trend Bearish | spine C2 |
| V3 | INV | entry-week dollar-ADV ≥ min_entry_dollar_adv when armed | realism gate silently off |
| V4 | INV | no position held past stale_exit_after_days without bars | ghost regression |
| V5 | INV | exit_trigger vs stop_trigger_kind consistency | the 2026-07-12 export-join defect |
| V6 | INV | no simultaneous same-underlying twins (NLS/BFX signature) | rename-twin dups (measured: ~11.9% of record-run realized PnL) |
| V7 | INV | Virgin_territory only with ≥ virgin_lookback_bars of history | the COO/CWST mislabel class |
| V8 | EXP | entries with ma_direction Declining (→ INV once declining-MA gate armed) | AIR class |
| V9 | EXP | entries with a 5y prior-top within +X% (default 25) | monitored statistic ONLY |
| V10 | EXP | entry-week close > Y% above 4-weeks-ago close (default 60) | monitored statistic ONLY |
| V11 | EXP | stop_initial_distance_pct within bounds | stop placement sanity |

## Amendment 2026-09-01: V13 + V14 — execution-causality checks

V12 (stop-distance gate consistency) landed after v1. V13 and V14 close a
different blind spot: **V1–V12 all reason about the entry DECISION, none about
whether the resulting FILL is physically possible.** Two defects on the 26y arc
run (`dev/experiments/arc-rerun-2026-09-01/README.md`) had to be found by hand
on the artifacts because the validator was structurally unable to see them.

| id | class | check | catches |
|---|---|---|---|
| V13 | INV | every trade's `entry_date` / `exit_date` has a bar for that symbol, and `entry_price` / `exit_price` lie inside that bar's `[low, high]` (± `fill_price_epsilon_pct`) | §D1 — 2,500+ exits dated on a SATURDAY (no bar exists) at the preceding Friday's OPEN, i.e. a fill at a price that predates the Friday-close decision. Also true of the record convention (269/269 laggard exits). |
| V14 | EXP | no `stop_loss` exit within `entry_bar_stopout_max_bars` trading bars of entry whose **entry-day close sits on the safe side of the installed stop** (≥ stop for LONG, ≤ for SHORT) | §D2 — 261/668 stop-losses exit within one day; 173 had entry-day low < stop ≤ entry-day close and were sold next open ABOVE the stop. The stop was evaluated against the entry bar's PRE-FILL low, which the position never held through. |

**Why V13 is INV and V14 is EXP.** A fill on a day the symbol did not trade, or
outside the day's range, is impossible under any fill model — an invariant. A
same-bar stop-out, by contrast, is legitimate when the entry day genuinely
gaps down and *closes past* the stop; only the closed-on-the-safe-side shape is
suspect, and its rate is a statistic to watch rather than a hard zero. V14's
severity can be promoted via `severity_overrides` once the entry-bar stop
evaluation is fixed and the expected count is 0.

**Skips (un-evaluable, not violations).** V13 skips rows whose symbol is absent
from the bar store, or whose store entry has no daily bars; V14 additionally
skips rows carrying neither stop-distance column and rows with no bar on the
entry date. Both are counted in the check's `n_skipped`, which the report
renders as `(N skipped)` — so "PASS because everything was skipped" stays
visible, per the same principle as the audit-join coverage line.

**Basis guard.** `bars.daily` carries RAW (unadjusted) OHLC, because the
simulator fills against `Daily_price.open_price/high_price/low_price/
close_price` and never `adjusted_close`. Should the CSV store nevertheless be
re-based after a run, every price for that symbol shifts at once; V13's price
leg and V14's stop comparison are therefore waived when the bar's close and the
fill price fail `Validator_step.price_basis_ok`. V13's date leg is basis-free
and always runs — which is the leg that catches §D1.

**Reconstructing the stop (V14).** `entry_price × (1 − d)` for LONG, `(1 + d)`
for SHORT, with `d` = `stop_fill_distance_pct` when the column is present
(fill-basis, exactly the quantity the `Stop_too_wide` gate bounds and V12
checks) and `stop_initial_distance_pct` otherwise (E-basis, approximate when
the fill diverges from the screener's `E`).

## ⚠ Amendment (same session, post-screens): V9 and V10 are PERMANENTLY report-only

Both were screened as prospective entry gates the same night and
**measured harmful** (`dev/notes/visual-trade-audit-2026-07-12.md`):
prior-top headroom blocks the momentum-leader winners and misses the
deep-crash losses; recent-S4/basing blocks the strategy's standard entry
(64-94% block rates, all variants net-negative, monsters feature-identical
to the loss cluster). They remain in the validator as DISTRIBUTION
STATISTICS (drift detection), and their severity must never be promoted to
INVARIANT. V8's promotion path (declining-MA gate, WF-CV-validated for
broad) is unaffected.

## Follow-ups

1. `scenario_runner --validate` post-step + goldens all-invariants-zero band.
2. Run v1 over the record run (first acceptance): expect hits on V5 (export
   join), V6 (10 twin groups), V7 (COO class); V1-V4 expected clean.
3. Live-pipeline reuse: validate each weekly snapshot before the report is
   trusted.
4. Fix-side work the validator will then pin: export-join fix (V5→0),
   twin-dedup in snapshot builders + re-pin (V6→0), resistance
   window/label fix (V7→0).
