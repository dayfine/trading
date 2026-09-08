open Core

let report_name = "rename_twin_report.txt"

(* Load a symbol's windowed daily bars and project them to the
   (date, adjusted_close) series the cross-symbol twin pass compares. Returns
   [None] when the CSV is missing / unreadable / empty in-window — such a symbol
   simply cannot be a twin candidate. *)
let _load_series ~data_dir ~start_date ~end_date symbol =
  let open Option.Let_syntax in
  let%bind storage = Result.ok (Csv.Csv_storage.create ~data_dir symbol) in
  let%bind bars = Result.ok (Csv.Csv_storage.get storage ()) in
  match Bar_window.filter ?start:start_date ?end_:end_date bars with
  | [] -> None
  | windowed ->
      let sorted =
        Array.of_list windowed
        |> Array.sorted_copy ~compare:(fun (a : Types.Daily_price.t) b ->
            Date.compare a.date b.date)
      in
      let closes =
        Array.map sorted ~f:(fun (b : Types.Daily_price.t) ->
            (b.date, b.adjusted_close))
      in
      let last_date, _ = closes.(Array.length closes - 1) in
      Some { Twin_detector.symbol; data_end = last_date; closes }

(* The sidecar goes beside the warehouse it describes, so an operator who copies
   an output directory out of the container carries the evidence with it. A
   write failure is logged, never fatal: the build's own output is the product,
   the report is the audit trail. *)
let _write_report ~output_dir report =
  (if not (Stdlib.Sys.file_exists output_dir) then
     try Stdlib.Sys.mkdir output_dir 0o755 with _ -> ());
  let text = Twin_detector.render report in
  let path = Filename.concat output_dir report_name in
  (try Out_channel.write_all path ~data:(text ^ "\n")
   with Sys_error msg ->
     Printf.eprintf "%s write failed: %s\n%!" report_name msg);
  Printf.eprintf "%s\n%!" text

let run config ~data_dir ~start_date ~end_date ~output_dir all_symbols =
  if not config.Twin_detector.Config.enabled then (all_symbols, [])
  else begin
    let series =
      List.filter_map all_symbols
        ~f:(_load_series ~data_dir ~start_date ~end_date)
    in
    let report = Twin_detector.detect config series in
    _write_report ~output_dir report;
    (Twin_detector.survivors report ~all_symbols, report.dropped_symbols)
  end

(* Flag [~doc] strings are hoisted so the [Command.Param] block below stays flat
   — the same convention [build_snapshots.ml] uses for its CLI shell. *)
let doc_dedupe =
  "Drop rename-twin duplicate legs (same series under old+new ticker) before \
   building; writes " ^ report_name
  ^ ". Default off — existing warehouses stay reproducible."

let doc_basis =
  "B Comparison basis: levels (default, adjusted-close levels) or returns \
   (consecutive daily returns — catches renames whose feeds carry different \
   adjustment bases)"

let doc_min_overlap = "N Min shared trading days for a twin match"

let doc_match_fraction =
  "F Min fraction of overlapping days with near-identical closes"

let doc_close_epsilon =
  "E Relative tolerance for a single-day close match (basis=levels)"

let doc_ret_epsilon =
  "E Absolute tolerance on the daily-return difference (basis=returns)"

let _basis_of_string = function
  | "levels" -> Twin_detector.Config.Levels
  | "returns" -> Twin_detector.Config.Returns
  | other ->
      failwithf "unknown -twin-basis %s (expected levels|returns)" other ()

let params =
  let default = Twin_detector.Config.default in
  let%map_open.Command enabled =
    flag "dedupe-rename-twins" no_arg ~doc:doc_dedupe
  and basis =
    flag "twin-basis" (optional_with_default "levels" string) ~doc:doc_basis
  and min_overlap_days =
    flag "twin-min-overlap-days"
      (optional_with_default default.min_overlap_days int)
      ~doc:doc_min_overlap
  and match_fraction =
    flag "twin-match-fraction"
      (optional_with_default default.match_fraction float)
      ~doc:doc_match_fraction
  and close_epsilon =
    flag "twin-close-epsilon"
      (optional_with_default default.close_epsilon float)
      ~doc:doc_close_epsilon
  and ret_epsilon =
    flag "twin-ret-epsilon"
      (optional_with_default default.ret_epsilon float)
      ~doc:doc_ret_epsilon
  in
  {
    Twin_detector.Config.enabled;
    min_overlap_days;
    match_fraction;
    close_epsilon;
    basis = _basis_of_string (String.lowercase basis);
    ret_epsilon;
    prefilter_rel_tol = default.prefilter_rel_tol;
  }
