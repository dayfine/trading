open Core
module Bar_reader = Weinstein_strategy.Bar_reader

let series_for bar_reader ~as_of ~symbol : Rename_detector.series =
  let bars = Bar_reader.daily_bars_for bar_reader ~symbol ~as_of in
  {
    symbol;
    closes =
      Array.of_list_map bars ~f:(fun (b : Types.Daily_price.t) ->
          (b.date, b.adjusted_close));
  }

let _report_for bar_reader ~as_of ~config tickers =
  let series =
    List.map tickers ~f:(fun symbol -> series_for bar_reader ~as_of ~symbol)
  in
  Rename_detector.detect config ~as_of series

let partition bar_reader ~as_of ~min_overlap_days ~match_fraction tickers =
  let config = Rename_detector.Config.armed ~min_overlap_days ~match_fraction in
  (* Short-circuit before any series is read: the disabled path must cost
     nothing, not merely return nothing. *)
  if not config.enabled then (tickers, [])
  else
    let report = _report_for bar_reader ~as_of ~config tickers in
    ( Rename_detector.survivors report ~all_symbols:tickers,
      Rename_detector.warnings report )
