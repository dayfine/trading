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
let _decision_close (ctx : entry_context) =
  match (ctx.adjusted_close_at_decision, ctx.close_at_decision) with
  | Some c, _ -> Some (c, "adjusted_close_at_decision")
  | None, Some c -> Some (c, "close_at_decision (raw)")
  | None, None -> None

let _v20_detail ~field ~close ~ma ~ratio config =
  sprintf "%s %.2f / ma_value %.2f = %.2f outside [%g, %g]" field close ma ratio
    config.audit_basis_ratio_min config.audit_basis_ratio_max

let _v20_pred config (row : trade_row) (ctx : entry_context) =
  match (ctx.ma_value, _decision_close ctx) with
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
