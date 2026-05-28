# Next-session priorities — 2026-05-29

**Supersedes:** all prior `dev/notes/next-session-priorities-*.md`. The strategic frame has shifted significantly based on diagnostic findings this session.

## TL;DR

**v7 BO is dead. v8 BO design is dead. The Weinstein strategy as currently implemented is a DEFENSIVE risk-management tool, not an alpha-generation tool.** Reframe to risk-adjusted (Calmar/Sortino) success metrics, then ship one concrete fix and one experiment.

## Read first

- `dev/notes/layered-decomposition-synthesis-2026-05-29.md` — full 27y component-isolation analysis with verdict + concrete next-step list
- `dev/notes/per-symbol-stage-strategy-2026-05-29.md` (PR #1353) — 12-symbol diagnostic: stage analysis is drawdown-protection, NOT alpha source on absolute return
- `dev/notes/mechanism-ablation-2026-05-29.md` (#1352 merged) — `laggard_rotation` is the dominant alpha-killer

## P0 — confirm direction with user

Before any dispatching, present the strategic verdict:

> **Outcome C-mixed:** stage analysis loses absolute CAGR (3/12 long-only winners vs BAH SPY) but wins risk-adjusted (Calmar 6/12). The Weinstein implementation IS extracting alpha — just risk-adjusted alpha, not absolute-return alpha. Recommended reframe: measure on Calmar/Sortino, ship one defensive-tilt config that beats BAH on Calmar, defer all v8 BO work.

Get user agreement OR pushback. If they want to pursue absolute-CAGR alpha anyway, the options are:
- (a) Try multi-symbol cross-sectional rotation (different mechanism than per-symbol)
- (b) Pivot to broader-universe per `project_strategic_pivot_broader_first.md`
- (c) Pivot off Weinstein entirely

## P1 — one config change + one ablation re-test

1. **Disable `laggard_rotation`** as new Cell-E default (PR-sized: config edit + tests).
2. **Re-run promote_config.sh** with that change against the 2-scenario panel (sp500-2010-2026 + sp500-2019-2023). Expectation: passes the gate (laggard was the alpha-killer that was making v7 fail). If it doesn't, the gate itself needs reframing per P2.

## P2 — adopt Calmar/Sortino as primary metric

Update `promote_config.sh` to gate on Calmar Δ ≥ +0.5 (or Sortino, depending on which is more stable across the 2-scenario panel) rather than Sharpe Δ ≥ -0.10. Add CAGR Δ ≥ -2.0pp as a sanity floor (don't promote configs that throw away half the upside).

Per the synthesis doc: "The reframed win condition: beat BAH SPY on Calmar ≥ 1.5× with CAGR within -2pp."

## P3 — investigate `stage3_force_exit` false-positives

The per-symbol agent's interpretation: ~half of Stage 3 exits resolve back to Stage 2 (continuation), not Stage 4 (decline). If true, fixing these false-positives could give 1-3pp CAGR back without breaking the risk profile. Needs:
- Per-symbol time-series of stage transitions (1998-2025)
- Count: of N Stage 3 exits, M resolved back to Stage 2 within K weeks
- Patch the classifier (or screener cascade) to require N-week confirmation before declaring Stage 3

## P4 — try cross-sectional rotation (NEW STRATEGY MODULE)

Per per-symbol agent's recommendation: RS filter selects the best Stage-2 candidate from a basket. This is `analysis/weinstein/french_weinstein_rotation/` (which may exist or need building — check). Tests whether holding the strongest trending name in a basket beats per-symbol independent runs.

This is the only path to potentially exceed BAH on absolute return — and it stays within the Weinstein mechanism (no premature mechanism redesign per `feedback_strategy_mechanic_changes_too_explorative.md`).

## STOP doing (per synthesis doc)

- v8 BO design + launch
- Score-formula tuning (any methodology)
- Short-side feature work (1/12 wins, -5pp avg)
- Optimizing portfolio mechanics for absolute-CAGR alpha
- Multi-window BO with any objective

## DEFER

- Broader-universe sweep (Russell 3000 / French-49 / Shiller) — worth doing AFTER P1+P2+P3 land
- Off-Weinstein mechanism (momentum, factor, regime-switching) — premature
- Mid-cycle redesigns (Kelly sizing, continuation buys, sector cap)

## Session state on return

**Merged to main during this session (overnight 2026-05-28/29):**
- v8 design churn: #1338 (v7 results) #1339 (score weights) #1341 (critique) #1342 (hard-gate) #1343 (hard-gate critique) #1346 (round-2 critique) #1349 (round-3 redesign)
- Diagnostics: #1340 (sensitivity-sweep fix) #1345 (1a sectors) #1347 (1a SPY-only) #1350 (1b/2b fullsize) #1352 (mechanism ablation)
- Ops: #1336 (orchestrator skip-PR-on-noop)

**Open PRs (auto-merge monitor running, CI pending):**
- #1351 — `docs/layered-synthesis-2026-05-29` synthesis (docs-only, will auto-merge)
- #1352 — `experiment/mechanism-ablation` (docs+sexp, will auto-merge on CI green)
- #1353 — `experiment/per-symbol-stage-strategy-clean` (HAS OCaml code, may need QC dispatch — flag for human decision)

**No active agents.** Two diagnostic agents completed (ablation, per-symbol). All others completed or stopped.

**No active sweeps.** v7 finished + post-analysis done.

**Main CI:** check `gh run list --branch main --workflow CI --limit 1` at session start per `session-rampup.md`.
