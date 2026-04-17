(* @large-module: stop state machine — initial, trailing, tightened, update *)
open Core
open Weinstein_types
open Trading_base.Types
include Stop_types
module Support_floor = Support_floor

(* ---- Nudge functions ---- *)

(* Round numbers and half-dollars attract heavy order flow, so stops placed right
   at those levels are more likely to be triggered by noise. We step just outside
   them when the raw stop lands within [config.round_number_nudge] of a level.
   The nearest half-dollar (or whole dollar) is used as the reference point. *)

let _nearest_half price =
  let floor_half = Float.round_down (price /. 0.5) *. 0.5 in
  let ceil_half = floor_half +. 0.5 in
  if
    Float.( < )
      (Float.abs (price -. ceil_half))
      (Float.abs (price -. floor_half))
  then ceil_half
  else floor_half

(* For longs, nudge the stop below the nearest level; for shorts, above. *)
let nudge_round_number ~config ~side price =
  let nudge = config.round_number_nudge in
  let candidate = _nearest_half price in
  if Float.( <= ) (Float.abs (price -. candidate)) nudge then
    match side with
    | Long when Float.( >= ) price candidate -> candidate -. nudge
    | Short when Float.( <= ) price candidate -> candidate +. nudge
    | _ -> price
  else price

(* ---- Stop level extraction ---- *)

let get_stop_level = function
  | Initial { stop_level; _ } -> stop_level
  | Trailing { stop_level; _ } -> stop_level
  | Tightened { stop_level; _ } -> stop_level

(* ---- Stop hit check ---- *)

let check_stop_hit ~state ~side ~bar =
  let stop_level = get_stop_level state in
  match side with
  | Long -> Float.( <= ) bar.Types.Daily_price.low_price stop_level
  | Short -> Float.( >= ) bar.Types.Daily_price.high_price stop_level

(* ---- Initial stop computation ---- *)

let compute_initial_stop ~config ~side ~reference_level =
  (* Half the min-correction threshold: places the initial stop modestly inside
     the reference level without using the full correction distance, which would
     be too loose for an entry stop. *)
  let delta = config.min_correction_pct /. 2.0 in
  let raw_stop =
    match side with
    | Long -> reference_level *. (1.0 -. delta)
    | Short -> reference_level *. (1.0 +. delta)
  in
  Initial
    { stop_level = nudge_round_number ~config ~side raw_stop; reference_level }

(* Fallback reference when the bar history yields no qualifying counter-move.
   Mirrors the pre-primitive caller behaviour: push the reference point into
   the position's favour by the configured buffer. *)
let _fallback_reference ~side ~entry_price ~fallback_buffer =
  match side with
  | Long -> entry_price *. fallback_buffer
  | Short -> entry_price /. fallback_buffer

let compute_initial_stop_with_floor ~config ~side ~entry_price ~bars ~as_of
    ~fallback_buffer =
  let reference_level =
    match
      Support_floor.find_recent_level ~bars ~as_of ~side
        ~min_pullback_pct:config.min_correction_pct
        ~lookback_bars:config.support_floor_lookback_bars
    with
    | Some level -> level
    | None -> _fallback_reference ~side ~entry_price ~fallback_buffer
  in
  compute_initial_stop ~config ~side ~reference_level

(* ---- Directional helpers ---- *)

(* The bar's extreme price in the against-trend direction.
   Long: session low (how far price pulled back against the uptrend).
   Short: session high (how far price counter-rallied against the downtrend).
   This same price is also the stop trigger: longs exit when the low reaches the
   stop level; shorts exit when the high reaches the stop level. *)
let _bar_extreme ~side ~bar =
  match side with
  | Long -> bar.Types.Daily_price.low_price
  | Short -> bar.Types.Daily_price.high_price

(* Stop candidate from a correction extreme.
   Applies [config.trailing_stop_buffer_pct] in the position's favour, then a
   round-number nudge. The nudge only widens the effective buffer — it moves
   longs further down and shorts further up, never the reverse. *)
let _stop_candidate ~config ~side ~correction_extreme =
  let buf = config.trailing_stop_buffer_pct in
  let adjusted =
    match side with
    | Long -> correction_extreme *. (1.0 -. buf)
    | Short -> correction_extreme *. (1.0 +. buf)
  in
  nudge_round_number ~config ~side adjusted

(* Stop candidate for tightened ratchet.
   Uses [config.tightened_stop_buffer_pct] — tighter than the trailing buffer
   to keep the stop close to market once tightening is triggered. *)
let _tightened_stop_candidate ~config ~side ~correction_extreme =
  let buf = config.tightened_stop_buffer_pct in
  let adjusted =
    match side with
    | Long -> correction_extreme *. (1.0 -. buf)
    | Short -> correction_extreme *. (1.0 +. buf)
  in
  nudge_round_number ~config ~side adjusted

(* Is [candidate] an improvement over [current] stop? *)
let _is_better_stop ~side ~current ~candidate =
  match side with
  | Long -> Float.( > ) candidate current
  | Short -> Float.( < ) candidate current

(* Was there a meaningful correction of at least [min_correction_pct]? *)
let _is_correction ~config ~side ~trend_extreme ~correction_extreme =
  let pullback =
    match side with
    | Long -> (trend_extreme -. correction_extreme) /. trend_extreme
    | Short -> (correction_extreme -. trend_extreme) /. trend_extreme
  in
  Float.( >= ) pullback config.min_correction_pct

(* Did price recover back through the trend extreme after the correction? *)
let _is_recovery ~side ~close ~trend_extreme =
  match side with
  | Long -> Float.( >= ) close trend_extreme
  | Short -> Float.( <= ) close trend_extreme

(* ---- Tightening trigger checks ---- *)

(* Long: tighten when stock enters topping/declining territory or MA deteriorates.
   Returns (should_tighten, reason). *)
let _should_tighten_long ~config ~ma_direction ~stage : bool * string =
  match stage with
  | Stage3 _ | Stage4 _ -> (true, "Stage 3/4 detected")
  | Stage1 _ -> (false, "")
  | Stage2 _ ->
      if config.tighten_on_flat_ma then
        match ma_direction with
        | Flat -> (true, "30-week MA flattening")
        | Declining -> (true, "30-week MA falling in Stage 2")
        | Rising -> (false, "")
      else (false, "")

(* Short: tighten when stock shows bullish recovery (Stage 1/2) or MA turns up.
   Returns (should_tighten, reason). *)
let _should_tighten_short ~config ~ma_direction ~stage : bool * string =
  match stage with
  | Stage1 _ | Stage2 _ -> (true, "Stage 1/2 detected")
  | Stage3 _ -> (false, "")
  | Stage4 _ ->
      if config.tighten_on_flat_ma then
        match ma_direction with
        | Rising -> (true, "30-week MA rising in Stage 4")
        | Flat -> (true, "30-week MA flattening in Stage 4")
        | Declining -> (false, "")
      else (false, "")

let _should_tighten ~config ~side ~ma_direction ~stage : bool * string =
  match side with
  | Long -> _should_tighten_long ~config ~ma_direction ~stage
  | Short -> _should_tighten_short ~config ~ma_direction ~stage

(* ---- Shared transition builders ---- *)

let _stop_hit_event ~side ~stop_level ~bar =
  Stop_hit { trigger_price = _bar_extreme ~side ~bar; stop_level }

(* Transitions to Tightened state. Used by both Initial and Trailing handlers. *)
let _to_tightened ~config ~side ~stop_level ~correction_extreme ~reason =
  let candidate = _stop_candidate ~config ~side ~correction_extreme in
  let new_stop =
    if _is_better_stop ~side ~current:stop_level ~candidate then candidate
    else stop_level
  in
  ( Tightened
      {
        stop_level = new_stop;
        last_correction_extreme = correction_extreme;
        reason;
      },
    Entered_tightening { reason } )

(* Transitions from Initial to Trailing, seeding tracking fields from current bar. *)
let _to_trailing ~side ~ma_value ~stop_level ~bar =
  Trailing
    {
      stop_level;
      last_correction_extreme = _bar_extreme ~side ~bar;
      last_trend_extreme = bar.Types.Daily_price.close_price;
      ma_at_last_adjustment = ma_value;
      correction_count = 0;
    }

(* ---- Shared stop-hit and tighten dispatch ---- *)

(* Check whether a tightening transition should fire; returns the new state pair
   or [None] if no tightening is warranted. *)
let _check_tighten ~config ~side ~stop_level ~correction_extreme ~ma_direction
    ~stage =
  let should_tighten, reason =
    _should_tighten ~config ~side ~ma_direction ~stage
  in
  if should_tighten then
    Some (_to_tightened ~config ~side ~stop_level ~correction_extreme ~reason)
  else None

(* Handles the stop-hit and tightening checks shared by Initial and Trailing states.
   Returns [Some (new_state, event)] if the stop was hit or tightening triggered,
   or [None] to proceed with state-specific update logic. *)
let _check_stop_or_tighten ~config ~side ~state ~bar ~correction_extreme
    ~ma_direction ~stage =
  let stop_level = get_stop_level state in
  if check_stop_hit ~state ~side ~bar then
    Some (state, _stop_hit_event ~side ~stop_level ~bar)
  else
    _check_tighten ~config ~side ~stop_level ~correction_extreme ~ma_direction
      ~stage

(* ---- Update: Initial state ---- *)

let _update_initial ~config ~side ~state ~current_bar ~ma_value ~ma_direction
    ~stage =
  let bar = current_bar in
  let stop_level = get_stop_level state in
  let correction_extreme = _bar_extreme ~side ~bar in
  match
    _check_stop_or_tighten ~config ~side ~state ~bar ~correction_extreme
      ~ma_direction ~stage
  with
  | Some result -> result
  | None -> (_to_trailing ~side ~ma_value ~stop_level ~bar, No_change)

(* ---- Correction cycle helpers ---- *)

(* Advance correction_extreme/trend_extreme tracking for one bar.
   Returns (new_trend_extreme, new_correction_extreme). *)
let _advance_tracking ~side ~last_correction_extreme ~last_trend_extreme ~bar =
  let extreme = _bar_extreme ~side ~bar in
  (* Correction extreme: track the worst the pullback has gone so far.
     Long → lowest low seen (deepest pullback below the trend peak).
     Short → highest high seen (highest counter-rally above the trend trough). *)
  let new_correction_extreme =
    match side with
    | Long -> Float.min last_correction_extreme extreme
    | Short -> Float.max last_correction_extreme extreme
  in
  let close = bar.Types.Daily_price.close_price in
  (* Trend extreme: track how far the main trend has extended.
     Long → highest close seen (rally peak to ratchet stop above).
     Short → lowest close seen (decline trough to ratchet stop below). *)
  let new_trend_extreme =
    match side with
    | Long -> Float.max last_trend_extreme close
    | Short -> Float.min last_trend_extreme close
  in
  (new_trend_extreme, new_correction_extreme)

(* Returns [Some new_stop] if a correction cycle just completed and the
   candidate stop is better than the current stop, otherwise [None].

   Per Weinstein Ch. 6: the stop is placed below min(correction_low, MA) —
   "the sell-stop was always kept below the MA even if the correction low
   held above it." When the correction dips below the MA (common in a
   healthy Stage 2), the correction low is the binding constraint.  When
   the correction holds above the MA (shallow pullback), the MA is lower
   and becomes the reference. Either way, the stop stays below BOTH. *)
let _completed_cycle_stop ~config ~side ~stop_level ~trend_extreme
    ~correction_extreme ~ma_value ~bar =
  let had_correction =
    _is_correction ~config ~side ~trend_extreme ~correction_extreme
  in
  let recovered =
    _is_recovery ~side ~close:bar.Types.Daily_price.close_price ~trend_extreme
  in
  if had_correction && recovered then
    (* Use whichever reference is more conservative: correction low or MA *)
    let effective_ref =
      match side with
      | Long -> Float.min correction_extreme ma_value
      | Short -> Float.max correction_extreme ma_value
    in
    let candidate =
      _stop_candidate ~config ~side ~correction_extreme:effective_ref
    in
    if _is_better_stop ~side ~current:stop_level ~candidate then Some candidate
    else None
  else None

(* Build a Trailing state after a completed correction cycle.
   Both extremes reset to close_price so the next cycle starts fresh — no phantom
   cycles from a prior correction low being reused against a continuing advance. *)
let _raised_trailing ~side:_ ~new_stop ~ma_value ~correction_count ~bar =
  Trailing
    {
      stop_level = new_stop;
      last_correction_extreme = bar.Types.Daily_price.close_price;
      last_trend_extreme = bar.Types.Daily_price.close_price;
      ma_at_last_adjustment = ma_value;
      correction_count = correction_count + 1;
    }

(* Advances tracking and adjusts stop if a correction cycle completed. *)
let _raise_after_cycle ~config ~side ~ma_value ~correction_count ~stop_level
    ~last_correction_extreme ~last_trend_extreme ~ma_at_last_adjustment ~bar =
  let new_trend_extreme, new_correction_extreme =
    _advance_tracking ~side ~last_correction_extreme ~last_trend_extreme ~bar
  in
  let no_change =
    Trailing
      {
        stop_level;
        last_correction_extreme = new_correction_extreme;
        last_trend_extreme = new_trend_extreme;
        ma_at_last_adjustment;
        correction_count;
      }
  in
  match
    _completed_cycle_stop ~config ~side ~stop_level
      ~trend_extreme:last_trend_extreme
      ~correction_extreme:new_correction_extreme ~ma_value ~bar
  with
  | None -> (no_change, No_change)
  | Some new_stop ->
      let reason =
        Printf.sprintf "Correction cycle %d complete" (correction_count + 1)
      in
      let new_state =
        _raised_trailing ~side ~new_stop ~ma_value ~correction_count ~bar
      in
      ( new_state,
        Stop_raised { old_level = stop_level; new_level = new_stop; reason } )

(* ---- Update: Trailing state ---- *)

(* Apply stop/tighten/cycle logic to a fully unpacked Trailing state. *)
let _apply_trailing ~config ~side ~state ~bar ~ma_value ~stop_level
    ~last_correction_extreme ~last_trend_extreme ~ma_at_last_adjustment
    ~correction_count ~ma_direction ~stage =
  match
    _check_stop_or_tighten ~config ~side ~state ~bar
      ~correction_extreme:last_correction_extreme ~ma_direction ~stage
  with
  | Some result -> result
  | None ->
      _raise_after_cycle ~config ~side ~ma_value ~correction_count ~stop_level
        ~last_correction_extreme ~last_trend_extreme ~ma_at_last_adjustment ~bar

let _update_trailing ~config ~side ~state ~current_bar ~ma_value ~ma_direction
    ~stage =
  let bar = current_bar in
  match state with
  | Trailing
      {
        stop_level;
        last_correction_extreme;
        last_trend_extreme;
        ma_at_last_adjustment;
        correction_count;
      } ->
      _apply_trailing ~config ~side ~state ~bar ~ma_value ~stop_level
        ~last_correction_extreme ~last_trend_extreme ~ma_at_last_adjustment
        ~correction_count ~ma_direction ~stage
  | _ -> (state, No_change)

(* ---- Tightened ratchet ---- *)

(* Ratchets the tightened stop in the position's favour as new extremes are set. *)
let _ratchet_tightened ~config ~side ~stop_level ~last_correction_extreme
    ~reason ~bar =
  let extreme = _bar_extreme ~side ~bar in
  let new_extreme =
    match side with
    | Long -> Float.min last_correction_extreme extreme
    | Short -> Float.max last_correction_extreme extreme
  in
  let candidate =
    _tightened_stop_candidate ~config ~side ~correction_extreme:new_extreme
  in
  if _is_better_stop ~side ~current:stop_level ~candidate then
    let event_reason = Printf.sprintf "%s (tightened ratchet)" reason in
    ( Tightened
        {
          stop_level = candidate;
          last_correction_extreme = new_extreme;
          reason;
        },
      Stop_raised
        { old_level = stop_level; new_level = candidate; reason = event_reason }
    )
  else
    ( Tightened { stop_level; last_correction_extreme = new_extreme; reason },
      No_change )

(* ---- Update: Tightened state ---- *)

let _update_tightened ~config ~side ~state ~current_bar =
  let bar = current_bar in
  match state with
  | Tightened { stop_level; last_correction_extreme; reason } ->
      if check_stop_hit ~state ~side ~bar then
        (state, _stop_hit_event ~side ~stop_level ~bar)
      else
        _ratchet_tightened ~config ~side ~stop_level ~last_correction_extreme
          ~reason ~bar
  | _ -> (state, No_change)

(* ---- Main update dispatcher ---- *)

let update ~config ~side ~state ~current_bar ~ma_value ~ma_direction ~stage =
  match state with
  | Initial _ ->
      _update_initial ~config ~side ~state ~current_bar ~ma_value ~ma_direction
        ~stage
  | Trailing _ ->
      _update_trailing ~config ~side ~state ~current_bar ~ma_value ~ma_direction
        ~stage
  | Tightened _ -> _update_tightened ~config ~side ~state ~current_bar
