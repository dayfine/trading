open Core
open Trading_strategy

(* Extra weekly bars read beyond the hold length so the trailing WMA window is
   already filled at the first holding week (the WMA needs [ma_period] prior
   weeks). *)
let _wma_window_margin = 4

(* Weekly WMA input on the adjusted-close basis — the same basis as the merged
   extension screen and Stage's default Wma. *)
let _ma_input (b : Types.Daily_price.t) =
  Indicator_types.{ date = b.date; value = b.adjusted_close }

(* WMA value per weekly date; missing until the trailing window fills. *)
let _wma_by_date ~ma_period weekly =
  let tbl = Date.Table.create () in
  Sma.calculate_weighted_ma (List.map weekly ~f:_ma_input) ma_period
  |> List.iter ~f:(fun iv ->
      Hashtbl.set tbl ~key:iv.Indicator_types.date
        ~data:iv.Indicator_types.value);
  tbl

(* Weekly (adjusted_close, wma30) arrays over the holding window
   [entry_date, current_date]. Enough weekly bars are read to also fill the
   trailing WMA window before entry, so early holding weeks carry a real
   (non-NaN) WMA; [wmas.(i)] is NaN where the window had not yet filled. *)
let _holding_window_series ~bar_reader ~ma_period ~symbol ~entry_date
    ~current_date =
  let weeks_held = (Date.diff current_date entry_date / 7) + 1 in
  let n = weeks_held + ma_period + _wma_window_margin in
  let weekly =
    Bar_reader.weekly_bars_for bar_reader ~symbol ~n ~as_of:current_date
  in
  let wma_by_date = _wma_by_date ~ma_period weekly in
  let in_window =
    List.filter weekly ~f:(fun b ->
        Date.( >= ) b.Types.Daily_price.date entry_date)
  in
  let closes =
    Array.of_list_map in_window ~f:(fun b -> b.Types.Daily_price.adjusted_close)
  in
  let wmas =
    Array.of_list_map in_window ~f:(fun b ->
        Option.value
          (Hashtbl.find wma_by_date b.Types.Daily_price.date)
          ~default:Float.nan)
  in
  (closes, wmas)

(* [StrategySignal "extension_stop"] with the trigger/trail config in the
   detail, for the [exit_trigger] forensic column. *)
let _exit_reason ~config =
  let detail =
    Printf.sprintf "trigger=%.2f,trail=%.2f"
      config.Weinstein_stops.Extension_stop.trigger_ratio
      config.Weinstein_stops.Extension_stop.trail_pct
  in
  Position.StrategySignal { label = "extension_stop"; detail = Some detail }

(* The [TriggerExit] for a fired extension stop: exit at the current bar's close
   (weekly-close semantics). *)
let _make_exit_transition ~(pos : Position.t) ~current_date ~bar ~config =
  let exit_price = bar.Types.Daily_price.close_price in
  {
    Position.position_id = pos.id;
    date = current_date;
    kind =
      Position.TriggerExit { exit_reason = _exit_reason ~config; exit_price };
  }

(* Whether the held long's extension trail has fired on its holding-window
   weekly series. *)
let _trail_fired ~config ~ma_period ~bar_reader ~current_date ~entry_date
    (pos : Position.t) =
  let closes, wmas =
    _holding_window_series ~bar_reader ~ma_period ~symbol:pos.symbol ~entry_date
      ~current_date
  in
  Weinstein_stops.Extension_stop.fired config ~closes ~wmas

(* Decide whether a held long's extension trail has fired and, if so, emit its
   exit. Skips the position when it is already exiting this tick or has no
   current bar. *)
let _exit_for_holding ~config ~ma_period ~bar_reader ~skip_position_ids
    ~get_price ~current_date ~entry_date (pos : Position.t) =
  let skipped = Set.mem skip_position_ids pos.Position.id in
  let fired =
    (not skipped)
    && _trail_fired ~config ~ma_period ~bar_reader ~current_date ~entry_date pos
  in
  if not fired then None
  else
    Option.map (get_price pos.symbol) ~f:(fun bar ->
        _make_exit_transition ~pos ~current_date ~bar ~config)

(* Only held LONG positions are eligible — the extension blow-off is a
   long-side phenomenon. *)
let _process_position ~config ~ma_period ~bar_reader ~skip_position_ids
    ~get_price ~current_date (pos : Position.t) =
  match (pos.Position.side, Position.get_state pos) with
  | Trading_base.Types.Long, Position.Holding h ->
      _exit_for_holding ~config ~ma_period ~bar_reader ~skip_position_ids
        ~get_price ~current_date ~entry_date:h.entry_date pos
  | _ -> None

let _fold_position ~config ~ma_period ~bar_reader ~skip_position_ids ~get_price
    ~current_date acc pos =
  match
    _process_position ~config ~ma_period ~bar_reader ~skip_position_ids
      ~get_price ~current_date pos
  with
  | Some t -> t :: acc
  | None -> acc

let update ~config ~ma_period ~is_screening_day ~positions ~bar_reader
    ~get_price ~skip_position_ids ~current_date =
  if
    (not (Weinstein_stops.Extension_stop.is_enabled config))
    || (not is_screening_day) || Map.is_empty positions
  then []
  else
    Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:pos acc ->
        _fold_position ~config ~ma_period ~bar_reader ~skip_position_ids
          ~get_price ~current_date acc pos)
