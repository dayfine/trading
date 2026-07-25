open Core
module Config = Weinstein_strategy_config
module Margin_config = Trading_portfolio.Margin_config

(* Extra weeks of MA history fetched beyond the flip-search window, so the
   [get_ma ~week_offset:(offset + slope_lookback)] read at the deepest searched
   offset stays inside the available MA depth. *)
let _flip_search_margin_weeks = 8

(* Cash-account initial-margin requirement (Reg-T 100%): the entry-walk
   requirement forced OUTSIDE a dawn week so no NEW long borrowing is initiated
   off-dawn. Distinct from the base [config.initial_long_margin_req], which the
   simulator funds fills at (see [dawn_effective_config] in the .mli for the
   permissive-funding / gated-sizing design). *)
let _cash_account_margin_req = 1.0

(* Rising test at [offset]: the stage classifier's Rising direction — the MA
   slope over [slope_lookback] weeks is at least [slope_threshold]. [None] when
   the MA is unavailable at either end of the slope window (data boundary) or the
   older anchor is non-positive (degenerate — cannot form a slope fraction). *)
let _rising_at ~get_ma ~slope_lookback ~slope_threshold ~offset =
  match
    (get_ma ~week_offset:offset, get_ma ~week_offset:(offset + slope_lookback))
  with
  | Some now, Some past when Float.( > ) past 0.0 ->
      Some (Float.( >= ) ((now -. past) /. past) slope_threshold)
  | _ -> None

(* Walk back while rising. The flip is the boundary where an older week is NOT
   rising: the first non-rising week at offset [k] means offsets [0..k-1] are
   the consecutive rising run, so the flip (first rising week) is at offset
   [k-1] = [k-1] weeks ago. Cap the search at [max_flip_age_weeks + 1]: a
   longer run means the flip predates the window (not dawn). A data boundary
   ([None]) reached before a non-rising week is inconclusive -> not dawn
   (conservative). *)
let rec _flip_search ~rising ~max_flip_age_weeks ~offset =
  if offset > max_flip_age_weeks + 1 then None
  else
    match rising offset with
    | Some true -> _flip_search ~rising ~max_flip_age_weeks ~offset:(offset + 1)
    | Some false -> Some (offset - 1)
    | None -> None

let flip_age_weeks ~get_ma ~slope_lookback ~slope_threshold ~max_flip_age_weeks
    =
  let rising offset =
    _rising_at ~get_ma ~slope_lookback ~slope_threshold ~offset
  in
  match rising 0 with
  | Some true -> _flip_search ~rising ~max_flip_age_weeks ~offset:1
  | Some false | None -> None

let is_dawn ~get_ma ~slope_lookback ~slope_threshold ~max_flip_age_weeks =
  Option.is_some
    (flip_age_weeks ~get_ma ~slope_lookback ~slope_threshold ~max_flip_age_weeks)

let effective_initial_long_margin_req ~(config : Config.config) ~dawn_active =
  if not config.dawn_leverage_enabled then config.initial_long_margin_req
  else if dawn_active then config.dawn_initial_long_margin_req
  else _cash_account_margin_req

(* Weeks of primary-index weekly history to fetch for the flip search: enough MA
   depth for offsets [0 .. max_flip_age + 1] plus the [slope_lookback] anchor and
   the [ma_period] warmup the MA kernel consumes, plus slack. *)
let _deep_n ~(stage_config : Stage.config) ~max_flip_age_weeks =
  stage_config.ma_period + max_flip_age_weeks + stage_config.slope_lookback
  + _flip_search_margin_weeks

let dawn_active ~(config : Config.config) ~bar_reader ~current_date =
  let stage_config = config.stage_config in
  let max_flip_age_weeks = config.dawn_max_ma_flip_age_weeks in
  let n = _deep_n ~stage_config ~max_flip_age_weeks in
  let weekly =
    Bar_reader.weekly_view_for bar_reader ~symbol:config.indices.primary ~n
      ~as_of:current_date
  in
  let cbs =
    Panel_callbacks.stage_callbacks_of_weekly_view ~config:stage_config ~weekly
      ()
  in
  is_dawn ~get_ma:cbs.Stage.get_ma ~slope_lookback:stage_config.slope_lookback
    ~slope_threshold:stage_config.slope_threshold ~max_flip_age_weeks

(* The armed path of [dawn_effective_config]: evaluate the signal and swap the
   requirement only when it actually changes (avoids a needless record copy). *)
let _dawn_req_config (config : Config.config) ~bar_reader ~current_date =
  let active = dawn_active ~config ~bar_reader ~current_date in
  let req = effective_initial_long_margin_req ~config ~dawn_active:active in
  if Float.equal req config.initial_long_margin_req then config
  else { config with initial_long_margin_req = req }

let dawn_effective_config (config : Config.config) ~bar_reader ~current_date =
  if not config.dawn_leverage_enabled then config
  else _dawn_req_config config ~bar_reader ~current_date

let _validate_margin_armed (config : Config.config) =
  if not config.margin_config.Margin_config.enabled then
    failwith
      "Leverage_dawn: dawn_leverage_enabled=true requires \
       margin_config.enabled=true (dawn leverage runs margin-armed)"

let _req_range_error req =
  Printf.sprintf
    "Leverage_dawn: dawn_initial_long_margin_req must be in (0.0, 1.0]; got %f"
    req

let _validate_req_in_range req =
  if Float.( <= ) req 0.0 || Float.( > ) req 1.0 then
    failwith (_req_range_error req)

let _base_gt_dawn_error ~base ~dawn =
  Printf.sprintf
    "Leverage_dawn: initial_long_margin_req (%f) must be <= \
     dawn_initial_long_margin_req (%f) so the simulator funds the dawn-week \
     levered entry instead of floor-rejecting it"
    base dawn

(* The simulator funds fills at the base [initial_long_margin_req] (permissive
   funding); the dawn-week entry walk sizes against [dawn_initial_long_margin_req].
   For a dawn-week levered entry to actually fund into [long_margin_debit], the
   base requirement must be at least as permissive (numerically <=) as the dawn
   rung — otherwise the simulator's cash-account branch floor-rejects the levered
   increment (the B1 misconfiguration). *)
let _validate_base_at_most_dawn_req (config : Config.config) =
  let base = config.initial_long_margin_req in
  let dawn = config.dawn_initial_long_margin_req in
  if Float.( > ) base dawn then failwith (_base_gt_dawn_error ~base ~dawn)

let validate (config : Config.config) =
  if config.dawn_leverage_enabled then begin
    _validate_margin_armed config;
    _validate_req_in_range config.dawn_initial_long_margin_req;
    _validate_base_at_most_dawn_req config
  end
