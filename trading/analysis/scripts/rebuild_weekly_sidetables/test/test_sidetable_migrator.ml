open Core
open OUnit2
open Matchers
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Weekly_sidetable_builder = Snapshot_pipeline.Weekly_sidetable_builder
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_columnar = Data_panel_snapshot.Snapshot_columnar
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

let _symbol = "TSYM"

(* Fixture calendar: deep history 2020-01-06 .. 2020-02-28, window
   2020-03-02 .. 2020-04-24, a 2:1 forward split effective 2020-03-16. The
   adjusted series is continuous; the raw series doubles it before the split
   date. All values stay exact at <= 4 decimal places so the CSV round-trip is
   lossless. *)
let _deep_start = Date.of_string "2020-01-06"
let _window_start = Date.of_string "2020-03-02"
let _window_end = Date.of_string "2020-04-24"
let _split_date = Date.of_string "2020-03-16"

(* 60 calendar days before the window start covers the whole deep fixture. *)
let _sketch_deep_days = 60

let _weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat | Day_of_week.Sun -> false
  | _ -> true

let _weekdays ~from ~until =
  let rec loop d acc =
    if Date.( > ) d until then List.rev acc
    else loop (Date.add_days d 1) (if _weekday d then d :: acc else acc)
  in
  loop from []

(* Continuous adjusted close: 50.0, 50.5, 51.0, ... in fixture-day order. *)
let _adjusted_of_index i = 50.0 +. (Float.of_int i /. 2.0)

let _bar ~date ~index : Types.Daily_price.t =
  let adj = _adjusted_of_index index in
  let raw = if Date.( < ) date _split_date then adj *. 2.0 else adj in
  Types.Daily_price.make ~date ~open_price:raw ~high_price:(raw *. 1.02)
    ~low_price:(raw *. 0.98) ~close_price:raw ~volume:1_000 ~adjusted_close:adj
    ()

let _all_bars () =
  _weekdays ~from:_deep_start ~until:_window_end
  |> List.mapi ~f:(fun index date -> _bar ~date ~index)

let _window_bars () =
  List.filter (_all_bars ()) ~f:(fun (b : Types.Daily_price.t) ->
      Date.( >= ) b.date _window_start)

let _deep_bars () =
  List.filter (_all_bars ()) ~f:(fun (b : Types.Daily_price.t) ->
      Date.( < ) b.date _window_start)

let _tmp_dir () = Filename_unix.temp_dir ~in_dir:"/tmp" "sidetable_migrator_" ""

let _ok_or_fail ~what = function
  | Ok v -> v
  | Error e -> assert_failure (what ^ ": " ^ Status.show e)

let _write_csv ~csv_dir bars =
  let storage =
    _ok_or_fail ~what:"csv create"
      (Csv.Csv_storage.create ~data_dir:(Fpath.v csv_dir) _symbol)
  in
  _ok_or_fail ~what:"csv save" (Csv.Csv_storage.save storage bars)

let _snap_rows () =
  _ok_or_fail ~what:"build_for_symbol"
    (Pipeline.build_for_symbol ~symbol:_symbol ~bars:(_window_bars ())
       ~schema:Snapshot_schema.default ())

let _manifest_entry ~snap_path : Snapshot_manifest.file_metadata =
  {
    symbol = _symbol;
    path = snap_path;
    byte_size = 0;
    payload_md5 = "";
    csv_mtime = 0.0;
    active_through = None;
  }

(* Source warehouse: TSYM.snap over the window bars, an old-basis TSYM.weekly
   (same week skeleton the adjusted rebuild must preserve), and a manifest
   stamped with the RAW-basis side-table format hash. *)
let _write_warehouse ~warehouse_dir =
  let snap_path = Filename.concat warehouse_dir (_symbol ^ ".snap") in
  _ok_or_fail ~what:"snap write"
    (Snapshot_columnar.write ~path:snap_path (_snap_rows ()));
  let old_entries =
    Weekly_sidetable_builder.of_bars ~deep_bars:(_deep_bars ())
      ~bars:(_window_bars ())
  in
  _ok_or_fail ~what:"weekly write"
    (Weekly_sidetable.write_file
       ~path:(Filename.concat warehouse_dir (_symbol ^ ".weekly"))
       old_entries);
  let manifest =
    Snapshot_manifest.set_weekly_sidetable_format_hash
      (Snapshot_manifest.create ~schema:Snapshot_schema.default
         ~entries:[ _manifest_entry ~snap_path ])
      Weekly_sidetable.format_hash_raw_basis
  in
  _ok_or_fail ~what:"manifest write"
    (Snapshot_manifest.write
       ~path:(Filename.concat warehouse_dir "manifest.sexp")
       manifest)

(* One migrate run over a fresh fixture; [mutate_csv] shapes the CSV store's
   bars relative to the true history (identity = unchanged since the build). *)
let _migrate ?(mutate_csv = fun bars -> Some bars) () =
  let warehouse_dir = _tmp_dir () in
  let csv_dir = _tmp_dir () in
  let output_dir = Filename.concat (_tmp_dir ()) "clone" in
  _write_warehouse ~warehouse_dir;
  (match mutate_csv (_all_bars ()) with
  | Some bars -> _write_csv ~csv_dir bars
  | None -> ());
  let summary =
    Sidetable_migrator.migrate ~warehouse_dir ~csv_data_dir:csv_dir ~output_dir
      ~sketch_deep_days:_sketch_deep_days ()
  in
  (warehouse_dir, output_dir, summary)

let _read_weekly ~dir =
  _ok_or_fail ~what:"weekly read"
    (Weekly_sidetable.read_file
       ~path:(Filename.concat dir (_symbol ^ ".weekly")))

let _expected_adjusted_entries () =
  Weekly_sidetable_builder.of_bars ~deep_bars:(_deep_bars ())
    ~bars:(_window_bars ())

(* {2 Matcher helpers — keep assertion trees shallow} *)

let _reports_matcher report_matchers =
  field
    (fun (s : Sidetable_migrator.summary) -> s.reports)
    (elements_are report_matchers)

let _outcome_matcher m =
  field (fun (r : Sidetable_migrator.symbol_report) -> r.outcome) m

let _parity_matcher expected =
  field
    (fun (r : Sidetable_migrator.symbol_report) -> r.date_parity)
    (equal_to expected)

let _basis_factor_matcher ~epsilon expected =
  matching ~msg:"Expected Rebuilt"
    (function Sidetable_migrator.Rebuilt r -> Some r.basis_factor | _ -> None)
    (float_equal ~epsilon expected)

let _entry_date_matcher (e : Weekly_sidetable.entry) =
  field
    (fun (a : Weekly_sidetable.entry) -> a.week_end_date)
    (equal_to e.week_end_date)

let _entry_mid_matcher (e : Weekly_sidetable.entry) =
  field (fun (a : Weekly_sidetable.entry) -> a.mid) (float_equal e.mid)

let _entry_high_matcher (e : Weekly_sidetable.entry) =
  field (fun (a : Weekly_sidetable.entry) -> a.high) (float_equal e.high)

let _entry_matcher e =
  all_of [ _entry_date_matcher e; _entry_mid_matcher e; _entry_high_matcher e ]

let _expected_happy_report () : Sidetable_migrator.symbol_report =
  let outcome =
    Sidetable_migrator.Rebuilt
      { deep_bars_used = List.length (_deep_bars ()); basis_factor = 1.0 }
  in
  { symbol = _symbol; outcome; date_parity = true }

let _expected_happy_summary () : Sidetable_migrator.summary =
  {
    total = 1;
    rebuilt = 1;
    fallback_no_csv = 0;
    fallback_unstable_basis = 0;
    date_parity_failures = 0;
    reports = [ _expected_happy_report () ];
  }

let test_happy_path_summary_and_entries _ =
  let _, output_dir, summary = _migrate () in
  assert_that summary (is_ok_and_holds (equal_to (_expected_happy_summary ())));
  assert_that
    (_read_weekly ~dir:output_dir)
    (equal_to (_expected_adjusted_entries ()))

let _manifest_hash_matcher =
  field
    (fun (m : Snapshot_manifest.t) -> m.weekly_sidetable_format_hash)
    (equal_to (Some Weekly_sidetable.format_hash))

let _manifest_paths_matcher =
  field
    (fun (m : Snapshot_manifest.t) ->
      List.map m.entries ~f:(fun e -> e.Snapshot_manifest.path))
    (equal_to [ _symbol ^ ".snap" ])

let test_happy_path_clone_manifest_and_snap _ =
  let warehouse_dir, output_dir, _ = _migrate () in
  let manifest =
    _ok_or_fail ~what:"clone manifest read"
      (Snapshot_manifest.read
         ~path:(Filename.concat output_dir "manifest.sexp"))
  in
  assert_that manifest
    (all_of [ _manifest_hash_matcher; _manifest_paths_matcher ]);
  assert_that
    (In_channel.read_all (Filename.concat output_dir (_symbol ^ ".snap")))
    (equal_to
       (In_channel.read_all (Filename.concat warehouse_dir (_symbol ^ ".snap"))))

(* The pre-split week's rebuilt high must sit on the adjusted scale: max
   adjusted close of that week * 1.02 — not the doubled raw scale. *)
let test_adjusted_scale_pre_split_week _ =
  let _, output_dir, _ = _migrate () in
  let week_end = Date.of_string "2020-03-13" in
  let in_week (b : Types.Daily_price.t) =
    Date.( <= ) (Date.of_string "2020-03-09") b.date
    && Date.( <= ) b.date week_end
  in
  let expected_high =
    List.filter (_all_bars ()) ~f:in_week
    |> List.map ~f:(fun (b : Types.Daily_price.t) -> b.adjusted_close)
    |> List.fold ~init:Float.neg_infinity ~f:Float.max
    |> ( *. ) 1.02
  in
  let entry =
    List.find (_read_weekly ~dir:output_dir)
      ~f:(fun (e : Weekly_sidetable.entry) ->
        Date.equal e.week_end_date week_end)
  in
  assert_that entry
    (is_some_and
       (field
          (fun (e : Weekly_sidetable.entry) -> e.high)
          (float_equal expected_high)))

let _rebase_exact ~rebase (b : Types.Daily_price.t) =
  { b with adjusted_close = b.adjusted_close *. rebase }

let _round4 v = Float.round_decimal ~decimal_digits:4 v

let _rebase_rounded ~rebase (b : Types.Daily_price.t) =
  { b with adjusted_close = _round4 (b.adjusted_close *. rebase) }

let _perturb_at ~date ~factor (b : Types.Daily_price.t) =
  if Date.equal b.date date then
    { b with adjusted_close = b.adjusted_close *. factor }
  else b

(* A globally rebased CSV (adjusted scaled by a constant, raw unchanged —
   EODHD's behaviour when a new dividend lands) must be re-pinned back onto the
   warehouse basis: same entries as the unchanged-CSV run, basis_factor 1/k. *)
let test_global_rebase_repinned _ =
  let rebase = 1.25 in
  let mutate_csv bars = Some (List.map bars ~f:(_rebase_exact ~rebase)) in
  let _, output_dir, summary = _migrate ~mutate_csv () in
  let report_matcher =
    all_of
      [
        _outcome_matcher (_basis_factor_matcher ~epsilon:1e-9 (1.0 /. rebase));
        _parity_matcher true;
      ]
  in
  assert_that summary (is_ok_and_holds (_reports_matcher [ report_matcher ]));
  let entry_matchers =
    List.map (_expected_adjusted_entries ()) ~f:_entry_matcher
  in
  assert_that (_read_weekly ~dir:output_dir) (elements_are entry_matchers)

(* A realistic rebase as the feed serves it: constant factor, then each
   adjusted value re-rounded to 4 decimals. Per-sample ratios wobble at ~1e-6
   relative — that is rounding noise, not a revision, and must still re-pin
   (observed live on PFE: 82 majors false-flagged under a 1e-6 tolerance). *)
let test_rounded_rebase_still_stable _ =
  let rebase = 1.0175 in
  let mutate_csv bars = Some (List.map bars ~f:(_rebase_rounded ~rebase)) in
  let _, _, summary = _migrate ~mutate_csv () in
  let report_matcher =
    all_of
      [
        _outcome_matcher (_basis_factor_matcher ~epsilon:1e-4 (1.0 /. rebase));
        _parity_matcher true;
      ]
  in
  assert_that summary (is_ok_and_holds (_reports_matcher [ report_matcher ]))

(* No CSV for the symbol: rebuild from the snap's window bars alone — the deep
   weekly prefix is lost, so date parity against the deep-fed source fails and
   the outcome flags the fallback. *)
let test_fallback_no_csv _ =
  let _, output_dir, summary = _migrate ~mutate_csv:(fun _ -> None) () in
  let expected_report : Sidetable_migrator.symbol_report =
    {
      symbol = _symbol;
      outcome = Sidetable_migrator.Fallback_no_csv;
      date_parity = false;
    }
  in
  assert_that summary
    (is_ok_and_holds (_reports_matcher [ equal_to expected_report ]));
  assert_that
    (_read_weekly ~dir:output_dir)
    (equal_to
       (Weekly_sidetable_builder.of_bars ~deep_bars:[] ~bars:(_window_bars ())))

(* A historical revision (one overlap date's adjusted moved by its own factor)
   is NOT a global rebase — no constant re-pin exists, so the migrator refuses
   the deep prefix rather than guessing. *)
let test_fallback_unstable_basis _ =
  let n_window = List.length (_window_bars ()) in
  let middle_date =
    (List.nth_exn (_window_bars ()) (n_window / 2)).Types.Daily_price.date
  in
  let mutate_csv bars =
    Some (List.map bars ~f:(_perturb_at ~date:middle_date ~factor:3.0))
  in
  let _, _, summary = _migrate ~mutate_csv () in
  let report_matcher =
    _outcome_matcher (equal_to Sidetable_migrator.Fallback_unstable_basis)
  in
  assert_that summary (is_ok_and_holds (_reports_matcher [ report_matcher ]))

let suite =
  "sidetable_migrator"
  >::: [
         "happy path: summary + adjusted entries"
         >:: test_happy_path_summary_and_entries;
         "happy path: clone manifest + snap"
         >:: test_happy_path_clone_manifest_and_snap;
         "adjusted scale on pre-split week"
         >:: test_adjusted_scale_pre_split_week;
         "global rebase re-pinned" >:: test_global_rebase_repinned;
         "rounded rebase still stable" >:: test_rounded_rebase_still_stable;
         "fallback: no csv" >:: test_fallback_no_csv;
         "fallback: unstable basis" >:: test_fallback_unstable_basis;
       ]

let () = run_test_tt_main suite
