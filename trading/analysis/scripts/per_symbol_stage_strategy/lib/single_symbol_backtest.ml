open Core
open Csv
open Types
module Stage_lib = Stage

type result = {
  symbol : string;
  variant : Stage_signal.variant;
  start_date : Date.t;
  end_date : Date.t;
  initial_cash : float;
  final_equity : float;
  strategy_cagr : float;
  strategy_sharpe : float;
  strategy_max_dd : float;
  bah_cagr : float;
  bah_max_dd : float;
  num_long_entries : int;
  num_short_entries : int;
  pct_time_long : float;
  pct_time_short : float;
  avg_holding_days : float;
  trades : Walk_step.trade list;
  year_end_equity : (int * float) list;
}
[@@deriving show]

let _default_bid_ask_bps = 0.5

(* ------------------------------------------------------------------ *)
(* Walk state                                                          *)
(* ------------------------------------------------------------------ *)

(* Mutable state threaded through the per-week loop. Refs are local to
   [_simulate] — never escape. *)
type _walk_state = {
  mutable cash : float;
  mutable position : Walk_step.position;
  mutable trades_rev : Walk_step.trade list;
  mutable num_long_entries : int;
  mutable num_short_entries : int;
  mutable weeks_long : int;
  mutable weeks_short : int;
  mutable prior_stage : Weinstein_types.stage option;
  mutable bar_index : int;
  equity : float array;
  classification_dates : Date.t array;
}

let _bump_entry_counter ~state ~action =
  match action with
  | Stage_signal.Enter_long ->
      state.num_long_entries <- state.num_long_entries + 1
  | Enter_short -> state.num_short_entries <- state.num_short_entries + 1
  | _ -> ()

let _bump_time_counter ~state =
  match state.position with
  | Long _ -> state.weeks_long <- state.weeks_long + 1
  | Short _ -> state.weeks_short <- state.weeks_short + 1
  | Flat -> ()

(* ------------------------------------------------------------------ *)
(* Per-week step                                                       *)
(* ------------------------------------------------------------------ *)

let _process_one_week ~config ~variant ~bid_ask_bps ~state ~bars_so_far ~bar =
  let stage_result =
    Stage_lib.classify ~config ~bars:bars_so_far ~prior_stage:state.prior_stage
  in
  let action =
    Stage_signal.action_of_transition ~variant ~prev_stage:state.prior_stage
      ~curr_stage:stage_result.stage
  in
  let cash', pos', trade_opt =
    Walk_step.step ~action ~close:bar.Daily_price.close_price ~date:bar.date
      ~bid_ask_bps ~cash:state.cash ~position:state.position
  in
  state.cash <- cash';
  state.position <- pos';
  (match trade_opt with
  | Some t -> state.trades_rev <- t :: state.trades_rev
  | None -> ());
  _bump_entry_counter ~state ~action;
  state.prior_stage <- Some stage_result.stage;
  let week_equity =
    Walk_step.mtm_equity ~cash:state.cash ~position:state.position
      ~close:bar.close_price
  in
  state.equity.(state.bar_index) <- week_equity;
  state.classification_dates.(state.bar_index) <- bar.date;
  state.bar_index <- state.bar_index + 1;
  _bump_time_counter ~state

(* Year-end equity samples + BAH baseline live in Bah_baseline.
   (Extracted 2026-05-29 to keep this file under the 300-line limit.) *)

(* ------------------------------------------------------------------ *)
(* Simulation driver                                                   *)
(* ------------------------------------------------------------------ *)

(* Build the warmup + run partition: bars strictly before [start_date]
   are warmup-only; bars on or after [start_date] are simulated. We pass
   ALL bars-so-far to [Stage.classify] each week so the classifier has its
   30-week MA available from week 1 of simulation. *)
let _split_warmup ~weekly_bars ~start_date =
  List.partition_tf weekly_bars ~f:(fun b ->
      Date.( < ) b.Daily_price.date start_date)

let _trade_days (t : Walk_step.trade) = Date.diff t.exit_date t.entry_date

let _total_holding_days ~trades =
  List.fold trades ~init:0 ~f:(fun acc t -> acc + _trade_days t)

let _avg_holding_days ~trades =
  match trades with
  | [] -> 0.0
  | _ ->
      Float.of_int (_total_holding_days ~trades)
      /. Float.of_int (List.length trades)

let _init_state ~initial_cash ~n_run =
  {
    cash = initial_cash;
    position = Walk_step.Flat;
    trades_rev = [];
    num_long_entries = 0;
    num_short_entries = 0;
    weeks_long = 0;
    weeks_short = 0;
    prior_stage = None;
    bar_index = 0;
    equity = Array.create ~len:n_run 0.0;
    classification_dates = Array.create ~len:n_run (Date.of_string "1900-01-01");
  }

(* Iterate over the in-run weekly bars; the warmup tail is appended to the
   left-fold accumulator as the new bar is added so [Stage.classify] sees
   the growing window in chronological order. *)
let _simulate ~config ~variant ~bid_ask_bps ~initial_cash ~weekly_bars
    ~start_date =
  let warmup, run = _split_warmup ~weekly_bars ~start_date in
  let n_run = List.length run in
  let state = _init_state ~initial_cash ~n_run in
  let bars_so_far_ref = ref warmup in
  List.iter run ~f:(fun bar ->
      bars_so_far_ref := !bars_so_far_ref @ [ bar ];
      _process_one_week ~config ~variant ~bid_ask_bps ~state
        ~bars_so_far:!bars_so_far_ref ~bar);
  state

(* Force-close any open position at the final weekly bar so the realised
   final equity reflects cash-only state and the equity curve's last sample
   is comparable across runs. The resulting trade IS appended to
   [trades_rev] but NOT counted in [num_long_entries]/[num_short_entries]
   (those count entries — the forced close consumes an already-counted
   entry). *)
let _apply_force_close ~state ~final_bar ~bid_ask_bps =
  let cash', pos', trade_opt =
    Walk_step.force_close_at_end ~position:state.position ~cash:state.cash
      ~final_bar ~bid_ask_bps
  in
  state.cash <- cash';
  state.position <- pos';
  match trade_opt with
  | Some t -> state.trades_rev <- t :: state.trades_rev
  | None -> ()

(* ------------------------------------------------------------------ *)
(* Result assembly                                                     *)
(* ------------------------------------------------------------------ *)

let _pct_time ~weeks ~total =
  if total = 0 then 0.0 else Float.of_int weeks /. Float.of_int total

let _build_result ~symbol ~variant ~start_date ~end_date ~initial_cash
    ~weekly_bars ~state =
  let equity = state.equity in
  let returns = Equity_metrics.returns_from_equity ~equity in
  let total_weeks = Array.length equity in
  let trades = List.rev state.trades_rev in
  let year_end_equity =
    Bah_baseline.year_end_equity ~dates:state.classification_dates ~equity
  in
  {
    symbol;
    variant;
    start_date;
    end_date;
    initial_cash;
    final_equity =
      (if total_weeks = 0 then initial_cash else equity.(total_weeks - 1));
    strategy_cagr = Equity_metrics.cagr_from_returns ~returns;
    strategy_sharpe = Equity_metrics.sharpe_from_returns ~returns;
    strategy_max_dd = Equity_metrics.max_drawdown_from_equity ~equity;
    bah_cagr = fst (Bah_baseline.metrics ~weekly_bars ~initial_cash);
    bah_max_dd = snd (Bah_baseline.metrics ~weekly_bars ~initial_cash);
    num_long_entries = state.num_long_entries;
    num_short_entries = state.num_short_entries;
    pct_time_long = _pct_time ~weeks:state.weeks_long ~total:total_weeks;
    pct_time_short = _pct_time ~weeks:state.weeks_short ~total:total_weeks;
    avg_holding_days = _avg_holding_days ~trades;
    trades;
    year_end_equity;
  }

(* ------------------------------------------------------------------ *)
(* Bar loading + validation                                            *)
(* ------------------------------------------------------------------ *)

let _load_bars ~data_dir ~symbol ~end_date =
  match Csv_storage.create ~data_dir symbol with
  | Error e -> Error e
  | Ok storage -> Csv_storage.get storage ~end_date ()

(* Validation: a usable bar series must have AT LEAST [ma_period +
   slope_lookback] weekly bars (otherwise the classifier has no signal). *)
let _too_few_bars_error ~symbol ~n ~min_weeks =
  Status.invalid_argument_error
    (sprintf "%s: only %d weekly bars, need >= %d for stage classifier" symbol n
       min_weeks)

let _validate_weekly_bars ~symbol ~config ~weekly_bars =
  let min_weeks =
    config.Stage_lib.ma_period + config.Stage_lib.slope_lookback
  in
  let n = List.length weekly_bars in
  if n < min_weeks then Error (_too_few_bars_error ~symbol ~n ~min_weeks)
  else Ok ()

(* ------------------------------------------------------------------ *)
(* Public entry point                                                  *)
(* ------------------------------------------------------------------ *)

let _in_window ~weekly_bars ~start_date =
  List.filter weekly_bars ~f:(fun b ->
      Date.( >= ) b.Daily_price.date start_date)

let _maybe_force_close ~state ~in_run ~bid_ask_bps =
  match List.last in_run with
  | None -> ()
  | Some final_bar -> _apply_force_close ~state ~final_bar ~bid_ask_bps

let _run_validated ~config ~variant ~bid_ask_bps ~initial_cash ~weekly_bars
    ~start_date ~end_date ~symbol =
  let state =
    _simulate ~config ~variant ~bid_ask_bps ~initial_cash ~weekly_bars
      ~start_date
  in
  let in_run = _in_window ~weekly_bars ~start_date in
  _maybe_force_close ~state ~in_run ~bid_ask_bps;
  _build_result ~symbol ~variant ~start_date ~end_date ~initial_cash
    ~weekly_bars:in_run ~state

let _run_with_bars ~config ~variant ~bid_ask_bps ~initial_cash ~start_date
    ~end_date ~symbol daily_bars =
  let weekly_bars =
    Time_period.Conversion.daily_to_weekly ~include_partial_week:false
      daily_bars
  in
  Result.map (_validate_weekly_bars ~symbol ~config ~weekly_bars) ~f:(fun () ->
      _run_validated ~config ~variant ~bid_ask_bps ~initial_cash ~weekly_bars
        ~start_date ~end_date ~symbol)

let run ~data_dir ~symbol ~start_date ~end_date ~initial_cash ~variant
    ?(bid_ask_bps = _default_bid_ask_bps) () =
  let config = Stage_lib.default_config in
  Result.bind
    (_load_bars ~data_dir ~symbol ~end_date)
    ~f:
      (_run_with_bars ~config ~variant ~bid_ask_bps ~initial_cash ~start_date
         ~end_date ~symbol)
