(** Market data interface for strategy access to prices and indicators *)

open Core

(** {1 Types} *)

type indicator_value = { date : Date.t; value : float } [@@deriving show, eq]

(** {1 Market Data Interface} *)

module type MARKET_DATA = sig
  type t

  val current_date : t -> Date.t
  val advance : t -> date:Date.t -> t
  val get_price : t -> symbol:string -> Types.Daily_price.t option

  val get_price_history :
    t -> symbol:string -> ?lookback_days:int -> unit -> Types.Daily_price.t list

  val get_ema : t -> symbol:string -> period:int -> float option

  val get_ema_series :
    t ->
    symbol:string ->
    period:int ->
    ?lookback_days:int ->
    unit ->
    indicator_value list
end

(** Note: Concrete implementations of MARKET_DATA will be provided by the
    data processing pipeline. This module only defines the interface. *)
