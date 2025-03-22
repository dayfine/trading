open Core
open Types

type ema_result = {
  date : Date.t;
  value : float;
} [@@deriving eq]

val calculate_ema_from_weekly :
  Daily_price.t list -> int -> ema_result list
(** Calculate exponential moving average from weekly price data
    @param data List of weekly price data points in chronological order
    @param period Number of weeks to use for EMA calculation
    @return
      List of EMA results, starting from the nth week where n is the
      period *)

val calculate_ema_from_daily :
  Daily_price.t list -> int -> ema_result list
(** Calculate exponential moving average from daily price data
    @param data List of daily price data points in chronological order
    @param period Number of weeks to use for EMA calculation
    @return
      List of EMA results, starting from the nth week where n is the
      period *)
