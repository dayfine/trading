open Core
open Friday_trace_format
module WS_config = Weinstein_strategy.Weinstein_strategy_config

(* The strategy default for the same universe and index: what a quoted value is
   compared with to say whether the demo changed it. *)
let _default_of (c : WS_config.config) =
  WS_config.default_config ~universe:c.universe ~index_symbol:c.indices.primary

let _int_setting ~default value =
  setting ~show:Int.to_string ~equal:Int.equal ~default value

let _on_off on = if on then "on" else "off"
let _or_off ~on text = if on then text else text ^ " (off)"

(* ------------------------------------------------------------------ *)
(* Stages 2 and 3                                                       *)
(* ------------------------------------------------------------------ *)

let stage_classification (sc : Stage.config) =
  [
    sprintf
      "places each stock in Stage 1-4 by its close against the %d-week moving \
       average (MA)."
      sc.ma_period;
    sprintf
      "Stage 2: the MA rising (up over %s in %d weeks) and the close above it \
       in most of the last %d weeks."
      (pct sc.slope_threshold) sc.slope_lookback sc.confirm_weeks;
    "Stage 4: the MA falling and the close mostly below it.";
    "With a flat MA the stage is decided by last week's: Stage 1 after a base \
     or a decline, Stage 3 after an advance.";
  ]

let _blocks_text blocks = if blocks then "blocks" else "allows"

let macro_gate (c : WS_config.config) =
  [
    "reads the market as a whole from weighted indicators. The confidence is \
     the Bullish share of the weight of the indicators that are not Neutral.";
    sprintf
      "A Bearish market blocks new buys and a Bullish one blocks new shorts; a \
       Neutral one %s new buys and %s new shorts."
      (_blocks_text c.neutral_blocks_longs)
      (_blocks_text c.neutral_blocks_shorts);
  ]

(* ------------------------------------------------------------------ *)
(* Stages 5 and 6                                                       *)
(* ------------------------------------------------------------------ *)

(* The ways a stock passes stage setup
   ([Stock_analysis.breakout_candidate_rejection]'s arms), each listed only
   when the config arms it. *)
let _stage_setup_arms (c : WS_config.config) =
  [
    Some
      (sprintf "a Stage 1 to 2 transition, or Stage 2 for at most %d weeks"
         c.screening_config.early_stage2_max_weeks);
    Option.some_if c.enable_continuation_buys
      "a continuation buy setup inside Stage 2";
    Option.some_if c.virgin_crossing_readmission
      "Stage 2 at any age when the breakout reaches new high ground (above \
       every weekly high of the last 10 years, or with no overhead supply in \
       the last 130 weeks)";
  ]
  |> List.filter_opt |> String.concat ~sep:"; or "

let _price_floor_rule (sc : Screener.config) =
  if Float.(sc.min_price > 0.0) then
    sprintf "price floor: at least %s" (money sc.min_price)
  else "price floor (off)"

(* One paragraph per rule, in [Screener_admission._long_breakout_gate]'s
   order. *)
let breakout_cascade (c : WS_config.config) =
  let sc = c.screening_config in
  [
    "checks each analysed stock against the buy rules in order; the first rule \
     it fails is where it stops. Long rules:";
    _price_floor_rule sc;
    "-> stage setup: " ^ _stage_setup_arms c;
    sprintf "-> breakout volume: at least %.1fx the prior %d weeks"
      Volume.default_config.adequate_threshold
      Volume.default_config.lookback_bars;
    "-> RS not declining";
    "-> "
    ^ _or_off
        ~on:Float.(sc.failed_breakout_tolerance_pct > 0.0)
        "failed breakout";
    "-> "
    ^ _or_off ~on:(Option.is_some sc.volume_ratio_exclude_range) "volume band";
  ]

let scoring (sc : Screener.config) =
  let g = sc.grade_thresholds in
  [
    "adds up points for each signal a breakout carries, and grades the total:";
    sprintf
      "A+ >= %d, A >= %d, B >= %d, C >= %d, D >= %d. The lowest grade bought \
       is %s."
      g.a_plus g.a g.b g.c g.d
      (Weinstein_types.grade_to_string sc.min_grade);
  ]

(* ------------------------------------------------------------------ *)
(* Stage 7                                                              *)
(* ------------------------------------------------------------------ *)

let _tiebreak_text (sc : Screener.config) ~(default : Screener.config) ~date =
  match sc.candidate_ranking with
  | Seeded | Price_band_seeded ->
      sprintf
        "a hash of the ticker and the date (%s) seeded with %s, smallest first"
        (Date.to_string date)
        (_int_setting ~default:default.tiebreak_seed sc.tiebreak_seed)
  | other ->
      sprintf "the %s rule"
        (Sexp.to_string (Screener.sexp_of_candidate_ranking other))

let ranking (c : WS_config.config) ~date =
  let sc = c.screening_config and default = (_default_of c).screening_config in
  [
    sprintf
      "orders the graded stocks by score, highest first. Equal scores go by %s."
      (_tiebreak_text sc ~default ~date);
    "Only the top names on each side go on to the entry walk:";
    sprintf "longs: max_buy_candidates = %s"
      (_int_setting ~default:default.max_buy_candidates sc.max_buy_candidates);
    sprintf "shorts: max_short_candidates = %s"
      (_int_setting ~default:default.max_short_candidates
         sc.max_short_candidates);
  ]

(* ------------------------------------------------------------------ *)
(* Stages 8 and 9                                                       *)
(* ------------------------------------------------------------------ *)

let _trigger_basis (c : WS_config.config) =
  if c.sim_entry_trigger_at_suggested && c.enable_sim_entry_stoplimit then
    "the breakout level"
  else "the last close"

(* Which bar field the support-floor scan reads its peak and low from. *)
let _floor_fields : Weinstein_stops.Support_floor.anchor_mode -> string * string
    = function
  | Wick -> ("high", "low")
  | Close -> ("close", "close")

(* The correction low the initial stop goes under, as
   [Support_floor.find_recent_level_with_callbacks] finds it for a long. *)
let _floor_rule (sc : Weinstein_stops.config) =
  let high, low = _floor_fields sc.support_floor_anchor_mode in
  let depth = pct sc.min_correction_pct in
  match sc.support_floor_anchor_scope with
  | Window_extreme ->
      sprintf
        "the lowest %s since the highest %s of the last %d trading days, when \
         that %s is %s or more below that %s"
        low high sc.support_floor_lookback_bars low depth high
  | Nearest ->
      sprintf
        "the %s of the most recent pullback of %s or more within the last %d \
         trading days"
        low depth sc.support_floor_lookback_bars

(* [Floor_stop.compute_initial_stop]: half the correction depth under the
   reference level, the floor or (fallback) the trigger times the buffer, then
   [Stop_nudge.nudge_round_number]. *)
let _stop_rule (sc : Weinstein_stops.config) ~initial_stop_buffer =
  let half_depth = sc.min_correction_pct /. 2.0 in
  sprintf
    "Initial stop: %s (half of %s) under %s. With no such %s it is a fallback \
     stop, %s under the trigger. A stop at or up to $%g above a half-dollar is \
     moved to $%g below it."
    (pct half_depth)
    (pct sc.min_correction_pct)
    (_floor_rule sc)
    (snd (_floor_fields sc.support_floor_anchor_mode))
    (pct (1.0 -. (initial_stop_buffer *. (1.0 -. half_depth))))
    sc.round_number_nudge sc.round_number_nudge

(* Book 5.1's width rule, and the investor preset's refusal of a fallback
   stop when [require_structural_stop] is on. *)
let _skip_rule (c : WS_config.config) =
  let width =
    sprintf "Skipped: a stop more than %s below the trigger (book 5.1)"
      (pct c.stops_config.max_stop_distance_pct)
  in
  if c.require_structural_stop then
    sprintf
      "%s, and a fallback stop, since require_structural_stop is %s, as in the \
       investor preset."
      width
      (setting ~show:_on_off ~equal:Bool.equal
         ~default:(_default_of c).require_structural_stop
         c.require_structural_stop)
  else width ^ "."

(* [Portfolio_risk.compute_position_size], then the walk's cash check. *)
let _sizing_rule (pc : Portfolio_risk.config) =
  sprintf
    "Shares: as many as put %s of the portfolio at risk between trigger and \
     stop, but at most %s of the portfolio in one long name (%s in one short); \
     a name that costs more than the cash left is skipped."
    (pct pc.risk_per_trade_pct)
    (pct (Float.min pc.max_long_exposure_pct pc.max_position_pct_long))
    (pct (Float.min pc.max_short_exposure_pct pc.max_position_pct_short))

let entry_walk (c : WS_config.config) ~initial_stop_buffer =
  [
    sprintf "takes the names above the cut in rank order. The trigger is %s."
      (_trigger_basis c);
    _stop_rule c.stops_config ~initial_stop_buffer;
    _skip_rule c;
    _sizing_rule c.portfolio_config;
  ]

(* The entry order shape the simulator works, as
   [Backtest.Execution_faithfulness.entry_order_kind_of_config] reads it. *)
let _ticket_text (c : WS_config.config) =
  if c.enable_sim_entry_stoplimit && Float.(c.entry_extension_max_pct > 0.0)
  then
    sprintf
      "one stop-limit entry ticket per placed name, for its shares. It \
       triggers at the trigger price and does not fill more than %.1f%% past \
       it."
      c.entry_extension_max_pct
  else "one market entry order per placed name, for its shares."

let orders (c : WS_config.config) =
  [
    "puts out the day's orders: " ^ _ticket_text c;
    "Once filled, the position starts under its initial stop.";
  ]
