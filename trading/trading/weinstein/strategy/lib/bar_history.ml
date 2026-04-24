open Core

type t = Types.Daily_price.t list Hashtbl.M(String).t

let create () : t = Hashtbl.create (module String)

let _is_new_bar (existing : Types.Daily_price.t list) bar =
  match List.last existing with
  | None -> true
  | Some last -> Date.( > ) bar.Types.Daily_price.date last.date

let _append_bar_if_new (t : t) ~symbol bar =
  let existing = Hashtbl.find t symbol |> Option.value ~default:[] in
  if _is_new_bar existing bar then
    Hashtbl.set t ~key:symbol ~data:(existing @ [ bar ])

let accumulate (t : t)
    ~(get_price : Trading_strategy.Strategy_interface.get_price_fn) ~symbols =
  List.iter symbols ~f:(fun symbol ->
      get_price symbol |> Option.iter ~f:(_append_bar_if_new t ~symbol))

let weekly_bars_for (t : t) ~symbol ~n =
  let daily = Hashtbl.find t symbol |> Option.value ~default:[] in
  let weekly =
    Time_period.Conversion.daily_to_weekly ~include_partial_week:true daily
  in
  let len = List.length weekly in
  if len <= n then weekly else List.drop weekly (len - n)

let daily_bars_for (t : t) ~symbol =
  Hashtbl.find t symbol |> Option.value ~default:[]

let _last_date_of (bars : Types.Daily_price.t list) : Date.t option =
  Option.map (List.last bars) ~f:(fun b -> b.Types.Daily_price.date)

let _bars_strictly_after ~last_date bars =
  List.filter bars ~f:(fun b -> Date.( > ) b.Types.Daily_price.date last_date)

let _pick_new_bars ~existing bars =
  match _last_date_of existing with
  | None -> bars
  | Some last_date -> _bars_strictly_after ~last_date bars

let _drop_bars_before ~cutoff bars =
  List.drop_while bars ~f:(fun b -> Date.( < ) b.Types.Daily_price.date cutoff)

let trim_before (t : t) ~(as_of : Date.t) ~(max_lookback_days : int) =
  if max_lookback_days < 0 then
    invalid_arg
      (Printf.sprintf
         "Bar_history.trim_before: max_lookback_days must be >= 0, got %d"
         max_lookback_days);
  let cutoff = Date.add_days as_of (-max_lookback_days) in
  Hashtbl.map_inplace t ~f:(fun bars -> _drop_bars_before ~cutoff bars)

let seed (t : t) ~symbol ~(bars : Types.Daily_price.t list) =
  let existing = Hashtbl.find t symbol |> Option.value ~default:[] in
  let new_bars = _pick_new_bars ~existing bars in
  if not (List.is_empty new_bars) then
    Hashtbl.set t ~key:symbol ~data:(existing @ new_bars)
