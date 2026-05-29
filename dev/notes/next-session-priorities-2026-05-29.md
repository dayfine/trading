# Next-session priorities — 2026-05-29

**Supersedes:** all prior `dev/notes/next-session-priorities-*.md`. The strategic frame has shifted significantly based on diagnostic findings this session.

## TL;DR

**v7 BO is dead. v8 BO design is dead. The Weinstein strategy as currently implemented is a DEFENSIVE risk-management tool, not an alpha-generation tool.** Reframe to risk-adjusted (Calmar/Sortino) success metrics, ship the metric-gate change (P2), and run the trade-autopsy decomposition (P3) before any further mechanism change.

**P1 update 2026-05-29 PM:** the proposed laggard-disable Cell-E refresh was RETRACTED after re-test — ablation finding doesn't generalize from 12-symbol to 500-symbol universes. See `p1-laggard-disable-retracted-2026-05-29.md`.

## Read first

- `dev/notes/layered-decomposition-synthesis-2026-05-29.md` — full 27y component-isolation analysis with verdict + concrete next-step list
- `dev/notes/per-symbol-stage-strategy-2026-05-29.md` (PR #1353) — 12-symbol diagnostic: stage analysis is drawdown-protection, NOT alpha source on absolute return
- `dev/notes/mechanism-ablation-2026-05-29.md` (#1352 merged) — `laggard_rotation` is the alpha-killer **on narrow universes** (narrowed claim post-P1 retest)
- `dev/notes/p1-laggard-disable-retracted-2026-05-29.md` (this session) — universe-dependence finding

## P0 — confirm direction with user

Before any dispatching, present the strategic verdict:

> **Outcome C-mixed:** stage analysis loses absolute CAGR (3/12 long-only winners vs BAH SPY) but wins risk-adjusted (Calmar 6/12). The Weinstein implementation IS extracting alpha — just risk-adjusted alpha, not absolute-return alpha. Recommended reframe: measure on Calmar/Sortino, ship one defensive-tilt config that beats BAH on Calmar, defer all v8 BO work.

Get user agreement OR pushback. If they want to pursue absolute-CAGR alpha anyway, the options are:
- (a) Try multi-symbol cross-sectional rotation (different mechanism than per-symbol)
- (b) Pivot to broader-universe per `project_strategic_pivot_broader_first.md`
- (c) Pivot off Weinstein entirely

## P1 — RETRACTED (laggard disable hurts on full-universe panel)

**Original P1:** disable `enable_laggard_rotation` as new Cell-E default.

**Outcome:** rejected after 2026-05-29 panel re-test. See `dev/notes/p1-laggard-disable-retracted-2026-05-29.md`.

Both panel scenarios regressed: 5y panel lost on every risk-adjusted metric (Sharpe −0.08, Calmar −0.11, MaxDD +3.4pp); 15y panel had marginal Calmar gain (+0.04) but Sharpe / Sortino / return all degraded (−0.04 / −0.11 / −45pp). The ablation finding (#1352) was real for narrow universes (12 symbols) but does not generalize to the production 500-symbol panel where rotation has many uncorrelated candidates to cycle into.

**Narrower form survives:** for per-symbol or sector-ETF diagnostic experiments, keep `enable_laggard_rotation = false`. NOT a global default change.

## P2 — adopt Calmar/Sortino as primary metric (STILL VALID)

Independent of P1's retraction. Update `promote_config.sh` to gate on Calmar Δ ≥ +0.5 (or Sortino — pick whichever is more stable across the 2-scenario panel) rather than Sharpe Δ ≥ -0.10. Add CAGR Δ ≥ -2.0pp as a sanity floor (don't promote configs that throw away half the upside).

Updated motivation post-P1 retraction: the per-symbol § 4.6 finding stands — stage analysis delivers risk-adjusted alpha (Calmar 6/12 wins) but loses absolute CAGR on most symbols. The gate should reward risk-adjusted gains rather than Sharpe-only. P2 proceeds against existing Cell-E baseline (laggard ON). The 15y panel actual.sexp now has Calmar 0.52 + Sortino 1.25 — directly usable for the new PANEL pin.

Per the synthesis doc: "The reframed win condition: beat BAH SPY on Calmar ≥ 1.5× with CAGR within -2pp."

## P3 — systematic gain-capture autopsy

The diagnostic verdict says Weinstein is great at avoiding losses, weak at capturing gains. Before fixing, decompose WHICH gain-capture failure mode is biggest. Four candidates ranked by likely impact:

| # | Failure mode | Why suspected | Already ruled out? |
|---|---|---|---|
| 1 | **Premature exit (Stage 3 false-positives)** | Per-symbol agent: "many Stage 3 periods resolve back to Stage 2" | NO |
| 2 | **Late re-entry** | After stop-out / Stage 3 exit, re-entry requires fresh Stage 1→2 cycle (~30w wait); price often runs hard during the wait (2009-Q2, 2020-Q2) | NO |
| 3 | **Late Stage 2 admission** | 30-week MA needs 30 weeks to compute; bear-bottom recoveries (Mar 2009, Mar 2020) signal Stage 2 months late, missing the V-recovery | NO |
| 4 | **Stop-out whipsaws during Stage 2** | Wide stops alone barely helped in ablation (+0.08pp SPY, -2.1pp sectors) — likely NOT a primary contributor | YES (eliminated) |

**Approach: build a trade-autopsy tool** on top of the per-symbol stage strategy module that just landed (#1353):
- For each of the 197 trades over 12 symbols × 27y, classify the exit reason
- Quantify "missed gain" = (BAH price at re-entry) − (exit price), in % of position
- Aggregate by failure mode → empirical breakdown of where each $ of the -2.31pp avg CAGR loss comes from
- Whichever mode is biggest = next surgical fix

Scope estimate: 1 day to build autopsy tool, 1 day to interpret + write up findings, 1 day to ship the targeted fix on the dominant mode. Total ~3 days to convert "stage analysis underperforms by 2.31pp" into "fixed mechanism X recovers Y pp."

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

**ALL PRs merged. No open work in flight.**

Final-session additions to main: #1351 (synthesis + this priorities doc) + #1353 (per-symbol stage strategy) + #1355 (mechanism ablation). #1348/#1352/#1354 closed as duplicates after add/add conflicts during concurrent-agent work.

**No active agents.** Two diagnostic agents completed (ablation, per-symbol). All others completed or stopped.

**No active sweeps.** v7 finished + post-analysis done.

**Main CI:** check `gh run list --branch main --workflow CI --limit 1` at session start per `session-rampup.md`.
