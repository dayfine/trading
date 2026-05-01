open Core
module Force_liquidation = Force_liquidation

type portfolio_snapshot = {
  total_value : float;
  cash : float;
  cash_pct : float;
  long_exposure : float;
  long_exposure_pct : float;
  short_exposure : float;
  short_exposure_pct : float;
  position_count : int;
  sector_counts : (string * int) list;
}
[@@deriving show, eq]

type sizing_result = {
  shares : int;
  position_value : float;
  position_pct : float;
  risk_amount : float;
}
[@@deriving show, eq]

type limit_violation =
  | Max_positions_exceeded of int
  | Long_exposure_exceeded of float
  | Short_exposure_exceeded of float
  | Cash_below_minimum of float
  | Sector_concentration of string * int
  | Unknown_sector_exceeded of int
  | Risk_too_high of float
[@@deriving show]

type config = {
  risk_per_trade_pct : float;
  max_positions : int;
  max_long_exposure_pct : float;
  max_short_exposure_pct : float;
  max_short_notional_fraction : float;
  min_cash_pct : float;
  max_sector_concentration : int;
  max_unknown_sector_positions : int;
  big_winner_multiplier : float;
  force_liquidation : Force_liquidation.config;
      [@sexp.default Force_liquidation.default_config]
}
[@@deriving show, eq, sexp]

let default_config =
  {
    risk_per_trade_pct = 0.01;
    max_positions = 20;
    max_long_exposure_pct = 0.90;
    max_short_exposure_pct = 0.30;
    max_short_notional_fraction = 0.30;
    min_cash_pct = 0.10;
    max_sector_concentration = 5;
    max_unknown_sector_positions = 2;
    big_winner_multiplier = 1.5;
    force_liquidation = Force_liquidation.default_config;
  }

(* ---- Snapshot helpers ---- *)

let _compute_exposures positions =
  List.fold positions ~init:(0.0, 0.0, 0)
    ~f:(fun (long_exp, short_exp, count) (_, qty, price) ->
      let market_value = qty *. price in
      if Float.( >= ) market_value 0.0 then
        (long_exp +. market_value, short_exp, count + 1)
      else (long_exp, short_exp +. Float.abs market_value, count + 1))

(* Build a (sector_name, count) list from open positions and an optional
   (symbol, sector) lookup. Positions whose symbol is missing from the lookup
   — or whose sector is the empty string — are bucketed under the empty
   string, which [max_unknown_sector_positions] governs. *)
let _compute_sector_counts positions sectors =
  let sector_map =
    List.fold sectors ~init:String.Map.empty ~f:(fun m (sym, sec) ->
        Map.set m ~key:sym ~data:sec)
  in
  List.fold positions ~init:String.Map.empty ~f:(fun acc (sym, _, _) ->
      let sector = Map.find sector_map sym |> Option.value ~default:"" in
      Map.update acc sector ~f:(function None -> 1 | Some n -> n + 1))
  |> Map.to_alist
  |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)

let _make_snapshot ~cash ~positions ~sector_counts =
  let long_exp, short_exp, position_count = _compute_exposures positions in
  let total_value = cash +. long_exp -. short_exp in
  let safe_pct v =
    if Float.( <= ) total_value 0.0 then 0.0 else v /. total_value
  in
  {
    total_value;
    cash;
    cash_pct = safe_pct cash;
    long_exposure = long_exp;
    long_exposure_pct = safe_pct long_exp;
    short_exposure = short_exp;
    short_exposure_pct = safe_pct short_exp;
    position_count;
    sector_counts;
  }

let snapshot ~cash ~positions ?(sectors = []) () =
  let sector_counts = _compute_sector_counts positions sectors in
  _make_snapshot ~cash ~positions ~sector_counts

(* Extract (symbol, total_quantity, current_price) triples from a portfolio
   and price lookup. Position quantity is the sum across all lots. *)
let _positions_of_portfolio ~portfolio ~prices =
  let price_of sym =
    List.Assoc.find prices ~equal:String.equal sym |> Option.value ~default:0.0
  in
  let (p : Trading_portfolio.Portfolio.t) = portfolio in
  List.map p.positions ~f:(fun pos ->
      let qty =
        List.fold pos.lots ~init:0.0 ~f:(fun acc lot -> acc +. lot.quantity)
      in
      (pos.symbol, qty, price_of pos.symbol))

let snapshot_of_portfolio ~portfolio ~prices ?(sectors = []) () =
  let positions = _positions_of_portfolio ~portfolio ~prices in
  snapshot ~cash:portfolio.current_cash ~positions ~sectors ()

(* ---- Position sizing ---- *)

(* G7 fix: cap shares so that position_value never exceeds the side's
   max-exposure budget. Without this, a tight stop (small risk_per_share)
   relative to dollar_risk produces an unbounded share count, allowing single
   positions whose notional dwarfs portfolio_value (observed: ABBV short at 124%
   of $1M starting portfolio, sp500-2019-2023 rerun 2026-04-30). *)
let _max_shares_by_exposure ~config ~side ~portfolio_value ~entry_price =
  let max_pct =
    match side with
    | `Long -> config.max_long_exposure_pct
    | `Short -> config.max_short_exposure_pct
  in
  let max_position_value = portfolio_value *. max_pct in
  if Float.( <= ) entry_price 0.0 then Int.max_value
  else Int.of_float (Float.round_down (max_position_value /. entry_price))

let compute_position_size ~config ~portfolio_value ~side ~entry_price
    ~stop_price ?(big_winner = false) () =
  (* Risk-per-share is the absolute distance between entry and stop. The
     direction is determined by [side]: for [Long] the stop must be below
     entry; for [Short] the stop must be above entry. If the stop is on the
     wrong side or equal to entry, [|entry - stop| = 0] (or the stop fails
     the directional check) and we return 0 shares. *)
  let stop_on_correct_side =
    match side with
    | `Long -> Float.( < ) stop_price entry_price
    | `Short -> Float.( > ) stop_price entry_price
  in
  let risk_per_share = Float.abs (entry_price -. stop_price) in
  if (not stop_on_correct_side) || Float.( <= ) risk_per_share 0.0 then
    { shares = 0; position_value = 0.0; position_pct = 0.0; risk_amount = 0.0 }
  else
    let base_risk_pct = config.risk_per_trade_pct in
    let effective_risk_pct =
      if big_winner then base_risk_pct *. config.big_winner_multiplier
      else base_risk_pct
    in
    let dollar_risk = portfolio_value *. effective_risk_pct in
    let risk_based_shares =
      Int.of_float (Float.round_down (dollar_risk /. risk_per_share))
    in
    let exposure_capped_shares =
      _max_shares_by_exposure ~config ~side ~portfolio_value ~entry_price
    in
    let shares = Int.min risk_based_shares exposure_capped_shares in
    let position_value = Float.of_int shares *. entry_price in
    let position_pct =
      if Float.( <= ) portfolio_value 0.0 then 0.0
      else position_value /. portfolio_value
    in
    let risk_amount = Float.of_int shares *. risk_per_share in
    { shares; position_value; position_pct; risk_amount }

(* ---- Limit checks ---- *)

(* Each check returns a (possibly empty) list of violations. check_limits
   combines them — the monoid is list concatenation over the empty list. *)

let _check_max_positions ~config ~snapshot =
  if snapshot.position_count >= config.max_positions then
    [ Max_positions_exceeded snapshot.position_count ]
  else []

let _check_exposure ~config ~snapshot ~proposed_side ~proposed_value =
  match proposed_side with
  | `Long ->
      let new_pct =
        (snapshot.long_exposure +. proposed_value) /. snapshot.total_value
      in
      if Float.( > ) new_pct config.max_long_exposure_pct then
        [ Long_exposure_exceeded new_pct ]
      else []
  | `Short ->
      let new_pct =
        (snapshot.short_exposure +. proposed_value) /. snapshot.total_value
      in
      if Float.( > ) new_pct config.max_short_exposure_pct then
        [ Short_exposure_exceeded new_pct ]
      else []

let _check_cash ~config ~snapshot ~proposed_value =
  let cash_pct_after =
    if Float.( <= ) snapshot.total_value 0.0 then 0.0
    else (snapshot.cash -. proposed_value) /. snapshot.total_value
  in
  if Float.( < ) cash_pct_after config.min_cash_pct then
    [ Cash_below_minimum cash_pct_after ]
  else []

let _check_sector ~config ~snapshot ~proposed_sector =
  let count =
    List.Assoc.find snapshot.sector_counts ~equal:String.equal proposed_sector
    |> Option.value ~default:0
  in
  let new_count = count + 1 in
  if String.is_empty proposed_sector then
    if new_count > config.max_unknown_sector_positions then
      [ Unknown_sector_exceeded new_count ]
    else []
  else if new_count > config.max_sector_concentration then
    [ Sector_concentration (proposed_sector, new_count) ]
  else []

let check_limits ~config ~snapshot ~proposed_side ~proposed_value
    ~proposed_sector =
  let violations =
    _check_max_positions ~config ~snapshot
    @ _check_exposure ~config ~snapshot ~proposed_side ~proposed_value
    @ _check_cash ~config ~snapshot ~proposed_value
    @ _check_sector ~config ~snapshot ~proposed_sector
  in
  match violations with [] -> Result.Ok () | vs -> Result.Error vs
