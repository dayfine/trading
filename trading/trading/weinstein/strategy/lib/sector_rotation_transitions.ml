(** Holding-exit and entry transition builders for the sector-rotation Weinstein
    strategy — see [sector_rotation_transitions.mli]. *)

open Core
open Trading_strategy

(* Overnight gap buffer for cash sizing — mirrors
   [Spy_only_weinstein_strategy._entry_gap_buffer_pct]. *)
let _entry_gap_buffer_pct = 0.01

let _position_id_of_symbol (symbol : string) : string =
  Printf.sprintf "%s-sector-rotation-weinstein" symbol

let _is_weekly_close ~(date : Date.t) : bool =
  Date.day_of_week date |> Day_of_week.equal Day_of_week.Fri

let _holding_quantity (pos : Position.t) : float option =
  match pos.state with
  | Position.Holding h -> Some h.quantity
  | Position.Entering _ | Position.Exiting _ | Position.Closed _ -> None

(* Whole shares affordable at [close_price] for [cash], gap buffer applied.
   [None] when the cash cannot buy a single share or inputs are non-positive. *)
let _shares_from_cash ~(cash : float) ~(close_price : float) : float option =
  if Float.(cash <= 0.0) || Float.(close_price <= 0.0) then None
  else
    let sizing_price = close_price *. (1.0 +. _entry_gap_buffer_pct) in
    let shares = Float.round_down (cash /. sizing_price) in
    Option.some_if Float.(shares > 0.0) shares

(* The per-symbol weekly stage read, recording the new prior stage. *)
let _holding_stage_read ~stage_config ~weekly_window ~bar_reader ~prior_stage
    ~(symbol : string) ~(as_of : Date.t) : Stage.result option =
  let prior = Map.find !prior_stage symbol in
  let bars =
    Bar_reader.weekly_bars_for bar_reader ~symbol ~n:weekly_window ~as_of
  in
  match bars with
  | [] -> None
  | bars ->
      let r = Stage.classify ~config:stage_config ~bars ~prior_stage:prior in
      prior_stage := Map.set !prior_stage ~key:symbol ~data:r.stage;
      Some r

(* The Friday stage-or-rotation exit for a held long when the stop did not fire:
   exit when the held stage read warrants it (Stage-4 roll-over) OR the symbol
   has left the top-[k] target set. [None] outside a weekly close. *)
let _stage_or_rotation_exit ~(in_target : bool)
    ~(stage_result : Stage.result option) ~(pos : Position.t)
    ~(bar : Types.Daily_price.t) : Position.transition option =
  if not (_is_weekly_close ~date:bar.date) then None
  else
    let stage_exit =
      Option.bind stage_result
        ~f:(Spy_only_signals.stage_exit_label_for_side ~side:Position.Long)
    in
    match stage_exit with
    | Some label -> Some (Spy_only_transitions.build_exit ~pos ~bar ~label)
    | None when in_target -> None
    | None ->
        Some (Spy_only_transitions.build_exit ~pos ~bar ~label:"rotation_out")

(* After deciding whether [symbol] exits this tick, update [stop_state]: remove
   on exit (so a re-entry re-seeds), set to the advanced [new_state]
   otherwise. *)
let _commit_stop_state ~stop_state ~symbol ~new_state ~exit =
  match exit with
  | Some _ -> stop_state := Map.remove !stop_state symbol
  | None -> stop_state := Map.set !stop_state ~key:symbol ~data:new_state

(* Holding branch for one symbol: run the stop, and on a Friday also test the
   stage / rotation exit. The stop takes precedence. Mutates [stop_state] /
   [prior_stage]; clears [stop_state] for the symbol on any exit so a re-entry
   re-seeds. Returns the (at most one) exit transition. *)
let _on_holding_symbol ~stops_config ~stage_config ~weekly_window ~bar_reader
    ~fallback_buffer ~stop_state ~prior_stage ~target ~(symbol : string)
    ~(pos : Position.t) ~(bar : Types.Daily_price.t) : Position.transition list
    =
  let stage_result =
    _holding_stage_read ~stage_config ~weekly_window ~bar_reader ~prior_stage
      ~symbol ~as_of:bar.date
  in
  let state =
    Sector_rotation_stops.seed_or_keep ~stops_config ~bar_reader
      ~fallback_buffer ~symbol
      ~existing:(Map.find !stop_state symbol)
      ~pos ~bar
  in
  let new_state, stop_exit =
    Sector_rotation_stops.step ~stops_config ~stage_result ~state ~pos ~bar
  in
  let in_target = Set.mem target symbol in
  let exit =
    match stop_exit with
    | Some _ -> stop_exit
    | None -> _stage_or_rotation_exit ~in_target ~stage_result ~pos ~bar
  in
  _commit_stop_state ~stop_state ~symbol ~new_state ~exit;
  Option.to_list exit

let holding_exits ~stops_config ~stage_config ~weekly_window ~bar_reader
    ~fallback_buffer ~stop_state ~prior_stage ~target
    ~(holdings : Position.t String.Map.t)
    ~(get_price : string -> Types.Daily_price.t option) :
    Position.transition list =
  let on_one (symbol, pos) =
    match (_holding_quantity pos, get_price symbol) with
    | Some _, Some bar ->
        _on_holding_symbol ~stops_config ~stage_config ~weekly_window
          ~bar_reader ~fallback_buffer ~stop_state ~prior_stage ~target ~symbol
          ~pos ~bar
    | _ -> []
  in
  Map.to_alist holdings |> List.concat_map ~f:on_one

let _build_entry_at ~symbol ~bar ~target_quantity =
  Spy_only_transitions.build_entry
    ~position_id:(_position_id_of_symbol symbol)
    ~symbol ~side:Position.Long ~bar ~target_quantity

(* Build the entry transition for [symbol] if today's price is present and the
   per-slot cash buys ≥1 whole share. *)
let _entry_for_symbol ~per_slot_cash ~get_price symbol :
    Position.transition option =
  let open Option.Let_syntax in
  let%bind (bar : Types.Daily_price.t) = get_price symbol in
  let%map target_quantity =
    _shares_from_cash ~cash:per_slot_cash ~close_price:bar.close_price
  in
  _build_entry_at ~symbol ~bar ~target_quantity

let entry_transitions ~(cash : float) ~(target : String.Set.t)
    ~(holdings : Position.t String.Map.t)
    ~(get_price : string -> Types.Daily_price.t option) :
    Position.transition list =
  let to_enter =
    Set.to_list target |> List.filter ~f:(fun s -> not (Map.mem holdings s))
  in
  let open_slots = List.length to_enter in
  if open_slots = 0 then []
  else
    let per_slot_cash = cash /. Float.of_int open_slots in
    List.filter_map to_enter ~f:(_entry_for_symbol ~per_slot_cash ~get_price)
