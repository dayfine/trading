# Overnight session — 2026-05-13

User briefed at session start (~2026-05-12 23:00) to work autonomously for
4-6 hours on the five identified follow-ups (F1-F5) plus residual QC/merge
work from the prior day. Effective working window ~3-4h.

## What shipped

| PR | Topic | Status | Wall |
|---|---|---|---|
| #1052 | P1 force-liq fix (Portfolio_floor death loop) | ✅ MERGED | (pre-session) |
| #1053 | P2 metric pin schema (Sortino/Calmar/Ulcer) | ✅ MERGED | (pre-session) |
| #1054 | F4 wall_seconds gate (emit + pin) | ✅ MERGED | ~1h |
| #1055 | F1 5y sp500-2019-2023 new-metric pins (both variants) | ✅ MERGED | ~1h |
| #1056 | F5 16y cascade investigation note | ✅ MERGED | ~1h |
| #1057 | F2 10y decade-2014-2023 new-metric pins | ✅ MERGED | ~2h (3 review iterations) |
| #1058 | F3 16y sp500-2010-2026 long-only + long-short pins + re-calibration | 🟡 OPEN, QC dispatched | — |

## Top findings

### F5 cascade investigation — death loop suppressed, not eliminated

PR #1052's halt-gate is mechanically correct (1 cascade per Bearish→non-Bearish
macro transition, observed). But the underlying signal is firing on a falsehood:
the 13 remaining force-liqs on 16y long-short have `portfolio_value` at ~79%
of peak (far above the 40% floor). The trigger is spurious — likely
`Portfolio_view._holding_market_value` returning 0.0 on `get_price=None` for
newly-entered positions + the known simulator NAV-fallback bug.

Documented in #1056 with three concrete follow-ups:
1. Forward-fill stale prices in Portfolio_view.
2. Land #1019 (simulator NAV-fallback fix).
3. Optionally switch the floor to a rolling high-water mark.

### Why P1 fix barely changed returns

User asked why 307 → 14 force-liqs left return nearly unchanged. The answer
confirms F5: the 306 spurious cascades were liquidating positions at
near-zero P&L and immediately re-entering ≈ same Stage 2 candidates. Net
effect = wash. Post-fix, the strategy goes dormant during halt periods, also
giving up market exposure. The two effects cancel.

If the F5 root cause (NAV stale-price) lands, the strategy should:
- Drop cascades from 14 to ≤2 (only DISCA 2014 + maybe one genuine bear flip).
- Stop wasting 2025 bull-market cycles on dormant halt periods.
- **Expected return uplift: 5-15% absolute.**

### P1 fix shifted long-only behavior more than expected

The 16y long-only golden (which had 0 force-liqs pre-fix) now shows:
- **10 force_liquidations** — one legitimate cascade × ~10 positions (same root
  bug as long-short; not a regression from #1052).
- **trades 1099 → 806** (-27%).
- **avg_holding_days 34 → 44.68** (+31%).

PR #1058 re-calibrates 4 pre-existing pins to absorb the shift. Behavior is
plausible — long-only is no longer churning through spurious cascades — but
the **10 force-liqs themselves are still spurious** per the F5 hypothesis.
They'll likely drop to 0-1 once the NAV fix lands.

## Goldens-harness coverage

After this session, the M5.2c metric pin schema (from #1053) is wired into 4
of 5 major regression goldens:

| Scenario | Sortino | Calmar | Ulcer |
|---|---|---|---|
| 5y sp500-2019-2023 (#1055) | ✅ | ✅ | ✅ |
| 5y sp500-2019-2023-long-only (#1055) | ✅ | ✅ | ✅ |
| 10y decade-2014-2023 (#1057) | ✅ | ✅ | ✅ |
| 16y sp500-2010-2026 (#1058) | ✅ | ✅ | ✅ |
| 16y sp500-2010-2026-longshort (#1058) | ✅ | ✅ | ✅ |

Plus the F4 (#1054) `wall_seconds` gate is plumbed end-to-end; no goldens pin
it YET (no scenarios re-run yet with the post-#1054 binary to capture the
canonical wall_seconds.txt) but the mechanism is ready.

## Open follow-ups (next session)

1. **NAV stale-price fix.** Land #1019 + the Portfolio_view forward-fill
   discussed in #1056. Expected to drop long-only force-liqs 10→0, long-short
   14→≤2, and unlock the 5-15% return uplift hypothesised above.
2. **Re-pin 16y goldens after NAV fix.** Both 16y goldens currently have
   force-liq counts that are likely artifacts of the bug. Re-run + tighten.
3. **Pin wall_seconds in 1-2 representative goldens.** Sample the 5y and
   10y wall-times after running with the post-#1054 binary, pin ±50% (wide
   tolerance for GHA vs local Docker variance).
4. **Continue the M5.5 tuning track.** The 81-cell screener-weights grid
   confirmed weights are inert under the cascade design (#1051). Next sweep
   axes per the planning notes: `stops_config.min_correction_pct` and
   `screening_config.installed_stop_min_pct` (the new knob from #1048).

## What didn't happen

- **Peak RSS gate (originally part of F4 scope).** Skipped to keep the F4 PR
  surgical — `wall_seconds` lands first, RSS in a follow-up.
- **Live trading.** Not in scope.
- **The 81-cell follow-up diagnostic** (4-cell `{rs=0.0, rs=5.0}` extreme
  sweep) — already done before this session in PR #1051; recapped in the
  earlier session note.

## Cross-references

- F5 investigation: `dev/notes/longshort-cascades-investigation-2026-05-13.md`
  (in #1056).
- Prior session: `dev/notes/session-2026-05-12-afternoon.md`.
- NAV bug: memory note `project_simulator_nav_fallback_bug.md`.
