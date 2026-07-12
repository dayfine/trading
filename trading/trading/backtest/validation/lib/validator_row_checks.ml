open Core
open Validator_types
open Validator_step

(* ---- V1 / V2 / V8: audit-derived checks -------------------------------- *)

let _v1_pred (row : trade_row) (ctx : entry_context) =
  match ctx.stage with
  | Weinstein_types.Stage2 _ -> Pass
  | s -> Fail (spec row ("entry stage=" ^ Backtest.Trade_context.stage_label s))

let _v2_pred (row : trade_row) (ctx : entry_context) =
  match ctx.macro_trend with
  | Weinstein_types.Bearish -> Fail (spec row "macro_trend=Bearish")
  | _ -> Pass

let _v8_pred (row : trade_row) (ctx : entry_context) =
  match ctx.ma_direction with
  | Weinstein_types.Declining -> Fail (spec row "ma_direction=Declining")
  | _ -> Pass

let check_v1 inputs =
  fold_steps (longs inputs) ~f:(audit_step inputs.audit ~pred:_v1_pred)

let check_v2 inputs =
  fold_steps (longs inputs) ~f:(audit_step inputs.audit ~pred:_v2_pred)

let check_v8 inputs =
  fold_steps (longs inputs) ~f:(audit_step inputs.audit ~pred:_v8_pred)

(* ---- V11: stop-distance bounds ----------------------------------------- *)

let _v11_detail (c : check_config) d =
  sprintf "stop_distance=%.4f outside [%.4f, %.4f]" d c.stop_distance_min_pct
    c.stop_distance_max_pct

let _v11_step (c : check_config) (row : trade_row) =
  match row.stop_initial_distance_pct with
  | None -> Skip
  | Some d
    when Float.( < ) d c.stop_distance_min_pct
         || Float.( > ) d c.stop_distance_max_pct ->
      Fail (spec row (_v11_detail c d))
  | Some _ -> Pass

let check_v11 inputs = fold_steps inputs.trades ~f:(_v11_step inputs.config)

(* ---- V5: exit_trigger vs stop_trigger_kind consistency ----------------- *)

let _stop_triggers =
  [ "stop_loss"; "force_liquidation_position"; "force_liquidation_portfolio" ]

let _expected_kinds trigger =
  if List.mem _stop_triggers trigger ~equal:String.equal then
    [ "gap_down"; "intraday" ]
  else if String.equal trigger "end_of_period" then [ "end_of_period" ]
  else [ "non_stop_exit" ]

let _v5_consistent (row : trade_row) =
  List.mem
    (_expected_kinds row.exit_trigger)
    row.stop_trigger_kind ~equal:String.equal

let _v5_detail (row : trade_row) =
  sprintf "exit_trigger=%s but stop_trigger_kind=%s" row.exit_trigger
    row.stop_trigger_kind

let _v5_step (row : trade_row) =
  if String.is_empty row.exit_trigger || String.is_empty row.stop_trigger_kind
  then Skip
  else if _v5_consistent row then Pass
  else Fail (spec row (_v5_detail row))

let check_v5 inputs = fold_steps inputs.trades ~f:_v5_step

(* ---- V6: rename-twin duplicate positions ------------------------------- *)

let _twin_key (r : trade_row) =
  sprintf "%s|%s|%.2f|%.2f"
    (Date.to_string r.entry_date)
    (Date.to_string r.exit_date)
    r.entry_price r.exit_price

let _add_twin groups (row : trade_row) =
  let key = _twin_key row in
  let cur = Hashtbl.find groups key |> Option.value ~default:[] in
  if
    List.exists cur ~f:(fun (r : trade_row) -> String.equal r.symbol row.symbol)
  then ()
  else Hashtbl.set groups ~key ~data:(row :: cur)

let _group_twins trades =
  let groups = Hashtbl.create (module String) in
  List.iter trades ~f:(_add_twin groups);
  groups

let _twin_step (rep : trade_row) data =
  let syms =
    List.map data ~f:(fun (r : trade_row) -> r.symbol)
    |> List.sort ~compare:String.compare
  in
  Fail (spec rep ("twin positions: " ^ String.concat ~sep:"/" syms))

let _v6_group_step data =
  match data with rep :: _ :: _ -> _twin_step rep data | _ -> Pass

let check_v6 inputs =
  Hashtbl.fold (_group_twins inputs.trades) ~init:empty_finding
    ~f:(fun ~key:_ ~data acc ->
      match _v6_group_step data with
      | Fail sp -> { acc with violations = sp :: acc.violations }
      | _ -> acc)
