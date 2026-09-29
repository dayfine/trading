open Core
open Validator_types
module S = Validator_step

let _legacy_row_reason = "rows carry no position_id (legacy trades.csv)"

(* Attach [reason] only when the check actually skipped something. *)
let _with_reason reason (f : S.finding) =
  if f.skipped > 0 then { f with skip_reason = Some reason } else f

(* No audit loaded: every trade is un-evaluable, and the report says why. *)
let _all_skipped inputs reason : S.finding =
  _with_reason reason
    { S.empty_finding with skipped = List.length inputs.trades }

let _v19_missing row pid =
  S.Fail
    (S.spec row (sprintf "position_id %s has no trade_audit entry record" pid))

(* A legacy row (no position_id) has no join key; a keyed row must resolve. *)
let _v19_step inputs (row : trade_row) =
  match (row.position_id, inputs.audit row) with
  | None, _ -> S.Skip
  | Some _, Some _ -> S.Pass
  | Some pid, None -> _v19_missing row pid

let check_v19 inputs =
  match inputs.audit_absent with
  | Some reason -> _all_skipped inputs reason
  | None ->
      S.fold_steps inputs.trades ~f:(_v19_step inputs)
      |> _with_reason _legacy_row_reason

(* The close to set against [ma_value], labelled with the field it came from.
   Adjusted first (same basis as the MA); raw only on pre-#2973 files. *)
let _decision_close (bar : decision_bar_read) =
  match (bar.adjusted_close_at_decision, bar.close_at_decision) with
  | Some c, _ -> Some (c, "adjusted_close_at_decision")
  | None, Some c -> Some (c, "close_at_decision (raw)")
  | None, None -> None

let _v20_detail ~field ~close ~ma ~ratio config =
  sprintf "%s %.2f / ma_value %.2f = %.2f outside [%g, %g]" field close ma ratio
    config.audit_basis_ratio_min config.audit_basis_ratio_max

let _v20_pred config (row : trade_row) (ctx : entry_context) =
  match (ctx.decision_bar.ma_value, _decision_close ctx.decision_bar) with
  | Some ma, Some (close, field) when Float.(ma > 0.0) ->
      let ratio = close /. ma in
      if
        Float.(
          ratio < config.audit_basis_ratio_min
          || ratio > config.audit_basis_ratio_max)
      then S.Fail (S.spec row (_v20_detail ~field ~close ~ma ~ratio config))
      else S.Pass
  | _ -> S.Skip

let check_v20 inputs =
  match inputs.audit_absent with
  | Some reason -> _all_skipped inputs reason
  | None ->
      S.fold_steps inputs.trades
        ~f:(S.audit_step inputs.audit ~pred:(_v20_pred inputs.config))

(* ---- V21: installed stop vs the screener's proxy stop -------------------- *)

let _v21_detail ~installed ~proxy ~dist config =
  sprintf "installed_stop %.4f vs screener_proxy_stop %.4f: %.2f%% apart > %g%%"
    installed proxy (dist *. 100.0)
    (config.installed_vs_proxy_stop_max_pct *. 100.0)

(* Legacy [installed_stop = 0.0], no proxy, or a non-positive proxy (the
   denominator) leave nothing to compare. *)
let _v21_pred config (row : trade_row) (ctx : entry_context) =
  match ctx.screener_proxy_stop with
  | Some proxy when Float.(proxy > 0.0 && ctx.installed_stop > 0.0) ->
      let installed = ctx.installed_stop in
      let dist = Float.abs (installed -. proxy) /. proxy in
      if Float.(dist > config.installed_vs_proxy_stop_max_pct) then
        S.Fail (S.spec row (_v21_detail ~installed ~proxy ~dist config))
      else S.Pass
  | _ -> S.Skip

let _v21_skip_reason =
  "no audit record, installed_stop 0.0 (legacy), or screener_proxy_stop \
   missing or <= 0"

let check_v21 inputs =
  match inputs.audit_absent with
  | Some reason -> _all_skipped inputs reason
  | None ->
      S.fold_steps inputs.trades
        ~f:(S.audit_step inputs.audit ~pred:(_v21_pred inputs.config))
      |> _with_reason _v21_skip_reason

(* ---- V23: long fill after a Bearish screen ------------------------------- *)

let _no_screens_reason = "trade_audit.sexp carries no cascade_summaries"
let _pre_screen_reason = "fill precedes the first recorded screen"

(* The latest screen strictly before [fill]: the screen runs at a Friday's
   close, so a fill dated on a screen Friday traded before that screen. *)
let _last_screen_before screens fill =
  List.fold screens ~init:None ~f:(fun best (s : screen_read) ->
      match best with
      | _ when Date.(s.screen_date >= fill) -> best
      | Some (b : screen_read) when Date.(b.screen_date >= s.screen_date) ->
          best
      | _ -> Some s)

let _v23_detail (row : trade_row) screen_date =
  sprintf "filled %s after the %s screen read Bearish"
    (Date.to_string row.entry_date)
    (Date.to_string screen_date)

let _v23_step screens (row : trade_row) =
  match _last_screen_before screens row.entry_date with
  | None -> S.Skip
  | Some { screen_date; screen_macro_trend = Weinstein_types.Bearish } ->
      S.Fail (S.spec row (_v23_detail row screen_date))
  | Some _ -> S.Pass

let _longs_all_skipped inputs reason : S.finding =
  _with_reason reason
    { S.empty_finding with skipped = List.length (S.longs inputs) }

let check_v23 inputs =
  match (inputs.audit_absent, inputs.screens) with
  | Some reason, _ -> _longs_all_skipped inputs reason
  | None, [] -> _longs_all_skipped inputs _no_screens_reason
  | None, screens ->
      S.fold_steps (S.longs inputs) ~f:(_v23_step screens)
      |> _with_reason _pre_screen_reason

let v23_severity inputs =
  match inputs.macro_suspend with
  | Some Weinstein_strategy.Entry_ticket_suspend_mode.On_bearish_macro ->
      Invariant
  | Some (Off | On_index_stage4) | None -> Expectation
