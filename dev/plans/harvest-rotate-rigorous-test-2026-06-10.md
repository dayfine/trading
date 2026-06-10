# Harvest-rotate — the rigorous test — plan — 2026-06-10

The read-only screen (`dev/experiments/harvest-rotate-validation-2026-06-10/`) was
**inconclusive, not a rejection** (coin-flip per decision, no exploitable edge,
mild tail-risk). User decision 2026-06-10: run the **rigorous** test — the only
thing that answers *"timing + picks, reliably hit-able."* This means implementing
harvest-rotate as a default-off **surface** and backtesting it under WF-CV, per
`.claude/rules/mechanism-validation-rigor.md` Step 3 ("escalate to the real test")
and the `experiment-gap-closing` loop.

## ⚠ Faithfulness tension to resolve FIRST (W1–W3, weinstein-faithful-core.md)

Trimming a **still-advancing Stage-2** winner to free capital contradicts the spine
item *"let winners run — sell in Stage 3/4, not on a capital-reallocation
argument."* The only Weinstein-faithful moment to harvest a winner is when it shows
**Stage-3 topping precursors** — at which point the normal Stage-3 exit
(`enable_stage3_force_exit`) already fires. So the faithful niche for harvest-rotate
is narrow and specific:

> **Faithful trigger = the Stage-2 `late` flag** (MA deceleration; fires 7–26 wk
> before tops, 6/7 episodes — `project_stage_late_flag_discarded`). The winner is
> *beginning* to top but hasn't triggered the Stage-3 exit yet. Harvest a fraction
> there and rotate into a fresh Stage-2 leader = the trader's "rotate into
> leadership" (his, "The Trader's Way"), not an arbitrary trim of a healthy
> advancer.

This is the **only** variant we should test as W2-faithful. A raw
extension-threshold trigger (trim any position >X% above the MA) is **not**
faithful — it trims healthy advancers — and should at most be a non-faithful
contrast arm, clearly labelled. Note: a late-flag **stop-tighten** was already
REJECTED (#1446), but that was *risk*-framed; this is *allocation*-framed (trim to
fund a specific better-ranked blocked candidate), a different and more principled
use — which is exactly why it's worth the real test.

## The mechanism (default-off config surface)

On the weekly `on_market_close`, for each held position P, IF:
- `harvest_rotate_enabled` (default false), AND
- P's stage is `Stage2 {late=true}` (the faithful trigger), AND
- the screener produced ≥1 candidate C that would be entered but was blocked by
  insufficient cash (the existing `alternatives_considered` / `Insufficient_cash`
  signal), AND C's cascade score ≥ P's "freshness" (a higher-forward-return
  candidate),
THEN partial-exit P by fraction `k` and enter C with the freed capital.

### Config axis (Variant_matrix)

- `harvest_rotate_enabled : bool [@sexp.default false]`
- `harvest_fraction k ∈ {0.33, 0.5, 1.0}` — fraction of P trimmed (1.0 = full rotate)
- trigger arm ∈ { `late_flag` (faithful), `extension>θ` (contrast, non-faithful) }
- `harvest_min_candidate_score` — only rotate if the blocked C is at least this
  good (avoid rotating into junk). ∈ {fixed 60, 70}
- candidate pick = highest cascade-score blocked candidate (fixed initially)

Baseline = `harvest_rotate_enabled=false` (today's behaviour, the no-op default).

## Core change required (A1 — decision item, user-greenlit 2026-06-10)

`TriggerExit` is **whole-position only**. Need a **partial-exit transition**:
`target_quantity` on `TriggerExit` (or a new `TriggerPartialExit { target_quantity }`)
+ engine/simulator handling to reduce `Holding` to `quantity − trim` and keep the
remainder `Holding` (not `Closed`). `ExitFill` already supports partial
`filled_quantity`, so fill mechanics exist — the gap is the **initiating transition**
+ the post-fill "return to Holding." Touches the A1 core watch-list
(`trading/trading/strategy/`, `engine`, `simulation`). Land it as its own small,
**strategy-agnostic** PR (it's generally useful, not Weinstein-specific), with QC.

## Build sequence (small PRs, each builds + tested)

1. **Core partial-exit transition** (strategy-agnostic). `target_quantity` on the
   exit transition + engine/simulator "reduce to Holding" path + tests asserting a
   `Holding(q) → partial-trim → Holding(q−t)` round-trip with correct cash + stop
   tracking on the remainder. ~A1 core. Behind no flag (it's a capability).
2. **Harvest-rotate mechanism** behind `harvest_rotate_enabled` (default-off) in
   the Weinstein strategy: late-flag trigger + blocked-candidate detection + emit
   the partial-exit + the rotation entry. Default-off → zero backtest change on
   merge (`experiment-flag-discipline.md` R1).
3. **Variant_matrix axis wiring** so `((flag harvest_rotate_enabled) (values (true false)))`
   + the k / trigger / score axes expand and validate (R2).
4. **WF-CV** on top-3000 (the universe where concentration arises), 15 folds,
   fork-per-fold parallel=1 (~4h). Variants = baseline ∪ {faithful late_flag × k ×
   score grid} (+ a few non-faithful extension arms as contrast). Rank via
   `Variant_ranking` (Pareto) + `Deflated_sharpe`.
5. **Decision** via `experiment-gap-closing` step 7: if a faithful variant survives
   DSR + per-fold gate → confirmation grid (`promotion-confirmation.md`, ≥3
   period×universe cells incl. one macro-regime-diverse). Else record ACCEPT/REJECT
   in the ledger and keep default-off.

## Metrics that matter here

Beyond return/Sharpe: **realised-vs-unrealised split** (harvest converts unrealised
marks to realised + redeployed capital — the `project_broad_universe_790_mtm_inflated`
concern), **max single-name NAV%** over the run, **capital-relative MaxDD / Ulcer**
(does rotation cut the concentration tail?), and **turnover / cost** (each trim is a
taxable, spread-paying partial sale — the cost model prices `bid_ask_spread_bps`).

## Prior-belief honesty

The screen + the standing prior both lean against this. We run it anyway because
(a) the user asked for the rigorous answer, and (b) the screen was genuinely
inconclusive (coin-flip), not a rejection — so the cheap evidence doesn't settle it.
Expected outcome is "REJECT, kept default-off" — but now with a WF-CV-grade verdict
we can cite, not a proxy overclaim. If it surprises us and a faithful late-flag
variant survives the grid, that's a real, promotable finding.
