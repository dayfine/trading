(** Stop-decision observability record. See [stop_decision.mli].

    Constructors of {!Stop_types} are always written qualified here: this module
    declares its own [Initial] / [Trailing] / [Tightened] / [Stop_hit] /
    [Entered_tightening] tags, and qualification keeps the two families from
    shadowing each other. *)

open Core
open Trading_base.Types

type reason =
  | Raised
  | No_correction_yet
  | Correction_not_recovered
  | Anchor_not_fresh
  | Cycle_stalled
  | Seeded_trailing
  | Entered_tightening
  | Tightened_ratchet
  | Tightened_hold
  | Stop_hit
  | Other_hold
[@@deriving show, eq, sexp]

type state_kind = Initial | Trailing | Tightened [@@deriving show, eq, sexp]

type step = {
  before : Stop_types.stop_state;
  after : Stop_types.stop_state;
  event : Stop_types.stop_event;
  bar : Types.Daily_price.t;
  ma_value : float;
}

type t = {
  date : Date.t;
  position_id : string;
  state_before : state_kind;
  state_after : state_kind;
  stop_before : float;
  stop_after : float;
  candidate : float option;
  correction_count_before : int;
  correction_count : int;
  last_trend_extreme : float option;
  last_correction_extreme : float option;
  ma_value : float;
  reason : reason;
}
[@@deriving eq, sexp]

let _kind_of_state : Stop_types.stop_state -> state_kind = function
  | Stop_types.Initial _ -> Initial
  | Stop_types.Trailing _ -> Trailing
  | Stop_types.Tightened _ -> Tightened

let _stop_level : Stop_types.stop_state -> float = function
  | Stop_types.Initial { stop_level; _ } -> stop_level
  | Stop_types.Trailing { stop_level; _ } -> stop_level
  | Stop_types.Tightened { stop_level; _ } -> stop_level

(* The correction extreme after this bar, before any cycle reset — the same
   [Float.min] / [Float.max] advance [Weinstein_stops] applies before its cycle
   test. *)
let _advanced_correction_extreme ~side ~last_correction_extreme ~bar =
  let extreme = Stop_geometry.bar_extreme ~side ~bar in
  match side with
  | Long -> Float.min last_correction_extreme extreme
  | Short -> Float.max last_correction_extreme extreme

(* A [Trailing] step that returned [No_change] without completing a counted
   cycle: name the first clause of the cycle test that failed. [observed] is
   the post-step [correction_observed_since_reset], i.e. the guard input the
   state machine itself used on this bar. *)
let _trailing_hold ~config ~side ~trend_extreme ~correction_extreme
    ~correction_count ~observed ~close =
  if
    not
      (Stop_geometry.is_correction ~config ~side ~trend_extreme
         ~correction_extreme)
  then No_correction_yet
  else if not (Stop_geometry.is_recovery ~side ~close ~trend_extreme) then
    Correction_not_recovered
  else if correction_count > 0 && not observed then Anchor_not_fresh
  else Cycle_stalled

let _classify_trailing_no_change ~config ~side (step : step) =
  match (step.before, step.after) with
  | ( Stop_types.Trailing
        {
          last_trend_extreme;
          last_correction_extreme;
          correction_count = count_before;
          _;
        },
      Stop_types.Trailing
        { correction_count = count_after; correction_observed_since_reset; _ }
    ) ->
      if count_after > count_before then Cycle_stalled
      else
        _trailing_hold ~config ~side ~trend_extreme:last_trend_extreme
          ~correction_extreme:
            (_advanced_correction_extreme ~side ~last_correction_extreme
               ~bar:step.bar)
          ~correction_count:count_before
          ~observed:correction_observed_since_reset
          ~close:step.bar.Types.Daily_price.close_price
  | _ -> Other_hold

let _classify_no_change ~config ~side (step : step) =
  match step.before with
  | Stop_types.Initial _ -> Seeded_trailing
  | Stop_types.Tightened _ -> Tightened_hold
  | Stop_types.Trailing _ -> _classify_trailing_no_change ~config ~side step

let classify ~config ~side (step : step) =
  match step.event with
  | Stop_types.Stop_hit _ -> Stop_hit
  | Stop_types.Entered_tightening _ -> Entered_tightening
  | Stop_types.Stop_raised _ -> (
      match step.before with
      | Stop_types.Tightened _ -> Tightened_ratchet
      | Stop_types.Initial _ | Stop_types.Trailing _ -> Raised)
  | Stop_types.No_change -> _classify_no_change ~config ~side step


let _correction_count (step : step) =
  match (step.after, step.before) with
  | Stop_types.Trailing { correction_count; _ }, _
  | _, Stop_types.Trailing { correction_count; _ } ->
      correction_count
  | _ -> 0

let _correction_count_before (step : step) =
  match step.before with
  | Stop_types.Trailing { correction_count; _ } -> correction_count
  | Stop_types.Initial _ | Stop_types.Tightened _ -> 0

(* Did the cycle test run on this step? [Weinstein_stops] runs it only when the
   stop was neither hit nor tightened. *)
let _cycle_test_ran (step : step) =
  match step.event with
  | Stop_types.No_change | Stop_types.Stop_raised _ -> true
  | Stop_types.Stop_hit _ | Stop_types.Entered_tightening _ -> false

(* [(last_trend_extreme, last_correction_extreme)] — see the field docs in the
   .mli for which state each side is read from. *)
let _extremes ~side (step : step) =
  match (step.before, step.after) with
  | Stop_types.Trailing { last_trend_extreme; last_correction_extreme; _ }, _
    ->
      let correction_extreme =
        if _cycle_test_ran step then
          _advanced_correction_extreme ~side ~last_correction_extreme
            ~bar:step.bar
        else last_correction_extreme
      in
      (Some last_trend_extreme, Some correction_extreme)
  | _, Stop_types.Trailing { last_trend_extreme; last_correction_extreme; _ }
    ->
      (Some last_trend_extreme, Some last_correction_extreme)
  | _, Stop_types.Tightened { last_correction_extreme; _ } ->
      (None, Some last_correction_extreme)
  | _, Stop_types.Initial _ -> (None, None)

(* The stop a completed cycle computes — mirrors [Weinstein_stops]'s private
   [_cycle_stop_candidate]: buffered below [min (correction extreme, MA)] for a
   long (above [max] for a short), then nudged. *)
let _cycle_candidate ~config ~side ~correction_extreme ~ma_value =
  let effective_ref =
    match side with
    | Long -> Float.min correction_extreme ma_value
    | Short -> Float.max correction_extreme ma_value
  in
  Stop_geometry.stop_candidate ~config ~side ~correction_extreme:effective_ref

let _candidate ~config ~side ~reason ~correction_extreme ~ma_value =
  match (reason, correction_extreme) with
  | (Raised | Cycle_stalled), Some correction_extreme ->
      Some (_cycle_candidate ~config ~side ~correction_extreme ~ma_value)
  | _ -> None

let make ~config ~side ~position_id (step : step) : t =
  let last_trend_extreme, last_correction_extreme = _extremes ~side step in
  let reason = classify ~config ~side step in
  {
    date = step.bar.Types.Daily_price.date;
    position_id;
    state_before = _kind_of_state step.before;
    state_after = _kind_of_state step.after;
    stop_before = _stop_level step.before;
    stop_after = _stop_level step.after;
    candidate =
      _candidate ~config ~side ~reason
        ~correction_extreme:last_correction_extreme ~ma_value:step.ma_value;
    correction_count_before = _correction_count_before step;
    correction_count = _correction_count step;
    last_trend_extreme;
    last_correction_extreme;
    ma_value = step.ma_value;
    reason;
  }

let is_hold = function
  | No_correction_yet | Correction_not_recovered | Anchor_not_fresh
  | Tightened_hold | Other_hold ->
      true
  | Raised | Cycle_stalled | Seeded_trailing | Entered_tightening
  | Tightened_ratchet | Stop_hit ->
      false

(* Monday of [date]'s ISO week. [Day_of_week.to_int] is Sun = 0 .. Sat = 6. *)
let _week_monday date =
  Date.add_days date (-((Day_of_week.to_int (Date.day_of_week date) + 6) % 7))

let _same_week_holds (a : t) (b : t) =
  is_hold a.reason && is_hold b.reason
  && Date.equal (_week_monday a.date) (_week_monday b.date)

let push newest_first (d : t) =
  match newest_first with
  | head :: rest when _same_week_holds head d -> d :: rest
  | _ -> d :: newest_first
