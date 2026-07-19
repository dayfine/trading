open Core
module Margin_config = Trading_portfolio.Margin_config
module Portfolio = Trading_portfolio.Portfolio
module Portfolio_margin = Trading_portfolio.Portfolio_margin
module Position = Trading_strategy.Position

(* Forensic detail string emitted on margin_call exit transitions. Kept
   ASCII-only + key=value so simple parsers (trades.csv readers, audit
   reports) can extract fields without OCaml-side helpers. *)
let _margin_call_detail ~entry_avg_cost ~current_price =
  Printf.sprintf "entry_avg_cost=%.6f current_price=%.6f" entry_avg_cost
    current_price

let mark_prices (today_bars : Trading_engine.Types.price_bar list) :
    (string * float) list =
  List.map today_bars ~f:(fun bar ->
      (bar.Trading_engine.Types.symbol, bar.Trading_engine.Types.close_price))

let accrue_borrow_fee ~(margin_config : Margin_config.t) ~portfolio ~prices =
  Portfolio_margin.accrue_daily_borrow_fee ~margin_config portfolio prices

(* Capitalize one trading day of long-margin interest onto the outstanding
   [long_margin_debit] (margin M1b-2). No-op at the default rate (0.0) or with no
   debit, so cash accounts / long-only baselines stay bit-equal. Gated by the
   rate rather than [margin_config.enabled] — long leverage is a distinct dial
   from the short-side margin surface. *)
let accrue_long_margin_interest ~long_margin_rate_annual_pct ~portfolio =
  Portfolio_margin.accrue_daily_long_margin_interest
    ~rate_annual_pct:long_margin_rate_annual_pct portfolio

(* Find the strategy-side Position.t for a flagged symbol. Match only
   positions currently in Holding state — Entering/Exiting are mid-flight
   under the regular order machinery and reissuing a TriggerExit on top
   would conflict with their existing transitions. *)
let _find_holding_short_for_symbol positions symbol =
  Map.to_alist positions
  |> List.find ~f:(fun (_, pos) ->
      String.equal pos.Position.symbol symbol
      &&
      match Position.get_state pos with
      | Position.Holding _ -> true
      | _ -> false)

let _entry_price_from_holding (pos : Position.t) : float =
  match Position.get_state pos with
  | Position.Holding h -> h.entry_price
  | _ -> 0.0

let _margin_call_exit_reason ~entry_avg_cost ~current_price :
    Position.exit_reason =
  let detail = _margin_call_detail ~entry_avg_cost ~current_price in
  Position.StrategySignal { label = "margin_call"; detail = Some detail }

let _build_margin_call_transition ~date ~current_price (id, pos) =
  let entry_avg_cost = _entry_price_from_holding pos in
  let exit_reason = _margin_call_exit_reason ~entry_avg_cost ~current_price in
  let kind = Position.TriggerExit { exit_reason; exit_price = current_price } in
  { Position.position_id = id; date; kind }

let _transition_for_flagged_symbol ~date ~price_map ~positions symbol =
  let%bind.Option current_price = Map.find price_map symbol in
  let%bind.Option holding = _find_holding_short_for_symbol positions symbol in
  Some (_build_margin_call_transition ~date ~current_price holding)

let margin_call_transitions ~margin_config ~portfolio ~positions ~prices ~date =
  if not margin_config.Margin_config.enabled then []
  else
    let flagged =
      Portfolio_margin.check_maintenance_margin ~margin_config portfolio prices
    in
    match flagged with
    | [] -> []
    | _ ->
        let price_map = Map.of_alist_exn (module String) prices in
        List.filter_map flagged
          ~f:(_transition_for_flagged_symbol ~date ~price_map ~positions)

(* Same-tick same-position [TriggerExit] collision is impossible to apply: the
   [Position.t] state machine accepts [Holding _ -> TriggerExit] only once
   per position, and the second transition fails with "Invalid transition
   Position.TriggerExit". When the strategy's stop-loss runner and the
   margin runner both fire on the same bar (a sharp adverse move can trip
   both at once), we keep the {b margin} transition and drop the strategy
   one — margin wins by priority per issue #1266 because its [exit_reason]
   carries forensic detail (entry_avg_cost + current_price) the strategy's
   stop exit doesn't. Other strategy transitions on the same position
   (e.g. [UpdateRiskParams]) are not [TriggerExit] kinds and pass through. *)
let dedup_strategy_exits_for_margin ~strategy_transitions ~margin_trans =
  let margin_exit_ids =
    List.map margin_trans ~f:(fun (t : Position.transition) -> t.position_id)
    |> Set.of_list (module String)
  in
  if Set.is_empty margin_exit_ids then strategy_transitions
  else
    List.filter strategy_transitions ~f:(fun (t : Position.transition) ->
        match t.kind with
        | Position.TriggerExit _ -> not (Set.mem margin_exit_ids t.position_id)
        | _ -> true)

let tick ~margin_config ~long_margin_rate_annual_pct ~maintenance_long_pct
    ~portfolio ~positions ~today_bars ~date ~strategy_transitions =
  let prices = mark_prices today_bars in
  let portfolio = accrue_borrow_fee ~margin_config ~portfolio ~prices in
  let portfolio =
    accrue_long_margin_interest ~long_margin_rate_annual_pct ~portfolio
  in
  let short_cover_trans =
    margin_call_transitions ~margin_config ~portfolio ~positions ~prices ~date
  in
  let long_reduce_trans =
    Long_maintenance.maintenance_reduce_transitions ~maintenance_long_pct
      ~portfolio ~positions ~prices ~date
  in
  let margin_trans = short_cover_trans @ long_reduce_trans in
  let strategy_transitions =
    dedup_strategy_exits_for_margin ~strategy_transitions ~margin_trans
  in
  (portfolio, strategy_transitions @ margin_trans)
