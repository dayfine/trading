open Async

type stock_data = { symbol : string; price : float; ema : float }

val above_30w_ema :
  token:string -> symbols:string list -> unit -> stock_data list Deferred.t
(** Find stocks trading above their 30-week EMA
    @param token API token for market data access
    @param symbols List of stock symbols to analyze
    @return List of stocks trading above their 30-week EMA *)

val print_results : stock_data list -> unit
(** Print formatted results table *)
