(* @large-module: portfolio tracks cash, positions, and trade history with full validation pipeline *)
open Core
open Result.Let_syntax
open Status
open Trading_base.Types
open Types

type t = {
  initial_cash : cash_value;
  trade_history : trade_with_pnl list;
  (* Computed state - maintained for performance *)
  current_cash : cash_value;
  positions : portfolio_position list;
  accounting_method : accounting_method;
      (* Default accounting method for new positions *)
  unrealized_pnl_per_position : (symbol * float) list;
      (* Mark-to-market state, sorted by symbol. Updated externally via
         mark_to_market; consumed by _check_sufficient_cash to compute the
         effective cash floor. *)
  locked_collateral : cash_value;
      (* Cash pledged against open shorts under Reg-T-style margin accounting
         (issue #859 Phase 1). 0.0 under legacy Stance-A semantics; the
         apply_*_with_margin APIs are the sole writers. *)
  accrued_borrow_fee : cash_value;
      (* Running total of borrow fees debited from current_cash. 0.0 unless
         accrue_daily_borrow_fee has been called with Margin_config.enabled
         = true. Audit-only field; not consumed by trading logic. *)
}
[@@deriving show, eq, sexp]

let create ?(accounting_method = AverageCost) ~initial_cash () =
  {
    initial_cash;
    trade_history = [];
    current_cash = initial_cash;
    positions = [];
    accounting_method;
    unrealized_pnl_per_position = [];
    locked_collateral = 0.0;
    accrued_borrow_fee = 0.0;
  }

let _find_position_in_list positions symbol =
  List.find positions ~f:(fun p -> String.equal p.symbol symbol)

let get_position portfolio symbol =
  _find_position_in_list portfolio.positions symbol

(* Constants *)
let negligible_quantity_epsilon = 1e-9

(* Helper functions *)
let _is_quantity_negligible (qty : float) : bool =
  Float.(abs qty < negligible_quantity_epsilon)

let _is_same_direction (qty1 : float) (qty2 : float) : bool =
  if _is_quantity_negligible qty1 || _is_quantity_negligible qty2 then false
  else Bool.equal Float.O.(qty1 >= 0.0) Float.O.(qty2 >= 0.0)

let _sort_lots_by_date (lots : position_lot list) : position_lot list =
  List.sort lots ~compare:(fun lot1 lot2 ->
      Core.Date.compare lot1.acquisition_date lot2.acquisition_date)

(* Helper functions for position updates *)

let _calculate_cost_basis_with_commission (trade : Trading_base.Types.trade) =
  let open Trading_base.Types in
  let commission_per_share = trade.commission /. trade.quantity in
  match trade.side with
  | Buy -> trade.price +. commission_per_share
  | Sell -> trade.price -. commission_per_share

let _calculate_average_cost (existing : portfolio_position)
    (trade_quantity : float) (effective_cost : float) (new_quantity : float) :
    float =
  let existing_qty = Calculations.position_quantity existing in
  let same_direction = _is_same_direction existing_qty new_quantity in
  let adding_to_position = _is_same_direction existing_qty trade_quantity in
  let existing_avg_cost = Calculations.avg_cost_of_position existing in

  if same_direction && adding_to_position then
    (* Adding to existing position in same direction - weighted average *)
    ((existing_avg_cost *. existing_qty) +. (effective_cost *. trade_quantity))
    /. new_quantity
  else if not same_direction then
    (* Direction changed - use new effective cost as basis *)
    effective_cost
  else
    (* Reducing position in same direction - keep existing average cost *)
    existing_avg_cost

(* FIFO lot matching helpers *)

let _partially_consume_lot (lot : position_lot) (consume_qty : float) :
    position_lot * position_lot =
  (* consume_qty and lot.quantity have opposite signs *)
  let remaining_qty = lot.quantity +. consume_qty in
  let lot_qty_abs = Float.abs lot.quantity in
  let consumed_qty_abs = Float.abs consume_qty in
  let remaining_cost =
    lot.cost_basis /. lot_qty_abs *. Float.abs remaining_qty
  in
  let consumed_cost = lot.cost_basis /. lot_qty_abs *. consumed_qty_abs in
  let remaining_lot =
    { lot with quantity = remaining_qty; cost_basis = remaining_cost }
  in
  let consumed_lot =
    { lot with quantity = consume_qty; cost_basis = consumed_cost }
  in
  (remaining_lot, consumed_lot)

(* Consume a lot that is in the opposite direction to [remaining_qty]. *)
let rec _consume_opposite_lot (remaining_qty : float) (lot : position_lot) rest
    : position_lot list * position_lot list =
  let lot_qty_abs = Float.abs lot.quantity in
  let remaining_qty_abs = Float.abs remaining_qty in
  if Float.(lot_qty_abs <= remaining_qty_abs) then
    (* Fully consume this lot *)
    let new_remaining_qty = remaining_qty +. lot.quantity in
    let remaining_lots, matched = _match_lots_rec new_remaining_qty rest in
    (remaining_lots, lot :: matched)
  else
    (* Partially consume this lot *)
    let remaining_lot, consumed_lot =
      _partially_consume_lot lot remaining_qty
    in
    (remaining_lot :: rest, [ consumed_lot ])

and _match_single_lot (remaining_qty : float) (lot : position_lot)
    (rest : position_lot list) : position_lot list * position_lot list =
  if _is_same_direction lot.quantity remaining_qty then
    (* Lot in same direction - keep it, continue matching *)
    let remaining_lots, matched = _match_lots_rec remaining_qty rest in
    (lot :: remaining_lots, matched)
  else _consume_opposite_lot remaining_qty lot rest

and _match_lots_rec (remaining_qty : float) (lots : position_lot list) :
    position_lot list * position_lot list =
  if _is_quantity_negligible remaining_qty then (lots, [])
  else
    match lots with
    | [] -> ([], [])
    | lot :: rest -> _match_single_lot remaining_qty lot rest

(* FIFO lot matching: consume oldest lots first when closing position.
   Assumes lots are already sorted by acquisition date (maintained as invariant). *)
let _match_fifo_lots (existing_lots : position_lot list)
    (trade_quantity : float) : position_lot list * position_lot list =
  _match_lots_rec trade_quantity existing_lots

let _make_lot trade_id trade_quantity effective_cost trade_timestamp :
    position_lot =
  {
    lot_id = trade_id;
    quantity = trade_quantity;
    cost_basis = Float.abs trade_quantity *. effective_cost;
    acquisition_date =
      Time_ns_unix.to_date trade_timestamp ~zone:Time_float.Zone.utc;
  }

let _set_position positions position : portfolio_position list =
  (* Remove existing position with same symbol and add new one, keeping sorted *)
  List.filter positions ~f:(fun p ->
      not (String.equal p.symbol position.symbol))
  |> fun ps ->
  position :: ps
  |> List.sort ~compare:(fun p1 p2 -> String.compare p1.symbol p2.symbol)

let _remove_position positions symbol : portfolio_position list =
  List.filter positions ~f:(fun p -> not (String.equal p.symbol symbol))
  |> List.sort ~compare:(fun p1 p2 -> String.compare p1.symbol p2.symbol)

let _create_new_position positions symbol trade_quantity effective_cost trade_id
    trade_timestamp accounting_method : portfolio_position list =
  let lot = _make_lot trade_id trade_quantity effective_cost trade_timestamp in
  let position = { symbol; lots = [ lot ]; accounting_method } in
  _set_position positions position

let _add_lot_to_position positions (existing : portfolio_position)
    trade_quantity effective_cost trade_id trade_timestamp :
    portfolio_position list =
  let new_lot =
    _make_lot trade_id trade_quantity effective_cost trade_timestamp
  in
  (* Maintain lots in sorted order by acquisition date (invariant) *)
  let updated_lots = _sort_lots_by_date (existing.lots @ [ new_lot ]) in
  let updated_position = { existing with lots = updated_lots } in
  _set_position positions updated_position

let _close_or_reduce_fifo_position positions (existing : portfolio_position)
    trade_quantity effective_cost trade_id trade_timestamp :
    portfolio_position list =
  let remaining_lots, _matched_lots =
    _match_fifo_lots existing.lots trade_quantity
  in
  let existing_qty = Calculations.position_quantity existing in
  let new_quantity = existing_qty +. trade_quantity in

  if _is_quantity_negligible new_quantity then
    _remove_position positions existing.symbol
  else if List.is_empty remaining_lots then
    (* Direction changed - create new position with new_quantity *)
    _create_new_position positions existing.symbol new_quantity effective_cost
      trade_id trade_timestamp existing.accounting_method
  else
    (* Position reduced - update with remaining lots *)
    let updated_position = { existing with lots = remaining_lots } in
    _set_position positions updated_position

let _update_existing_position_fifo positions (existing : portfolio_position)
    trade_quantity effective_cost trade_id trade_timestamp :
    portfolio_position list =
  let existing_qty = Calculations.position_quantity existing in
  let adding_to_position = _is_same_direction existing_qty trade_quantity in
  if adding_to_position then
    _add_lot_to_position positions existing trade_quantity effective_cost
      trade_id trade_timestamp
  else
    _close_or_reduce_fifo_position positions existing trade_quantity
      effective_cost trade_id trade_timestamp

let _update_existing_position_average_cost positions
    (existing : portfolio_position) trade_quantity effective_cost trade_id
    trade_timestamp : portfolio_position list =
  let existing_qty = Calculations.position_quantity existing in
  let new_quantity = existing_qty +. trade_quantity in
  if _is_quantity_negligible new_quantity then
    _remove_position positions existing.symbol
  else
    let new_avg_cost =
      _calculate_average_cost existing trade_quantity effective_cost
        new_quantity
    in
    _create_new_position positions existing.symbol new_quantity new_avg_cost
      trade_id trade_timestamp existing.accounting_method

let _update_existing_position positions (existing : portfolio_position)
    trade_quantity effective_cost trade_id trade_timestamp :
    portfolio_position list =
  match existing.accounting_method with
  | AverageCost ->
      _update_existing_position_average_cost positions existing trade_quantity
        effective_cost trade_id trade_timestamp
  | FIFO ->
      _update_existing_position_fifo positions existing trade_quantity
        effective_cost trade_id trade_timestamp

let _update_position_with_trade positions accounting_method
    (trade : Trading_base.Types.trade) : portfolio_position list =
  let symbol = trade.symbol in
  let trade_quantity =
    match trade.side with Buy -> trade.quantity | Sell -> -.trade.quantity
  in
  let effective_cost = _calculate_cost_basis_with_commission trade in

  match _find_position_in_list positions symbol with
  | None ->
      _create_new_position positions symbol trade_quantity effective_cost
        trade.id trade.timestamp accounting_method
  | Some existing ->
      _update_existing_position positions existing trade_quantity effective_cost
        trade.id trade.timestamp

(* Helper functions for trade application *)
let _calculate_cash_change (trade : Trading_base.Types.trade) =
  match trade.side with
  | Buy -> -.((trade.quantity *. trade.price) +. trade.commission)
  | Sell -> (trade.quantity *. trade.price) -. trade.commission

let _is_closing_trade position_qty trade_qty : bool =
  not (_is_same_direction position_qty trade_qty)

(* Calculate P&L from matched lots (used for FIFO) *)
let _calculate_pnl_from_matched_lots (matched_lots : position_lot list)
    (trade : Trading_base.Types.trade) : float =
  let total_cost_basis =
    List.fold matched_lots ~init:0.0 ~f:(fun acc lot -> acc +. lot.cost_basis)
  in
  (* Matched lots all have the same sign (opposite to trade direction),
     so we can sum quantities directly and take abs once. *)
  let total_qty_signed =
    List.fold matched_lots ~init:0.0 ~f:(fun acc lot -> acc +. lot.quantity)
  in
  let total_qty = Float.abs total_qty_signed in
  if Float.(total_qty < negligible_quantity_epsilon) then 0.0
  else
    let matched_avg_cost = total_cost_basis /. total_qty in
    let pnl_before_commission =
      match trade.side with
      | Sell -> total_qty *. (trade.price -. matched_avg_cost)
      | Buy -> total_qty *. (matched_avg_cost -. trade.price)
    in
    pnl_before_commission -. trade.commission

(* Calculate P&L for average cost method *)
let _calculate_average_cost_pnl (trade : Trading_base.Types.trade)
    (existing_position : portfolio_position) : float =
  let existing_qty = Calculations.position_quantity existing_position in
  let close_qty =
    Float.min (Float.abs existing_qty) (Float.abs trade.quantity)
  in
  let existing_avg_cost = Calculations.avg_cost_of_position existing_position in
  let pnl_before_commission =
    match trade.side with
    | Sell -> close_qty *. (trade.price -. existing_avg_cost)
    | Buy -> close_qty *. (existing_avg_cost -. trade.price)
  in
  pnl_before_commission -. trade.commission

(* Calculate P&L for FIFO method *)
let _calculate_fifo_pnl (trade : Trading_base.Types.trade) (trade_qty : float)
    (existing_position : portfolio_position) : float =
  let _remaining_lots, matched_lots =
    _match_fifo_lots existing_position.lots trade_qty
  in
  _calculate_pnl_from_matched_lots matched_lots trade

let _calculate_realized_pnl (trade : Trading_base.Types.trade)
    (existing_position : portfolio_position) : float =
  let trade_qty =
    match trade.side with Buy -> trade.quantity | Sell -> -.trade.quantity
  in
  let existing_qty = Calculations.position_quantity existing_position in
  if _is_closing_trade existing_qty trade_qty then
    match existing_position.accounting_method with
    | AverageCost -> _calculate_average_cost_pnl trade existing_position
    | FIFO -> _calculate_fifo_pnl trade trade_qty existing_position
  else 0.0 (* Opening or adding to position *)

(* Sum of negative unrealized P&L across all marked positions. Positive
   unrealized P&L is clamped to 0 — only paper losses count against the
   effective cash floor. Returns 0.0 when the portfolio has never been
   marked or every position is at-or-above its entry. *)
let _negative_unrealized_pnl_total portfolio =
  List.fold portfolio.unrealized_pnl_per_position ~init:0.0
    ~f:(fun acc (_symbol, pnl) -> acc +. Float.min 0.0 pnl)

let _check_sufficient_cash portfolio cash_change =
  let new_cash = portfolio.current_cash +. cash_change in
  let unrealized_drag = _negative_unrealized_pnl_total portfolio in
  let effective_cash = new_cash +. unrealized_drag in
  if Float.(effective_cash < 0.0) then
    error_invalid_argument
      ("Insufficient cash for trade. Required: "
      ^ Float.to_string (-.cash_change)
      ^ ", Available: "
      ^ Float.to_string portfolio.current_cash
      ^ ", Unrealized loss drag: "
      ^ Float.to_string unrealized_drag)
  else Result.Ok new_cash

(* After a trade, prune the unrealized-pnl accumulator. Positions that no
   longer exist (fully closed) are dropped. New positions get a 0.0 seed,
   so the accumulator's symbol set tracks the current open positions —
   stale until the next mark_to_market. Existing entries on
   not-yet-closed positions are kept (their MtM is also stale until the
   next mark, but carrying the prior loss is the conservative choice for
   the cash-floor check). *)
let _refresh_unrealized_after_trade ~old_accumulator ~new_positions =
  let old_map = Map.of_alist_exn (module String) old_accumulator in
  List.map new_positions ~f:(fun (p : portfolio_position) ->
      let pnl =
        match Map.find old_map p.symbol with Some v -> v | None -> 0.0
      in
      (p.symbol, pnl))

let apply_single_trade (portfolio : t) (trade : Trading_base.Types.trade) :
    t status_or =
  let cash_change = _calculate_cash_change trade in
  let%bind new_cash = _check_sufficient_cash portfolio cash_change in
  let realized_pnl =
    match get_position portfolio trade.symbol with
    | None -> 0.0 (* New position - no realized P&L *)
    | Some existing_position -> _calculate_realized_pnl trade existing_position
  in
  let new_positions =
    _update_position_with_trade portfolio.positions portfolio.accounting_method
      trade
  in
  let new_accumulator =
    _refresh_unrealized_after_trade
      ~old_accumulator:portfolio.unrealized_pnl_per_position ~new_positions
  in
  let trade_with_pnl = { trade; realized_pnl } in
  return
    {
      portfolio with
      current_cash = new_cash;
      positions = new_positions;
      (* Newest-first: prepend (O(1), shares tail across snapshots) instead of
         append-via-[@] (O(N) per call, fresh prefix per snapshot). The latter
         was the dominant cost on Cell E 15 y runs — both algorithmically
         (N(N+1)/2 cons cells for N trades) and via [step_history] retention
         (every [step_result.portfolio] held a fresh trade_history spine, so
         [step_history] memory scaled O(N²) instead of O(N)).
         See [dev/notes/cell-e-15y-engineering-blocker-2026-05-09.md]. *)
      trade_history = trade_with_pnl :: portfolio.trade_history;
      unrealized_pnl_per_position = new_accumulator;
    }

let apply_trades portfolio trades =
  List.fold_result trades ~init:portfolio ~f:apply_single_trade

let mark_to_market portfolio market_prices =
  let price_map = Map.of_alist_exn (module String) market_prices in
  let new_accumulator =
    List.filter_map portfolio.positions ~f:(fun (p : portfolio_position) ->
        match Map.find price_map p.symbol with
        | None -> None
        | Some price -> Some (p.symbol, Calculations.unrealized_pnl p price))
    |> List.sort ~compare:(fun (s1, _) (s2, _) -> String.compare s1 s2)
  in
  { portfolio with unrealized_pnl_per_position = new_accumulator }

(* Reconstruct portfolio from scratch for validation. [trade_history] is stored
   newest-first (see [trade_history = trade_with_pnl :: ...] above), so we
   reverse it once here to replay trades in chronological order. *)
let reconstruct_from_history initial_cash accounting_method trade_history =
  let trades = List.rev_map trade_history ~f:(fun { trade; _ } -> trade) in
  let empty_portfolio = create ~accounting_method ~initial_cash () in
  apply_trades empty_portfolio trades

(* Helper functions for combinational validation *)
let _validate_lots_sorted (position : portfolio_position) : status =
  let rec check_sorted = function
    | [] | [ _ ] -> true
    | lot1 :: (lot2 :: _ as rest) ->
        Core.Date.(lot1.acquisition_date <= lot2.acquisition_date)
        && check_sorted rest
  in
  if check_sorted position.lots then ok ()
  else
    error_invalid_argument
      (Printf.sprintf "Lots not sorted by acquisition date for symbol %s"
         position.symbol)

let _validate_all_positions_lots_sorted positions : status =
  let position_validations = List.map positions ~f:_validate_lots_sorted in
  combine_status_list position_validations

let _validate_cash_balance portfolio reconstructed =
  if Float.equal portfolio.current_cash reconstructed.current_cash then ok ()
  else
    error_invalid_argument
      (Printf.sprintf "Cash balance mismatch: expected %.2f, found %.2f"
         reconstructed.current_cash portfolio.current_cash)

let _validate_positions portfolio reconstructed =
  (* Positions are already sorted lists *)
  if
    List.equal equal_portfolio_position portfolio.positions
      reconstructed.positions
  then ok ()
  else
    let format_positions positions =
      List.map positions ~f:(fun pos ->
          Printf.sprintf "%s: %s" pos.symbol (show_portfolio_position pos))
      |> String.concat ~sep:"; "
    in
    error_invalid_argument
      (Printf.sprintf "Positions mismatch:\nExpected: [%s]\nFound: [%s]"
         (format_positions reconstructed.positions)
         (format_positions portfolio.positions))

let validate portfolio =
  let%bind reconstructed =
    reconstruct_from_history portfolio.initial_cash portfolio.accounting_method
      portfolio.trade_history
  in
  (* Run all validations and collect errors *)
  let validations =
    [
      _validate_all_positions_lots_sorted portfolio.positions;
      _validate_cash_balance portfolio reconstructed;
      _validate_positions portfolio reconstructed;
    ]
  in
  combine_status_list validations

(* ========================================================================== *)
(* Margin accounting (issue #859 Phase 1)                                     *)
(* ========================================================================== *)

(* available_cash = current_cash net of pledged short collateral. Strategy
   code should read this rather than current_cash when sizing new entries. *)
let available_cash portfolio =
  portfolio.current_cash -. portfolio.locked_collateral

(* Classify a Sell or Buy trade against the current position into one of four
   margin-relevant cases. Phase 1 only treats opening short / closing short
   specially; long-side cases pass straight through. *)
type margin_trade_kind =
  | Long_side (* Buy opening long, Sell closing long, etc. *)
  | Short_open of float (* Sell opening / growing short; carries qty *)
  | Short_close of float (* Buy reducing a short; carries closed-qty (>0) *)

let _classify_trade portfolio (trade : Trading_base.Types.trade) :
    margin_trade_kind =
  let existing_qty =
    match get_position portfolio trade.symbol with
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

let _existing_avg_cost portfolio symbol : float =
  match get_position portfolio symbol with
  | None -> 0.0
  | Some p -> Calculations.avg_cost_of_position p

(* Apply margin-mode side-effects on top of the base [apply_single_trade]
   result. Called only when [margin_config.enabled = true]. *)
let _apply_margin_effects ~(margin_config : Margin_config.t) ~portfolio_before
    ~(portfolio_after : t) (trade : Trading_base.Types.trade) : t status_or =
  match _classify_trade portfolio_before trade with
  | Long_side -> return portfolio_after
  | Short_open qty ->
      let lock =
        _initial_collateral_for_short ~margin_config ~price:trade.price ~qty
      in
      let new_locked = portfolio_after.locked_collateral +. lock in
      let new_available = portfolio_after.current_cash -. new_locked in
      if Float.O.(new_available < 0.0) then
        error_invalid_argument
          ("Insufficient cash for short collateral. Required lock: "
         ^ Float.to_string lock ^ ", available_cash before: "
          ^ Float.to_string (available_cash portfolio_after))
      else return { portfolio_after with locked_collateral = new_locked }
  | Short_close closed_qty ->
      let avg_cost = _existing_avg_cost portfolio_before trade.symbol in
      let release =
        _collateral_release_on_cover ~margin_config ~closed_qty
          ~existing_avg_cost:avg_cost
      in
      (* Guard against floating-point drift pushing locked below 0. *)
      let new_locked =
        Float.max 0.0 (portfolio_after.locked_collateral -. release)
      in
      return { portfolio_after with locked_collateral = new_locked }

let apply_single_trade_with_margin ~(margin_config : Margin_config.t)
    (portfolio : t) (trade : Trading_base.Types.trade) : t status_or =
  if not margin_config.enabled then apply_single_trade portfolio trade
  else
    let%bind portfolio_after = apply_single_trade portfolio trade in
    _apply_margin_effects ~margin_config ~portfolio_before:portfolio
      ~portfolio_after trade

let apply_trades_with_margin ~margin_config portfolio trades =
  List.fold_result trades ~init:portfolio
    ~f:(apply_single_trade_with_margin ~margin_config)

(* Sum |qty * price| across short positions present in the price list. *)
let sum_short_notional portfolio market_prices : float =
  let price_map = Map.of_alist_exn (module String) market_prices in
  List.fold portfolio.positions ~init:0.0 ~f:(fun acc p ->
      let qty = Calculations.position_quantity p in
      if Float.O.(qty < 0.0) then
        match Map.find price_map p.symbol with
        | None -> acc
        | Some price -> acc +. (Float.abs qty *. price)
      else acc)

let accrue_daily_borrow_fee ~(margin_config : Margin_config.t) (portfolio : t)
    (market_prices : (symbol * price) list) : t =
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

let check_maintenance_margin ~(margin_config : Margin_config.t) (portfolio : t)
    (market_prices : (symbol * price) list) : symbol list =
  if not margin_config.enabled then []
  else
    let price_map = Map.of_alist_exn (module String) market_prices in
    List.filter_map portfolio.positions ~f:(fun p ->
        let qty = Calculations.position_quantity p in
        if Float.O.(qty >= 0.0) then None
        else
          match Map.find price_map p.symbol with
          | None -> None
          | Some price ->
              let entry_avg_cost = Calculations.avg_cost_of_position p in
              let ratio =
                _short_equity_ratio ~margin_config ~entry_avg_cost
                  ~current_price:price
              in
              if Float.O.(ratio < margin_config.maintenance_margin_pct) then
                Some p.symbol
              else None)
    |> List.sort ~compare:String.compare
