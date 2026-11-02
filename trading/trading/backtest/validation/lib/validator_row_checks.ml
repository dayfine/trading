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

(* ---- V12: stop-distance gate consistency ------------------------------- *)

(* The strategy rejects any entry whose installed stop sits farther than
   [stops_config.max_stop_distance_pct] from the fill as [Stop_too_wide]
   ([entry_audit_capture.ml]). So a filled trade wider than the gate is an
   invariant break: either the gate did not fire, or the captured
   [installed_stop] disagrees with the gated stop. The distance is measured
   exactly as the gate measures it — against the FILL price
   ([trade_row.entry_price] = the strategy's [effective_entry]), not the
   screener's [suggested_entry].

   F3 exception (2026-08-10): under [config.stop_width_mode = Size_down] the
   strategy ADMITS a wider-than-gate structural stop and shrinks the share count
   instead, so every sized-down entry is a filled trade wider than
   [gate_max_stop_distance_pct] BY DESIGN — not an invariant break. A ladder-v4
   cell running [Size_down] must raise [gate_max_stop_distance_pct] to that
   cell's [stop_width_size_down_max_pct] or V12 reports a wall of false
   failures. Under the default [Drop_over_max] the invariant holds exactly as
   stated above. *)
(* #3420: the gate measures from its [effective_entry], which is [E] when the run
   armed [sim_entry_trigger_at_suggested] and the decision-bar close otherwise
   (the default). The audit does not say which, so the stop is measured from
   each decision-time base the gate could have used, and V12 fails only when it
   is wider than the gate from {b all} of them: then the gate cannot have
   admitted it, whichever it used. [installed_stop], [E] and the decision close
   share one split basis, so a split between decision and fill no longer
   matters (NVDA 2021-05-24: 2.67 against the restated fill, 0.081 from [E]),
   and neither does the up-to-2 % band a stop-limit fill lands above [E] (KD
   2023-09-11). A legacy audit with neither base falls back to the fill. *)
let _v12_bases ~(row : trade_row) ~(ctx : entry_context) =
  let positive = List.filter ~f:(fun b -> Float.( > ) b 0.0) in
  match
    positive
      (ctx.suggested_entry :: Option.to_list ctx.decision_bar.close_at_decision)
  with
  | [] -> positive [ row.entry_price ]
  | bases -> bases

let _v12_dist_from ~(ctx : entry_context) base =
  Float.abs (ctx.installed_stop -. base) /. base

(* The base with the smallest distance: the most favourable reading of the
   gate's own measure. [None] when there is no usable base. *)
let _v12_closest ~(row : trade_row) ~(ctx : entry_context) =
  _v12_bases ~row ~ctx
  |> List.map ~f:(fun b -> (_v12_dist_from ~ctx b, b))
  |> List.min_elt ~compare:(fun (a, _) (b, _) -> Float.compare a b)

let _v12_detail (c : check_config) ~dist ~base ~(ctx : entry_context) =
  sprintf
    "installed_stop=%.4f vs closest gate base=%.4f (E=%.4f) -> dist=%.4f > \
     gate=%.4f"
    ctx.installed_stop base ctx.suggested_entry dist
    c.gate_max_stop_distance_pct

(* Un-evaluable rows: legacy audits with no captured [installed_stop] ([0.0]
   default) or no positive base at all. *)
let _v12_unevaluable ~(ctx : entry_context) =
  Float.( <= ) ctx.installed_stop 0.0

let _v12_pred (c : check_config) (row : trade_row) (ctx : entry_context) =
  match _v12_closest ~row ~ctx with
  | _ when _v12_unevaluable ~ctx -> Skip
  | None -> Skip
  | Some (dist, base) when Float.( > ) dist c.gate_max_stop_distance_pct ->
      Fail (spec row (_v12_detail c ~dist ~base ~ctx))
  | Some _ -> Pass

let check_v12 inputs =
  fold_steps inputs.trades
    ~f:(audit_step inputs.audit ~pred:(_v12_pred inputs.config))

(* ---- V5: exit_trigger vs stop_trigger_kind consistency ----------------- *)

(* Triggers whose row must carry a real stop kind ([gap_down] / [gap_up] /
   [intraday]; [gap_up] is a short's gap through its stop, #3147).
   The two legacy [force_liquidation_*] labels belong here because the relabel
   that produced them (removed 2026-09-14) overwrote rows whose underlying exit
   really was a stop-out. The token the breaker emits today,
   ["force_liquidation"], deliberately does NOT: it rides a [StrategySignal],
   which {!Stop_log.classify_stop_trigger_kind} maps to [Non_stop_exit], and
   that is what [_expected_kinds]'s else-branch already requires of it. *)
let _stop_triggers =
  [ "stop_loss"; "force_liquidation_position"; "force_liquidation_portfolio" ]

let _expected_kinds trigger =
  if List.mem _stop_triggers trigger ~equal:String.equal then
    [ "gap_down"; "gap_up"; "intraday" ]
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
