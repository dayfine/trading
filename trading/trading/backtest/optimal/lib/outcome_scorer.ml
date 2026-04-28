(** Phase B scorer for the optimal-strategy counterfactual.

    See [outcome_scorer.mli] for the API contract. *)

open Core

type weekly_outlook = {
  date : Core.Date.t;
  bar : Types.Daily_price.t;
  stage_result : Stage.result;
}

type config = {
  stops_config : Weinstein_stops.config;
  stage3_confirm_weeks : int;
}

let default_config : config =
  { stops_config = Weinstein_stops.default_config; stage3_confirm_weeks = 2 }

(** Validate the candidate is well-formed enough to score. *)
let _candidate_valid (c : Optimal_types.candidate_entry) : bool =
  Float.is_finite c.entry_price
  && Float.(c.entry_price > 0.0)
  && Float.is_finite c.suggested_stop
  && Float.(c.suggested_stop > 0.0)

(** Seed the trailing-stop state machine from the candidate's suggested stop.
    Mirrors {!Weinstein_stops.compute_initial_stop} in shape — both [stop_level]
    and [reference_level] are set to [suggested_stop], because the
    counterfactual treats [suggested_stop] as the cleanest available initial
    stop (per plan §What the counterfactual ignores). *)
let _seed_state (c : Optimal_types.candidate_entry) : Weinstein_stops.stop_state
    =
  Initial { stop_level = c.suggested_stop; reference_level = c.suggested_stop }

(** Whether the stage classifier reports Stage 3 at this outlook. *)
let _is_stage3 (outlook : weekly_outlook) : bool =
  match outlook.stage_result.stage with
  | Weinstein_types.Stage3 _ -> true
  | _ -> false

(** Build the {!Optimal_types.scored_candidate} from raw exit fields, computing
    [hold_weeks], [raw_return_pct], [initial_risk_per_share], and [r_multiple]
    in one place. *)
let _build_scored ~(candidate : Optimal_types.candidate_entry)
    ~(exit_outlook : weekly_outlook)
    ~(exit_trigger : Optimal_types.exit_trigger) :
    Optimal_types.scored_candidate =
  let exit_price = exit_outlook.bar.close_price in
  let raw_return_pct =
    match candidate.side with
    | Trading_base.Types.Long ->
        (exit_price -. candidate.entry_price) /. candidate.entry_price
    | Short -> (candidate.entry_price -. exit_price) /. candidate.entry_price
  in
  let hold_weeks = Date.diff exit_outlook.date candidate.entry_week / 7 in
  let initial_risk_per_share =
    Float.abs (candidate.entry_price -. candidate.suggested_stop)
  in
  let r_multiple =
    if Float.(initial_risk_per_share <= 0.0) then 0.0
    else
      let signed_pnl_per_share =
        match candidate.side with
        | Long -> exit_price -. candidate.entry_price
        | Short -> candidate.entry_price -. exit_price
      in
      signed_pnl_per_share /. initial_risk_per_share
  in
  {
    entry = candidate;
    exit_week = exit_outlook.date;
    exit_price;
    exit_trigger;
    raw_return_pct;
    hold_weeks;
    initial_risk_per_share;
    r_multiple;
  }

type _walk_state = {
  stop_state : Weinstein_stops.stop_state;
  stage3_streak_start : (Core.Date.t * weekly_outlook) option;
  stage3_streak_len : int;
}
(** Per-step state during the forward walk. [stage3_streak_start] is [Some f]
    when the previous outlook was Stage 3 and [f] is the Friday on which the
    Stage-3 streak began. The exit week of a Stage-3 transition is [f] (the
    earliest signal), not the streak's confirmation week. *)

(** Process a single weekly outlook, returning either an exit decision or the
    advanced walk state. Splits the per-step logic out of the recursive walker
    so each path stays under the function-length budget. *)
let _step ~(config : config) ~(side : Trading_base.Types.position_side)
    ~(state : _walk_state) ~(outlook : weekly_outlook) :
    [ `Exit of weekly_outlook * Optimal_types.exit_trigger
    | `Continue of _walk_state ] =
  let new_stop_state, stop_event =
    Weinstein_stops.update ~config:config.stops_config ~side
      ~state:state.stop_state ~current_bar:outlook.bar
      ~ma_value:outlook.stage_result.ma_value
      ~ma_direction:outlook.stage_result.ma_direction
      ~stage:outlook.stage_result.stage
  in
  let stop_hit = match stop_event with Stop_hit _ -> true | _ -> false in
  if stop_hit then `Exit (outlook, Optimal_types.Stop_hit)
  else
    let stage3 = _is_stage3 outlook in
    let new_streak_start, new_streak_len, exit_anchor =
      match (stage3, state.stage3_streak_start) with
      | true, None -> (Some (outlook.date, outlook), 1, outlook)
      | true, Some (start_date, start_outlook) ->
          ( Some (start_date, start_outlook),
            state.stage3_streak_len + 1,
            start_outlook )
      | false, _ -> (None, 0, outlook)
    in
    if stage3 && new_streak_len >= config.stage3_confirm_weeks then
      `Exit (exit_anchor, Optimal_types.Stage3_transition)
    else
      `Continue
        {
          stop_state = new_stop_state;
          stage3_streak_start = new_streak_start;
          stage3_streak_len = new_streak_len;
        }

(** Walk [forward] week by week. Returns the chosen [(exit_outlook, trigger)]
    pair, or [None] when the walk runs to the end without firing — caller
    handles the End_of_run case. *)
let rec _walk ~config ~side ~state ~forward :
    (weekly_outlook * Optimal_types.exit_trigger) option =
  match forward with
  | [] -> None
  | outlook :: rest -> (
      match _step ~config ~side ~state ~outlook with
      | `Exit (out, trigger) -> Some (out, trigger)
      | `Continue new_state ->
          _walk ~config ~side ~state:new_state ~forward:rest)

let score ~config ~(candidate : Optimal_types.candidate_entry)
    ~(forward : weekly_outlook list) : Optimal_types.scored_candidate option =
  if not (_candidate_valid candidate) then None
  else
    match forward with
    | [] -> None
    | _ ->
        let initial_state =
          {
            stop_state = _seed_state candidate;
            stage3_streak_start = None;
            stage3_streak_len = 0;
          }
        in
        let exit_outlook, exit_trigger =
          match
            _walk ~config ~side:candidate.side ~state:initial_state ~forward
          with
          | Some chosen -> chosen
          | None ->
              (* End of run: exit at the last forward outlook. *)
              let last = List.last_exn forward in
              (last, Optimal_types.End_of_run)
        in
        Some (_build_scored ~candidate ~exit_outlook ~exit_trigger)
