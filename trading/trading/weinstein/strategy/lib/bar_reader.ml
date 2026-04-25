(** Bar source abstraction — see [bar_reader.mli]. *)

module Bar_panels = Data_panel.Bar_panels

type backend = History of Bar_history.t | Panels of Bar_panels.t
type t = backend

let of_history h = History h
let of_panels p = Panels p

(* For the panels backend, [as_of] is mapped to a panel column. When the
   date is not in the calendar (e.g., the backtest hasn't started yet, or
   the strategy was somehow handed a date outside the bounds), return the
   empty list. The strategy's downstream code already tolerates an empty
   result: [Stage.classify_with_callbacks] returns the Stage1 default,
   [Sector.analyze] returns the empty result, etc. *)
let daily_bars_for t ~symbol ~as_of =
  match t with
  | History h -> Bar_history.daily_bars_for h ~symbol
  | Panels p -> (
      match Bar_panels.column_of_date p as_of with
      | None -> []
      | Some as_of_day -> Bar_panels.daily_bars_for p ~symbol ~as_of_day)

let weekly_bars_for t ~symbol ~n ~as_of =
  match t with
  | History h -> Bar_history.weekly_bars_for h ~symbol ~n
  | Panels p -> (
      match Bar_panels.column_of_date p as_of with
      | None -> []
      | Some as_of_day -> Bar_panels.weekly_bars_for p ~symbol ~n ~as_of_day)

let accumulate t ~get_price ~symbols =
  match t with
  | History h -> Bar_history.accumulate h ~get_price ~symbols
  | Panels _ -> ()
