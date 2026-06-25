# Next-session priorities — 2026-06-25 PM (handoff)

**Supersedes** `next-session-priorities-2026-06-25.md`. That doc's P0 (#1743 merge)
was already done before this session. This session worked its **P1 — capacity
levers** and produced a reframe: the capacity gap is partly a *basis artifact*.

## Done this session (2026-06-25 PM)
- **P0 from prior doc (#1743 snapshot-mode) — already merged** before session start.
- **Capacity lever 1, concentration (`max_position_pct_long`) — WF-CV done,
  INCONCLUSIVE/no-promote** (#1748, merged). Real lever (amplifies the fat tail) but
  a return-for-DD/dispersion tradeoff; the 0.25 "near-doubling" is a knife-edge
  single-point overfit (fold-000 non-monotonic 52→131→97%). `max_long_exposure_pct`
  is inert (per-position cap is the sole binding constraint). Note:
  `capacity-concentration-surface-2026-06-25.md`. Ledger:
  `2026-06-25-capacity-concentration-surface`.
- **Capacity lever 2, turnover (`laggard hysteresis_weeks`) — WF-CV done,
  INCONCLUSIVE/no-promote.** Weak directional support (return + Calmar up, gentler
  dispersion than concentration) but non-monotonic Sharpe (6 dips below baseline),
  modest, noisy. Ledger: `2026-06-25-laggard-cadence-surface`. (In the PR below.)
- **Cross-cutting reframe (the real finding):** the deep-golden basis is tuned MORE
  capacity-suppressing than the production defaults — concentration **0.14 vs 0.30**,
  laggard hysteresis **2 vs 4** — and the **default beats the deep-base in both
  surfaces**. So the optimal-lens `Insufficient_cash` capacity gap is **partly an
  artifact of the conservative deep basis**, not necessarily a production gap. Note:
  `capacity-levers-deep-basis-recalibration-2026-06-25.md`. Memory:
  `project_deep_goldens_conservative_vs_default`.
- `min_cash_pct` confirmed **dead** (deprecated, never wired into the entry walk) —
  dropped from the capacity-lever set; the prior doc's P1.1 was a non-lever.

## P0 next session — re-pin the deep basis to production defaults, then re-run the optimal lens
The highest-value action is NOT another capacity lever — it's correcting the basis
the whole capacity question sits on. **Needs user oversight: this re-pins golden
expected metrics (golden tests shift).**
1. Re-pin the deep **long-only** goldens (`sp500-2000-2026-catstop`,
   `sp500-1998-2026`, `sp500-2010-2026`): `max_position_pct_long 0.14→0.30`,
   `laggard hysteresis_weeks 2→4`. NB long-only catstop has
   `enable_short_side=false`, so 0.14's short-diversification rationale doesn't apply.
   The **longshort** goldens may have a real force-liquidation-cascade reason to keep
   0.14/2 — re-pin those separately, if at all. Run through the confirmation grid
   (`.claude/rules/promotion-confirmation.md`) since it changes the basis every
   recent result rests on.
2. Re-run the optimal-strategy / missed-trades lens on the corrected basis. The
   `Insufficient_cash` miss rate should shrink; what remains is the *honest*
   production capacity gap.

## P1 — only if the gap survives recalibration
- **`max_positions` count cap** (planned lever 3): forces concentration via a count
  constraint rather than a size cap. Worth one surface ONLY if the gap survives P0;
  if recalibration shrinks it, deprioritise. Default-off axis → WF-CV (use a
  return/Calmar gate, NOT the `worst_delta=0` insurance gate — see process note) →
  confirmation grid.

## Process notes
- **The `Fold_gate` `worst_delta=0.0` is mis-specified for return-amplifying
  capacity levers** — it FAILs every cell because they make some folds worse while
  winning on aggregate. Read Pareto + fold-win-rate + the full response curve, not
  the gate. Future capacity surfaces: return/Calmar gate or a `worst_delta` budget.
- **WF-CV runner invocation (deep basis):** `walk_forward_runner.exe --spec <spec>
  --out-dir /tmp/sweeps/<name> --fixtures-root test_data/backtest_scenarios
  --parallel 4`. The `--fixtures-root` is REQUIRED (universe_path resolves via
  `Filename.concat fixtures_root`; default points at repo-root `data/` where the
  sp500-historical universes do not live). ~15-20 min per ~5-cell deep surface.
  `rank_variants.exe --aggregate <agg> --baseline-label baseline --lifetime-trials
  <variant-count incl baseline>` for Pareto + DSR.
- Container had ~21 `<defunct>` scenario_runner zombies (orphaned, RSS 0, harmless);
  cleared on next container restart. No live backtest at session start.

## Operational (unchanged from prior doc)
- Deep gitignored bar store is **repo-root `data/`** (735 syms 1998-2026 +
  `data/breadth/`), NOT `trading/data/`.
- All deep sp500-historical goldens currently pin `max_position_pct_long 0.14` +
  `laggard hysteresis_weeks 2` (the values P0 proposes to correct).
