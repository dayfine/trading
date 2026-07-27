open Core

type outcome =
  | Holding of Stop_track.t
  | Triggered of {
      track : Stop_track.t;
      week : Date.t;
      close : float;
      stop_level : float;
    }
[@@deriving show, eq]

(* The live held book is long-only, as [Held_position_row] and
   [Stop_recompute.for_held_long] already assume. *)
let _side = Trading_base.Types.Long

let seed ~stops_config ~initial_stop_buffer ~entry_price ~working_stop
    ~daily_bars ~as_of =
  let state =
    Weinstein_stops.compute_initial_stop_with_floor ~config:stops_config
      ~side:_side ~entry_price ~bars:daily_bars ~as_of
      ~fallback_buffer:initial_stop_buffer
  in
  let track = { Stop_track.state; updated = as_of; raises = 0 } in
  (* Never seed below the stop actually resting at the broker: a long-held
     position's working stop can sit well above any floor derivable from its
     original base. *)
  Option.value (Stop_track.ratchet track ~to_:working_stop) ~default:track

(* See the .mli: the bars replayed here are WEEKLY, so the config's default
   intra-bar trigger would fire on an intra-week wick. Weinstein's rule is a
   weekly CLOSE below the stop. *)
let _weekly_close_config (config : Weinstein_stops.config) =
  { config with Weinstein_stops.trigger_on_weekly_close = true }

(* Advance the track by exactly one week and classify what happened. Only
   [Stop_raised] increments the ratchet history — [Entered_tightening] changes
   the state arm without moving the stop, and [No_change] moves nothing. *)
let _step ~config ~(track : Stop_track.t) ~(bar : Types.Daily_price.t)
    ~(cls : Stage.result) =
  let state, event =
    Weinstein_stops.update ~config ~side:_side ~state:track.state
      ~current_bar:bar ~ma_value:cls.ma_value ~ma_direction:cls.ma_direction
      ~stage:cls.stage
  in
  let raises =
    match event with
    | Weinstein_stops.Stop_raised _ -> track.raises + 1
    | Stop_hit _ | Entered_tightening _ | No_change -> track.raises
  in
  let week = bar.date in
  let track = { Stop_track.state; updated = week; raises } in
  match event with
  | Weinstein_stops.Stop_hit { trigger_price; stop_level } ->
      Triggered { track; week; close = trigger_price; stop_level }
  | Stop_raised _ | Entered_tightening _ | No_change -> Holding track

(* One week of the walk: classify the stage on the prefix ending at this bar,
   then replay it if it postdates the track. Weeks at or before [track.updated]
   are context for the MA and the chained stage, not replayed — that is what
   makes a re-run idempotent. Returns this week's stage so the next iteration
   can thread it as [prior_stage], the way the generator's own chained-stage
   reconstruction does. *)
let _week ~config ~stage_config ~prior_stage ~(track : Stop_track.t) ~prefix
    ~(bar : Types.Daily_price.t) =
  let cls = Stage.classify ~config:stage_config ~bars:prefix ~prior_stage in
  let outcome =
    if Date.( <= ) bar.date track.updated then Holding track
    else _step ~config ~track ~bar ~cls
  in
  (Some cls.stage, outcome)

let rec _walk ~config ~stage_config ~prefix_rev ~prior_stage ~track = function
  | [] -> Holding track
  | bar :: rest -> (
      let prefix_rev = bar :: prefix_rev in
      let prior_stage, outcome =
        _week ~config ~stage_config ~prior_stage ~track
          ~prefix:(List.rev prefix_rev) ~bar
      in
      match outcome with
      | Triggered _ -> outcome
      | Holding track ->
          _walk ~config ~stage_config ~prefix_rev ~prior_stage ~track rest)

let advance ~stops_config ~stage_config ~weekly_bars ~prior =
  _walk
    ~config:(_weekly_close_config stops_config)
    ~stage_config ~prefix_rev:[] ~prior_stage:None ~track:prior weekly_bars
