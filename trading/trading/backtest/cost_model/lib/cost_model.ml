(** Cost-model overlay for backtest pipelines. See [cost_model.mli] for the
    contract. *)

open Core

type t = {
  per_trade_commission : float;
  per_share_commission : float;
  bid_ask_spread_bps : float;
  market_impact_bps_per_pct_adv : float;
}
[@@deriving sexp, show, eq]

let zero =
  {
    per_trade_commission = 0.0;
    per_share_commission = 0.0;
    bid_ask_spread_bps = 0.0;
    market_impact_bps_per_pct_adv = 0.0;
  }

let retail_default =
  {
    per_trade_commission = 0.0;
    per_share_commission = 0.0;
    bid_ask_spread_bps = 5.0;
    market_impact_bps_per_pct_adv = 0.0;
  }

(* IBKR Pro tiered ≈ $0.005/share; bid-ask ≈ 2 bps for top-of-book
   liquid US equities; impact coefficient ≈ 1 bps per 1% ADV is a
   conservative-end published baseline (Almgren–Chriss and Kissell
   give similar magnitudes for small-mid caps). *)
let institutional_default =
  {
    per_trade_commission = 0.0;
    per_share_commission = 0.005;
    bid_ask_spread_bps = 2.0;
    market_impact_bps_per_pct_adv = 1.0;
  }

(* Returns Ok () if [x] is non-negative and finite; Error otherwise. *)
let _check_nonneg_finite ~field x =
  if Float.is_nan x || Float.is_inf x then
    Error
      (Status.invalid_argument_error
         (Printf.sprintf "%s must be finite: %f" field x))
  else if Float.(x < 0.0) then
    Error
      (Status.invalid_argument_error
         (Printf.sprintf "%s must be >= 0: %f" field x))
  else Ok ()

let validate t =
  let validations =
    [
      _check_nonneg_finite ~field:"per_trade_commission" t.per_trade_commission;
      _check_nonneg_finite ~field:"per_share_commission" t.per_share_commission;
      _check_nonneg_finite ~field:"bid_ask_spread_bps" t.bid_ask_spread_bps;
      _check_nonneg_finite ~field:"market_impact_bps_per_pct_adv"
        t.market_impact_bps_per_pct_adv;
    ]
  in
  Status.combine_status_list validations

let to_engine_costs t =
  let commission =
    { Trading_engine.Types.per_share = t.per_share_commission; minimum = 0.0 }
  in
  let slippage_bps = Float.iround_nearest_exn t.bid_ask_spread_bps in
  (commission, slippage_bps)

let apply_per_trade_commission t (trade : Trading_base.Types.trade) =
  if Float.(t.per_trade_commission = 0.0) then trade
  else { trade with commission = trade.commission +. t.per_trade_commission }

let market_impact_bps t ~adv_pct =
  let clamped = Float.max adv_pct 0.0 in
  t.market_impact_bps_per_pct_adv *. clamped

let apply_market_impact t ~adv_pct ~(side : Trading_base.Types.side) ~fill_price
    =
  let bps = market_impact_bps t ~adv_pct in
  if Float.(bps = 0.0) then fill_price
  else
    let factor = 1.0 +. (bps /. 10_000.0) in
    match side with Buy -> fill_price *. factor | Sell -> fill_price /. factor
