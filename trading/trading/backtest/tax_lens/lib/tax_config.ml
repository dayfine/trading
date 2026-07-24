open Core

type mode = Mtm_flat | Realized_st_lt [@@deriving sexp, equal]

type t = {
  mode : mode;
  flat_rate : float;
  st_rate : float;
  lt_rate : float;
  lt_days : int;
  carryforward : bool;
  top_winners : int;
}
[@@deriving sexp, equal]

let default =
  {
    mode = Realized_st_lt;
    flat_rate = 0.35;
    st_rate = 0.35;
    lt_rate = 0.238;
    lt_days = 365;
    carryforward = true;
    top_winners = 15;
  }

let load_exn path = Sexp.load_sexp path |> t_of_sexp

let effective_rates t =
  match t.mode with
  | Mtm_flat -> (t.flat_rate, t.flat_rate)
  | Realized_st_lt -> (t.st_rate, t.lt_rate)
