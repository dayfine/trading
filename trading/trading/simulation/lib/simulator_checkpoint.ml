open Core
module Cash_yield = Trading_simulation_cash_yield.Cash_yield
module Dividend_crediting = Trading_simulation_dividends.Dividend_crediting

type deps_state = {
  orders : Trading_orders.Types.order list;
  engine : Trading_engine.Engine.snapshot;
  entry_fill_retry : Entry_fill_retry.snapshot;
  cash_yield_total : float option;
  dividends : Dividend_crediting.snapshot option;
  stale_hold_log : Stale_hold.event list;
}
[@@deriving sexp]

type t = {
  current_date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  positions : Trading_strategy.Position.t String.Map.t;
  steps : Trading_simulation_types.Simulator_types.step_result list;
  last_known_prices : (string * float) list;
  valuation_failure_count : int;
  order_links : Fill_router.snapshot;
  deps : deps_state;
}
[@@deriving sexp]

let capture_deps ~order_manager ~engine ~entry_fill_retry
    ~(cash_credits : Cash_credits.t) ~stale_hold_log =
  {
    orders = Trading_orders.Manager.list_orders order_manager;
    engine = Trading_engine.Engine.snapshot engine;
    entry_fill_retry = Entry_fill_retry.snapshot entry_fill_retry;
    cash_yield_total =
      Option.map cash_credits.cash_yield ~f:Cash_yield.Accrual.total;
    dividends = Option.map cash_credits.dividends ~f:Dividend_crediting.snapshot;
    stale_hold_log = Stale_hold.Log.snapshot stale_hold_log;
  }

let _restore_orders order_manager orders =
  Trading_orders.Manager.submit_orders order_manager orders
  |> Status.combine_status_list

(* [saved] and [armed] must agree: restoring interest or dividends the new run
   does not account for (or the reverse) would resume a different experiment. *)
let _restore_optional ~what saved armed ~restore =
  match (saved, armed) with
  | None, None -> Ok ()
  | Some s, Some a -> restore a s
  | _ ->
      Status.error_invalid_argument
        (what ^ ": checkpoint and dependencies disagree on whether it is armed")

let restore_deps ~order_manager ~engine ~entry_fill_retry
    ~(cash_credits : Cash_credits.t) ~stale_hold_log (s : deps_state) =
  let open Result.Let_syntax in
  let%bind () = _restore_orders order_manager s.orders in
  Trading_engine.Engine.restore engine s.engine;
  Entry_fill_retry.restore entry_fill_retry s.entry_fill_retry;
  Stale_hold.Log.restore stale_hold_log s.stale_hold_log;
  let%bind () =
    _restore_optional ~what:"cash yield" s.cash_yield_total
      cash_credits.cash_yield ~restore:(fun acc total ->
        Ok (Cash_yield.Accrual.restore_total acc total))
  in
  _restore_optional ~what:"dividends" s.dividends cash_credits.dividends
    ~restore:Dividend_crediting.restore
