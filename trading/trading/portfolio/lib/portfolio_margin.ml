open Core
open Result.Let_syntax
open Status
open Trading_base.Types
open Types

(* Spendable cash net of pledged short collateral (full contract in [.mli]). *)
let available_cash (portfolio : Portfolio.t) : cash_value =
  portfolio.current_cash -. portfolio.locked_collateral

(* Equity cash net of borrowed long-margin debt, margin M1b-2 (see [.mli]). *)
let equity_cash (portfolio : Portfolio.t) : cash_value =
  portfolio.current_cash -. portfolio.long_margin_debit

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
      ^ Float.to_string (available_cash portfolio_after))
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

(* Price-tiered daily borrow fee for one position (M3a); an empty tier table →
   flat rate, so the per-position sum equals [sum_short_notional * flat_daily]
   bit-for-bit (distributivity). Longs / unpriced shorts contribute nothing. *)
let _short_daily_borrow_fee ~(margin_config : Margin_config.t) ~price_map p :
    float =
  let qty = Calculations.position_quantity p in
  if Float.O.(qty >= 0.0) then 0.0
  else
    Map.find price_map p.symbol
    |> Option.value_map ~default:0.0 ~f:(fun price ->
        Float.abs qty *. price
        *. Margin_config.daily_borrow_rate_for_price margin_config ~price)

let accrue_daily_borrow_fee ~(margin_config : Margin_config.t)
    (portfolio : Portfolio.t) (market_prices : (symbol * price) list) :
    Portfolio.t =
  if not margin_config.enabled then portfolio
  else
    let price_map = Map.of_alist_exn (module String) market_prices in
    let fee =
      List.sum
        (module Float)
        portfolio.positions
        ~f:(_short_daily_borrow_fee ~margin_config ~price_map)
    in
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
  let ratio =
    _short_equity_ratio ~margin_config ~entry_avg_cost ~current_price
  in
  (* Price-tiered threshold (M3a); empty [short_maintenance_tiers] → flat
     [maintenance_margin_pct], i.e. bit-identical to pre-M3a. *)
  let threshold =
    Margin_config.maintenance_pct_for_price margin_config ~price:current_price
  in
  if Float.O.(ratio < threshold) then Some p.symbol else None

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

(* ========================================================================== *)
(* Long-margin (levered long) accounting — margin M1b-2 (Option A)            *)
(* ========================================================================== *)

(* Total cash a Buy consumes: (quantity * price) + commission — the magnitude of
   [Portfolio._calculate_cash_change]'s Buy branch. *)
let _long_buy_cost (trade : trade) : float =
  (trade.quantity *. trade.price) +. trade.commission

(* Non-positive sum of paper losses across marked positions. Mirrors
   [Portfolio._negative_unrealized_pnl_total] (that helper is private); used only
   to size the temporary cash cushion that lets the base cash floor pass for a
   borrowed buy. *)
let _negative_unrealized_pnl_total (portfolio : Portfolio.t) : float =
  List.fold portfolio.unrealized_pnl_per_position ~init:0.0
    ~f:(fun acc (_symbol, pnl) -> acc +. Float.min 0.0 pnl)

(* Fund a long BUY whose cost exceeds available cash by borrowing the shortfall
   into [long_margin_debit]. Own cash is spent first; the remainder is the debit,
   so [current_cash] never goes negative (Option A — the cash floor's semantics
   are untouched; we route *around* it here rather than relaxing it). The base
   [apply_single_trade] is run on a portfolio whose cash is temporarily credited
   by [borrow +. |paper-loss drag|] purely so its floor check passes; the
   position / history updates it performs are cash-independent, so [current_cash]
   and [long_margin_debit] are then overwritten from the pre-trade values. *)
let _apply_long_leveraged_buy ~(portfolio : Portfolio.t) ~(trade : trade)
    ~(available : float) : Portfolio.t status_or =
  let cost = _long_buy_cost trade in
  let borrow = Float.max 0.0 (cost -. available) in
  let cash_spent = cost -. borrow in
  let drag = Float.abs (_negative_unrealized_pnl_total portfolio) in
  let inflated =
    { portfolio with current_cash = portfolio.current_cash +. borrow +. drag }
  in
  let%bind after = Portfolio.apply_single_trade inflated trade in
  return
    {
      after with
      current_cash = portfolio.current_cash -. cash_spent;
      long_margin_debit = portfolio.long_margin_debit +. borrow;
    }

(* Route a long exit's proceeds against the outstanding debit first, then to
   cash. Reached only with a positive prior debit. *)
let _apply_long_exit_paydown ~(portfolio : Portfolio.t) ~(trade : trade) :
    Portfolio.t status_or =
  let%bind after = Portfolio.apply_single_trade portfolio trade in
  let proceeds = after.current_cash -. portfolio.current_cash in
  let paydown =
    Float.min portfolio.long_margin_debit (Float.max 0.0 proceeds)
  in
  return
    {
      after with
      current_cash = after.current_cash -. paydown;
      long_margin_debit = portfolio.long_margin_debit -. paydown;
    }

let _existing_qty (portfolio : Portfolio.t) symbol : float =
  match Portfolio.get_position portfolio symbol with
  | None -> 0.0
  | Some p -> Calculations.position_quantity p

let apply_single_trade_with_long_margin ~(initial_long_margin_req : float)
    (portfolio : Portfolio.t) (trade : trade) : Portfolio.t status_or =
  if Float.O.(initial_long_margin_req >= 1.0) then
    (* Cash account / leverage disarmed: byte-identical to the base apply. *)
    Portfolio.apply_single_trade portfolio trade
  else
    let existing_qty = _existing_qty portfolio trade.symbol in
    match trade.side with
    | Buy when Float.O.(existing_qty >= 0.0) ->
        let available = available_cash portfolio in
        if Float.O.(_long_buy_cost trade > available) then
          _apply_long_leveraged_buy ~portfolio ~trade ~available
        else Portfolio.apply_single_trade portfolio trade
    | Sell
      when Float.O.(existing_qty > 0.0)
           && Float.O.(portfolio.long_margin_debit > 0.0) ->
        _apply_long_exit_paydown ~portfolio ~trade
    | _ -> Portfolio.apply_single_trade portfolio trade

let accrue_daily_long_margin_interest ~(rate_annual_pct : float)
    (portfolio : Portfolio.t) : Portfolio.t =
  if
    Float.O.(rate_annual_pct <= 0.0)
    || Float.O.(portfolio.long_margin_debit <= 0.0)
  then portfolio
  else
    let daily = rate_annual_pct /. Margin_config.trading_days_per_year in
    let charge = portfolio.long_margin_debit *. daily in
    { portfolio with long_margin_debit = portfolio.long_margin_debit +. charge }
