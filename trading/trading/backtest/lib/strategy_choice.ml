(** Strategy selector for {!Backtest.Runner} — see [strategy_choice.mli]. *)

open Core

(* Investor preset MA period (Weinstein's 30-week MA); the default when a
   scenario omits [ma_period_weeks], keeping pre-existing SPY scenarios
   bit-identical to the investor preset. *)
let default_spy_ma_period_weeks = 30

(* Stage-4 short leg off by default: a scenario that omits [enable_stage4_short]
   gets the long/flat strategy, bit-identical to the pre-short-leg behaviour. *)
let default_spy_enable_stage4_short = false

(* Sector-rotation defaults: hold the single strongest Stage-2 sector (k=1) with
   the 30-week investor MA when a scenario omits the fields. *)
let default_sector_rotation_k = 1
let default_sector_rotation_ma_period_weeks = 30

(* Macro gate off by default: a scenario that omits [enable_macro_gate] gets the
   ungated selection-only sector strategy, bit-identical to the pre-gate
   behaviour. *)
let default_sector_rotation_enable_macro_gate = false

(* Scenario-universe opt-in off by default: a scenario that omits
   [use_scenario_universe] keeps the hardcoded 11-SPDR tradable list,
   bit-identical to the pre-opt-in behaviour. *)
let default_sector_rotation_use_scenario_universe = false

(* No per-sector cap by default: a scenario that omits [sector_cap] gets the
   uncapped top-k selection, bit-identical to the pre-cap behaviour. *)
let default_sector_rotation_sector_cap = None

(* Breaker SPY sleeve default instrument (the P1b floor sleeve trades SPY). *)
let default_breaker_spy_symbol = "SPY"

type t =
  | Weinstein
  | Bah_benchmark of { symbol : string }
  | Spy_only_weinstein of {
      symbol : string;
      ma_period_weeks : int; [@sexp.default default_spy_ma_period_weeks]
      enable_stage4_short : bool; [@sexp.default default_spy_enable_stage4_short]
    }
  | Sector_rotation_weinstein of {
      k : int; [@sexp.default default_sector_rotation_k]
      ma_period_weeks : int;
          [@sexp.default default_sector_rotation_ma_period_weeks]
      enable_macro_gate : bool;
          [@sexp.default default_sector_rotation_enable_macro_gate]
      use_scenario_universe : bool;
          [@sexp.default default_sector_rotation_use_scenario_universe]
      sector_cap : int option; [@sexp.default default_sector_rotation_sector_cap]
    }
  | Breaker_spy_sleeve of {
      symbol : string; [@sexp.default default_breaker_spy_symbol]
    }
[@@deriving sexp, eq, show]

let default = Weinstein

(* Render the sector-rotation label. Extracted from [name]'s match arm so the
   arm stays a flat call (the inline conditionals pushed [name] over the nesting
   limit); the flat sequential lets here keep this helper well under it. *)
let _sector_rotation_label ~k ~ma_period_weeks ~enable_macro_gate
    ~use_scenario_universe ~sector_cap =
  let macro = if enable_macro_gate then ",macrogate" else "" in
  let scenuniv = if use_scenario_universe then ",scenuniv" else "" in
  let cap =
    match sector_cap with Some n -> sprintf ",cap=%d" n | None -> ""
  in
  sprintf "Sector_rotation_weinstein(k=%d,ma=%dwk%s%s%s)" k ma_period_weeks
    macro scenuniv cap

let name = function
  | Weinstein -> "Weinstein"
  | Bah_benchmark { symbol } -> sprintf "Bah_benchmark(%s)" symbol
  | Spy_only_weinstein { symbol; ma_period_weeks; enable_stage4_short } ->
      sprintf "Spy_only_weinstein(%s,ma=%dwk%s)" symbol ma_period_weeks
        (if enable_stage4_short then ",short" else "")
  | Sector_rotation_weinstein
      {
        k;
        ma_period_weeks;
        enable_macro_gate;
        use_scenario_universe;
        sector_cap;
      } ->
      _sector_rotation_label ~k ~ma_period_weeks ~enable_macro_gate
        ~use_scenario_universe ~sector_cap
  | Breaker_spy_sleeve { symbol } -> sprintf "Breaker_spy_sleeve(%s)" symbol
