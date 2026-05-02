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
}
[@@deriving sexp, eq, show]

type held_position = {
  symbol : string;
  entered : Date.t;
  stop : float;
  status : string;
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
}
[@@deriving sexp, eq, show]
