(** Derived chart series for the HTML report: the downsampled curve, the
    buy-and-hold benchmark, capital utilization, and per-trade weekly price
    series with a WMA30. Pure helpers split out of {!Html_report}. *)

open Core

type interval
(** A holding interval (symbol, entry, optional exit, share count). *)

val downsample : every:int -> 'a list -> 'a list
(** Keep every [every]-th row, always retaining the last row. *)

val benchmark :
  adjusted_close:(symbol:string -> as_of:Date.t -> float option) ->
  symbol:string ->
  initial_cash:float ->
  dates:Date.t list ->
  (Date.t * float) list option
(** Buy-and-hold benchmark indexed to [initial_cash] at the first date. [None]
    if any date fails to resolve. Marks must be split/dividend-adjusted. *)

val extra_of :
  Html_sources.trade_extra Core.Map.M(String).t ->
  sym:string ->
  entry:Date.t ->
  exit_:Date.t ->
  Html_sources.trade_extra
(** Look up a trade's extra columns, defaulting to empty values. *)

val intervals :
  Trade_audit_report.t ->
  Html_sources.trade_extra Core.Map.M(String).t ->
  Html_data.open_position list ->
  interval list
(** Holding intervals for closed round trips and open positions. *)

val utilization :
  position_mark:(symbol:string -> as_of:Date.t -> float option) ->
  intervals:interval list ->
  curve:(Date.t * float) list ->
  float list
(** Percentage of NAV deployed at each curve point. Marks must be raw. *)

val series :
  weekly_series:
    (symbol:string -> n:int -> as_of:Date.t -> (Date.t * float) array) ->
  extra:Html_sources.trade_extra ->
  sym:string ->
  entry:Date.t ->
  exit_:Date.t ->
  Html_data.trade_series option
(** Per-trade weekly close + WMA30 series, entry-52w to exit+26w. *)
