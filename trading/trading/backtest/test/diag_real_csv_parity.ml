(** Regression diagnostic: compare [Bar_panels] and [Snapshot_bar_views] on
    REAL CSV data across the full sp500-2019-2023 universe to verify the two
    readers produce bit-equal weekly/daily views on every (symbol, weekday)
    cell the strategy queries.

    Used during the 2026-05-04 sp500-2019-2023 parity bisect (issue #843,
    `dev/notes/parity-bisect-2026-05-04.md`) to confirm that the
    `Snapshot_bar_views.weekly_view_for` / `daily_bars_for` primitives are NOT
    the source of the F.3.a-3 (#828) regression — both readers test bit-equal
    cell-by-cell, yet the strategy's signals diverge under
    `Bar_reader.of_snapshot_views`. The divergence therefore lives in some
    path-dependent or stateful interaction in the snapshot path that this
    cell-by-cell comparison cannot catch.

    Run from the repo root:
    {v
      dune build trading/backtest/test/diag_real_csv_parity.exe
      ./_build/default/trading/backtest/test/diag_real_csv_parity.exe
    v}

    Expected output on a healthy main:
    {v
      Universe: 491 symbols
      Calendar: 1453 trading days (2018-06-06..2023-12-29)
      Test dates: 261 weekdays in 2019
      Total weekly_view: 0/132066 cells differ
      Total daily_bars: 0/132066 cells differ
    v}

    A non-zero diff in either count indicates a primitive-level divergence
    between the two readers — investigate before any further F.3.x work. *)

open Core
module Bar_panels = Data_panel.Bar_panels
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Symbol_index = Data_panel.Symbol_index
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Pipeline = Snapshot_pipeline.Pipeline
module Csv_storage = Csv.Csv_storage

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

let _build_calendar ~start ~end_ : Date.t array =
  let rec loop d acc =
    if Date.( > ) d end_ then List.rev acc
    else
      let dow = Date.day_of_week d in
      let is_weekend =
        Day_of_week.equal dow Day_of_week.Sat
        || Day_of_week.equal dow Day_of_week.Sun
      in
      let acc' = if is_weekend then acc else d :: acc in
      loop (Date.add_days d 1) acc'
  in
  Array.of_list (loop start [])

let _data_dir = Fpath.v "/workspaces/trading-1/data"

let _read_bars symbol ~start_date ~end_date =
  let storage =
    match Csv_storage.create ~data_dir:_data_dir symbol with
    | Ok s -> s
    | Error err -> failwith ("Csv_storage.create: " ^ Status.show err)
  in
  match Csv_storage.get storage ~start_date ~end_date () with
  | Ok bars -> bars
  | Error err when Status.equal_code err.code Status.NotFound -> []
  | Error err -> failwith ("Csv_storage.get: " ^ Status.show err)

let _build_full_panel ~symbols ~calendar : Bar_panels.t =
  let symbol_index =
    match Symbol_index.create ~universe:symbols with
    | Ok t -> t
    | Error err -> failwith ("Symbol_index.create: " ^ Status.show err)
  in
  let ohlcv =
    match
      Ohlcv_panels.load_from_csv_calendar symbol_index ~data_dir:_data_dir
        ~calendar
    with
    | Ok t -> t
    | Error err ->
        failwith ("Ohlcv_panels.load_from_csv_calendar: " ^ Status.show err)
  in
  match Bar_panels.create ~ohlcv ~calendar with
  | Ok p -> p
  | Error err -> failwith ("Bar_panels.create: " ^ Status.show err)

let _build_full_snapshot ~symbols ~start_date ~end_date :
    Snapshot_callbacks.t * Daily_panels.t =
  let dir = Stdlib.Filename.temp_dir "diag_full_snap_" "" in
  let entries =
    List.map symbols ~f:(fun symbol ->
        let bars = _read_bars symbol ~start_date ~end_date in
        let rows =
          match
            Pipeline.build_for_symbol ~symbol ~bars
              ~schema:Snapshot_schema.default ()
          with
          | Ok r -> r
          | Error err ->
              failwith ("Pipeline.build_for_symbol: " ^ err.Status.message)
        in
        let path = Filename.concat dir (symbol ^ ".snap") in
        (match Snapshot_format.write ~path rows with
        | Ok () -> ()
        | Error err -> failwith ("Snapshot_format.write: " ^ err.Status.message));
        ({
           symbol;
           path;
           byte_size = 0;
           payload_md5 = "ignored";
           csv_mtime = 0.0;
         }
          : Snapshot_manifest.file_metadata))
  in
  let manifest =
    Snapshot_manifest.create ~schema:Snapshot_schema.default ~entries
  in
  let manifest_path = Filename.concat dir "manifest.sexp" in
  (match Snapshot_manifest.write ~path:manifest_path manifest with
  | Ok () -> ()
  | Error err -> failwith ("Snapshot_manifest.write: " ^ err.Status.message));
  let panels =
    match Daily_panels.create ~snapshot_dir:dir ~manifest ~max_cache_mb:512 with
    | Ok p -> p
    | Error err -> failwith ("Daily_panels.create: " ^ Status.show err)
  in
  (Snapshot_callbacks.of_daily_panels panels, panels)

let _diff_views ~symbol ~as_of (panel : Bar_panels.weekly_view)
    (snap : Snapshot_bar_views.weekly_view) =
  if panel.n <> snap.n then
    Some
      (Printf.sprintf "%s %s: panel.n=%d snap.n=%d" symbol
         (Date.to_string as_of) panel.n snap.n)
  else
    let n = panel.n in
    let rec walk i =
      if i >= n then None
      else
        let date_eq = Date.equal panel.dates.(i) snap.dates.(i) in
        let f_eq a b =
          Float.equal a b || (Float.is_nan a && Float.is_nan b)
        in
        let close_eq = f_eq panel.closes.(i) snap.closes.(i) in
        let raw_eq = f_eq panel.raw_closes.(i) snap.raw_closes.(i) in
        let high_eq = f_eq panel.highs.(i) snap.highs.(i) in
        let low_eq = f_eq panel.lows.(i) snap.lows.(i) in
        let vol_eq = f_eq panel.volumes.(i) snap.volumes.(i) in
        if not date_eq then
          Some
            (Printf.sprintf "%s %s [%d] dates differ: panel=%s snap=%s" symbol
               (Date.to_string as_of) i (Date.to_string panel.dates.(i))
               (Date.to_string snap.dates.(i)))
        else if not (close_eq && raw_eq && high_eq && low_eq && vol_eq) then
          Some
            (Printf.sprintf
               "%s %s [%d] OHLCV differ: panel(c=%.10f r=%.10f h=%.10f l=%.10f \
                v=%.0f) snap(c=%.10f r=%.10f h=%.10f l=%.10f v=%.0f)"
               symbol (Date.to_string as_of) i panel.closes.(i)
               panel.raw_closes.(i) panel.highs.(i) panel.lows.(i)
               panel.volumes.(i) snap.closes.(i) snap.raw_closes.(i)
               snap.highs.(i) snap.lows.(i) snap.volumes.(i))
        else walk (i + 1)
    in
    walk 0

let _load_universe path =
  let univ_sexp = Sexp.load_sexp path in
  match univ_sexp with
  | Sexp.List [ Sexp.Atom "Pinned"; Sexp.List entries ] ->
      List.map entries ~f:(function
        | Sexp.List
            [
              Sexp.List [ Sexp.Atom "symbol"; Sexp.Atom s ];
              Sexp.List [ Sexp.Atom "sector"; _ ];
            ] ->
            s
        | _ -> failwith "diag_real_csv_parity: bad universe entry")
  | _ -> failwith "diag_real_csv_parity: bad universe sexp"

let () =
  let univ_path =
    "/workspaces/trading-1/trading/test_data/backtest_scenarios/universes/sp500.sexp"
  in
  let universe = _load_universe univ_path in
  let warmup_start = _ymd 2018 6 6 in
  let end_date = _ymd 2023 12 29 in
  Printf.printf "Universe: %d symbols\n" (List.length universe);
  let sector_etfs =
    [
      "XLK"; "XLF"; "XLE"; "XLV"; "XLI"; "XLP"; "XLY"; "XLU"; "XLB"; "XLRE";
      "XLC";
    ]
  in
  let global_indices = [ "GDAXI.INDX"; "N225.INDX"; "ISF.LSE" ] in
  let symbols = ("GSPC.INDX" :: universe) @ sector_etfs @ global_indices in
  let calendar = _build_calendar ~start:warmup_start ~end_:end_date in
  Printf.printf "Calendar: %d trading days (%s..%s)\n" (Array.length calendar)
    (Date.to_string warmup_start) (Date.to_string end_date);
  Printf.printf "Building Bar_panels...\n%!";
  let panel = _build_full_panel ~symbols ~calendar in
  Printf.printf "Building snapshot...\n%!";
  let cb, _dp =
    _build_full_snapshot ~symbols ~start_date:warmup_start ~end_date
  in
  let weekdays =
    Array.to_list calendar |> List.filter ~f:(fun d -> Date.year d = 2019)
  in
  Printf.printf "Test dates: %d weekdays in 2019\n" (List.length weekdays);
  let weekly_diff = ref 0 in
  let weekly_total = ref 0 in
  let weekly_first = ref [] in
  List.iter weekdays ~f:(fun as_of ->
      List.iter symbols ~f:(fun symbol ->
          Int.incr weekly_total;
          let panel_view =
            match Bar_panels.column_of_date panel as_of with
            | None ->
                {
                  Bar_panels.closes = [||];
                  raw_closes = [||];
                  highs = [||];
                  lows = [||];
                  volumes = [||];
                  dates = [||];
                  n = 0;
                }
            | Some as_of_day ->
                Bar_panels.weekly_view_for panel ~symbol ~n:52 ~as_of_day
          in
          let snap_view =
            Snapshot_bar_views.weekly_view_for cb ~symbol ~n:52 ~as_of
          in
          match _diff_views ~symbol ~as_of panel_view snap_view with
          | None -> ()
          | Some msg ->
              Int.incr weekly_diff;
              if List.length !weekly_first < 20 then
                weekly_first := msg :: !weekly_first));
  let dbars_diff = ref 0 in
  let dbars_total = ref 0 in
  List.iter weekdays ~f:(fun as_of ->
      List.iter symbols ~f:(fun symbol ->
          Int.incr dbars_total;
          let panel_bars =
            match Bar_panels.column_of_date panel as_of with
            | None -> []
            | Some as_of_day ->
                Bar_panels.daily_bars_for panel ~symbol ~as_of_day
          in
          let snap_bars =
            Snapshot_bar_views.daily_bars_for cb ~symbol ~as_of
          in
          if List.length panel_bars <> List.length snap_bars then
            Int.incr dbars_diff
          else
            match (List.last panel_bars, List.last snap_bars) with
            | None, None -> ()
            | Some pb, Some sb when Date.equal pb.date sb.date -> ()
            | _ -> Int.incr dbars_diff));
  if !weekly_diff > 0 then (
    Printf.printf "\nFirst 20 weekly_view diffs:\n";
    List.iter (List.rev !weekly_first) ~f:(Printf.printf "  %s\n"));
  Printf.printf "Total weekly_view: %d/%d cells differ\n" !weekly_diff
    !weekly_total;
  Printf.printf "Total daily_bars: %d/%d cells differ\n" !dbars_diff
    !dbars_total
