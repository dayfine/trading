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
    }
[@@deriving sexp, eq, show]

let default = Weinstein

let name = function
  | Weinstein -> "Weinstein"
  | Bah_benchmark { symbol } -> sprintf "Bah_benchmark(%s)" symbol
  | Spy_only_weinstein { symbol; ma_period_weeks; enable_stage4_short } ->
      sprintf "Spy_only_weinstein(%s,ma=%dwk%s)" symbol ma_period_weeks
        (if enable_stage4_short then ",short" else "")
  | Sector_rotation_weinstein { k; ma_period_weeks } ->
      sprintf "Sector_rotation_weinstein(k=%d,ma=%dwk)" k ma_period_weeks
