open Core
open Validator_types
module S = Validator_step
module Sd = Weinstein_stops.Stop_decision

let _no_decisions_reason =
  "trade_audit.sexp carries no stop_decisions (pre-#2986 artefact)"

let _position_no_rows_reason = "position has no stop-decision rows"
let _days_per_week = 7

(* A row moved the stop iff its level changed. The state machine never lowers a
   stop, so any change is a raise or a tightening — [Raised] and
   [Tightened_ratchet] always change it, an [Entered_tightening] may. *)
let _moved (d : Sd.t) = not (Float.equal d.stop_before d.stop_after)

(* A completed correction + recovery that did not move the stop: a
   [Cycle_stalled] row whose predecessor — the previous stop update, since
   [Stop_decision.push] only ever replaces a hold head with a newer hold — is
   [Correction_not_recovered], i.e. a correction of at least
   [min_correction_pct] was on file and had not yet recovered. Any other
   predecessor ([No_correction_yet], [Seeded_trailing], none) means the cycle
   test passed on the very bar that first showed the depth, which a low printed
   before the peak does with no pullback at all. *)
let _completed_stall ~(prev : Sd.t option) (d : Sd.t) =
  Sd.equal_reason d.reason Sd.Cycle_stalled
  &&
  match prev with
  | Some p -> Sd.equal_reason p.reason Sd.Correction_not_recovered
  | None -> false

(* One no-move stretch: from [start] (the first row, or the row that last moved
   the stop) to [last] (the latest row before the next move, or the row that
   made it). [stalls] is newest first. *)
type _stretch = { start : Date.t; last : Date.t; stalls : Sd.t list }

let _days s = Date.diff s.last s.start

let _qualifies config s =
  (not (List.is_empty s.stalls))
  && _days s >= config.stalled_ratchet_min_weeks * _days_per_week

(* Keep the longer of two qualifying stretches. *)
let _consider config best s =
  if not (_qualifies config s) then best
  else match best with Some b when _days b >= _days s -> best | _ -> Some s

let _step config (cur, best) ((prev : Sd.t option), (d : Sd.t)) =
  if _moved d then
    let closed = { cur with last = d.date } in
    ( { start = d.date; last = d.date; stalls = [] },
      _consider config best closed )
  else
    let stalls =
      if _completed_stall ~prev d then d :: cur.stalls else cur.stalls
    in
    ({ cur with last = d.date; stalls }, best)

(* Each row paired with the row before it ([None] for the first). *)
let _with_prev decisions =
  List.folding_map decisions ~init:None ~f:(fun prev d -> (Some d, (prev, d)))

(* The longest qualifying stretch of a non-empty oldest-first history. *)
let _longest_stall config (decisions : Sd.t list) =
  match decisions with
  | [] -> None
  | first :: _ ->
      let init = { start = first.date; last = first.date; stalls = [] } in
      let cur, best =
        List.fold (_with_prev decisions) ~init:(init, None) ~f:(_step config)
      in
      _consider config best cur

let _opt_str = function None -> "none" | Some v -> sprintf "%.2f" v

(* correction extreme / MA: ~1.0-1.4 when a lagging MA binds the candidate in
   an uptrend, far above that when the MA sits on another price basis (#2982). *)
let _extreme_over_ma (d : Sd.t) =
  match d.last_correction_extreme with
  | Some e when Float.(d.ma_value > 0.0) -> sprintf "%.2f" (e /. d.ma_value)
  | _ -> "n/a"

let _detail s =
  let last = List.hd_exn s.stalls in
  sprintf
    "no stop move for %d weeks (%s..%s), %d completed cycle(s) stalled; last: \
     stop %.2f, candidate %s, ma %.2f, correction extreme %s (extreme/ma %s)"
    (_days s / _days_per_week)
    (Date.to_string s.start) (Date.to_string s.last) (List.length s.stalls)
    last.stop_after (_opt_str last.candidate) last.ma_value
    (_opt_str last.last_correction_extreme)
    (_extreme_over_ma last)

let _spec (h : stop_history) s : specimen =
  {
    symbol = h.symbol;
    entry_date = Date.to_string h.entry_date;
    detail = _detail s;
  }

let _history_step config (h : stop_history) =
  if List.is_empty h.decisions then S.Skip
  else
    match _longest_stall config h.decisions with
    | Some s -> S.Fail (_spec h s)
    | None -> S.Pass

(* Every position the run knows of — its round trips + open positions, or its
   audit records if those are more — skipped with [reason]. *)
let _all_skipped inputs reason : S.finding =
  let n =
    Int.max
      (List.length inputs.stop_histories)
      (List.length inputs.trades + List.length inputs.open_positions)
  in
  if n = 0 then S.empty_finding
  else { S.empty_finding with skipped = n; skip_reason = Some reason }

let _with_reason (f : S.finding) =
  if f.skipped > 0 then { f with skip_reason = Some _position_no_rows_reason }
  else f

let _has_rows (h : stop_history) = not (List.is_empty h.decisions)

let check_v22 inputs =
  match inputs.audit_absent with
  | Some reason -> _all_skipped inputs reason
  | None when not (List.exists inputs.stop_histories ~f:_has_rows) ->
      _all_skipped inputs _no_decisions_reason
  | None ->
      S.fold_steps inputs.stop_histories ~f:(_history_step inputs.config)
      |> _with_reason
