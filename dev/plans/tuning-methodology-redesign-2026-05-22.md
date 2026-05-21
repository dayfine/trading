# Tuning methodology redesign — 2026-05-22

Filed mid-session after V3→V7 sweep stack converged on byte-identical
trajectories. This doc reframes the tuning problem **away from
parameter-space-sweeping toward methodology-first design**, in
response to user feedback: *"if we are spending 100h on ineffective /
non-generalizing / limited experiments, then we are not using the
time wisely, and should think harder about the methodology and refine
it more aggressively / to be more robust."*

Supersedes `dev/plans/tuning-methodology-2026-05-21.md` (which was
narrowly scoped to V3 promotion infrastructure).

## 1. Top-level objective — re-stated

**What we actually want:** a parameter config that **generalizes**
across:
- Time periods (not just 2010-2026)
- Universes (not just SP500-510-symbol)
- Market regimes (bull, bear, choppy, regime shifts)

**Not just:** a config that scores highest on the 27-fold SP500 BO
training surface.

V3→V7's "stuck composite_delta ~0.4" is symptomatic. We've been
optimizing for the wrong thing:
- The Composite scoring formula is internally consistent but biased
  toward fold-mean performance.
- The 4-param surface might be too narrow to express a meaningfully
  different strategy.
- The training universe (SP500 2010-2026) is one slice of one market;
  what works there might not transfer.
- The 27 in-sample folds are sequential (chronological); BO has no
  way to test regime independence.

A config that scores +0.25 mean Sharpe but degrades on French-49 or
Shiller-pre-1950 is worse than cell-E, not better. The promotion gate
should reflect this; the BO objective should partially encode this.

## 2. What current methodology is missing

User's 8 questions, each tagged with [Confirmed gap] or [Confirmed not-an-issue].

### 2.1 Missing randomness [GAP — significant]

Current setup is deterministic given seed:
- BO has random init samples (10), then deterministic GP.
- Walk-forward folds are sequential calendar windows, never resampled.
- Strategy is deterministic given bars + config.
- Bars are historical (no noise injection).

**Consequence:** V5 and V6 produced byte-identical BO scores to 16
decimal places. The system has no way to measure config STABILITY
under perturbation.

**Mitigations:**
| Mechanism | What it tests | Cost |
|---|---|---|
| Random restarts (different BO seeds) | Local-optima escape; gives N independent BO runs | N× wall time |
| Bootstrap fold resampling (each BO eval scores on a random fold-subset) | Robustness to fold-mix | Same wall |
| Synthetic bar noise (small Gaussian perturbation on OHLC) | Sensitivity to data quality | ~free |
| Random fold ORDER in walk-forward | Path-dependency check | ~free |

**Recommendation:** add random restarts (seeds 2026, 2027, 2028) for
the next BO sweep. If the winners diverge between seeds, the surface
has multiple local optima and we're choosing arbitrarily.

### 2.2 Training-set shape [partial GAP]

- Universe: SP500 510-symbol survivorship-corrected (`sp500-2010-2026.sexp`).
- Per-fold: 1-year test window (`test_days=365`), 6-month stride
  (`step_days=182`), 210-day warmup before each test window.
- `train_days=0`: no per-fold parameter fitting. BO selects parameters
  ONCE globally based on mean composite over all 27 in-sample folds.

**Gap:** "training set = SP500-2010-2026" is narrow. Cells optimized
here may not transfer to Russell 3000, French 49-Industry, Shiller
pre-1950, or other markets.

### 2.3 Overfitting risk [LOW within training surface, GAP across universes]

V3 winner: in-sample mean Sharpe 0.81, OOS mean 0.83 (gap +0.01) —
classic sign of NO overfitting within the training surface. 4 params
× 27 fold observations is overspecified for overfitting in the
textbook sense.

**Real concern:** 4 params can't express a meaningfully different
strategy from cell-E. The 4-D Composite landscape is genuinely
plateau-like; not a fitting failure but a parameterization failure.

### 2.4 Only 4 parameters [GAP — significant]

V3-V7 all use the same 4. Strategy has ~30-50 tunable knobs across:
- `Portfolio_risk.config` (7-12 fields)
- `Screening_config` (entry buffer, score weights, stop knobs, etc.)
- `Stage3_force_exit_config`, `Laggard_rotation_config`
- Continuation buys / PI filter / sector cap (feature flags)
- Slippage, cost-model overlay

Existing 11-knob fixture at
`trading/test_data/walk_forward/bayesian-multi-param-2026-05-16.sexp`
adds screener weights + risk-per-trade. **Tested algorithmically,
never run in production.** Natural next BO surface.

Beyond 11: each strategy module's config record. Full surface ~30-50.
Curse-of-dim hits ~15-D for plain BO; needs sparsity priors or
random-forest surrogate beyond that.

### 2.5 Cross-scenario validation [GAP — load-bearing]

The promotion gate today is:
- 5-axis composite/Sharpe/MaxDD/trades check ON the BO training
  surface.
- Plus an OOS check (4 held-out folds on the SAME universe + same
  time period as in-sample).

**Both directions to fix:**

**(a) HOLDOUT cross-scenario validation in promotion** — `promote_config.sh`
runs the winner cell against a fixed panel of REFERENCE scenarios:
- `sp500-2010-2026` (16y SP500 — the BO training universe)
- `sp500-2019-2023` (5y SP500 — different time slice)
- Broad-universe 2019 (Russell-3000-ish)
- French 49-industry 1926-2026 (100y, industry baskets — different shape)
- Shiller 1871-2025 (155y, monthly index returns — sanity check)

Output structured form (not just markdown):
```sexp
((sp500-2010-2026 ((sharpe 0.81) (max_dd 10.2) ...))
 (sp500-2019-2023 ((sharpe ...) ...))
 ...)
```

PROMOTE GATE: winner must not regress > 1pp Sharpe on any reference
scenario vs current live config.

**(b) Mixing other periods/universes INTO BO training itself** —
deeper change. Need a meta-walk-forward where each BO eval scores on
a multi-scenario panel (not just SP500 27-fold mean). Doable, ~200
LOC + new aggregate writer. Important if (a) catches V3 regressing on
broad universe.

### 2.6 Optimal-strategy counterfactual [GAP — exists but unverified]

`trading/trading/backtest/optimal/` builds the perfect-hindsight
strategy (uses future bars). Status MERGED 2026-04-29 but with a
quality concern in #856 diagnostic. Needs refresh.

**Proposed normalization:** `efficiency = candidate_sharpe / optimal_sharpe`
- 0.0 = candidate captures no alpha
- 1.0 = candidate captures all available alpha
- Adds a Composite term: rewards capturing more of the available signal

**Prerequisite:** validate optimal_strategy quality on current
universe / window. If still has bias, fix first.

### 2.7 Feature flags as 0/1 parameters [GAP]

Strategy mechanics currently hard-coded ON/OFF:
- `use_shorts` (off by default)
- `use_continuation_buys` (off by default per memory)
- `use_sector_cap` (off by default)
- `use_volume_confirmation` (on by default)

BO supports option-typed knobs via `bound_spec.Sentinel`. Could encode
as `Sentinel { threshold=0.5; upper=1.0 }` — sample below 0.5 = false,
above = true.

Plus continuous params currently hardcoded canonical:
- Stage classifier MA slope threshold
- Stage classifier weeks_advancing requirement (currently 4)
- Stage classifier MA period (canonical 30 weeks — **keep**)
- Screener score weights (W_positive_rs, W_strong_volume)
- Entry buffer, stage3 force_exit threshold
- Trailing stop tighten rate

### 2.8 Component scoring [GAP — most strategic]

Current Composite is global P&L-derived. **Should decompose:**

| Component | What it measures |
|---|---|
| Screener score | Avg Sharpe of selected cells vs universe-average Sharpe in same period |
| Portfolio score | Risk-adjusted return improvement from sizing vs equal-weighted alternative |
| Order/execution score | Actual fill prices vs idealized next-day-open prices |
| Stops score | Avg-loss-per-stopped-trade vs without-stops counterfactual |

Then BO composite becomes `w1×screener + w2×portfolio + w3×orders + w4×stops`,
and BO can target the weak component.

**Cost:** ~200-400 LOC (per-fold per-component metrics in
aggregate.sexp). **Payoff:** decomposed signal — "V3 winner improves
Sharpe by 0.25 vs cell-E; that improvement is 80% portfolio-management,
20% stops, 0% screener" tells us where the next sweep should invest.

## 3. Generalization-first redesign

The four structural changes (in order of leverage):

| # | Change | Why | Cost |
|---|---|---|---|
| **A** | Cross-scenario validation IS the promote gate (no scenario regresses > 1pp Sharpe) | If V3 winner regresses on broad universe or French-49, it's not a winner | ~3-4h dev |
| **B** | Add feature-flag knobs (use_shorts, continuation_buys, sector_cap) + canonical-but-tunable parameters (stage MA slope, screener weights) | 4 params is too few to escape the cell-E plateau; need more degrees of freedom | ~6h + a new sweep |
| **C** | Component-decomposition objective (screener/portfolio/orders/stops scores) | Lets the BO target the weak component; current global Composite blurs the signal | ~12-20h dev |
| **D** | Random restarts (multiple BO seeds) + bootstrap fold resampling | Catches local-optima lock + measures fold-mix robustness | ~free at runtime |

## 4. Stopping rules — when to abandon an experiment

V3 → V4 → V5 → V6 → V7 has been **5 sweeps testing 4 hypotheses**, with
V4/V5/V6 each killed early once their hypothesis was provisionally
disproven (~3-4h of CPU each). V7 in flight; cron at 07:15 surfaces
the iter-10 verdict.

**Rule we've been using implicitly:** if a sweep's first 10-15 iters
show identical scores to a prior sweep with a different hypothesis,
kill it. This week the rule saved us ~30h of CPU.

**Codify:** in each new sweep's plan, name the SPECIFIC observation
that would confirm / refute the hypothesis. Examples:

- V4 (soft penalty): "if first 5 iters score < -3.5, penalty isn't
  binding; kill." Was 100% met.
- V5 (wider bounds): "if first 10 iters scores within 0.05 of V3's
  random phase, wider bounds aren't binding; kill." 100% met.
- V6 (relaxed worst_delta): "if any iter score > -1.5, gate-relaxation
  surfaced a Pass cell; continue." 0% met.
- V7 (m=14): "if V7 random iters score > -1.5, wins-count was binding."
  TBD.

## 5. Experiment ordering by value/cost

Re-ranked from the prior session list:

| # | Experiment | Cost | Generalization value | Order |
|---|---|---|---|---|
| **P0** | **Refresh on optimal-strategy quality** (#856 diagnostic). Without this we can't use efficiency normalization. | ~2-3h dev | Foundation for §6 below | now |
| **P1** | **Wire cross-scenario validation as the promote gate** (Change A above). Run V3 winner against 5-scenario panel; record structured `validation.sexp`. If V3 regresses anywhere, V3 is not promotable. | ~3-4h dev + 4-6h backtest | Best leverage per hour | THIS WEEK |
| **P2** | Wait on V7 (~6h more wall) | 0h dev, 6h CPU | Closes the gate-too-strict hypothesis | passive |
| **P3** | **Random-restart V8** (V3 spec, seeds 2026 + 2027 + 2028 = 3 BO runs, pick best) | 33h CPU (background; can split across sessions) | Local-optima check; cheap to interleave | parallel to P1 |
| **P4** | **11-knob sweep** (existing `bayesian-multi-param-2026-05-16.sexp` fixture) | 12-15h CPU | More dimensions; might escape 4-D plateau | sequential after P1 lands |
| **P5** | **Feature-flag sweep** (add use_shorts, continuation_buys, sector_cap as Sentinel knobs) | ~6h dev + 12h CPU | New strategy mechanic dimensions | after P4 reads |
| **P6** | **Component-decomposition objective** (Change C above) | ~12-20h dev + 12h CPU | Highest strategic value; biggest commitment | after P5 reads |
| **P7** | Mixed-universe BO training (Change A-deeper) | ~10h dev + 30h CPU | Most strategic but most expensive | gated on P1 reading |

**Budget allocation:** the next 100h of compute + 30h of dev time
should follow P0 → P1 → P3+P4 in parallel → P5 → P6 → P7.

**Critical methodology principle:** **don't run a new sweep without
first defining what would falsify the hypothesis** (per §4 stopping
rule). This week's V4/V5/V6 kills were the right call because we had
named the falsification criterion before launching.

## 6. Top-level milestones — where we are

Per `docs/design/weinstein-trading-system-v2.md` §3:

| M# | What | Status |
|---|---|---|
| M1 | Single-stock analyst (analyze any ticker on demand) | ✓ shipped |
| M2 | Market context (macro regime + sector health) | ✓ shipped — Shiller M1 + French M2 cross-cycle complete (#1207, #1211) |
| M3 | Automated screening (weekly scan → ranked candidates) | ✓ shipped |
| M4 | Position management (full portfolio tracking + stops) | ✓ shipped |
| M5 | Historical backtesting (any date range) | ✓ shipped (M5.5 single-lever tuning EXHAUSTED) |
| **M5.5 Bayesian tuning Phase 3** | multi-param Bayesian + walk-forward CV | ✓ shipped (this week's V3→V7 are M5.5 follow-on experiments) |
| M6 | Full automated cycle (cron → report → review → trade) | Phase 1 SHIPPED (auto-emitted daily summaries); **Phase 2 PLANNED but no active dispatch since 2026-05-04**; **Phase M6.6 (true live cycle: `live` DATA_SOURCE + cron + alert dispatch + trading-state durability) DEFERRED** |
| M7 | Parameter optimization | M5.5+M5.6 cover the parameter side; **M7.1 ML training + M7.2 synthetic stress NOT STARTED** |

## 7. Open tracks + capability gaps (per track-pacer 2026-05-17)

Active / progressing well:
- `tuning` (this week's V3-V7 stack)
- `data-foundations` (delisted + Shiller + French + IWV + asset-type enrichment + Q2-A composition)
- `walk-forward-cv` (PRs #1100/#1111/#1116)
- `harness` (CI hardening)

**Punted / capability gaps:**

| Gap | Source | Recommended action |
|---|---|---|
| **M6.6 — true live cycle** | track-pacer 2026-05-17 §P7 | Quarterly reassess; current strategy is "defer until M5 tuning matures." V3-V7 plateau suggests M5 tuning IS mature — could promote V3 winner (under Option E gate) + start scoping M6.6 |
| **M7.1 ML training + M7.2 synthetic stress** | weinstein-trading-system-v2.md §7 | Not started. Maps to user's "synthetic data" question in §2.1 above. Worth opening a track once cross-scenario validation lands |
| **Shares-outstanding fundamentals source** | track-pacer 2026-05-17 §P7 | EODHD Fundamentals tier upgrade ($59.99/mo) vs Sharadar/AlphaVantage swap. Blocks dollar-volume-correct broad universe. Maintainer decision |
| **Orchestrator-automation Phase 2** | track-pacer 2026-05-17 §P6 | No active dispatch since 2026-05-04. Wrap track MERGED or commit to Phase 2 work |
| **cleanup `[~]` items** | track-pacer 2026-05-17 §P1 | 4 in-flight items dated 2026-05-07/08. Dispatch `code-health` or close |

## 8. Concrete next action (this session)

P0: **refresh on optimal-strategy quality.** Read `856-optimal-strategy-diagnostic-15y-2026-05-06.md` + `dev/status/optimal-strategy.md` (latter is older — verify against current code). If quality is good enough, define optimal_efficiency = `candidate_sharpe / optimal_sharpe` and use it as a sanity-check column in V3 winner's promotion provenance (don't bake into BO objective yet — needs P1 to land first).

P1: **wire cross-scenario validation into `promote_config.sh`.** ~3-4h of OCaml + bash. Until this is shipped, no winner gets promoted.

If P0 reads cleanly, this can run in parallel with V7 completion + P1 dev.

## 9. What we're NOT going to do (explicit deferral)

- More parameter-space sweeps on the 4-knob V3 surface until cross-scenario validation lands. The "V3 winner under Option E" + V7 are the last 4-knob sweeps. After V7, no more.
- Synthetic data (M7.2) until cross-scenario validation in (P1) reveals whether we even need it.
- M6.6 live cycle until V3 winner (or better) is promotable AND has shipped cross-scenario validation.

## 10. Decisions (resolved 2026-05-22)

These were §10 open questions; resolved with the maintainer in the
same session this doc was filed. Pinned here so the plan is
self-contained going forward.

- **§2.5 (a) vs (b):** Adopt **(a) promote-gate first** (~3-4h dev + 4-6h backtest panel). Defer (b) BO-training-input but scope it in parallel as a separate track — (b) is ~10-15h dev + 4-5× longer sweep wall (~50h vs 11h at parallel=4). If (a) catches V3 regressing on broad universe / French / Shiller, (b) is justified; if (a) shows V3 generalizes cleanly, (b) is premature optimization.
- **§2.6 optimal-strategy quality budget:** ≤2 days. If quality isn't restored within that budget, park optimal-strategy as deferred and proceed without optimal-efficiency normalization (use raw `candidate_return / cell_e_return` as the proxy).
- **§6 M6.6 timing:** start scoping M6.6 NOW. Prereqs are (1) parameter pin (handled by promote_config.sh once V3 winner or successor lands), (2) code version pin (handled by promote_config.sh provenance.md SHA — already shipped in #1234), (3) `live` DATA_SOURCE — does NOT exist yet; M6.6 scope = build this. Cross-scenario validation gate (P1 here) is a coupled requirement before any winner reaches the M6.6 live cycle.
- **§9 deferral list:** Looks good. No missing items flagged.
