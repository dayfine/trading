# Build-2 arming-speed (`fast_v_arm_on_rate_alone`) WF-CV — FINDINGS (2026-06-22)

WF-CV follow-up to the strong 2-window screen
(`dev/backtest/build2-arming-speed-screen-2026-06-22/FINDINGS.md`), which showed
the knob dormant in a bull and transformative in the 2020-V. This re-tests it
across **every regime 2000-2026** — crucially the **2008 GFC** (a slow cascade)
and choppy corrections (2010, 2011) the 2-window screen could not see.

- **Spec:** `test_data/walk_forward/arming-speed-deep-2000-2026.sexp`.
- **Base:** `sp500-2000-2026-catstop` (deep long-only, **catastrophic_stop_pct=0.10
  ON in both cells**). Axis `((flag fast_v_arm_on_rate_alone) (values (true
  false)))`. Rolling 2000-2026, test 365 / step 365 → 26 OOS folds. CSV on `data/`.

## Result — frontier-dominant but SMALL; the screen over-claimed

| Variant | Sharpe | Calmar | MaxDD % | Pareto | DSR |
|---|---|---|---|---|---|
| baseline (≡ false) | 0.695 | 1.334 | 10.68 | **no** | 1.0000 |
| **fast_v_arm_on_rate_alone=true** | **0.699** | **1.348** | **10.60** | **yes** | 1.0000 |

`true` is the **sole Pareto-frontier member** — it dominates baseline on all three
(Sharpe ↑, Calmar ↑, MaxDD ↓). But the aggregate edge is **small** (+0.004 Sharpe,
+0.014 Calmar, mean return 11.43→11.52%) — far less than the 2018-2021 screen's
"MaxDD halved" suggested, because the catastrophic stop only fires in the ~2 fast-V
folds of 26, and the screen's framing concentrated on exactly that window.

## Per-fold — helps fast-V crashes, whipsaws choppy corrections, inert in slow cascades

`true` differs from baseline in only **4 of 26 folds**:

| fold | regime | baseline ret | true ret | Δ | read |
|---|---|---|---|---|---|
| fold-020 | 2020 COVID fast-V | 6.93% | **9.96%** | **+3.0** | crash win (MaxDD 18.6→16.3) ✓ |
| fold-018 | 2018-Q4 sharp correction | 8.62% | **9.84%** | **+1.2** | fast-V win ✓ |
| fold-010 | 2010 recovery chop | 12.12% | 11.35% | **−0.77** | whipsaw |
| fold-011 | 2011 Euro-crisis chop | −8.61% | −9.80% | **−1.2** | whipsaw |
| fold-008 | **2008 GFC** | −8.73% | −8.73% | **0** | **inert (slow cascade, not fast-V)** |
| fold-022 | 2022 bear | −10.59% | −10.59% | 0 | inert (grind) |

Two clean wins (2020, 2018-Q4: +4.2pp combined), two whipsaw losses (2010, 2011:
−2.0pp combined), inert in the rest — net mildly positive, frontier-dominant.

## The transferable WHY (this is the load-bearing output)

1. **The knob targets FAST-V crashes specifically — and 2008 was NOT one.**
   fold-008 (the GFC) is byte-identical: the 2008 cascade declined slowly enough
   that the 4-week rate never armed `Fast_v` early, so the knob did nothing.
   `fast_v_arm_on_rate_alone` is insurance against *gap-down V-crashes* (2020,
   2018-Q4), not slow distribution bears (2008, 2022) — those are the
   `slow_grind`/structural-exit regime. The two decline-characters need different
   tools; this confirms the `Decline_character` split is real.
2. **There is a whipsaw cost the 2-window screen hid.** In choppy corrections
   (2010, 2011) the rate-armed `Fast_v` fires on a sharp-but-recovering dip, the
   −10% catastrophic stop sells, and price re-takes the level → a small loss. The
   screen's two windows (one clean crash, one clean bull) had no choppy-correction
   regime, so it read as "dormant-or-helpful." WF-CV reveals it is
   **helpful-in-fast-V / whipsaw-in-chop / inert-in-slow-bear.** (Textbook
   screen-rigor: the screen over-claimed; the surface corrects it.)
3. **The whipsaw points at a tunable.** `fast_v_min_rate_pct` (default 0.08) is the
   arming threshold; raising it would suppress the 2010/2011 false-positives while
   keeping the 2020 catch. The mechanism's net value is gated on that threshold —
   the WF-CV should be re-run as a `fast_v_min_rate_pct` SURFACE, not a single
   point. (NB: this threshold is a `Decline_character.config` field NOT yet exposed
   as a `Weinstein_strategy.config` field — exposing it is a small feat follow-up,
   prerequisite to the surface.)

## Verdict: ACCEPT (weak, single cell) — escalate to a threshold surface, not a flip

`true` dominates baseline on the frontier and is net-positive, concentrated in
genuine fast-V crashes — a faithful tail-RISK-insurance mechanism
(`weinstein-faithful-core.md`) that does **not** tax the fat tail (inert in
24/26 folds). But the edge is small and carries a real whipsaw cost in choppy
corrections. Per `promotion-confirmation.md` this single cell is **not** a default
flip:
- **Next: expose `fast_v_min_rate_pct` as a strategy config field, then run a
  `{0.08, 0.12, 0.16}` surface** to suppress the 2010/2011 whipsaw, then the
  macro-regime-diverse confirmation grid.
- Default stays off; the knob remains a default-off axis.

Recorded: `dev/experiments/_ledger/2026-06-22-arming-speed-wfcv.sexp`.

## Caveats
- Long-only base (isolates crash protection), static sp500-as-of-2000 universe,
  single `catastrophic_stop_pct=0.10` and single `fast_v_min_rate_pct=0.08`. The
  threshold surface (above) is the priority follow-up.
- Evidence: `walk_forward_report.md` + `ranking.md` (committed). Deep `data/`
  store gitignored.
