open Core

type variant = Long_only | Long_short [@@deriving show, eq]

type config = {
  ma_trading_days : int;
  rs_lookback_days : int;
  rebalance_days : int;
  top_k : int;
  variant : variant;
  slope_lookback_days : int;
  slope_threshold_pct : float;
}
[@@deriving show, eq]

let default_config =
  {
    ma_trading_days = 150;
    rs_lookback_days = 65;
    rebalance_days = 5;
    top_k = 5;
    variant = Long_only;
    slope_lookback_days = 30;
    slope_threshold_pct = 0.005;
  }

type decade_report = {
  decade_label : string;
  n_days : int;
  strategy_cagr : float;
  strategy_sharpe : float;
  strategy_maxdd : float;
  bh_cagr : float;
  bh_sharpe : float;
  bh_maxdd : float;
  pct_days_invested : float;
}
[@@deriving show, eq]

type result = {
  config : config;
  industries : string list;
  dates : Date.t array;
  strategy_daily_returns : float array;
  benchmark_daily_returns : float array;
  decade_reports : decade_report list;
}

(* ────────────────────────────────────────────────────────────
   Basket selection
   ──────────────────────────────────────────────────────────── *)

type basket = { long_idxs : int array; short_idxs : int array }

let _empty_basket = { long_idxs = [||]; short_idxs = [||] }

let _stage_at_with_config ~industries ~config i t =
  Universe.stage_at ~industry:industries.(i)
    ~ma_trading_days:config.ma_trading_days
    ~slope_lookback_days:config.slope_lookback_days
    ~slope_threshold_pct:config.slope_threshold_pct t

let _candidate_scores ~industries ~config t =
  let scores =
    Universe.relative_strengths ~industries
      ~rs_lookback_days:config.rs_lookback_days t
  in
  Array.filter_mapi scores ~f:(fun i s ->
      if Float.is_nan s then None
      else Some (i, s, _stage_at_with_config ~industries ~config i t))
  |> Array.to_list

let _take_top_by ~k candidates ~compare =
  List.sort candidates ~compare
  |> (fun xs -> List.take xs k)
  |> List.map ~f:(fun (i, _, _) -> i)
  |> Array.of_list

let _select_basket ~industries ~config t =
  let candidates = _candidate_scores ~industries ~config t in
  let by_stage stage =
    List.filter candidates ~f:(fun (_, _, s) -> Stage.equal_stage s stage)
  in
  let long_idxs =
    _take_top_by ~k:config.top_k (by_stage Stage.Stage2)
      ~compare:(fun (_, a, _) (_, b, _) -> Float.compare b a)
  in
  let short_idxs =
    match config.variant with
    | Long_only -> [||]
    | Long_short ->
        _take_top_by ~k:config.top_k (by_stage Stage.Stage4)
          ~compare:(fun (_, a, _) (_, b, _) -> Float.compare a b)
  in
  { long_idxs; short_idxs }

(* ────────────────────────────────────────────────────────────
   Daily portfolio return
   ──────────────────────────────────────────────────────────── *)

let _portfolio_daily_return ~industries ~basket ~config t =
  let k = Float.of_int config.top_k in
  if Float.(k <= 0.0) then 0.0
  else
    let weight = 1.0 /. k in
    let sum_returns idxs =
      Array.fold idxs ~init:0.0 ~f:(fun acc i ->
          acc +. industries.(i).Universe.returns.(t))
    in
    (sum_returns basket.long_idxs *. weight)
    -. (sum_returns basket.short_idxs *. weight)

let _gross_exposure ~basket ~config =
  let k = Float.of_int config.top_k in
  if Float.(k <= 0.0) then 0.0
  else
    let weight = 1.0 /. k in
    (Float.of_int (Array.length basket.long_idxs) *. weight)
    +. (Float.of_int (Array.length basket.short_idxs) *. weight)

(* ────────────────────────────────────────────────────────────
   Walk-forward loop
   ──────────────────────────────────────────────────────────── *)

(** No-look-ahead semantics: each day we first apply the *currently held* basket
    to day-t returns, THEN (if it's a rebalance day) update the basket for use
    on day t+1 onward. *)
let _run_strategy ~industries ~config ~n_days =
  let strategy = Array.create ~len:n_days 0.0 in
  let gross = Array.create ~len:n_days 0.0 in
  let basket = ref _empty_basket in
  let last_rebalance = ref (-1) in
  let first_decision_t = config.ma_trading_days + config.slope_lookback_days in
  for t = 0 to n_days - 1 do
    gross.(t) <- _gross_exposure ~basket:!basket ~config;
    strategy.(t) <-
      _portfolio_daily_return ~industries ~basket:!basket ~config t;
    if
      t >= first_decision_t
      && (!last_rebalance = -1 || t - !last_rebalance >= config.rebalance_days)
    then begin
      basket := _select_basket ~industries ~config t;
      last_rebalance := t
    end
  done;
  (strategy, gross)

(* ────────────────────────────────────────────────────────────
   Decade slicing
   ──────────────────────────────────────────────────────────── *)

let _trading_days_per_year = 252.0
let _decade_of (d : Date.t) = Date.year d / 10 * 10

let _mean arr =
  if Array.is_empty arr then 0.0
  else Array.fold arr ~init:0.0 ~f:( +. ) /. Float.of_int (Array.length arr)

let _decade_report ~decade ~bh ~strat ~gross =
  {
    decade_label = sprintf "%ds" decade;
    n_days = Array.length bh;
    strategy_cagr =
      Metrics.cagr ~returns:strat ~periods_per_year:_trading_days_per_year;
    strategy_sharpe =
      Metrics.sharpe ~returns:strat ~periods_per_year:_trading_days_per_year;
    strategy_maxdd = Metrics.max_drawdown ~returns:strat;
    bh_cagr = Metrics.cagr ~returns:bh ~periods_per_year:_trading_days_per_year;
    bh_sharpe =
      Metrics.sharpe ~returns:bh ~periods_per_year:_trading_days_per_year;
    bh_maxdd = Metrics.max_drawdown ~returns:bh;
    pct_days_invested = 100.0 *. _mean gross;
  }

let _push_to_decade ~by_decade ~i ~dates ~strategy ~benchmark ~gross =
  let dec = _decade_of dates.(i) in
  let bh_l, strat_l, gross_l =
    Hashtbl.find_or_add by_decade dec ~default:(fun () -> ([], [], []))
  in
  Hashtbl.set by_decade ~key:dec
    ~data:(benchmark.(i) :: bh_l, strategy.(i) :: strat_l, gross.(i) :: gross_l)

let _decade_report_for ~by_decade decade =
  let bh_l, strat_l, gross_l = Hashtbl.find_exn by_decade decade in
  _decade_report ~decade ~bh:(Array.of_list_rev bh_l)
    ~strat:(Array.of_list_rev strat_l)
    ~gross:(Array.of_list_rev gross_l)

let _build_decade_reports ~dates ~strategy ~benchmark ~gross =
  let by_decade = Hashtbl.create (module Int) in
  Array.iteri dates ~f:(fun i _ ->
      _push_to_decade ~by_decade ~i ~dates ~strategy ~benchmark ~gross);
  Hashtbl.keys by_decade
  |> List.sort ~compare:Int.compare
  |> List.map ~f:(_decade_report_for ~by_decade)

(* ────────────────────────────────────────────────────────────
   Entry point
   ──────────────────────────────────────────────────────────── *)

let compute_strategy ~rows ~industries ~config =
  let n_days = Array.length rows in
  let industries_arr =
    Universe.build ~rows ~industries ~ma_trading_days:config.ma_trading_days
  in
  let strategy_daily_returns, gross =
    _run_strategy ~industries:industries_arr ~config ~n_days
  in
  let benchmark_daily_returns =
    Array.init n_days ~f:(fun t ->
        Universe.benchmark_return ~industries:industries_arr t)
  in
  let dates = Array.map rows ~f:(fun (r : Loader.daily_row) -> r.date) in
  let decade_reports =
    _build_decade_reports ~dates ~strategy:strategy_daily_returns
      ~benchmark:benchmark_daily_returns ~gross
  in
  {
    config;
    industries;
    dates;
    strategy_daily_returns;
    benchmark_daily_returns;
    decade_reports;
  }
