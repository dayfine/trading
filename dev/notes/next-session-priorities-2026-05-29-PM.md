# Next-session priorities — 2026-05-29 PM session

**Supersedes:** `dev/notes/next-session-priorities-2026-05-29.md` (morning) after the reframe-cycle PRs landed + autopsy data identified the dominant fix.

## TL;DR

Reframe cycle complete (PRs #1357 retraction, #1359 Calmar gate, #1360 autopsy tool). Autopsy data identifies **Stage 3 false-positive** as the dominant load-bearing failure mode. New P0: **stage3 hysteresis** — single-knob fix on a high-confidence diagnostic basis.

## What shipped this session

| PR | Track | What |
|---|---|---|
| #1357 | docs (P1 retraction) | Original P1 (disable laggard_rotation as Cell-E default) **retracted** — 12-symbol ablation finding doesn't generalize to 500-symbol panel; would have regressed Sharpe/Calmar/MaxDD/return on both windows |
| #1359 | promote (P2) | **Calmar/Sortino primary gate** in `promote_config.sh` + CAGR floor (2pp default). PANEL row format extended with cell_e_calmar + cell_e_sortino. Sharpe + MaxDD + trades ratio retained as secondary guardrails |
| #1360 | autopsy (P3) | **trade_autopsy tool** under `analysis/scripts/trade_autopsy/`. Classifies the 196 trades from per-symbol stage strategy (#1353) into 4 failure modes + quantifies missed gain. Survived QC rework iter 1 (nesting + file-length linter fixes) |

## Autopsy headline

| Rank | Failure mode | # trades | Total missed gain | Avg/trade |
|---|---|---|---|---|
| 1 | **late_reentry** | 48 | **+1557.83%** | +32.45% |
| 2 | **stage3_false_positive** | 71 | **+1176.23%** | +16.57% |
| 3 | late_stage2_admission | 100 | +505.01% | +5.05% |
| 4 | stop_out_whipsaw | 0 | 0 | inert |

**Ranks 1 + 2 share a common root cause:** false Stage 2→3 transitions that immediately resolve back to Stage 2. Strategy exits prematurely, then waits months/years for a fresh Stage 1→2 cycle. Concrete SPY examples: 2012-2016 (+58.5%) and 2022-2025 (+56.3%). The two modes are really one mechanism viewed at two points in the trade lifecycle.

Combined missed gain across modes 1+2: **+2734% over 27 years × 12 symbols** — roughly +8.4% CAGR per symbol that the current Cell-E-with-laggard configuration leaves on the table.

## P0 — stage3 hysteresis (the data-driven fix)

Build a two-knob hysteresis on Stage 2→3 transitions:

1. **`stage3_confirmation_weeks` (int, default 2-3)** — Stage-3 classification only fires after N consecutive weeks where the classifier says Stage 3. Filters single-week false transitions (the 2012-2016 SPY case).
2. **`stage3_exit_margin_pct` (float, default 0.02-0.05)** — require price below 30-week MA by at least margin% before declaring Stage 3, on top of the existing definition. Filters marginal touches that resolve immediately.

### Concrete change set

- `weinstein_strategy_config.{ml,mli}` — two new config fields with documented defaults. Defaults = 0 + 0.0 (preserve existing behavior); panel scenarios opt in via override.
- `stage_classifier.ml` (or wherever Stage 3 entry is decided) — apply hysteresis. Pure-function change; testable in isolation.
- Tests in `stage_classifier/test/` — 4-6 new cases covering: (a) single-week Stage 3 transient correctly suppressed at N=2; (b) confirmed Stage 3 fires at week N; (c) margin threshold correctly accepts deep Stage 3 + rejects marginal touches; (d) backward-compat: default config = pre-PR behavior.
- Panel scenario re-pins — enable the hysteresis in both `sp500-2010-2026.sexp` + `sp500-2019-2023.sexp`; re-run both via scenario_runner; update headers + promote_config.sh PANEL constants (now includes Calmar + Sortino columns per #1359).
- Trade-autopsy re-run after the fix — confirm late_reentry + stage3_false_positive missed-gain drops materially. This validates the autopsy framework is real (not just a labelling exercise).

### Scope
- 1 day for config + classifier + unit tests
- 1 day for panel re-runs + repins (2× scenarios × ~25 min wall = ~1h wall) + promote_config PANEL update
- 0.5 day for autopsy re-run + report
- ~2-3 days total wall, single PR (or 2 PRs if scenario re-pins want to be separate)

### Authority
- `dev/notes/trade-autopsy-2026-05-29.md` (in PR #1360, will land on main shortly) — the diagnostic data
- `docs/design/weinstein-book-reference.md` — the book's Stage 3 definition. Stan's writing supports hysteresis (he emphasizes confirmation; a single-week MA touch isn't a regime change).
- `dev/notes/p1-laggard-disable-retracted-2026-05-29.md` — lesson for sanity-checking the fix on the production panel BEFORE generalizing.

### Risk + sanity checks

- The autopsy classified failure modes via a price-recovery proxy ("close ≥ exit × 1.05 within 12 weeks"), not by re-evaluating the 30-week MA. The proxy is documented honestly in the autopsy report + .mli. For the hysteresis fix, the actual classifier change uses the MA-based definition — this is a strictly principled basis.
- Hysteresis adds latency to Stage 3 detection. In SHARP bear regimes (2008, COVID 2020 Q1), late-by-2-weeks exit could cost 3-8% of position. Need to verify the fix doesn't make 2008 MaxDD worse on the 15y panel.
- Cell-E baseline must still pass the P2 Calmar/Sortino gate after the hysteresis change. Plan: re-pin panel headers + verify against the new gate before promoting.

## P1 — re-run trade-autopsy with the hysteresis fix in place

After P0 ships, re-run autopsy_runner against the per-symbol stage strategy module with the new defaults. Expectation:
- late_reentry total drops by 40-70% (the suppressed false transitions stop firing → no premature exit → no late re-entry)
- stage3_false_positive total drops dramatically (definitionally, hysteresis suppresses these)
- late_stage2_admission unchanged (separate mechanism, no fix yet)
- Aggregate missed gain drop confirms the hypothesis

Write up findings in `dev/notes/trade-autopsy-post-hysteresis-2026-05-29.md`. If the fix worked, this is the validation moment for the autopsy framework as a fix-finder.

## P2 — promote Cell-E with stage3 hysteresis as new default

If P1 confirms material improvement:
- Update Cell-E panel scenarios to enable hysteresis by default (the canonical Cell-E config now includes the two new knobs)
- Use `promote_config.sh` (P2 of this session) to validate via the Calmar/Sortino gate
- Land as `feat(cell-e): adopt stage3 hysteresis — autopsy-validated fix`

## P3 — late_stage2_admission as next surface

Per autopsy, late_stage2_admission is the #3 failure mode (+505% missed gain, 100 trades). Lower per-trade impact than late_reentry / stage3_false_positive but widely distributed. Root cause: 30-week MA needs 30 weeks of data; bear-bottom recoveries (Mar 2009, Mar 2020) signal Stage 2 months late.

Candidate fix surfaces:
- Shorter confirmation MA (e.g. 13-week + 30-week dual confirmation; enter Stage 2 on 13-week confirmation, hold on 30-week — Weinstein-flavored "early admission" rule)
- Volatility-adjusted MA period (faster MA in low-vol regimes)
- Volume + breadth confirmation as proxy for trend establishment before MA recovers

This is more exploratory than P0/P1. Defer until P0 + P1 confirm the framework actually delivers.

## DEFER (per prior session)

- **Cross-sectional rotation (`french_weinstein_rotation`)** — was P4 in the morning doc. Still on roadmap but downgraded: P0 (stage3 hysteresis) is higher-confidence + smaller scope + addresses 75% of measured missed gain (modes 1+2 = 2734% / total ≈ 3239%). Cross-section is the right next move only if hysteresis fix doesn't close the gap.
- **Broader-universe sweep (Russell 3000 / French-49 / Shiller)** — per `project_strategic_pivot_broader_first.md`. Same reason: hysteresis fix on existing panel is the higher-leverage move first.
- **Off-Weinstein mechanism** — premature. The autopsy + hysteresis + Calmar-gate framework is producing real signal; don't pivot.
- **Score-formula tuning, v8 BO, short-side feature work** — dead per prior session.

## Session state on return

**Merged this session (2026-05-29 AM/PM):**
- #1357 (P1 retraction)
- #1359 (P2 Calmar/Sortino gate)
- #1360 (P3 trade-autopsy tool, with rework iter 1)
- Plus this docs PR (forthcoming)

**Main CI:** check `gh run list --branch main --workflow CI --limit 1` per `session-rampup.md`.

**No active agents.** No active sweeps. No locked worktrees expected (cleanup happened mid-session).
