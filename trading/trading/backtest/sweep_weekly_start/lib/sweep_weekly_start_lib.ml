open Core
module Scenario_strategy = Backtest.Strategy_choice
module Metric_types = Trading_simulation_types.Metric_types

(* Data model and end-date guard re-exported from their own modules. *)
include Sweep_types

let default_max_end_date_gap_days = End_date_guard.default_max_end_date_gap_days
let resolve_coverage = End_date_guard.resolve_coverage
let effective_end_date = End_date_guard.effective_end_date
let load_coverage = End_date_guard.load_coverage
let _epoch = Date.create_exn ~y:1970 ~m:Jan ~d:1

(** Walk forward from [d] until we hit a Monday; returns the first Monday at or
    after [d]. Bounded by 7 iterations since the weekday cycles. *)
let _first_monday_on_or_after (d : Date.t) =
  let rec loop d remaining =
    if remaining = 0 then d
    else
      match Date.day_of_week d with
      | Day_of_week.Mon -> d
      | _ -> loop (Date.add_days d 1) (remaining - 1)
  in
  loop d 7

let mondays_in_window ~end_date ~years_back =
  let window_start = Date.add_years end_date (-years_back) in
  let first_monday = _first_monday_on_or_after window_start in
  let rec loop d acc =
    if Date.( >= ) d end_date then List.rev acc
    else loop (Date.add_days d 7) (d :: acc)
  in
  loop first_monday []

(** Cell selector for [List.{max,min}_elt] keyed by CAGR. *)
let _compare_cell_by_cagr (a : cell) (b : cell) = Float.compare a.cagr b.cagr

let _median (xs : float list) =
  let sorted = List.sort xs ~compare:Float.compare in
  let n = List.length sorted in
  if n = 0 then 0.0
  else if n % 2 = 1 then List.nth_exn sorted (n / 2)
  else
    let a = List.nth_exn sorted ((n / 2) - 1) in
    let b = List.nth_exn sorted (n / 2) in
    (a +. b) /. 2.0

let _mean (xs : float list) =
  match xs with
  | [] -> 0.0
  | _ -> List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int (List.length xs)

let _stddev (xs : float list) =
  let n = List.length xs in
  if n < 2 then 0.0
  else
    let m = _mean xs in
    let sum_sq =
      List.fold xs ~init:0.0 ~f:(fun acc x ->
          let d = x -. m in
          acc +. (d *. d))
    in
    Float.sqrt (sum_sq /. Float.of_int (n - 1))

let _empty_summary =
  {
    best_cell_start = _epoch;
    best_cagr = 0.0;
    worst_cell_start = _epoch;
    worst_cagr = 0.0;
    median_cagr = 0.0;
    mean_cagr = 0.0;
    stddev_cagr = 0.0;
    n_cells = 0;
  }

let _summary_of_nonempty (cells : cell list) =
  let best_c =
    Option.value_exn (List.max_elt cells ~compare:_compare_cell_by_cagr)
  in
  let worst_c =
    Option.value_exn (List.min_elt cells ~compare:_compare_cell_by_cagr)
  in
  let cagrs = List.map cells ~f:(fun c -> c.cagr) in
  {
    best_cell_start = best_c.start_date;
    best_cagr = best_c.cagr;
    worst_cell_start = worst_c.start_date;
    worst_cagr = worst_c.cagr;
    median_cagr = _median cagrs;
    mean_cagr = _mean cagrs;
    stddev_cagr = _stddev cagrs;
    n_cells = List.length cells;
  }

let summarize (cells : cell list) =
  match cells with [] -> _empty_summary | _ -> _summary_of_nonempty cells

let format_sexp (r : sweep_result) = sexp_of_sweep_result r

(** Sample [n] evenly-spaced cells from [xs] including endpoints. When
    [n >= List.length xs], returns [xs] unchanged. *)
let _sample_evenly (xs : 'a list) ~n =
  let total = List.length xs in
  if n >= total then xs
  else if n <= 0 then []
  else if n = 1 then [ List.hd_exn xs ]
  else
    let arr = Array.of_list xs in
    let step = Float.of_int (total - 1) /. Float.of_int (n - 1) in
    List.init n ~f:(fun i ->
        let idx = Float.iround_exn ~dir:`Nearest (Float.of_int i *. step) in
        arr.(idx))

let _format_money v = Printf.sprintf "$%s" (Float.to_string_hum v ~decimals:0)
let _format_pct v = Printf.sprintf "%.2f%%" (v *. 100.0)
let _format_sharpe v = Printf.sprintf "%.2f" v

let _format_row (idx : int) (c : cell) =
  Printf.sprintf "| %d | %s | %s | %s | %s | %s | %s |" (idx + 1)
    (Date.to_string c.start_date)
    (_format_money c.final_value)
    (_format_pct c.total_return)
    (_format_pct c.cagr)
    (_format_pct (-1.0 *. c.max_dd))
    (_format_sharpe c.sharpe)

let _header_block (r : sweep_result) =
  Printf.sprintf
    "# Weekly-start sweep -- BAH %s\n\n\
     Run date: %s\n\
     End date: %s\n\
     %sWindow: %d years trailing\n\
     Cells: %d (one per Monday)\n\
     Dropped cells: %d\n\
     Initial: %s\n\
     %s"
    r.symbol
    (Date.to_string r.run_date)
    (Date.to_string r.end_date)
    (End_date_guard.last_bar_line r)
    r.years_back r.summary.n_cells
    (List.length r.dropped_cells)
    (_format_money r.initial_cash)
    (End_date_guard.clamp_warning r)

let _summary_block (s : summary) =
  Printf.sprintf
    "\n\
     ## Summary\n\n\
     - Best entry (highest CAGR to end_date): %s -> CAGR %s\n\
     - Worst entry: %s -> CAGR %s\n\
     - Median CAGR: %s\n\
     - Mean CAGR: %s\n\
     - Stddev across cells: %s\n"
    (Date.to_string s.best_cell_start)
    (_format_pct s.best_cagr)
    (Date.to_string s.worst_cell_start)
    (_format_pct s.worst_cagr)
    (_format_pct s.median_cagr)
    (_format_pct s.mean_cagr)
    (_format_pct s.stddev_cagr)

let _table_block ?max_cells (cells : cell list) =
  let header =
    "\n\
     ## Distribution\n\n\
     | Cell | Start | Final $ | Total Return | CAGR | Max DD | Sharpe |\n\
     |------|-------|---------|--------------|------|--------|--------|"
  in
  let rows =
    match max_cells with None -> cells | Some n -> _sample_evenly cells ~n
  in
  let row_lines = List.mapi rows ~f:_format_row |> String.concat ~sep:"\n" in
  header ^ "\n" ^ row_lines ^ "\n"

let format_markdown ?max_cells (r : sweep_result) =
  let dropped = End_date_guard.dropped_block r.dropped_cells in
  if List.is_empty r.cells then
    Printf.sprintf "%s\n(no cells in window)\n%s" (_header_block r) dropped
  else
    let header = _header_block r in
    let summary = _summary_block r.summary in
    let table = _table_block ?max_cells r.cells in
    header ^ summary ^ table ^ dropped

let _metric_or_default (m : Metric_types.metric_set)
    (key : Metric_types.metric_type) ~default =
  match Map.find m key with
  | Some v when Float.is_finite v -> v
  | Some _ | None -> default

(** Extract the (total_return, cagr, max_dd, sharpe) tuple from the simulator's
    [Metric_set]. Values are scaled from percent to fraction where appropriate
    so cells compose with [Float] arithmetic. *)
let _metrics_to_cell_fields ~final_value ~initial_cash
    (metrics : Metric_types.metric_set) =
  let cagr_pct = _metric_or_default metrics CAGR ~default:0.0 in
  let max_dd_pct = _metric_or_default metrics MaxDrawdown ~default:0.0 in
  let sharpe = _metric_or_default metrics SharpeRatio ~default:0.0 in
  let total_return = (final_value -. initial_cash) /. initial_cash in
  (total_return, cagr_pct /. 100.0, Float.abs max_dd_pct /. 100.0, sharpe)

let _run_one_exn (cfg : config) (start_date : Date.t) ~sector_map_override =
  let strategy_choice : Scenario_strategy.t =
    Scenario_strategy.Bah_benchmark { symbol = cfg.symbol }
  in
  (* [Backtest.Runner] hardcodes [initial_cash = $1,000,000] and the runner
     does not currently accept an override for that value. BAH is linear in
     initial cash to a near-zero residual (commissions are $0.01/share, so on
     a $1M -> $100k re-scaling the commission drag changes by ~10x relative
     to final equity but ~$40 absolute — negligible for entry-timing
     dispersion analysis). We accept the small bias and re-scale the final
     value proportionally so the [cell.final_value] field matches the
     user-configured [initial_cash]. Returns / CAGR / Sharpe / max-DD are all
     ratios and don't need re-scaling. *)
  let result =
    Backtest.Runner.run_backtest ~start_date ~end_date:cfg.end_date
      ~sector_map_override ~strategy_choice ()
  in
  let summary = result.summary in
  let runner_initial = summary.initial_cash in
  let scale = cfg.initial_cash /. runner_initial in
  let scaled_final = summary.final_portfolio_value *. scale in
  let total_return, cagr, max_dd, sharpe =
    _metrics_to_cell_fields ~final_value:summary.final_portfolio_value
      ~initial_cash:runner_initial summary.metrics
  in
  { start_date; final_value = scaled_final; total_return; cagr; max_dd; sharpe }

let skip_message (start_date : Date.t) (exn : exn) =
  Printf.sprintf "sweep_weekly_start: skipping cell start_date=%s -- %s"
    (Date.to_string start_date)
    (Stdlib.Printexc.to_string exn)

(** Report a cell dropped because its window held no trading day. Printed rather
    than swallowed: the artefact's [n_cells] shrinks silently otherwise, and the
    usual cause (the committed bars stop before the floating [end_date]) is a
    data-floor problem the workflow log should surface. The content lives in the
    pure {!skip_message} so a test can pin what the line says without capturing
    stderr. *)
let _warn_skipped_cell (start_date : Date.t) (exn : exn) =
  eprintf "%s\n%!" (skip_message start_date exn)

let run_one (cfg : config) (start_date : Date.t) ~sector_map_override =
  match _run_one_exn cfg start_date ~sector_map_override with
  | cell -> Ok cell
  | exception (Backtest.Window_filter.Empty_measurement_window _ as exn) ->
      _warn_skipped_cell start_date exn;
      Error { start_date; reason = Stdlib.Printexc.to_string exn }

let _full_sector_map_unsupported path =
  failwith
    (Printf.sprintf
       "sweep_weekly_start: universe %s resolved to Full_sector_map; the sweep \
        requires a pinned universe with [Pinned] entries."
       path)

(** Load the pinned universe and convert it to the [sector_map_override] shape
    [Backtest.Runner.run_backtest] expects. Fails when the universe file
    resolves to [Full_sector_map] — the sweep cannot operate against the
    ~10k-symbol broad universe (one snapshot per cell would be prohibitive). *)
let _load_pinned_sector_map ~fixtures_root ~universe_path =
  let full_path = Filename.concat fixtures_root universe_path in
  let universe = Scenario_lib.Universe_file.load full_path in
  match Scenario_lib.Universe_file.to_sector_map_override universe with
  | Some tbl -> tbl
  | None -> _full_sector_map_unsupported full_path

let run (cfg : config) =
  let sector_map_override =
    _load_pinned_sector_map ~fixtures_root:cfg.fixtures_root
      ~universe_path:cfg.universe_path
  in
  let coverage =
    load_coverage
      ~data_dir:(Data_path.default_data_dir ())
      ~symbol:cfg.symbol ~requested_end_date:cfg.end_date
      ~tolerance_days:cfg.max_end_date_gap_days
  in
  End_date_guard.warn_if_clamped cfg.symbol coverage;
  let end_date = effective_end_date coverage in
  let cell_cfg = { cfg with end_date } in
  let mondays = mondays_in_window ~end_date ~years_back:cfg.years_back in
  let cells, dropped_cells =
    List.partition_result
      (List.map mondays ~f:(fun start_date ->
           run_one cell_cfg start_date ~sector_map_override))
  in
  {
    run_date = cfg.end_date;
    end_date;
    coverage = Some coverage;
    dropped_cells;
    symbol = cfg.symbol;
    initial_cash = cfg.initial_cash;
    years_back = cfg.years_back;
    cells;
    summary = summarize cells;
  }
