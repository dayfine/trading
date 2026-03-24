# Screener / Analysis — Engineering Design

**Codebase:** `dayfine/trading` — ~18,600 lines OCaml, 34 test files. Core + Async throughout.

**Related docs:** [System Design](weinstein-trading-system-v2.md) · [Detailed Design](weinstein-detailed-design.md) · [Book Reference](weinstein-screener-design-doc-v2.md)

## Screener / Analysis

## 2.1 Components

- **Indicators** — extend `analysis/technical/indicators/`: SMA, Weighted MA, Breadth (A-D, MI, NH-NL)
- **Stage Classifier** — new: `analysis/weinstein/stage/`
- **Relative Strength** — new: `analysis/weinstein/rs/`
- **Volume Analyzer** — new: `analysis/weinstein/volume/`
- **Resistance Mapper** — new: `analysis/weinstein/resistance/`
- **Breakout Detector** — new: `analysis/weinstein/breakout/`
- **Macro Analyzer** — new: `analysis/weinstein/macro/`
- **Sector Analyzer** — new: `analysis/weinstein/sector/`
- **Screener** — new: `analysis/weinstein/screener/`

## 2.2 Requirements

**Functional:**
- Classify any stock into Stage 1–4 given weekly bar history
- Detect breakouts/breakdowns with volume confirmation and overhead resistance grading
- Compute relative strength vs benchmark index
- Determine market regime from multiple indicators
- Classify sectors by stage; rate Strong/Neutral/Weak
- Screen full universe through cascading filter (macro → sector → stock); produce ranked candidates with grades

**Non-functional:**
- Full universe screen (5K tickers): <60 seconds (CPU-bound, parallelizable per ticker)
- Every analysis function is pure: same input → same output
- All thresholds and weights are configurable — no magic numbers in code

**Non-requirements:**
- Machine learning or statistical prediction (rules-based; ML tunes params, not makes decisions)
- Fundamental analysis (Weinstein explicitly rejects this)
- Intraday analysis

## 2.3 Design

### Shared Types

```ocaml
(* weinstein_types.mli *)

type ma_slope = Rising | Flat | Declining [@@deriving show, eq]

type stage =
  | Stage1 of { weeks_in_base : int }
  | Stage2 of { weeks_advancing : int; late : bool }
  | Stage3 of { weeks_topping : int }
  | Stage4 of { weeks_declining : int }
[@@deriving show, eq]

type overhead_quality =
  | Virgin_territory | Clean | Moderate_resistance | Heavy_resistance
[@@deriving show, eq]

type volume_confirmation =
  | Strong of float | Adequate of float | Weak of float
[@@deriving show, eq]

type rs_trend =
  | Bullish_crossover | Positive_rising | Positive_flat
  | Negative_improving | Negative_declining | Bearish_crossover
[@@deriving show, eq]

type market_trend = Bullish | Bearish | Neutral [@@deriving show, eq]
type grade = A_plus | A | B | C | D | F [@@deriving show, eq, compare]
```

**Why variant types for stages?** Each variant carries metadata (weeks in stage, `late` flag). Pattern matching is exhaustive — compiler forces you to handle every case. Can't accidentally confuse Stage1 and Stage3.

### Stage Classifier

```ocaml
(* stage.mli *)
type config = {
  ma_period : int;            (* default: 30 *)
  ma_weighted : bool;         (* default: true *)
  slope_threshold : float;    (* ±%, default: 0.005 *)
  slope_lookback : int;       (* weeks, default: 4 *)
  confirm_weeks : int;        (* default: 6 *)
  late_stage2_decel : float;  (* MA deceleration threshold *)
}

type result = {
  stage : Weinstein_types.stage;
  ma_value : float;
  ma_slope : Weinstein_types.ma_slope;
  ma_slope_pct : float;
  transition : (Weinstein_types.stage * Weinstein_types.stage) option;
}

val classify : config:config -> bars:Types.Daily_price.t list ->
  prior_stage:Weinstein_types.stage option -> result
```

**Algorithm:**
```
1. Compute N-week MA (SMA or weighted per config)
2. slope_pct = (MA_now - MA_lookback_ago) / MA_lookback_ago
3. Classify slope: >threshold → Rising, <-threshold → Declining, else Flat
4. Count recent weeks: close > MA vs close < MA
5. Classify:
     MA Declining + mostly below → Stage4
     MA Rising + mostly above   → Stage2
     MA Flat + oscillating      → needs prior context
6. Disambiguate flat MA:
     Prior ∈ {Stage4, Stage1} → Stage1
     Prior ∈ {Stage2, Stage3} → Stage3
7. Detect late Stage2: rising but decelerating MA + extended price
8. Compare vs prior_stage → emit transition if changed
```

**Correctness:** Pure function. Same bars + same prior_stage = same result. Essential for reproducible backtests.

**Edge case (no prior_stage):** Look at long-term MA trend. Was declining, now flat → Stage1. Was rising, now flat → Stage3. Ambiguous → default Stage1 (conservative — won't trigger buy or short).

### Macro Analyzer

```ocaml
(* macro.mli *)
type indicator_reading = {
  name : string;
  signal : [ `Bullish | `Bearish | `Neutral ];
  weight : float;
  detail : string;
}

type result = {
  index_stage : Stage.result;
  indicators : indicator_reading list;
  trend : Weinstein_types.market_trend;
  confidence : float;          (* 0.0–1.0, weighted agreement *)
  regime_changed : bool;
  rationale : string list;
}

val analyze : config:config -> stage_config:Stage.config ->
  index_bars:Types.Daily_price.t list ->
  ad_data:(Date.t * int * int) list ->
  global_index_bars:(string * Types.Daily_price.t list) list ->
  prior:result option -> result
```

**Indicator weights (configurable):**

| Indicator | Weight | Bullish | Bearish |
|---|---|---|---|
| DJI/SPX stage | 3.0 | Stage 1→2 or 2 | Stage 3→4 or 4 |
| A-D divergence | 2.0 | A-D new low, DJI holds | A-D fails to confirm DJI high |
| Momentum index | 2.0 | Crosses above zero | Crosses below zero |
| NH-NL divergence | 1.5 | Trending up vs DJI down | Trending down vs DJI up |
| Global consensus | 1.5 | Majority in Stage 2 | Majority in Stage 4 |

**Composite:** `confidence = weighted_bullish / weighted_total`. >0.65 → Bullish. <0.35 → Bearish. Otherwise Neutral.

### Screener

```ocaml
(* screener.mli *)
type scored_candidate = {
  ticker : string;
  analysis : Stock_analysis.t;
  sector : Sector.result;
  grade : Weinstein_types.grade;
  score : int;
  suggested_entry : float;
  suggested_stop : float;
  risk_pct : float;
  swing_target : float option;
  rationale : string list;
}

type result = {
  buy_candidates : scored_candidate list;
  short_candidates : scored_candidate list;
  watchlist : (string * string) list;
}

val screen : config:config -> macro:Macro.result ->
  sectors:Sector.result list -> stocks:Stock_analysis.t list ->
  held_tickers:string list -> result
```

**Cascade filter:**
```
1. MACRO GATE: Bearish → no buys. Bullish → no shorts (except A+). Neutral → both active.
2. SECTOR FILTER: Weak sector → exclude from buys. Strong sector → exclude from shorts.
3. SCORING: Additive weighted score from config weights.
4. FILTER + SORT: Remove below min_grade. Remove held tickers. Sort by grade desc.
```

### Data Flow

```
              DATA_SOURCE
                  │
    ┌─────────────┼─────────────┐
    ▼             ▼             ▼
Index bars   Sector constit.  Stock bars
+ A-D data                    (per ticker)
    │             │             │
    ▼             │             ▼
  Macro           │          Stock Analyzer
  Analyzer        │          (Stage, RS, Vol,
    │             ▼           Resist, Breakout)
    │          Sector              │
    │          Analyzer            │
    │             │                │
    └──────┬──────┴────────────────┘
           ▼
      Screener (cascade) ← config + held_tickers
           │
    scored_candidate list
```

All arrows are data. Each box is a pure function. Orchestrator calls them in order.

### Alternatives Considered

| Option | Rejected because |
|---|---|
| ML stage classifier | Rules are well-specified, interpretable, debuggable. No labeled training data. Tuner optimizes rule params. |
| Single-pass screening (no cascade) | Macro context fundamentally changes valid signals. Would surface buys in bear markets. |
| Lazy indicator computation inside screener | Pre-compute is simpler, more testable, and performance is not an issue. |

---

## Trade-offs

| Decision | Chosen | Alternative | Rationale |
|---|---|---|---|
| Rules-based analysis | Weinstein's explicit rules | ML classifier | Interpretable, debuggable, matches book, tunable via config |
| Cascade screener | Macro → sector → stock | Single-pass scoring | Core methodology, prevents invalid signals in wrong regime |
| Pre-compute all analysis | Then feed to screener | Lazy compute inside screener | Simpler, more testable, performance not a bottleneck |
| Variant types for stages | Stage1/2/3/4 with metadata | Int (1-4) | Compiler-enforced exhaustive matching, metadata per stage |
