(** Shared helpers for trade-autopsy tests: synthetic weekly-bar builders and
    long/short trade constructors. Used by every test_* file in this directory.
*)

open Core
module Walk_step = Per_symbol_stage_strategy_lib.Walk_step

val mk_bar : date:Date.t -> close:float -> Types.Daily_price.t
(** [mk_bar ~date ~close] builds a weekly bar at [date] with all OHLC equal to
    [close], volume 1000, and [active_through = None]. *)

val mk_series :
  start_date:Date.t -> closes:float list -> Types.Daily_price.t list
(** [mk_series ~start_date ~closes] builds a series of weekly bars starting at
    [start_date], with closes given by [closes]. The resulting list has one bar
    per close, spaced 7 days apart. *)

val start_date : Date.t
(** Canonical start date for synthetic series ([2020-01-03]). *)

val long_trade :
  entry_date:Date.t ->
  exit_date:Date.t ->
  entry_price:float ->
  exit_price:float ->
  Walk_step.trade
(** [long_trade ~entry_date ~exit_date ~entry_price ~exit_price] constructs a
    long trade with [return_pct = (exit_price - entry_price) / entry_price]. *)

val short_trade :
  entry_date:Date.t ->
  exit_date:Date.t ->
  entry_price:float ->
  exit_price:float ->
  Walk_step.trade
(** [short_trade ~entry_date ~exit_date ~entry_price ~exit_price] constructs a
    short trade with [return_pct = (entry_price - exit_price) / entry_price]. *)
