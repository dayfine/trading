# Continuation buys — second/third Stage-2 entries (issue #889)

**Status:** design proposal — no code yet
**Author:** feat-weinstein
**Date:** 2026-05-13
**Issue:** [#889 feat(strategy): continuation buys — second/third buys on subsequent breakouts (Weinstein Ch.3)](https://github.com/dayfine/trading/issues/889)
**Sequenced after:** #872 Stage-3 force-exit (MERGED) + #887 laggard rotation (MERGED).

## 1. Context — domain rule pin

Authority: `docs/design/weinstein-book-reference.md` §4.6 "Continuation Buys (Ch. 3, ~lines 2214–2238)" already pins the book passages. Quoted verbatim from the book (re-stated here for self-contained review):

> "There is one other very profitable time to do new buying. It occurs after a Stage 2 advance is well underway, when the stock drops back close to its MA and consolidates. It then breaks out anew above the top of its resistance zone… This is called a **continuation buy**."

> "This type of buy is more suited to traders than investors. But investors, too, should be willing to do some late Stage 2 buying when the overall market is very strong and there aren't many initial breakout opportunities left."

> "The moving average should be clearly trending higher. This is important! … If the MA starts to roll over and flatten out, you don't want that stock."

**Five mechanical preconditions** the book stipulates:

| # | Precondition | Existing primitive that computes it |
|---|---|---|
| (a) | 30-week MA is **clearly trending higher** (not merely flat-to-rising) | `Stage.result` carries `ma_direction = Rising`; the *clearly* requirement maps to a configurable slope-floor — stricter than `is_late_stage2_callback` threshold. |
| (b) | Price has pulled back to (or near) the MA | New: `pullback_to_ma` computed from `close / ma_30w` — must dip within a configurable band (e.g. 0.97 to 1.03) within the recent N weeks. |
| (c) | Consolidated near the MA | New: low/high range over last K weeks ≤ configurable threshold (e.g. 8% range). Mirrors `is_in_base` semantics but anchored to MA, not just absolute range. |
| (d) | Breakout above resistance again | Reuse `stock_analysis.breakout_price` (top of recent base) + the existing breakout-detection in `Stock_analysis.is_breakout_candidate` |
| (e) | Volume confirmation on the new breakout | Reuse `Volume.result.confirmation` (Strong / Adequate) — same gate as initial breakout. |

The book also calls out the **macro context**: continuation buys are "inapplicable in early bull markets" and "most relevant in late bull markets". Encoded mechanically as a config gate that defaults the feature off until other signals justify it; not hard-pinned to a regime detector in v1.

## 2. Recommended interpretation (resolves issue's A-vs-B)

**Recommend Interpretation B first** (new positions in symbols we don't currently hold), with A (pyramid adds) gated behind a separate config knob.

### Why B first

1. **Lower risk-management surface.** B is a regular new entry that flows through the existing `entries_from_candidates` cash + cap walk. A requires a new transition type (or a "second `CreateEntering` against an existing `Holding`") and a new sizing path that compounds existing position risk. Defer until B is proven not to be net-bad.
2. **More directly addresses the empirical pain point.** Per `dev/notes/capital-recycling-framing-2026-05-06.md`, the cascade rejects late-Stage-2 candidates because `is_breakout_candidate` requires `Stage2.weeks_advancing ≤ 4` *or* a `prior_stage = Some Stage1` transition. Once Stage 1 → Stage 2 is in the past, the symbol becomes invisible to the cascade. Interpretation B's continuation pattern is precisely a way to re-admit such symbols.
3. **Pyramid-add interactions are subtle.** Stop relocation on the pyramid leg, average-cost-basis vs lot-by-lot stop, `portfolio_lot_ids` extension, audit_recorder semantics — none of these are touched today. Each is a small but real surface that needs its own decision.

### Coexistence with A (pyramid)

A is a strict opt-in upgrade on top of B once B is shipped and measured. Two knobs:
- `continuation_new_buy_enabled : bool` (B; default `false`)
- `continuation_pyramid_enabled : bool` (A; default `false`; requires B enabled)

Pyramid sizing uses a separate fraction (see §5 below), and emits a new `transition_kind` (see §4) so the position state machine stays decoupled from "regular new entry vs add-to-existing".

The book is ambiguous between A and B but the *trader-vs-investor* aside suggests A is the trader's variant (you owned the stock from the first breakout) and B is the investor's variant (you missed the first breakout). Both are valid; B just lands first.

## 3. Detection logic sketch

New module: `trading/analysis/weinstein/continuation/lib/continuation.{ml,mli}`. Pure function, fed from the same `Stock_analysis.callbacks` bundle so the panel-backed snapshot pipeline reuses zero-allocation reads.

```ocaml
type config = {
  ma_slope_min : float;
      (* §3.(a). MA's 4-week slope must be ≥ this (per-bar log-return). Stricter
         than Stage.config.slope_threshold. Default: 0.010 (1% per week). *)
  pullback_band : { low : float; high : float };
      (* §3.(b). close/ma_30w within [low,high] at some bar in the lookback
         window. Default: { low = 0.97; high = 1.03 }. *)
  pullback_lookback_weeks : int;
      (* §3.(b). How far back to scan for the pullback-to-MA bar. Default: 8. *)
  consolidation_range_pct : float;
      (* §3.(c). (high - low) / avg(close) over consolidation window. Default:
         0.08 (8%, matches initial-base range tolerance). *)
  consolidation_weeks : int;
      (* §3.(c). Window length. Default: 4. *)
}

type result = {
  is_continuation : bool;
  pullback_low : float option;
      (* Low of the pullback bar — used as the new structural stop floor for
         the continuation entry. *)
  consolidation_high : float option;
      (* Top of the consolidation range — the breakout price the cascade gates
         on for §3.(d). *)
  ma_slope_observed : float;
}

val analyze_with_callbacks :
  config:config ->
  stage_callbacks:Stage.callbacks ->
  resistance_callbacks:Resistance.callbacks ->
  as_of_date:Core.Date.t ->
  result
```

Reuses primitives:
- `Stage.callbacks.get_ma` for §3.(a) slope computation.
- `Stage.callbacks.get_close` + `get_ma` for the close/MA ratio in §3.(b).
- `Resistance.callbacks.get_high` / `get_low` / `get_date` for §3.(c) range + §3.(d) prior resistance.

What is new:
- The pullback-detection pass (find a bar in `[-pullback_lookback_weeks, 0]` where `close/ma_30w` ∈ `pullback_band`).
- The consolidation-range pass anchored at the pullback bar.

Both are O(window-size) scans over already-loaded callbacks — no new bar list materialisation.

## 4. Integration points

### For Interpretation B (new buys)

The seam is `Weinstein_strategy_screening.screen_universe`. Today the cascade produces `buy_candidates` keyed on `is_breakout_candidate`, which excludes mature Stage-2 symbols. Two compatible approaches:

**Approach B-1 (preferred): extend the breakout predicate.** Modify `Stock_analysis.is_breakout_candidate` to OR in a "continuation" arm:
```
let is_breakout_candidate a =
  initial_breakout_predicate a
  || (a.continuation.is_continuation && volume_ok && rs_ok)
```
This keeps the existing cascade ranking, audit emission, and held-ticker exclusion working unchanged. The candidate carries a tag (new field on `Stock_analysis.t`: `entry_kind : Initial | Continuation`) that the audit row and trade-grading sees.

**Approach B-2 (rejected): parallel cascade.** Run a second screener pass for continuation candidates and merge. Rejected because (i) it duplicates the macro/sector/RS/hold-set/cooldown gates, (ii) the ranking is now two competing pools rather than one, (iii) entry_audit_capture rivals-analysis breaks.

Cost of B-1: every analyze call computes a continuation result even when initial breakout already qualifies. Bound: O(20 weeks) per symbol per Friday; well below current per-Friday Stock_analysis cost.

### For Interpretation A (pyramid adds)

The position state machine needs a new transition:
```
| AddToHolding of {
    additional_quantity : float;
    fill_price : float;       (* limit / suggested *)
    reasoning : entry_reasoning;
  }
```
This is the *only* way to ADD to an existing `Holding` without trashing the average-entry/entry-date invariants. The transition:
- Updates `Holding.quantity` += additional_quantity
- Recomputes `entry_price` as cost-weighted average
- Keeps `entry_date` (the original — for time-in-position metrics)
- Appends a new portfolio_lot_id to `portfolio_lot_ids`

This is a `trading/trading/strategy/lib/position.ml` change — a **core module** touch per `.claude/rules/qc-structural-authority.md` §A1. Per project rules, this is **proposed as a decision item for review approval rather than executed by the feat agent autonomously**. The change is strategy-agnostic (any pyramid-able strategy can use it) and shouldn't be a blocker, but the call belongs to the human / review agent.

Integration site for A: a new pass *after* `entries_from_candidates` in `Weinstein_strategy.on_market_close`:
1. Filter `portfolio.positions` for `Holding` longs.
2. Run `Continuation.analyze_with_callbacks` for each.
3. For each with `is_continuation = true` and not already at the per-position notional cap, emit `AddToHolding` transitions.

Tagged in the audit recorder as a separate event kind (`pyramid_add_event`) so analysis can distinguish initial / continuation / pyramid in trade grading.

### Where continuation does NOT plug in

- **Not in `Stage.classify`.** Stage definitions don't change. A continuation candidate's stage is still `Stage2 { weeks_advancing = N; late = false_or_true }`. Continuation lives one layer up, in stock_analysis or screener.
- **Not in `Macro`.** The book's "most relevant in late bull markets" framing is satisfied by leaving the feature default-off and letting tuning enable it.
- **Not in `Stops`.** The continuation stop uses `pullback_low` (a new structural floor) but the *state machine* is unchanged — the entry-time stop install still flows through `compute_initial_stop_with_floor_with_callbacks`. Just a new `support_floor : float` input.

## 5. Position sizing interaction

Two distinct sizing paths:

**B (new buy, continuation-tagged):** Same `Portfolio_risk.compute_position_size` as initial buys. Same `max_position_pct_long`, same risk_pct, same per-position cap. The continuation tag does NOT shrink the new-buy allocation — by hypothesis the entry is in a less-mature pullback that still passes the macro / sector / RS gates, so the risk-per-share captures whatever extra danger the book warns about. Tuning can later sweep a `continuation_risk_pct` if the data motivates it.

**A (pyramid add):** Strictly smaller than initial allocation. Per the issue ("e.g., 50%"). New config field:
```
pyramid_add_risk_pct_multiplier : float  (* default 0.5 *)
```
Applied as: `effective_risk_pct = base_risk_pct * pyramid_add_risk_pct_multiplier`. Caps still apply — `max_position_pct_long` is computed against the **combined** quantity (original + add), so the add is rejected if it would push the combined notional above the cap. This is the only sane interpretation: a position that's already at-cap shouldn't be allowed to pyramid past the cap on the basis of a new breakout — that's how concentrated single-name blowups happen.

Field belongs in `Weinstein_portfolio_risk.config` (its natural home). No core-module changes needed for this field.

## 6. Risk interactions — sequencing with #872 (Stage-3 exit) and #887 (laggard rotation)

The concern from the issue: continuation buys ADD positions; #872 + #887 REMOVE them. Are they consistent?

**Yes, with caveats.** Both removal paths fire per-Friday in `Weinstein_strategy.on_market_close` *before* the entry walk:

```
on_market_close:
  1. force_liquidation        (stops + macro force exits)
  2. stage3_force_exit         (#872, removes Stage 3+ positions)
  3. laggard_rotation          (#887, removes weak RS positions)
  4. screening → entries        (where continuation B plugs in)
  5. (proposed) pyramid scan    (where A plugs in)
```

Implication:
- A position that #872 / #887 just exited is no longer in `held_set` for step 4, so it CAN re-enter as a continuation B candidate the same Friday. This is undesirable churn. **Mitigation:** lean on the existing `cascade_post_stop_cooldown_weeks` knob — extend it to also cover stage3-force-exit and laggard-rotation events (or add a sibling `cascade_post_rotation_cooldown_weeks`). One-line plumbing change in the strategy where it threads `last_stop_out_dates` into the cascade.
- For pyramid A: never pyramid a position that fired any exit signal this Friday. Sequence guarantees that if #872 / #887 selected a position for exit, the pyramid scan in step 5 won't see it (it's in `Exiting`, not `Holding`). No explicit guard needed if the scan only matches `Holding`.

**The one ordering hazard** is when #887 (RS-laggard) flags a position simultaneously with the continuation detector firing on the same symbol. By construction #887 fires first and pre-empts the pyramid — the right behaviour. Doc this in the .mli of the continuation module so future readers don't re-derive it.

## 7. Acceptance test plan

Golden scenarios to add to `trading/trading/weinstein/strategy/test/`:

### G1 — single-symbol continuation B happy path
- Hand-rolled 30 weekly bars: Stage 1 → Stage 2 initial breakout at week 12 (we do NOT enter — simulate having missed it) → pullback to MA at week 22 → consolidate weeks 22–25 → new breakout at week 26 on Strong volume.
- Assert: entry transition emitted at week 26 with `entry_kind = Continuation` and stop at the pullback low (week 22 low).

### G2 — continuation gate blocks when MA flattens
- Same as G1 but MA slope decays after week 20 below `ma_slope_min`.
- Assert: zero continuation entries; the assertion explicitly checks that the original Stage-2 advance is still recognised (Stage2.late = true).

### G3 — continuation respects macro gate
- Same as G1, but inject Bearish macro at week 26.
- Assert: zero entries (macro gate blocks). Diagnostics counter `long_macro_admitted = 0`.

### G4 — pyramid A happy path
- Same as G1 but the strategy *did* enter at week 12 and is still Holding at week 26.
- Assert: `AddToHolding` transition emitted at week 26 with `additional_quantity` = `pyramid_add_risk_pct_multiplier * original_quantity` (rounded), `entry_date` unchanged, `quantity` += add. (Only when A is enabled — also test default off.)

### G5 — continuation post-stop-out cooldown
- Position stops out at week 20, continuation pattern matches at week 24.
- Assert: entry blocked by `cascade_post_stop_cooldown_weeks`; entry admitted at week 26 (after cooldown).

### G6 — no double-rotation race
- Position passes #887 laggard threshold AND continuation detector at the same Friday.
- Assert: position exits (via #887), no pyramid emitted same week.

Fixtures live as inline weekly bar arrays in the OUnit2 test files — the existing pattern in `weinstein/strategy/test/test_weinstein_strategy_*.ml`. No new fixture infrastructure.

## 8. Config surface

Additions only — no removals.

### `Continuation.config` (new)
| Field | Default | Notes |
|---|---|---|
| `ma_slope_min` | 0.010 | per-bar log-slope of 30w MA |
| `pullback_band.low` | 0.97 | close/MA min ratio for pullback bar |
| `pullback_band.high` | 1.03 | close/MA max ratio |
| `pullback_lookback_weeks` | 8 | scan window |
| `consolidation_range_pct` | 0.08 | high-low range of consolidation |
| `consolidation_weeks` | 4 | consolidation window length |

### `Stock_analysis.config` (extend)
| Field | Default | Notes |
|---|---|---|
| `continuation` | `Continuation.default_config` | bundles the above |

### `Weinstein_strategy_config.t` (extend)
| Field | Default | Notes |
|---|---|---|
| `continuation_new_buy_enabled` | `false` | gates B at the strategy level so default goldens stay bit-equal |
| `continuation_pyramid_enabled` | `false` | gates A; requires B enabled for a clean error-message path |
| `cascade_post_rotation_cooldown_weeks` | 0 | cooldown after #872 / #887 exits; default 0 preserves current goldens |

### `Weinstein_portfolio_risk.config` (extend)
| Field | Default | Notes |
|---|---|---|
| `pyramid_add_risk_pct_multiplier` | 0.5 | size multiplier for A |

All fields `[@sexp.default …]` so overlay sexps that omit them deserialise to defaults. No on-disk golden re-pin required if defaults preserve existing behaviour.

## 9. Effort estimate — commit plan

Sequenced so each commit is independently mergeable.

| # | Commit | Scope | LOC est. |
|---|---|---|---|
| 1 | `feat(continuation): pure detector` | `trading/analysis/weinstein/continuation/lib/{continuation.ml,mli,dune}` + unit tests | ~250 |
| 2 | `feat(stock_analysis): expose Continuation result + entry_kind tag` | `Stock_analysis.t` adds `continuation : Continuation.result option`, `entry_kind : Initial \| Continuation`. Wire callback bundle. | ~150 |
| 3 | `feat(screener): admit continuation candidates` | `Stock_analysis.is_breakout_candidate` OR-arm + cascade diagnostics counter for continuation admissions | ~120 |
| 4 | `feat(strategy): wire continuation_new_buy_enabled gate` | `Weinstein_strategy_config` field + plumbing in `weinstein_strategy_screening.ml`; cooldown unification | ~100 |
| 5 | `test(strategy): golden scenarios G1-G3, G5` | Hand-rolled bar fixtures | ~250 |
| 6 | (decision-gated) `feat(position): AddToHolding transition` | `trading/trading/strategy/lib/position.{ml,mli}` core-module change; needs human / review-agent approval per A1 | ~180 |
| 7 | (decision-gated) `feat(strategy): pyramid scan` | `Weinstein_strategy.on_market_close` pyramid pass; sizing; audit emission | ~250 |
| 8 | (decision-gated) `test(strategy): golden G4 + G6` | Pyramid fixtures | ~180 |

Commits 1–5 land Interpretation B. Commits 6–8 land A and are gated on the core-module decision.

**Total LOC for B-only:** ~870 (5 commits, each PR ≤ 500 LOC after format).
**Total LOC for B + A:** ~1,480.

## 10. Out of scope (v1)

- Late-bull-market regime detector that auto-enables the feature (book §"most relevant in late bull markets"). Manual config knob only.
- Adjusting `Stage2.late` semantics. The continuation gate uses its own stricter slope floor; `late` is read-only here.
- Backtest-side parameter sweep on continuation knobs — that's `feat-backtest`'s scope once the detector lands.
- Short-side analogue ("continuation breakdown"). Mirror would live in a parallel `Continuation_short` module if/when motivated.

## 11. Risks / unknowns

| Risk | Mitigation |
|---|---|
| Continuation overlap with `Stage2.late` confuses readers ("late but still a buy?") | Explicit doc in continuation.mli: late refers to MA deceleration, continuation requires the OPPOSITE — clearly-rising MA. The two flags can coexist when MA decelerated then re-accelerated. |
| Pyramid average-cost re-computation breaks downstream trade-attribution reports | Defer A until reports are surveyed; document the average-cost rule in position.mli before merging commit 6. |
| Cooldown unification (commit 4) changes existing cooldown behaviour | Keep the existing `cascade_post_stop_cooldown_weeks` semantics bit-equal; add a *separate* `cascade_post_rotation_cooldown_weeks` rather than expanding the existing knob's meaning. |
| Continuation detector fires on synthetic-data Stage-2-only fixtures used elsewhere in the suite, breaking unrelated goldens | The strategy-level config gate (`continuation_new_buy_enabled = false` default) keeps every existing golden bit-equal. Goldens that want to exercise continuation opt in. |
| Issue says "investors should be willing to do some late Stage 2 buying" — we may want to admit `Stage2.late = true` symbols specifically (the cascade currently rejects them via the `weeks_advancing ≤ 4` clause) | The continuation pattern is precisely the gate Weinstein uses to qualify a late-Stage-2 buy: any symbol the continuation detector accepts is by-construction safe to admit despite `weeks_advancing > 4`. The B-1 approach (OR-arm in `is_breakout_candidate`) gets this right for free. |

## 12. References

- Issue [#889](https://github.com/dayfine/trading/issues/889)
- `docs/design/weinstein-book-reference.md` §4.6 (already pinned)
- Capital-recycling motivation: `dev/notes/capital-recycling-framing-2026-05-06.md`
- Sequenced after: PRs landing #872 (Stage-3 force exit) and #887 (laggard rotation)
- Related: `dev/status/short-side-strategy.md` (for future short-side analogue)
