open Core

type bar_query = {
  symbol : string;
  period : Types.Cadence.t;
  start_date : Date.t option;
  end_date : Date.t option;
}
[@@deriving show, eq]

module type DATA_SOURCE = sig
  open Async

  val get_bars :
    query:bar_query ->
    unit ->
    Types.Daily_price.t list Status.status_or Deferred.t

  val get_universe :
    unit -> Types.Instrument_info.t list Status.status_or Deferred.t
end
