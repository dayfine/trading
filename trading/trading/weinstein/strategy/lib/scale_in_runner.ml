(** Scale-in add runner — wires {!Scale_in_detector} into the strategy. See
    .mli. *)

open Core
open Trading_strategy
open Weinstein_strategy_config

let add_reasoning_description = "Weinstein scale-in add (revealed strength)"

(* Fresh-entry sizing config. With scale-in enabled, initial entries commit
   [initial_entry_fraction] of the full risk unit (the explore half — plan
   §3.1); the pullback add supplies the rest. Flag off → the exact same
   record, bit-identical sizing. *)
let entry_sizing_config (config : config) =
  if not config.enable_scale_in then config.portfolio_config
  else
    {
      config.portfolio_config with
      Portfolio_risk.risk_per_trade_pct =
        config.portfolio_config.Portfolio_risk.risk_per_trade_pct
        *. config.scale_in_config.Scale_in_detector.initial_entry_fraction;
    }

(* Same admission rule as the fresh-entry walk: Bearish blocks buys
   unconditionally (the macro gate applies to ANY buy, adds included);
   Neutral admits per [neutral_blocks_longs]. *)
let _longs_admitted ~(config : config) ~macro_result_opt =
  match macro_result_opt with
  | None -> false
  | Some (r : Macro.result) -> (
      match r.trend with
      | Weinstein_types.Bearish -> false
      | Weinstein_types.Neutral -> not config.neutral_blocks_longs
      | Weinstein_types.Bullish -> true)

let _positions_by_symbol positions =
  Map.data positions
  |> List.fold
       ~init:(Map.empty (module String))
       ~f:(fun acc (p : Position.t) -> Map.add_multi acc ~key:p.symbol ~data:p)

(* The add targets a symbol whose ONLY position is a Long in [Holding] — a
   sibling already Entering (add in flight) or Exiting (stop fired) disarms
   the symbol. Returns (quantity, entry_price, entry_date). *)
let _sole_long_holding = function
  | [ (pos : Position.t) ] -> (
      match (Position.get_state pos, pos.side) with
      | Position.Holding h, Trading_base.Types.Long ->
          Some (h.quantity, h.entry_price, h.entry_date)
      | _ -> None)
  | _ -> None

(* Stage gate: only a (non-late, when required) Stage-2 holding is
   add-eligible. No recorded stage → no add. *)
let _stage_admits ~require_not_late ~prior_stages symbol =
  match Hashtbl.find prior_stages symbol with
  | Some (Weinstein_types.Stage2 { late; _ }) ->
      (not require_not_late) || not late
  | _ -> false

(* Weekly bars strictly after the entry week. Weekly bars are dated by their
   last session; anything >= 5 calendar days after the entry date is past the
   entry's own week bucket (Friday- or holiday-shortened alike). *)
let _bars_since_entry ~bar_reader ~lookback_bars ~as_of ~entry_date symbol =
  Bar_reader.weekly_bars_for bar_reader ~symbol ~n:lookback_bars ~as_of
  |> List.filter ~f:(fun (b : Types.Daily_price.t) ->
      Date.diff b.date entry_date >= 5)

(* Extension gate + trigger dispatch against one MA reading. The gate applies
   to ALL triggers uniformly; see the extension_max_pct interplay warning in
   scale_in_detector.mli. *)
let _gate_and_signal ~(sc : Scale_in_detector.config) ~ma ~close ~entry_price
    ~bars =
  (not
     (Scale_in_detector.extended_above_ma ~max_pct:sc.extension_max_pct ~close
        ~ma))
  && Scale_in_detector.add_signal ~trigger:sc.add_trigger
       ~proximity_pct:sc.pullback_proximity_pct ~consolidation:sc.consolidation
       ~ma ~entry_price ~bars_since_entry:bars

(* A real MA reading (populated by the Friday stops pass earlier in the tick)
   is required — no MA → no add. *)
let _not_extended_and_signalled ~(sc : Scale_in_detector.config)
    ~prior_stage_ma_values ~symbol ~close ~entry_price ~bars =
  match Hashtbl.find prior_stage_ma_values symbol with
  | None -> false
  | Some ma -> _gate_and_signal ~sc ~ma ~close ~entry_price ~bars

(* Size the add: the remaining risk fraction (1 - initial_entry_fraction) of a
   full unit, capped so aggregate symbol notional (existing sibling + add)
   stays within max_position_pct_long. Reuses the canonical fixed-risk sizing;
   the add does NOT touch stop_states — it rides the ticker's existing stop. *)
let _add_sizing ~(config : config) ~portfolio_value ~existing_notional
    ~entry_price ~stop_price =
  let pc = config.portfolio_config in
  let sc = config.scale_in_config in
  let add_fraction =
    match sc.Scale_in_detector.add_fraction with
    | Some f -> Float.max 0.0 f
    | None -> Float.max 0.0 (1.0 -. sc.initial_entry_fraction)
  in
  let cap_left =
    Float.max 0.0
      (pc.Portfolio_risk.max_position_pct_long
      -. (existing_notional /. portfolio_value))
  in
  let sizing_config =
    {
      pc with
      Portfolio_risk.risk_per_trade_pct =
        pc.Portfolio_risk.risk_per_trade_pct *. add_fraction;
      max_position_pct_long = cap_left;
    }
  in
  Portfolio_risk.compute_position_size ~config:sizing_config ~portfolio_value
    ~side:`Long ~entry_price ~stop_price ()

let _add_transition ~symbol ~shares ~entry_price ~current_date :
    Position.transition =
  let kind =
    Position.CreateEntering
      {
        symbol;
        side = Trading_base.Types.Long;
        target_quantity = Float.of_int shares;
        entry_price;
        reasoning =
          Position.ManualDecision { description = add_reasoning_description };
      }
  in
  {
    Position.position_id = Entry_audit_capture.gen_position_id symbol;
    date = current_date;
    kind;
  }

(* The revealed-strength signal + the not-late / not-extended gates for one
   sole-Holding long. *)
let _signal_and_gates ~(config : config) ~bar_reader ~prior_stages
    ~prior_stage_ma_values ~current_date ~symbol ~entry_price ~entry_date ~close
    =
  let sc = config.scale_in_config in
  let bars =
    _bars_since_entry ~bar_reader ~lookback_bars:config.lookback_bars
      ~as_of:current_date ~entry_date symbol
  in
  _stage_admits ~require_not_late:sc.require_not_late ~prior_stages symbol
  && _not_extended_and_signalled ~sc ~prior_stage_ma_values ~symbol ~close
       ~entry_price ~bars

(* Size a signalled add and build its transition; [None] when sizing collapses
   to zero shares (risk fraction, remaining per-name cap, or price). *)
let _sized_add ~config ~portfolio_value ~quantity ~close ~stop_price ~symbol
    ~current_date =
  let sizing =
    _add_sizing ~config ~portfolio_value ~existing_notional:(quantity *. close)
      ~entry_price:close ~stop_price
  in
  if sizing.Portfolio_risk.shares <= 0 then None
  else
    Some
      ( _add_transition ~symbol ~shares:sizing.shares ~entry_price:close
          ~current_date,
        Float.of_int sizing.shares *. close )

(* Evaluate one symbol: gates + signal + sizing. Returns the add transition
   with its cash cost, or [None] when anything blocks. *)
let _eval_symbol ~(config : config) ~bar_reader ~get_price ~prior_stages
    ~prior_stage_ma_values ~stop_states ~portfolio_value ~current_date
    (symbol, (quantity, entry_price, entry_date)) =
  let open Option.Let_syntax in
  let%bind bar = get_price symbol in
  let close = bar.Types.Daily_price.close_price in
  let%bind stop_state = Map.find !stop_states symbol in
  let stop_price = Weinstein_stops.get_stop_level stop_state in
  let signal =
    Float.( < ) stop_price close
    && _signal_and_gates ~config ~bar_reader ~prior_stages
         ~prior_stage_ma_values ~current_date ~symbol ~entry_price ~entry_date
         ~close
  in
  if not signal then None
  else
    _sized_add ~config ~portfolio_value ~quantity ~close ~stop_price ~symbol
      ~current_date

(* Symbols whose sole Long Holding hasn't used up its adds. *)
let _add_candidates ~(config : config) ~positions ~scale_in_added =
  let sc = config.scale_in_config in
  _positions_by_symbol positions
  |> Map.to_alist
  |> List.filter_map ~f:(fun (symbol, ps) ->
      let adds_done =
        Hashtbl.find scale_in_added symbol |> Option.value ~default:0
      in
      if adds_done >= sc.max_adds then None
      else _sole_long_holding ps |> Option.map ~f:(fun h -> (symbol, h)))

(* Cash-gate the evaluated adds in symbol order (deterministic), deducting
   each accepted add's cost. Marks accepted symbols in [scale_in_added] at
   EMIT time — conservative: a cancelled/unfilled add still consumes the
   symbol's add budget (fails toward fewer adds, never more). *)
let _fund_adds ~cash ~scale_in_added evaluated =
  let remaining = ref cash in
  let take (symbol, (trans, cost)) =
    if Float.( <= ) cost !remaining then (
      remaining := !remaining -. cost;
      Hashtbl.incr scale_in_added symbol;
      Some trans)
    else None
  in
  let transitions = List.filter_map evaluated ~f:take in
  (transitions, cash -. !remaining)

(* Evaluate every add-candidate symbol, tagging each surviving add with its
   symbol for [_fund_adds]' bookkeeping. *)
let _evaluated_adds ~config ~positions ~scale_in_added ~bar_reader ~get_price
    ~prior_stages ~prior_stage_ma_values ~stop_states ~portfolio_value
    ~current_date =
  let eval (symbol, h) =
    _eval_symbol ~config ~bar_reader ~get_price ~prior_stages
      ~prior_stage_ma_values ~stop_states ~portfolio_value ~current_date
      (symbol, h)
    |> Option.map ~f:(fun r -> (symbol, r))
  in
  _add_candidates ~config ~positions ~scale_in_added |> List.filter_map ~f:eval

let run ~(config : config) ~positions ~(portfolio : Portfolio_view.t) ~get_price
    ~bar_reader ~prior_stages ~prior_stage_ma_values ~stop_states
    ~scale_in_added ~macro_result_opt ~is_screening_day ~halted ~current_date =
  if
    (not config.enable_scale_in)
    || (not is_screening_day) || halted
    || not (_longs_admitted ~config ~macro_result_opt)
  then ([], 0.0)
  else
    let portfolio_value = Portfolio_view.portfolio_value portfolio ~get_price in
    let evaluated =
      _evaluated_adds ~config ~positions ~scale_in_added ~bar_reader ~get_price
        ~prior_stages ~prior_stage_ma_values ~stop_states ~portfolio_value
        ~current_date
    in
    _fund_adds ~cash:portfolio.Portfolio_view.cash ~scale_in_added evaluated
