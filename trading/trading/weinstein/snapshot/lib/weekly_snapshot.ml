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
}
[@@deriving sexp, eq, show]

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
  held_positions : held_position list;
  warnings : string list; [@sexp.default []]
}
[@@deriving sexp, eq, show]
