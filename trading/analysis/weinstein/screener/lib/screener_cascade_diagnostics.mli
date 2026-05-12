(** Per-cascade-phase admission counts for one screener call. The cumulative
    fold {!build} turns per-side phase tuples + top-N counts into the public
    record. Extracted from {!Screener} to keep that file under the
    declared-large file-length cap. {!Screener.cascade_diagnostics} is a type
    alias so existing consumers continue to spell the type as
    [Screener.cascade_diagnostics]. *)

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

val build :
  total_stocks:int ->
  candidates_after_held:int ->
  macro_trend:market_trend ->
  long_phases:int * int * int ->
  short_phases:int * int * int * int ->
  long_top_n:int ->
  short_top_n:int ->
  t
(** [build] composes the diagnostics record. Phase tuples are
    [(breakout, sector, grade)] for longs and [(breakdown, sector, rs, grade)]
    for shorts. When the macro gate closes a side (Bearish for longs, Bullish
    for shorts), downstream phase counts are forced to zero — the screener never
    evaluates the side, so the recorded counts must reflect that. *)
