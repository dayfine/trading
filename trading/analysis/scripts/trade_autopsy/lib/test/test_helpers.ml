(** Shared helpers for trade-autopsy tests: synthetic weekly-bar builders and
    long/short trade constructors. Used by every test_* file in this directory.
*)

open Core
module Walk_step = Per_symbol_stage_strategy_lib.Walk_step

(** Build a weekly bar at date [d] with all OHLC equal to [close]. *)
let mk_bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    volume = 1_000;
    adjusted_close = close;
    active_through = None;
  }

(** Build a series of weekly bars starting at [start_date], with closes given by
    [closes]. The resulting list has one bar per close, spaced 7 days apart. *)
let mk_series ~start_date ~closes =
  List.mapi closes ~f:(fun i close ->
      mk_bar ~date:(Date.add_days start_date (7 * i)) ~close)

(** Canonical start date for synthetic series. *)
let start_date = Date.of_string "2020-01-03"

(** Construct a long trade. *)
let long_trade ~entry_date ~exit_date ~entry_price ~exit_price : Walk_step.trade
    =
  {
    variant_side = `Long;
    entry_date;
    exit_date;
    entry_price;
    exit_price;
    return_pct = (exit_price -. entry_price) /. entry_price;
  }

(** Construct a short trade. *)
let short_trade ~entry_date ~exit_date ~entry_price ~exit_price :
    Walk_step.trade =
  {
    variant_side = `Short;
    entry_date;
    exit_date;
    entry_price;
    exit_price;
    return_pct = (entry_price -. exit_price) /. entry_price;
  }
