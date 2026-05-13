## P3 — M5.5 tuning sweep design, post-NAV-fix

**Status:** design-ready; blocked on PR #1063 landing + new 5y/10y/16y baselines (these are the post-fix baselines that the sweep arms measure against).

**Context.** PR #1051's 81-cell grid sweep over `screening_config.weights.*` reported flat metrics — interpreted as "weights are inert under the current cascade". The P4 investigation note (`dev/notes/screener-weights-inertness-2026-05-13.md`) showed that conclusion was driven by a key-path bug in the swept overlays: `weights.rs/volume/breakout/sector` keys do not match any field of the `scoring_weights` record (real names are `w_positive_rs/w_strong_volume/w_stage2_breakout/w_sector_strong`). `runner.ml:_apply_overrides` silently dropped the unrecognized keys, so every cell ran identical config. Weights are NOT inert — the M5.4-E4 sweep (2026-05-08, correct paths) moved metrics by 22 pp return / 0.12 Sharpe.

This note revises the original P3 axes from `next-session-priorities-2026-05-12.md` to: (a) the three knobs that were always legitimate, (b) the corrected weight sweep, and (c) the runner deep-merge fix that gates everything multi-overlay.

## Axes

| # | Knob | Path | Default | Sweep cells | Why |
|---|------|------|---------|------------:|-----|
| 1 | `installed_stop_min_pct` | `screening_config.candidate_params.installed_stop_min_pct` | 0.0 | {0.0, 0.06, 0.08, 0.10, 0.12} | Legitimate version of entry-caps arm C. Floor on installed-stop distance (G15-refactored path). Test the "wider stops on Q4 candidates stabilize hold periods" hypothesis from the entry-caps follow-up. |
| 2 | `min_correction_pct` | `stops_config.min_correction_pct` | 0.08 | {0.06, 0.08, 0.10, 0.12} | Controls support-floor detection AND the stop buffer. Lower = tighter, more stop-outs; higher = wider, longer holds. |
| 3 | `min_score_override` | `screening_config.min_score_override` | None | {None, 50, 55, 60, 65} | Cascade score gate. Tightening the floor (instead of capping the top end like arm B did) keeps the long-hold compounding regime while excluding marginal cells. |
| 4 | `max_score_override` × `installed_stop_min_pct` | combined | (None, 0.0) | {79, 82, 85} × {0.08, 0.10, 0.12} | E6 from entry-caps — Q5 cap paired with wider stops. Bundle into single overlay sexp until runner deep-merge fix lands (#TBD). |
| 5 | Conditional Q5 cap on `macro=Bullish` | screener-side guard | always-on | (off, on) | E7 from entry-caps. Two-arm test. |
| 6 | Soft Q5 penalty | `Screener.scoring_weights.w_*` | additive | TBD | E5. Re-tune weights so Q5 features get less score weight rather than hard-rejecting Q5 candidates. Requires the corrected key paths from P4. |

## Sequencing

1. **Wait for #1063 (NAV fix) merge** — without it, sweep results are noise-bounded by the silent NAV collapse.
2. **Re-pin 10y + 16y goldens** (PR follow-up if force-liqs drop on long-short, per #1056 P1 sub-path 3). 5y already verified PASS-in-range.
3. **Re-baseline:** single-cell control runs on the 3 horizons (5y, 10y, 16y long-only + long-short) with the merged fix. Pin canonical metrics in a `m5.5-tuning-baseline-2026-05-XX.md` note.
4. **Axis 1 (`installed_stop_min_pct`)** — 5 cells × 5y horizon, parallel-3 budget. Cheapest, most-likely lever for the Sharpe-vs-MaxDD tradeoff observed in entry-caps arm B.
5. **Axis 2 (`min_correction_pct`)** — 4 cells × 5y. Interacts with axis 1 (both modify effective stop distance).
6. **Axis 3 (`min_score_override` floor tightening)** — 5 cells × 5y.
7. **Cross-axis 1×2** — 5×4 = 20 cells × 5y if axes 1+2 each show a clear winner. Expensive; defer unless axes 1+2 individually move metrics.
8. **Axis 4 (E6: Q5 cap × wider stops, BUNDLED overlay)** — 3×3 = 9 cells × 5y. Sub-condition: requires the workaround documented in entry-caps report ("bundle into single overlay sexp").
9. **Axis 5 (E7: conditional Q5)** — requires a code change in `Screener.scoring` / `Weinstein_strategy_screening`. Defer until E6 picks a winner.
10. **Axis 6 (E5: soft Q5 penalty)** — requires understanding which `w_*` fields drive Q5's confidence (high RS, extreme volume, late-Stage-2 timing). Needs a Q5-feature-attribution sub-investigation before sweep design.

## Pre-flight checks

Before launching any multi-overlay sweep (axes 4+), verify the runner deep-merge bug is either:
- Fixed (separate PR; touches `trading/trading/backtest/lib/runner.ml:_merge_records`), OR
- Worked around by bundling all overrides for one top-level field into a single overlay sexp.

A sweep-path validation linter (suggested in the P4 note) would catch this hazard preventively — e.g. validate that every overlay key path resolves to a real record field after deserializing.

## Runtime budget

Per-cell wall on 5y:
- Local parallel-3: ~6–8 min (verified by the 2026-05-13 P1 verification run).
- GHA: ~15 min post-Cell-E (per `golden-runs-sp500-5y.yml`).

5 cells × 8 min × parallel-3 = ~14 min wall for axis 1.
4 cells × 8 min × parallel-3 = ~11 min wall for axis 2.
20-cell cross-axis: ~55 min wall.

10y / 16y horizons triple the per-cell time (broad universe + longer window) — reserve those for the final 1–2 winning cells per axis, not the whole grid.

## Outputs (per sweep)

Each sweep produces:
- `dev/experiments/m5.5-tuning-axis-{N}-{date}/` directory
- One overlay sexp per cell (`cell-{i}.sexp`)
- One report `report.md` summarizing metric deltas vs. baseline
- A single ROW added to `dev/notes/m5.5-tuning-rollup-2026-05-XX.md` so the matrix is comparable across axes

## Open items

- Q5 feature attribution: which scoring features push a candidate above 80? Need a one-Friday tap on `Screener.scoring` that emits per-candidate sub-scores. Likely lives in `analysis/weinstein/screener/lib/screener_scoring.ml` — add a debug emitter behind a config flag, or a one-shot OCaml exe under `analysis/scripts/`.
- Runner deep-merge fix: file as separate plan note; not part of P3 itself but blocks axes 4+ at scale.
- Sweep-path validation linter: same — separate plan note; closes the silent-no-op hazard from PR #1051.
