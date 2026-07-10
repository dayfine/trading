(** Breaker SPY sleeve — see [breaker_spy_strategy.mli]. *)

open Core
open Trading_strategy

type config = { symbol : string; breaker : Index_circuit_breaker.config }

let name = "BreakerSpySleeve"
let default_symbol = "SPY"

let default_config =
  { symbol = default_symbol; breaker = Index_circuit_breaker.default_config }

(* Overnight gap buffer for all-cash sizing, identical in spirit to
   [Bah_benchmark_strategy._entry_gap_buffer_pct]: size against
   [close * (1 + buffer)] so a small gap-up between today's sizing close and
   tomorrow's fill open does not bust the cash budget and stall the entry. *)
let _entry_gap_buffer_pct = 0.01

(* Weekly bars fed to the breaker step. Comfortably covers the breaker's widest
   window (52-week floor peak / trailing high) plus the ~60 weeks the 30-week
   stage MA in [Macro.analyze] wants to warm up, with margin. The breaker windows
   its own lookbacks internally, so surplus history is harmless. *)
let _breaker_lookback_weeks = 130

let _position_id_of_symbol (symbol : string) : string =
  Printf.sprintf "%s-breaker-spy-sleeve" symbol

let _is_weekly_close ~(date : Date.t) : bool =
  Date.day_of_week date |> Day_of_week.equal Day_of_week.Fri

(* All-cash sizing: whole shares affordable at [close_price] with the gap buffer
   applied. [None] when the cash cannot buy a single share or inputs are
   non-positive. *)
let _shares_from_cash ~(cash : float) ~(close_price : float) : float option =
  if Float.(cash <= 0.0) || Float.(close_price <= 0.0) then None
  else
    let sizing_price = close_price *. (1.0 +. _entry_gap_buffer_pct) in
    let shares = Float.round_down (cash /. sizing_price) in
    Option.some_if Float.(shares > 0.0) shares

(* Where the portfolio stands for our symbol, collapsed to the three cases the
   sleeve acts on. [In_transition] (an [Entering] awaiting fill or an [Exiting]
   awaiting close) means "do nothing this tick" so we neither double-enter nor
   double-exit. *)
type _pos_status = Holding of Position.t | In_transition | Flat

(* The strategy's single live (non-[Closed]) position for [symbol], if any. *)
let _live_position ~(symbol : string) ~(positions : Position.t String.Map.t) :
    Position.t option =
  Map.data positions
  |> List.find ~f:(fun (p : Position.t) ->
      String.equal p.symbol symbol
      &&
      match p.state with
      | Position.Entering _ | Position.Holding _ | Position.Exiting _ -> true
      | Position.Closed _ -> false)

let _classify_position ~(symbol : string) ~(positions : Position.t String.Map.t)
    : _pos_status =
  match _live_position ~symbol ~positions with
  | None -> Flat
  | Some pos -> (
      match pos.state with
      | Position.Holding _ -> Holding pos
      | Position.Entering _ | Position.Exiting _ -> In_transition
      | Position.Closed _ -> Flat)

(* --- transition builders (long-only; correct breaker reasoning) ------------ *)

let _entry_reasoning : Position.entry_reasoning =
  ManualDecision
    {
      description = "Breaker SPY sleeve: default-in-market buy-and-hold deploy";
    }

let _build_entry ~(position_id : string) ~(symbol : string)
    ~(bar : Types.Daily_price.t) ~(target_quantity : float) :
    Position.transition =
  let kind : Position.transition_kind =
    CreateEntering
      {
        symbol;
        side = Long;
        target_quantity;
        entry_price = bar.close_price;
        reasoning = _entry_reasoning;
      }
  in
  { Position.position_id; date = bar.date; kind }

(* Label the exit by which breaker trigger fired, so the trade audit distinguishes
   the slow structural exit from the fast tail-insurance exits. *)
let _exit_label_of_reason (reason : Index_circuit_breaker.exit_reason) : string
    =
  match reason with
  | Index_circuit_breaker.Fast_crash -> "breaker_fast_crash"
  | Index_circuit_breaker.Slow_grind -> "breaker_slow_grind"
  | Index_circuit_breaker.Absolute_floor -> "breaker_absolute_floor"

let _build_exit ~(pos : Position.t) ~(bar : Types.Daily_price.t)
    ~(reason : Index_circuit_breaker.exit_reason) : Position.transition =
  let exit_reason : Position.exit_reason =
    StrategySignal
      { label = _exit_label_of_reason reason; detail = Some "breaker" }
  in
  let kind : Position.transition_kind =
    TriggerExit { exit_reason; exit_price = bar.close_price }
  in
  { Position.position_id = pos.id; date = bar.date; kind }

(* At most one all-cash entry for [bar], or none when the cash cannot afford a
   whole share. *)
let _entry_transitions ~(config : config) ~(cash : float)
    ~(bar : Types.Daily_price.t) : Position.transition list =
  match _shares_from_cash ~cash ~close_price:bar.close_price with
  | None -> []
  | Some target_quantity ->
      [
        _build_entry
          ~position_id:(_position_id_of_symbol config.symbol)
          ~symbol:config.symbol ~bar ~target_quantity;
      ]

(* Deploy cash into the symbol when flat and the breaker wants to be in market —
   the default-in-market property (runs every day, independent of the step). *)
let _deploy_if_flat ~(config : config) ~(state : Index_circuit_breaker.state)
    ~(pos_status : _pos_status) ~(cash : float) ~(bar : Types.Daily_price.t) :
    Position.transition list =
  match (pos_status, state) with
  | Flat, Index_circuit_breaker.In_market _ ->
      _entry_transitions ~config ~cash ~bar
  | Flat, Index_circuit_breaker.Out_of_market _ | (Holding _ | In_transition), _
    ->
      []

(* --- breaker step wiring --------------------------------------------------- *)

(* Weekly index view for the breaker: the symbol's own weekly-aggregated bars up
   to [as_of], oldest-first. *)
let _weekly_index_bars ~(config : config) ~(bar_reader : Bar_reader.t)
    ~(as_of : Date.t) : Types.Daily_price.t list =
  Bar_reader.weekly_bars_for bar_reader ~symbol:config.symbol
    ~n:_breaker_lookback_weeks ~as_of

(* The macro read the breaker's decline-character consumes. Single-instrument
   degradation: empty A-D / global inputs leave the A-D indicator [`Neutral]
   ("no breadth lead", per [Decline_character.classify]). [Macro.default_config]
   is reused verbatim — it adds no tunable of ours; the breaker's own thresholds
   live in [config.breaker]. [prior_macro] threads last week's result for
   [Macro.analyze]'s prior / prior_stage arguments and is advanced here. *)
let _macro ~(prior_macro : Macro.result option ref)
    ~(index_bars : Types.Daily_price.t list) : Macro.result =
  let prior_stage =
    Option.map !prior_macro ~f:(fun (m : Macro.result) -> m.index_stage.stage)
  in
  let result =
    Macro.analyze ~config:Macro.default_config ~index_bars ~ad_bars:[]
      ~global_index_bars:[] ~prior_stage ~prior:!prior_macro
  in
  prior_macro := Some result;
  result

(* Turn the (new state, action) the breaker returned into at most one transition,
   given where the portfolio stands. Exit sells a held position; Re_enter buys
   when flat; otherwise fall through to the default-in-market deploy (which is
   also what realizes the very first buy on a Hold-into-In_market Friday). *)
let _act_on ~(config : config) ~(state : Index_circuit_breaker.state)
    ~(action : Index_circuit_breaker.action) ~(pos_status : _pos_status)
    ~(cash : float) ~(bar : Types.Daily_price.t) : Position.transition list =
  match (action, pos_status) with
  | Index_circuit_breaker.Exit reason, Holding pos ->
      [ _build_exit ~pos ~bar ~reason ]
  | Index_circuit_breaker.Re_enter, Flat ->
      _entry_transitions ~config ~cash ~bar
  | (Index_circuit_breaker.Exit _ | Re_enter | Hold), _ ->
      _deploy_if_flat ~config ~state ~pos_status ~cash ~bar

(* Friday: advance the breaker one step against this week's index view + macro,
   persist the new state, and act on the returned action. *)
let _friday_transitions ~(config : config) ~(bar_reader : Bar_reader.t)
    ~(breaker_state : Index_circuit_breaker.state ref)
    ~(prior_macro : Macro.result option ref) ~(pos_status : _pos_status)
    ~(cash : float) ~(bar : Types.Daily_price.t) : Position.transition list =
  let index_bars = _weekly_index_bars ~config ~bar_reader ~as_of:bar.date in
  let ad_macro = _macro ~prior_macro ~index_bars in
  let new_state, action =
    Index_circuit_breaker.step ~config:config.breaker ~state:!breaker_state
      ~index_bars ~ad_macro
  in
  breaker_state := new_state;
  _act_on ~config ~state:new_state ~action ~pos_status ~cash ~bar

let _transitions_for_bar ~(config : config) ~(bar_reader : Bar_reader.t)
    ~(breaker_state : Index_circuit_breaker.state ref)
    ~(prior_macro : Macro.result option ref) ~(portfolio : Portfolio_view.t)
    ~(bar : Types.Daily_price.t) : Position.transition list =
  let pos_status =
    _classify_position ~symbol:config.symbol ~positions:portfolio.positions
  in
  if _is_weekly_close ~date:bar.date then
    _friday_transitions ~config ~bar_reader ~breaker_state ~prior_macro
      ~pos_status ~cash:portfolio.cash ~bar
  else
    (* Mid-week: no breaker evaluation; only the default-in-market deploy runs,
       carrying the last Friday's state. *)
    _deploy_if_flat ~config ~state:!breaker_state ~pos_status
      ~cash:portfolio.cash ~bar

let _on_market_close config ~bar_reader ~breaker_state ~prior_macro ~get_price
    ~get_indicator:_ ~(portfolio : Portfolio_view.t) =
  let transitions =
    match get_price config.symbol with
    | None -> []
    | Some bar ->
        _transitions_for_bar ~config ~bar_reader ~breaker_state ~prior_macro
          ~portfolio ~bar
  in
  Result.return { Strategy_interface.transitions }

let make ?(config = default_config) ~bar_reader () :
    (module Strategy_interface.STRATEGY) =
  let breaker_state : Index_circuit_breaker.state ref =
    ref Index_circuit_breaker.in_market
  in
  let prior_macro : Macro.result option ref = ref None in
  let module M = struct
    let on_market_close =
      _on_market_close config ~bar_reader ~breaker_state ~prior_macro

    let name = name
  end in
  (module M : Strategy_interface.STRATEGY)
