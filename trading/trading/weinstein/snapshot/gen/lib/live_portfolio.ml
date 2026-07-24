open Core

type position = {
  symbol : string;
  shares : int;
  entry_price : float;
  entry_date : Date.t;
  stop_price : float;
}
[@@deriving sexp, eq, show]

type t = { cash : float; as_of : Date.t; positions : position list }
[@@deriving sexp, eq, show]

let load ~path = Or_error.try_with (fun () -> Sexp.load_sexp path |> t_of_sexp)
