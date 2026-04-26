(** Bar source abstraction — see [bar_reader.mli]. *)

open Core
module Bar_panels = Data_panel.Bar_panels
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels

type t = Bar_panels.t

let of_panels p = p

(** Build an empty [Bar_panels.t] backed by a zero-symbol universe + zero-day
    calendar. Used by [empty ()] for tests where no panel-backed read is
    expected. *)
let _empty_panels () =
  let symbol_index =
    match Symbol_index.create ~universe:[] with
    | Ok t -> t
    | Error err ->
        failwithf "Bar_reader.empty: Symbol_index.create []: %s"
          err.Status.message ()
  in
  let ohlcv = Ohlcv_panels.create symbol_index ~n_days:0 in
  match Bar_panels.create ~ohlcv ~calendar:[||] with
  | Ok p -> p
  | Error err ->
      failwithf "Bar_reader.empty: Bar_panels.create: %s" err.Status.message ()

let empty () = _empty_panels ()

(* When [as_of] is not in the calendar (e.g., the backtest hasn't started yet,
   or the strategy was somehow handed a date outside the bounds), return the
   empty list. The strategy's downstream code already tolerates an empty
   result: [Stage.classify_with_callbacks] returns the Stage1 default,
   [Sector.analyze] returns the empty result, etc. *)
let daily_bars_for t ~symbol ~as_of =
  match Bar_panels.column_of_date t as_of with
  | None -> []
  | Some as_of_day -> Bar_panels.daily_bars_for t ~symbol ~as_of_day

let weekly_bars_for t ~symbol ~n ~as_of =
  match Bar_panels.column_of_date t as_of with
  | None -> []
  | Some as_of_day -> Bar_panels.weekly_bars_for t ~symbol ~n ~as_of_day
