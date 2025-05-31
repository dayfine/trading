open Async

val fetch_and_save_prices :
  token:string ->
  symbols:string list ->
  unit ->
  (string * unit Status.status_or) list Deferred.t
(** Fetch and save historical prices for multiple symbols in parallel. Returns a
    list of (symbol, result) pairs, where each result is either [Ok ()] for
    successfully processed symbols or [Error status] for failed symbols. *)
