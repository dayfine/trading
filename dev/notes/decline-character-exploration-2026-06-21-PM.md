# Decline-character idea — exploration + build sequence (2026-06-21 PM, autonomous)

Synthesizes two read-only explorations run this session. Governs the autonomous
build run. Pairs with `dev/plans/capitalize-findings-build-plan-2026-06-21.md`
(the parent plan) and the user's 2026-06-21 directive: **mine findings for
strength vs weakness; a rejection isn't done until its *why* is a buildable
default-off directive.**

## The user's framing (2026-06-21, before heading AFK 8h)
- Confirmed the 2020 long-side problem: the structural MA/correction-low trailing
  stop is **too wide + too slow** for a fast crash — it trails a distant 2019
  correction low and only re-checks weekly, so longs exited Mar 13-18 2020 *at the
  bottom*, eating the full ~38% DD (window MaxDD 38.0-38.7% vs S&P -34%).
- User's new idea: an **absolute drop-% stop** (from the trailing high) to cap the
  fast-crash loss the structural stop misses.
- Picked the **faithful short** (option 1) but the absolute-stop is the higher-value
  branch (long-side, fixes the 2020 problem directly).

## The synthesis: decline-character is the shared primitive
A lookahead-free classifier `Slow_grind | Fast_v | Not_declining` feeds BOTH:
- **slow-grind → short** (faithful short, gated to confirmed distribution bears), and
- **fast-V → arm a tight absolute long stop** (explicit tail-RISK insurance —
  the sanctioned exception in `edge_is_the_fat_tail`; dormant in normal bull chop
  so it does NOT tax the fat tail).

## Premise validation — VERDICT: BUILD-WORTHY (with a data-wiring prerequisite)
Source: read-only screen, screen-rigor discipline. Proxy = the deep run's weekly
macro-trend series (`dev/experiments/deep-1998-2026-2026-06-14/macro_trend.sexp`,
1425 weeks 1998-2026).

**Regime separation is real and categorical** (trend-state durations):
| episode | Bearish wks | Neutral | Bullish | character |
|---|---|---|---|---|
| dot-com 2000-03→2001-12 | 65 | 20 | 4 | SLOW (sustained bear ~1yr) |
| GFC 2007-10→2009-03 | 49 | 15 | 8 | SLOW (sustained bear ~1yr) |
| COVID 2020-01→2020-06 | **0** | 11 | 10 | FAST (never Bearish; Neutral 03-13 = at the bottom) |

COVID exits were individual `stop_loss` fires 2020-03-10/13/17 (losses to -33.6%),
at/near the bottom — long side ate the full drop with zero macro early-warning.

**The honesty caveat (gates the novel part):** the deep run passed `~ad_bars:[]`
(`trading/analysis/weinstein/snapshot_pipeline/lib/pipeline.ml:103`), so the macro
trend was **index-price-only** — the "A-D Line" indicator (`macro_indicators.ml:68`,
present in `Macro.result.indicators`) returned "No A-D data (Neutral)" the whole run.
So the existing macro gate ALREADY separates the regimes behaviorally — but via
index-stage LAG (flips at the bottom in COVID). The *novel* value (A/D line peaks
5-10mo before the index top in distribution bears, per Weinstein book Ch.8) is
**asserted from theory, not yet measured in our data**. n=3 crashes (2 slow, 1 fast)
is an irreducible ceiling — the strongest the data can ever say is "consistent with
the doctrine across available crashes," never "proven."

**Signal definition (lookahead-free, to be gridded):**
- Input 1 — **A/D-divergence lead**: weeks since cumulative A/D line peaked, measured
  while index still within X% of its high. SLOW ⇒ lead ≥ ~13-26wk; FAST ⇒ lead ≈ 0.
  (Needs the data wiring below; reads `Macro` A-D Line indicator once fed real bars.)
- Input 2 — **rate-of-decline** (%/wk, trailing 4wk): FAST ≈ -10-15%/wk; grind -1-3%/wk.
  Computable today from index bars.
- Input 3 — **weeks-below-declining-MA**: grind accumulates ≥~8; V snaps back first.
  Computable today.
- Rule: SLOW if (lead≥~13wk) OR (weeks-below-MA≥~8 AND rate<~4%/wk); FAST if
  (lead≈0 AND rate>~8%/wk). Reproduces 2000/2008=SLOW, 2020=FAST on the proxy.

## Build sequence (all default-off, no core edits, per build-surface map)

### Build 0 — A/D data wiring (the harness gap; makes the novel input real)
Run `trading/analysis/scripts/compute_synthetic_adl` to produce
`synthetic_advn/decln.csv` over the deep universe (≥1998); wire `Ad_bars.load`
into the snapshot pipeline (replace `~ad_bars:[]` at `pipeline.ml:103` /
`weekly_snapshot_generator.ml:24`). Feat-data. Until this lands, the A/D-lead leg
is theory-only; Inputs 2/3 still work. **Build 1 does NOT block on this** (classifier
is a pure function unit-tested on synthetic fixtures); backtests of the *signal's
A/D leg* do.

### Build 1 — Decline-character classifier (shared primitive) — BUILD FIRST
New standalone `trading/analysis/weinstein/macro/lib/decline_character.{ml,mli}`
(do NOT extend `Macro.result` — churns goldens). Pure `classify` reading the existing
`Macro.result` (incl. A-D Line indicator) + index bars; computes Inputs 2/3 (new).
Output `Slow_grind | Fast_v | Not_declining [@@deriving show,eq,sexp]`. No flag on
Build 1 itself (changes no behavior until a consumer reads it). Tests: synthetic
fast-V / slow-grind / rising-MA fixtures. Add to macro lib (wrapped false) + its test dune.

### Build 2 — Fast-crash absolute stop (user's higher-value idea; arms on Fast_v)
`catastrophic_stop_pct : float; [@sexp.default 0.0]` in
`trading/trading/weinstein/stops/lib/stop_types.{mli,ml}` config (already inside
`stops_config` → auto Variant_matrix-searchable, like `vol_scaled_stop_atr_mult`).
Trigger: new `Weinstein_stops.check_catastrophic_hit ~armed ~pct ~trailing_high ~bar`
(`bar.low <= trailing_high*(1-pct)` long), OR'd into the trigger decision in
`stops_runner.ml` (`_handle_stop_trigger_only` + the `Stop_hit` path). `trailing_high`
= `Trailing.last_trend_extreme` from stop state (no new state). **Regime threading:**
stops pass runs BEFORE macro this tick — use `prior_macro_result` (already in scope at
`weinstein_strategy.ml:119`) to classify lookahead-free; pass a plain `~armed:bool`
(Fast_v decision made in the strategy lib, which deps macro+stops) so the **stops lib
stays macro-agnostic** (avoids an A2 dep). New `Stops_runner.update` arg is optional+no-op.
Tests: `test_weinstein_stops.ml` (helper, both sides, no-op at 0.0) +
`test_stops_runner.ml` (arms only on Fast_v + pct>0 + price≤trail*(1-pct)).

### Build 3 — Faithful short (Bearish-only + slow-grind gate) — user's option-1 pick
3a: `neutral_blocks_shorts : bool; [@sexp.default false]` in `screener.ml` config,
symmetric to `neutral_blocks_longs` (~line 244/267); new
`_shorts_admitted_by_macro` (`Bullish->false | Neutral->not neutral_blocks_shorts |
Bearish->true`); rewrite `_evaluate_shorts`. Default false = current behavior
(Neutral still admits) per R1; the *intent* (bears-only) is the flag-on state.
3b: slow-grind gate — pass a plain `~decline_is_slow_grind:bool` into `_evaluate_shorts`
(computed in the strategy lib via `Decline_character.classify`, keeping the **screener
lib macro-agnostic** — A2). Plumb new fields through `weinstein_strategy_config` →
`_run_screener` with-override seam (`weinstein_strategy_screening.ml:417-429`), exactly
like `neutral_blocks_longs`. Tests: `test_screener.ml` (Neutral→0 shorts when true).

## Dispatch order (serialized jj-writers — concurrent QC wiped .jj tonight)
1. Build 1 (classifier) — clean, no data dep. → PR → QC (serial) → merge.
2. Build 0 (A/D wiring) — feat-data; makes A/D-lead real.
3. Build 2 (fast-crash stop) — depends on Build 1.
4. Build 3 (faithful short) — depends on Build 1.
5. Screens (read-only, screen-rigor) on wired data → WF-CV if promising → promotion grid.

Independent of all above: **P0.2 barbell weight cert** (WF-CV grid on the correct
window; weight is universe-dependent per `barbell-breadth-2026-06-21` — floor dominates
top-1000, light floor on the strong window). Heavy; needs snapshot rebuild (cleaned).

## Guardrail status
Decline-character is **regime INSURANCE**, not a winner-touching/fat-tail-taxing lever
— `edge_is_the_fat_tail` endorses "winner-touching only as explicit tail-RISK insurance,"
which the Fast_v-armed absolute stop is (dormant in normal times). Weinstein-faithful
(book Ch.8 A/D-lead breadth doctrine = a dial, not a spine change). All builds default-off.
