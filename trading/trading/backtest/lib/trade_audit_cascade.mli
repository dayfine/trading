(** Per-Friday cascade-rejection counts for the trade audit.

    Split out of [Trade_audit] purely to keep that file under the file-length
    limit; [Trade_audit] [include]s this module, so callers keep using
    [Trade_audit.cascade_summary]. The field-level documentation lives on
    {!Trade_audit.cascade_summary} — the public contract — and is not repeated
    here. *)

open Core

type cascade_summary = {
  date : Date.t;
  total_stocks : int;
  candidates_after_held : int;
  macro_trend : Weinstein_types.market_trend;
  breadth_state : Weinstein_types.breadth_state;
      [@sexp.default Weinstein_types.Neutral_breadth]
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
  entered : int;
}
[@@deriving sexp]
(** See {!Trade_audit.cascade_summary}. *)
