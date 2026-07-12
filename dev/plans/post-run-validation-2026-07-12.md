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
