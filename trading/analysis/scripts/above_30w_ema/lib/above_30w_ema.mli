open Async

type stock_data = {
  symbol : string;
  name : string;
  sector : string;
  price : float;
  ema : float;
}

val above_30w_ema : token:string -> unit -> stock_data list Deferred.t
(** Find S&P 500 stocks trading above their 30-week EMA
    @param token API token for market data access
    @return List of stocks trading above their 30-week EMA *)

val print_results : stock_data list -> unit
(** Print formatted results table *)
