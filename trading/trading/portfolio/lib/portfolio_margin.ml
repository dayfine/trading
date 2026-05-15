open Core
open Result.Let_syntax
open Status
open Trading_base.Types
open Types

(* Classify a Sell or Buy trade against the current position into one of four
   margin-relevant cases. Phase 1 only treats opening short / closing short
   specially; long-side cases pass straight through. *)
type margin_trade_kind =
  | Long_side  (** Buy opening long, Sell closing long, etc. *)
  | Short_open of float  (** Sell opening / growing short; carries qty *)
  | Short_close of float  (** Buy reducing a short; carries closed-qty (>0) *)

let _classify_trade portfolio (trade : Trading_base.Types.trade) :
    margin_trade_kind =
  let existing_qty =
    match Portfolio.get_position portfolio trade.symbol with
    | None -> 0.0
    | Some p -> Calculations.position_quantity p
  in
  match trade.side with
  | Sell when Float.O.(existing_qty <= 0.0) ->
      (* Selling into a flat or already-short position grows the short. *)
      Short_open trade.quantity
  | Buy when Float.O.(existing_qty < 0.0) ->
      (* Buying covers part or all of a short. closed_qty is bounded by the
         existing short size so an over-cover that flips long is split:
         the short-close portion releases collateral here; the new-long
         portion is regular long-side accounting (no collateral change). *)
      let closed = Float.min trade.quantity (Float.abs existing_qty) in
      Short_close closed
  | _ -> Long_side

(* Total collateral required for a new short of [qty] shares at [price]:
   (1.0 + initial_margin_pct) * qty * price. *)
let _initial_collateral_for_short ~(margin_config : Margin_config.t) ~price ~qty
    : cash_value =
  Margin_config.total_collateral_factor margin_config *. price *. qty

(* Release a proportional share of the locked collateral when covering. The
   portfolio tracks one aggregate [locked_collateral] number rather than
   per-symbol locks (sufficient for Phase 1 — the locked amount on each
   symbol is implicit in its position's avg_cost). *)
let _collateral_release_on_cover ~(margin_config : Margin_config.t) ~closed_qty
    ~(existing_avg_cost : float) : cash_value =
  let factor = Margin_config.total_collateral_factor margin_config in
  (* Released = factor * closed_qty * avg_entry_cost. Using the position's
     own avg cost (not the cover trade's price) keeps the release symmetric
     with the lock at entry. *)
  factor *. closed_qty *. existing_avg_cost

let _existing_avg_cost (portfolio : Portfolio.t) symbol : float =
  match Portfolio.get_position portfolio symbol with
  | None -> 0.0
  | Some p -> Calculations.avg_cost_of_position p

(* Lock collateral for a fresh short-open or short-add. Returns Error if the
   resulting [available_cash] would go negative. *)
let _apply_short_open ~(margin_config : Margin_config.t)
    ~(portfolio_after : Portfolio.t) ~price ~qty : Portfolio.t status_or =
  let lock = _initial_collateral_for_short ~margin_config ~price ~qty in
  let new_locked = portfolio_after.locked_collateral +. lock in
  let new_available = portfolio_after.current_cash -. new_locked in
  if Float.O.(new_available < 0.0) then
    error_invalid_argument
      ("Insufficient cash for short collateral. Required lock: "
     ^ Float.to_string lock ^ ", available_cash before: "
      ^ Float.to_string (Portfolio.available_cash portfolio_after))
  else return { portfolio_after with locked_collateral = new_locked }

(* Release collateral proportional to the covered fraction of a short. *)
let _apply_short_close ~(margin_config : Margin_config.t)
    ~(portfolio_before : Portfolio.t) ~(portfolio_after : Portfolio.t) ~symbol
    ~closed_qty : Portfolio.t status_or =
  let avg_cost = _existing_avg_cost portfolio_before symbol in
  let release =
    _collateral_release_on_cover ~margin_config ~closed_qty
      ~existing_avg_cost:avg_cost
  in
  (* Guard against floating-point drift pushing locked below 0. *)
  let new_locked =
    Float.max 0.0 (portfolio_after.locked_collateral -. release)
  in
  return { portfolio_after with locked_collateral = new_locked }

(* Apply margin-mode side-effects on top of the base [apply_single_trade]
   result. Called only when [margin_config.enabled = true]. *)
let _apply_margin_effects ~(margin_config : Margin_config.t)
    ~(portfolio_before : Portfolio.t) ~(portfolio_after : Portfolio.t)
    (trade : Trading_base.Types.trade) : Portfolio.t status_or =
  match _classify_trade portfolio_before trade with
  | Long_side -> return portfolio_after
  | Short_open qty ->
      _apply_short_open ~margin_config ~portfolio_after ~price:trade.price ~qty
  | Short_close closed_qty ->
      _apply_short_close ~margin_config ~portfolio_before ~portfolio_after
        ~symbol:trade.symbol ~closed_qty

let apply_single_trade_with_margin ~(margin_config : Margin_config.t)
    (portfolio : Portfolio.t) (trade : Trading_base.Types.trade) :
    Portfolio.t status_or =
  if not margin_config.enabled then Portfolio.apply_single_trade portfolio trade
  else
    let%bind portfolio_after = Portfolio.apply_single_trade portfolio trade in
    _apply_margin_effects ~margin_config ~portfolio_before:portfolio
      ~portfolio_after trade

let apply_trades_with_margin ~margin_config portfolio trades =
  List.fold_result trades ~init:portfolio
    ~f:(apply_single_trade_with_margin ~margin_config)

(* Sum |qty * price| across short positions present in the price list. *)
let sum_short_notional (portfolio : Portfolio.t) market_prices : float =
  let price_map = Map.of_alist_exn (module String) market_prices in
  List.fold portfolio.positions ~init:0.0 ~f:(fun acc p ->
      let qty = Calculations.position_quantity p in
      if Float.O.(qty < 0.0) then
        match Map.find price_map p.symbol with
        | None -> acc
        | Some price -> acc +. (Float.abs qty *. price)
      else acc)

let accrue_daily_borrow_fee ~(margin_config : Margin_config.t)
    (portfolio : Portfolio.t) (market_prices : (symbol * price) list) :
    Portfolio.t =
  if not margin_config.enabled then portfolio
  else
    let notional = sum_short_notional portfolio market_prices in
    let fee = notional *. Margin_config.daily_borrow_rate margin_config in
    {
      portfolio with
      current_cash = portfolio.current_cash -. fee;
      accrued_borrow_fee = portfolio.accrued_borrow_fee +. fee;
    }

(* Equity ratio for a short position whose qty is negative.
   See [.mli] for the derivation: equity_ratio = ((1+im) c0 - p) / p. *)
let _short_equity_ratio ~(margin_config : Margin_config.t)
    ~(entry_avg_cost : float) ~(current_price : float) : float =
  if Float.O.(current_price <= 0.0) then Float.infinity
  else
    let factor = Margin_config.total_collateral_factor margin_config in
    ((factor *. entry_avg_cost) -. current_price) /. current_price

(* Check whether a short position priced at [current_price] breaches the
   maintenance threshold. Returns [Some symbol] when flagged, [None]
   otherwise. *)
let _short_breaches_maintenance ~(margin_config : Margin_config.t)
    ~(current_price : float) (p : portfolio_position) : symbol option =
  let entry_avg_cost = Calculations.avg_cost_of_position p in
  let ratio = _short_equity_ratio ~margin_config ~entry_avg_cost ~current_price in
  if Float.O.(ratio < margin_config.maintenance_margin_pct) then Some p.symbol
  else None

(* Per-position maintenance check. Long positions and shorts with no price in
   the mark list are ignored. *)
let _maintenance_flagged_symbol ~(margin_config : Margin_config.t) ~price_map
    (p : portfolio_position) : symbol option =
  let qty = Calculations.position_quantity p in
  if Float.O.(qty >= 0.0) then None
  else
    Option.bind (Map.find price_map p.symbol) ~f:(fun current_price ->
        _short_breaches_maintenance ~margin_config ~current_price p)

let check_maintenance_margin ~(margin_config : Margin_config.t)
    (portfolio : Portfolio.t) (market_prices : (symbol * price) list) :
    symbol list =
  if not margin_config.enabled then []
  else
    let price_map = Map.of_alist_exn (module String) market_prices in
    List.filter_map portfolio.positions
      ~f:(_maintenance_flagged_symbol ~margin_config ~price_map)
    |> List.sort ~compare:String.compare
