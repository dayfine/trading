(** Single-symbol monthly Weinstein-style reduction on the Shiller S&P composite
    series.

    Strategy:
    - Compute Stan Weinstein's canonical 30-week moving average over [sp_price].
      The underlying data is monthly, so the default [ma_window = Weeks 30] is
      converted internally to ~7 monthly bars (see
      {!Shiller_decades_metrics.ma_window_to_months}). Operators override the
      window length via [-ma-window] (supports day / week / month units; see
      {!Shiller_decades_metrics.parse_ma_window_arg}).
    - Long the index when current price > MA AND MA is rising (price[t] > ma[t]
      AND ma[t] > ma[t-1]). Cash otherwise. No shorts in this reduction.
    - Returns are computed on a monthly basis. The strategy participates in
      month t's return iff it was Long at the end of month t-1 (i.e. the
      Long-cash decision is applied with a one-month lag, matching the "decision
      at end-of-week, holds through next week" cadence the production strategy
      uses on weekly bars).

    Output: a decade-by-decade table (1870s through 2020s) with CAGR, Sharpe,
    MaxDD for both the strategy and a buy-and-hold benchmark, plus headline
    155-year totals, β diagnostic, Stage 1-4 classification breakdown, and
    optional per-decade ASCII charts.

    Limitations (per dev/plans/cross-cycle-weinstein-validation-2026-05-19.md):
    - Index-level only. No cross-sectional ranking, no sector rotation.
    - Monthly granularity. Can't measure intra-month stop performance.
    - The MA window is rounded to whole months at the data boundary, so
      [Weeks 30] → 7 month-bars, [Days 150] → 5 month-bars, etc. Fine for the
      "does the framework profit at all in 1929 / 1973 / 2000?" question; if you
      need finer resolution use weekly-bar data downstream. *)

open Core
module Client = Shiller.Shiller_client
open Shiller_decades_metrics
open Shiller_decades_stage
open Shiller_decades_report

let load_series ~csv_path =
  let body = In_channel.read_all csv_path in
  Shiller_decades_csv.parse_derived_csv body

let maybe_chart_decades ~chart_decades ~prices ~ma ~stages ~obs =
  let stage_dates = Array.map obs ~f:(fun o -> o.Client.period) in
  let n = Array.length prices in
  List.iter chart_decades ~f:(fun dec ->
      let from_idx = ref None in
      let to_idx = ref None in
      for i = 0 to n - 1 do
        let y = Date.year stage_dates.(i) in
        let target_dec = y / 10 * 10 in
        if target_dec = dec then begin
          if Option.is_none !from_idx then from_idx := Some i;
          to_idx := Some i
        end
      done;
      match (!from_idx, !to_idx) with
      | Some f, Some t ->
          Shiller_decades_chart.ascii_chart ~prices ~ma ~stages
            ~dates:stage_dates ~from_idx:f ~to_idx:t
            ~title:(sprintf "%ds chart" dec)
      | _ -> ())

let run ~csv_path ~chart_decades ~ma_window =
  let ma_window_months = ma_window_to_months ma_window in
  let series = load_series ~csv_path in
  let obs = Array.of_list series.observations in
  let prices = Array.map obs ~f:(fun o -> o.Client.sp_price) in
  let dates =
    Array.map obs ~f:(fun o -> o.Client.period) |> fun arr ->
    Array.sub arr ~pos:1 ~len:(Array.length arr - 1)
  in
  printf "MA window: %s (= %d monthly bars)\n"
    (format_ma_window ma_window)
    ma_window_months;
  let ma = moving_average prices ~window:ma_window_months in
  let bh_rs = monthly_returns prices in
  let strat_rs = strategy_returns ~prices ~ma in
  let strategy_signal =
    Array.init (Array.length bh_rs) ~f:(fun i -> is_long ~prices ~ma i)
  in
  let by_decade = slice_by_decade ~periods:dates ~rs:bh_rs ~strategy_signal in
  let decs = Hashtbl.keys by_decade |> List.sort ~compare:Int.compare in
  let reports =
    List.map decs ~f:(fun decade ->
        let bh_rs_d, strat_rs_d, _, n_long =
          Hashtbl.find_exn by_decade decade
        in
        decade_report ~decade ~bh_rs:bh_rs_d ~strat_rs:strat_rs_d ~n_long)
  in
  print_table reports;
  print_headline ~strat_rs ~bh_rs;
  let stages =
    Array.init (Array.length prices) ~f:(fun t -> classify_stage ~prices ~ma t)
  in
  let stage_dates = Array.map obs ~f:(fun o -> o.Client.period) in
  print_stage_breakdown ~stages ~dates:stage_dates;
  let transitions = count_transitions ~stages in
  let beta = beta strat_rs bh_rs in
  printf
    "\n\
     === Diagnostics ===\n\
     β (strat vs B&H): %.3f (β<1 = lower-vol regime)\n\
     Stage transitions (whipsaw count): %d over %d months (%.1f per decade)\n"
    beta transitions (Array.length stages)
    (Float.of_int transitions /. Float.of_int (Array.length stages) *. 120.0);
  maybe_chart_decades ~chart_decades ~prices ~ma ~stages ~obs

let command =
  Command.basic
    ~summary:"single-symbol monthly Weinstein reduction on Shiller S&P"
    (let%map_open.Command csv_path =
       flag "-csv" (required string)
         ~doc:
           "PATH parsed Shiller monthly CSV (output of fetch_shiller_history)"
     and chart_decades_str =
       flag "-chart-decades"
         (optional_with_default "" string)
         ~doc:
           "CSV comma-separated decade starts to chart, e.g. '1920,1970,2000'"
     and ma_window_str =
       flag "-ma-window"
         (optional_with_default "30w" string)
         ~doc:
           "STR moving-average window, unit-tagged. Accepts '30w' (weeks, \
            default, ≈ Stan's canonical 30wk), '7m'/'7mo' (months), '150d' \
            (days), or a bare integer (= months for backward compat)."
     in
     fun () ->
       let chart_decades =
         if String.is_empty chart_decades_str then []
         else
           String.split chart_decades_str ~on:','
           |> List.map ~f:String.strip
           |> List.filter ~f:(fun s -> not (String.is_empty s))
           |> List.map ~f:Int.of_string
       in
       let ma_window = parse_ma_window_arg ma_window_str in
       run ~csv_path ~chart_decades ~ma_window)

let () = Command_unix.run command
