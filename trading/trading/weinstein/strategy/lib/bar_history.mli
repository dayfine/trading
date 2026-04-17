(** Per-symbol accumulated daily bar buffer used by the Weinstein strategy
    closure. The buffer is read by the stage classifier, MA computation, and
    macro input builders. Writes are idempotent on repeated calls with the same
    bar date so the simulator can re-invoke the strategy on a replayed day
    without duplicating history. *)

open Core

type t = Types.Daily_price.t list Hashtbl.M(String).t
(** A mutable hashtable from symbol to its daily bar history, in chronological
    order (oldest first). *)

val create : unit -> t
(** Empty bar history. *)

val accumulate :
  t ->
  get_price:Trading_strategy.Strategy_interface.get_price_fn ->
  symbols:string list ->
  unit
(** For each symbol in [symbols], pull today's bar via [get_price] and append it
    to the buffer — but only if the bar's date is strictly later than the last
    recorded bar. Called on every strategy invocation; idempotent for replayed
    days. *)

val weekly_bars_for : t -> symbol:string -> n:int -> Types.Daily_price.t list
(** Return the most recent [n] weekly-aggregated bars for [symbol]. Daily bars
    are converted via {!Time_period.Conversion.daily_to_weekly} with
    [include_partial_week:true]. Returns the empty list if [symbol] has no
    accumulated bars, or all available weekly bars if fewer than [n] exist. *)

val daily_bars_for : t -> symbol:string -> Types.Daily_price.t list
(** Return the full accumulated daily bar history for [symbol] in chronological
    order (oldest first). Returns the empty list if [symbol] has no accumulated
    bars. Callers that need a bounded window should slice the result themselves
    — the support-floor primitive in [weinstein_stops] is one such caller. *)
