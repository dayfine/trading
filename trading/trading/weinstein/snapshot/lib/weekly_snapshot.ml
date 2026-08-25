open Core

let current_schema_version = 1

type macro_context = { regime : string; score : float }
[@@deriving sexp, eq, show]

type candidate = {
  symbol : string;
  score : float;
  grade : string;
  entry : float;
  stop : float;
  sector : string;
  rationale : string;
  rs_vs_spy : float option;
  resistance_grade : string option;
  sized_shares : int; [@sexp.default 0]
  sized_position_value : float; [@sexp.default 0.0]
  sized_position_pct : float; [@sexp.default 0.0]
  sized_risk_amount : float; [@sexp.default 0.0]
  sizing_note : string option; [@sexp.default None]
  stop_is_structural : bool; [@sexp.default false]
  data_suspect : bool; [@sexp.default false]
  reconciliation : Entry_reconciliation.t;
      [@sexp.default Entry_reconciliation.Not_reconciled]
  score_components : (string * int) list; [@sexp.default []]
}
[@@deriving sexp, eq, show]

let expected_fill_price c =
  match c.reconciliation with
  | Entry_reconciliation.Through_entry { close; _ } -> close
  | Not_reconciled | Valid_stop _ | Extended _ -> c.entry

let sizing_basis_price c =
  match c.reconciliation with
  | Entry_reconciliation.Valid_stop { cap; _ }
  | Through_entry { cap; _ }
  | Extended { cap; _ }
    when Float.( > ) cap 0.0 ->
      cap
  | Not_reconciled | Valid_stop _ | Through_entry _ | Extended _ ->
      expected_fill_price c

type held_position = {
  symbol : string;
  entered : Date.t;
  stop : float;
  status : string;
  shares : int; [@sexp.default 0]
  entry_price : float; [@sexp.default 0.0]
  current_price : float; [@sexp.default 0.0]
  unrealized_pct : float; [@sexp.default 0.0]
  recommended_stop : float option; [@sexp.default None]
}
[@@deriving sexp, eq, show]

type t = {
  schema_version : int;
  system_version : string;
  date : Date.t;
  macro : macro_context;
  sectors_strong : string list;
  sectors_weak : string list;
  long_candidates : candidate list;
  short_candidates : candidate list;
  long_eligible_beyond_cap : int; [@sexp.default 0]
  short_eligible_beyond_cap : int; [@sexp.default 0]
  held_positions : held_position list;
  warnings : string list; [@sexp.default []]
}
[@@deriving sexp, eq, show]
