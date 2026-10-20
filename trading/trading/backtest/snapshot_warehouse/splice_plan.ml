(* Splice-pass wiring extracted from [build_scenario_snapshots.ml] (file-length
   cleanup, #2876): bar loading, sidecar writing and the per-symbol decision. *)

open Core
module Series_splice = Snapshot_pipeline.Series_splice

(* Load a symbol's windowed daily bars, ascending by date. Returns [None] when
   the CSV is missing / unreadable / empty in-window — such a symbol simply
   cannot be a candidate for either data-integrity pass below. *)
let load_windowed_bars ~data_dir ~warmup_start ~end_date symbol =
  let open Option.Let_syntax in
  let%bind storage = Result.ok (Csv.Csv_storage.create ~data_dir symbol) in
  let%bind bars = Result.ok (Csv.Csv_storage.get storage ()) in
  match Bar_window.filter ~start:warmup_start ~end_:end_date bars with
  | [] -> None
  | windowed ->
      let sorted =
        Array.of_list windowed
        |> Array.sorted_copy ~compare:(fun (a : Types.Daily_price.t) b ->
            Date.compare a.date b.date)
      in
      Some sorted

(* The within-symbol continuity pass reads whole bars: the adjusted close for
   the ratio, the raw close for the split guard, the volume for the report. *)
let _load_splice_series ~data_dir ~warmup_start ~end_date symbol =
  let open Option.Let_syntax in
  let%map bars = load_windowed_bars ~data_dir ~warmup_start ~end_date symbol in
  { Splice_detector.symbol; bars }

let _write_sidecar ~output_dir ~name ~data =
  (if not (Stdlib.Sys.file_exists output_dir) then
     try Stdlib.Sys.mkdir output_dir 0o755 with _ -> ());
  let path = Filename.concat output_dir name in
  try Out_channel.write_all path ~data
  with Sys_error msg -> Printf.eprintf "%s write failed: %s\n%!" name msg

(* Splice dates per symbol, keyed for the per-symbol decision below. *)
let _splice_dates (report : Splice_detector.report) =
  List.fold report.findings
    ~init:(Map.empty (module String))
    ~f:(fun acc (f : Splice_detector.finding) ->
      Map.add_multi acc ~key:f.symbol ~data:f.date)

(* One decision per scanned symbol. The BARS this returns are discarded: the
   scan sees only the windowed series it loaded here, while the edit has to
   reach both halves of the symbol's history (the windowed bars behind its
   [.snap] and the deep prefix behind its [.weekly]), so the cut is re-applied
   inside {!Build_runner.build} via the plan. Only the finding — the report row,
   which carries the decision — is kept. *)
let _splice_findings ~splice_config ~exceptions ~report series =
  let dates = _splice_dates report in
  List.filter_map series ~f:(fun (s : Splice_detector.series) ->
      snd
        (Series_splice.apply splice_config ~exceptions ~symbol:s.symbol
           ~splices:(Map.find_multi dates s.symbol)
           (Array.to_list s.bars)))

let _report_splice_actions ~output_dir findings =
  _write_sidecar ~output_dir ~name:"splice_actions.csv"
    ~data:(Series_splice.to_csv findings);
  Printf.eprintf "%s\n%!" (Series_splice.summary findings)

(* When armed, scan every symbol's adjusted-close series for ticker-reuse
   splices, write the [splices.csv] + [splice_actions.csv] sidecars, and return
   the symbols that survive plus the cuts the builder must apply. Default-off
   config → no scan, no file, no I/O, every symbol kept and no cuts. *)
let plan_splices ~config ~splice_config ~exceptions ~data_dir ~warmup_start
    ~end_date ~output_dir all_symbols =
  if not config.Splice_detector.Config.enabled then
    (all_symbols, Map.empty (module String))
  else begin
    let series =
      List.filter_map all_symbols
        ~f:(_load_splice_series ~data_dir ~warmup_start ~end_date)
    in
    let report = Splice_detector.detect config series in
    _write_sidecar ~output_dir ~name:"splices.csv"
      ~data:(Splice_detector.to_csv report);
    Printf.eprintf "%s\n%!" (Splice_detector.summary report);
    let findings = _splice_findings ~splice_config ~exceptions ~report series in
    _report_splice_actions ~output_dir findings;
    let dropped =
      Set.of_list (module String) (Series_splice.dropped_symbols findings)
    in
    ( List.filter all_symbols ~f:(fun s -> not (Set.mem dropped s)),
      Series_splice.cut_plan findings )
  end
