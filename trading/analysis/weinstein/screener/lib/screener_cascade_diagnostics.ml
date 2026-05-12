open Core
open Weinstein_types

type t = {
  total_stocks : int;
  candidates_after_held : int;
  macro_trend : market_trend;
  long_macro_admitted : int;
  long_breakout_admitted : int;
  long_sector_admitted : int;
  long_grade_admitted : int;
  long_top_n_admitted : int;
  short_macro_admitted : int;
  short_breakdown_admitted : int;
  short_sector_admitted : int;
  short_rs_hard_gate_admitted : int;
  short_grade_admitted : int;
  short_top_n_admitted : int;
}
[@@deriving sexp]

let build ~total_stocks ~candidates_after_held ~macro_trend ~long_phases
    ~short_phases ~long_top_n ~short_top_n =
  let long_breakout, long_sector, long_grade = long_phases in
  let short_breakdown, short_sector, short_rs, short_grade = short_phases in
  let long_macro_admitted =
    match macro_trend with
    | Bearish -> 0
    | Bullish | Neutral -> candidates_after_held
  in
  let short_macro_admitted =
    match macro_trend with
    | Bullish -> 0
    | Bearish | Neutral -> candidates_after_held
  in
  let zero_if (gate : int) (n : int) = if gate = 0 then 0 else n in
  {
    total_stocks;
    candidates_after_held;
    macro_trend;
    long_macro_admitted;
    long_breakout_admitted = zero_if long_macro_admitted long_breakout;
    long_sector_admitted = zero_if long_macro_admitted long_sector;
    long_grade_admitted = zero_if long_macro_admitted long_grade;
    long_top_n_admitted = long_top_n;
    short_macro_admitted;
    short_breakdown_admitted = zero_if short_macro_admitted short_breakdown;
    short_sector_admitted = zero_if short_macro_admitted short_sector;
    short_rs_hard_gate_admitted = zero_if short_macro_admitted short_rs;
    short_grade_admitted = zero_if short_macro_admitted short_grade;
    short_top_n_admitted = short_top_n;
  }
