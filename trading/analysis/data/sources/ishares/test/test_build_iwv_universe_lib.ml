open Core
open OUnit2
open Matchers
module Lib = Build_iwv_universe_lib
module Client = Ishares.Ishares_holdings_client
module Replay = Ishares.Ishares_membership_replay

(* ------------------------------------------------------------------------- *)
(* Fixture path helpers                                                      *)
(*                                                                           *)
(* Tests run from [trading/analysis/data/sources/ishares/test/], so all      *)
(* fixture paths are relative to that directory.                             *)
(* ------------------------------------------------------------------------- *)

let _sample_dir = "./data/sample_history"
let _date y m d = Date.create_exn ~y ~m ~d

let _sample_dates =
  [
    _date 2007 Month.Sep 28;
    _date 2010 Month.Jan 29;
    _date 2012 Month.Apr 30;
    _date 2018 Month.Jun 15;
    _date 2020 Month.Jun 1;
  ]

(* ------------------------------------------------------------------------- *)
(* list_cache_entries                                                        *)
(* ------------------------------------------------------------------------- *)

let test_list_cache_entries_returns_all_in_window _ =
  let entries =
    Lib.list_cache_entries ~cache_dir:_sample_dir ~from:(_date 2000 Month.Jan 1)
      ~until:(_date 2030 Month.Jan 1)
  in
  assert_that entries
    (is_ok_and_holds
       (elements_are
          (List.map _sample_dates ~f:(fun d ->
               field (fun (e : Lib.cache_entry) -> e.as_of) (equal_to d)))))

let test_list_cache_entries_filters_window _ =
  let entries =
    Lib.list_cache_entries ~cache_dir:_sample_dir ~from:(_date 2012 Month.Jan 1)
      ~until:(_date 2019 Month.Jan 1)
  in
  assert_that entries
    (is_ok_and_holds
       (elements_are
          [
            field
              (fun (e : Lib.cache_entry) -> e.as_of)
              (equal_to (_date 2012 Month.Apr 30));
            field
              (fun (e : Lib.cache_entry) -> e.as_of)
              (equal_to (_date 2018 Month.Jun 15));
          ]))

let test_list_cache_entries_missing_dir_errors _ =
  let entries =
    Lib.list_cache_entries ~cache_dir:"./data/does_not_exist"
      ~from:(_date 2000 Month.Jan 1) ~until:(_date 2030 Month.Jan 1)
  in
  assert_that entries is_error

(* Sentinel marker files (extension [.sentinel]) must be skipped by the
   loader — pins the [cache_entry] docstring claim "deliberately excluded
   from this list". The marker carries no date-bearing CSV body; emitting
   it as a cache_entry would propagate to [load_and_filter] and fail. *)
let _tmpdir () = Filename_unix.temp_dir ~in_dir:"/tmp" "iwv-prd-test-" ""

let _write_file ~path ~contents =
  Out_channel.with_file path ~f:(fun oc ->
      Out_channel.output_string oc contents)

let test_list_cache_entries_skips_sentinel_files _ =
  let dir = _tmpdir () in
  _write_file
    ~path:(Filename.concat dir "2025-01-15.csv")
    ~contents:"placeholder body\n";
  _write_file ~path:(Filename.concat dir "2025-02-15.sentinel") ~contents:"\n";
  let entries =
    Lib.list_cache_entries ~cache_dir:dir ~from:(_date 2000 Month.Jan 1)
      ~until:(_date 2030 Month.Jan 1)
  in
  assert_that entries
    (is_ok_and_holds
       (elements_are
          [
            field
              (fun (e : Lib.cache_entry) -> e.as_of)
              (equal_to (_date 2025 Month.Jan 15));
          ]))

(* ------------------------------------------------------------------------- *)
(* load_and_filter                                                           *)
(* ------------------------------------------------------------------------- *)

(* When the equity + US filter is on (default), the futures row ESM6 in the
   2020-06-01 fixture must be dropped. The other 8 rows survive. *)
let test_load_and_filter_drops_futures_row _ =
  let entries =
    match
      Lib.list_cache_entries ~cache_dir:_sample_dir
        ~from:(_date 2020 Month.Jun 1) ~until:(_date 2020 Month.Jun 1)
    with
    | Ok e -> e
    | Error err -> assert_failure (Status.show err)
  in
  let result = Lib.load_and_filter ~entries ~filter:Lib.default_filter_config in
  let snap_holdings =
    match result with
    | Ok [ (_, snap) ] -> snap.Client.holdings
    | _ -> assert_failure "expected exactly one snapshot"
  in
  let tickers =
    List.map snap_holdings ~f:(fun h -> h.Client.ticker)
    |> List.sort ~compare:String.compare
  in
  (* All 8 surviving rows in 2020-06-01 fixture — alphabetical. The futures
     hedge ESM6 must be absent; the 7 equities plus the cash row USD pass
     the equity filter as written... actually USD is asset_class=Cash so it
     is also filtered. So expected = 7 equity tickers. *)
  assert_that tickers
    (elements_are
       [
         equal_to "AAPL";
         equal_to "FB";
         equal_to "IBM";
         equal_to "JNJ";
         equal_to "KODK";
         equal_to "MSFT";
         equal_to "TSLA";
       ])

(* When the filter is disabled, the futures row passes through. *)
let test_load_and_filter_no_filter_keeps_futures _ =
  let entries =
    match
      Lib.list_cache_entries ~cache_dir:_sample_dir
        ~from:(_date 2020 Month.Jun 1) ~until:(_date 2020 Month.Jun 1)
    with
    | Ok e -> e
    | Error err -> assert_failure (Status.show err)
  in
  let no_filter =
    { Lib.require_equity_asset_class = false; require_us_location = false }
  in
  let result = Lib.load_and_filter ~entries ~filter:no_filter in
  let snap_size =
    match result with
    | Ok [ (_, snap) ] -> List.length snap.Client.holdings
    | _ -> assert_failure "expected exactly one snapshot"
  in
  assert_that snap_size (equal_to 8)

(* All 5 sample fixtures load successfully and produce 5 (date, snapshot)
   pairs in ascending date order. *)
let test_load_and_filter_full_window _ =
  let entries =
    match
      Lib.list_cache_entries ~cache_dir:_sample_dir
        ~from:(_date 2000 Month.Jan 1) ~until:(_date 2030 Month.Jan 1)
    with
    | Ok e -> e
    | Error err -> assert_failure (Status.show err)
  in
  let result = Lib.load_and_filter ~entries ~filter:Lib.default_filter_config in
  let dates =
    match result with
    | Ok pairs -> List.map pairs ~f:fst
    | Error err -> assert_failure (Status.show err)
  in
  assert_that dates
    (elements_are (List.map _sample_dates ~f:(fun d -> equal_to d)))

(* Pins the [load_and_filter] docstring claim "drops [No_data_sentinel]
   outcomes (cached sentinel bodies that slipped past the marker-file
   check)". A cached CSV body whose line-2 cell is ["-"] parses to
   [No_data_sentinel] (per [Ishares_holdings_client.parse]); the loader
   must silently skip it rather than fail or emit a stub snapshot.

   The minimal sentinel template is two lines: a placeholder line 1 and
   ["Fund Holdings as of,\"-\""] on line 2 — see
   [Ishares_holdings_client]'s parser, which only inspects line 2 before
   returning [No_data_sentinel]. *)
let _sentinel_body = "iShares Russell 3000 ETF\nFund Holdings as of,\"-\"\n"

let test_load_and_filter_skips_in_body_sentinel _ =
  let dir = _tmpdir () in
  _write_file
    ~path:(Filename.concat dir "2025-03-01.csv")
    ~contents:_sentinel_body;
  let entries =
    match
      Lib.list_cache_entries ~cache_dir:dir ~from:(_date 2000 Month.Jan 1)
        ~until:(_date 2030 Month.Jan 1)
    with
    | Ok e -> e
    | Error err -> assert_failure (Status.show err)
  in
  let result = Lib.load_and_filter ~entries ~filter:Lib.default_filter_config in
  assert_that result (is_ok_and_holds is_empty)

(* ------------------------------------------------------------------------- *)
(* build_universe — end-to-end on the 5-snapshot sample                      *)
(* ------------------------------------------------------------------------- *)

let _load_all_snapshots () =
  let entries =
    match
      Lib.list_cache_entries ~cache_dir:_sample_dir
        ~from:(_date 2000 Month.Jan 1) ~until:(_date 2030 Month.Jan 1)
    with
    | Ok e -> e
    | Error err -> assert_failure (Status.show err)
  in
  match Lib.load_and_filter ~entries ~filter:Lib.default_filter_config with
  | Ok pairs -> pairs
  | Error err -> assert_failure (Status.show err)

(* Trace:
   - AAPL, MSFT, JNJ, IBM, KODK: in 2007 → all 5 snapshots (KODK missing in
     2012 only — 1 miss < threshold=3, tenure stays open).
   - LEH: 2007 only; misses in 2010, 2012, 2018 → closed at snap 2018 with
     last_seen=2007. Filter [as_of=2020] excludes it.
   - TSLA, FB: first seen 2012, present 2012/2018/2020.
   - ESM6: filtered before replay (asset_class=Futures).
   Expected active members @ as_of=2020-06-01:
     AAPL, FB, IBM, JNJ, KODK, MSFT, TSLA (7 symbols, alphabetical). *)
let test_build_universe_yields_seven_members_at_end_of_window _ =
  let snapshots = _load_all_snapshots () in
  let outcome =
    Lib.build_universe ~snapshots ~threshold_consecutive_misses:3
      ~as_of:(_date 2020 Month.Jun 1)
  in
  assert_that outcome
    (all_of
       [
         field (fun o -> o.Lib.member_count) (equal_to 7);
         field (fun o -> o.Lib.snapshot_count) (equal_to 5);
         field (fun o -> o.Lib.removed_count) (equal_to 1);
       ])

(* The output sexp must match the broad-3000 fixture shape exactly:
   (Pinned (((symbol X) (sector Y)) ...)), sorted alphabetically. The
   sector pinned per ticker is [sector_at_first] (which for the pre-2009
   era is "-"). *)
let test_build_universe_sexp_shape_and_order _ =
  let snapshots = _load_all_snapshots () in
  let outcome =
    Lib.build_universe ~snapshots ~threshold_consecutive_misses:3
      ~as_of:(_date 2020 Month.Jun 1)
  in
  let expected_sexp =
    Sexp.of_string
      "(Pinned\n\
      \  (((symbol AAPL) (sector \"-\"))\n\
      \   ((symbol FB) (sector \"Communication Services\"))\n\
      \   ((symbol IBM) (sector \"-\"))\n\
      \   ((symbol JNJ) (sector \"-\"))\n\
      \   ((symbol KODK) (sector \"-\"))\n\
      \   ((symbol MSFT) (sector \"-\"))\n\
      \   ((symbol TSLA) (sector \"Consumer Discretionary\"))))"
  in
  assert_that outcome.Lib.universe_sexp (equal_to expected_sexp)

(* Mid-window as_of: at 2010-01-29, LEH was already "missing once" but
   below threshold=3 — the tenure_record for LEH stays in the replay,
   so LEH at first_seen=2007 last_seen=2007. The as_of filter rejects
   it (2010 > last_seen). TSLA/FB not yet observed → also excluded.
   Expected: AAPL, IBM, JNJ, KODK, MSFT (5 symbols). *)
let test_build_universe_mid_window_pi_filter _ =
  let snapshots = _load_all_snapshots () in
  let outcome =
    Lib.build_universe ~snapshots ~threshold_consecutive_misses:3
      ~as_of:(_date 2010 Month.Jan 29)
  in
  let symbols =
    match outcome.Lib.universe_sexp with
    | Sexp.List [ _; Sexp.List entries ] ->
        List.map entries ~f:(function
          | Sexp.List [ Sexp.List [ _; Sexp.Atom sym ]; _ ] -> sym
          | _ -> assert_failure "bad entry shape")
    | _ -> assert_failure "bad sexp shape"
  in
  assert_that symbols
    (elements_are
       [
         equal_to "AAPL";
         equal_to "IBM";
         equal_to "JNJ";
         equal_to "KODK";
         equal_to "MSFT";
       ])

(* Threshold=1: KODK's single-snapshot absence in 2012-04-30 closes the
   tenure. KODK re-appears in 2018 → opens a fresh tenure. At as_of=
   2020-06-01, the second KODK tenure (first_seen=2018, last_seen=2020)
   is active, but the first one (2007-2010) is not. Result: KODK still
   appears once in the output universe, but its [sector_at_first] is now
   "Information Technology" (from the 2018 re-observation), NOT "-".  *)
let test_build_universe_threshold_one_changes_kodk_sector _ =
  let snapshots = _load_all_snapshots () in
  let outcome =
    Lib.build_universe ~snapshots ~threshold_consecutive_misses:1
      ~as_of:(_date 2020 Month.Jun 1)
  in
  let kodk_sector =
    match outcome.Lib.universe_sexp with
    | Sexp.List [ _; Sexp.List entries ] ->
        List.find_map entries ~f:(function
          | Sexp.List
              [
                Sexp.List [ _; Sexp.Atom "KODK" ]; Sexp.List [ _; Sexp.Atom s ];
              ] ->
              Some s
          | _ -> None)
    | _ -> assert_failure "bad sexp shape"
  in
  assert_that kodk_sector (is_some_and (equal_to "Information Technology"))

(* Pins the [build_universe] docstring claim "The function is total —
   empty input yields an empty universe sexp." Empty snapshot input must
   not raise; counts collapse to zero and the sexp is the empty Pinned
   shape so downstream callers can [Sexp.of_string] the output without
   special-casing. *)
let test_build_universe_empty_input_is_total _ =
  let outcome =
    Lib.build_universe ~snapshots:[] ~threshold_consecutive_misses:3
      ~as_of:(_date 2020 Month.Jun 1)
  in
  assert_that outcome
    (all_of
       [
         field (fun o -> o.Lib.member_count) (equal_to 0);
         field (fun o -> o.Lib.snapshot_count) (equal_to 0);
         field (fun o -> o.Lib.removed_count) (equal_to 0);
         field
           (fun o -> o.Lib.universe_sexp)
           (equal_to (Sexp.of_string "(Pinned ())"));
       ])

(* ------------------------------------------------------------------------- *)
(* write_outcome_to_file — file format / atomicity                           *)
(* ------------------------------------------------------------------------- *)

(* Reuses [_tmpdir] defined above: each file-write test uses a fresh sandbox
   to avoid stale leftovers from prior runs. *)

let test_write_outcome_to_file_includes_header_and_body _ =
  let tmp = _tmpdir () in
  let path = Filename.concat tmp "russell-3000-sample.sexp" in
  let snapshots = _load_all_snapshots () in
  let outcome =
    Lib.build_universe ~snapshots ~threshold_consecutive_misses:3
      ~as_of:(_date 2020 Month.Jun 1)
  in
  let write_result =
    Lib.write_outcome_to_file ~path ~as_of:(_date 2020 Month.Jun 1)
      ~from:(_date 2007 Month.Sep 28) ~until:(_date 2020 Month.Jun 1) outcome
  in
  assert_that write_result is_ok;
  let on_disk = In_channel.read_all path in
  assert_that on_disk
    (all_of
       [
         contains_substring ";; Russell 3000 universe (IWV-derived)";
         contains_substring "as-of: 2020-06-01";
         contains_substring "members: 7";
         contains_substring "snapshots replayed: 5";
         contains_substring "(Pinned";
         contains_substring "(symbol AAPL)";
         contains_substring "(symbol TSLA)";
       ])

(* The output universe sexp parses cleanly: removing the comment block
   leaves a single Sexp.t that round-trips through Sexp.of_string. *)
let test_written_sexp_roundtrips_via_sexp_of_string _ =
  let tmp = _tmpdir () in
  let path = Filename.concat tmp "russell-3000-sample.sexp" in
  let snapshots = _load_all_snapshots () in
  let outcome =
    Lib.build_universe ~snapshots ~threshold_consecutive_misses:3
      ~as_of:(_date 2020 Month.Jun 1)
  in
  let _ =
    Lib.write_outcome_to_file ~path ~as_of:(_date 2020 Month.Jun 1)
      ~from:(_date 2007 Month.Sep 28) ~until:(_date 2020 Month.Jun 1) outcome
  in
  let on_disk = In_channel.read_all path in
  let body_only =
    String.split_lines on_disk
    |> List.filter ~f:(fun l -> not (String.is_prefix l ~prefix:";;"))
    |> String.concat ~sep:"\n"
  in
  let parsed = Sexp.of_string body_only in
  assert_that parsed (equal_to outcome.Lib.universe_sexp)

(* ------------------------------------------------------------------------- *)
(* run — end-to-end pipeline                                                 *)
(* ------------------------------------------------------------------------- *)

let test_run_pipeline_full_stack _ =
  let tmp = _tmpdir () in
  let path = Filename.concat tmp "universe.sexp" in
  let result =
    Lib.run ~cache_dir:_sample_dir ~output:path ~from:(_date 2007 Month.Sep 28)
      ~until:(_date 2020 Month.Jun 1) ~as_of:(_date 2020 Month.Jun 1)
      ~threshold_consecutive_misses:3 ()
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field (fun o -> o.Lib.member_count) (equal_to 7);
            field (fun o -> o.Lib.snapshot_count) (equal_to 5);
            field (fun o -> o.Lib.removed_count) (equal_to 1);
          ]));
  assert_that (Sys_unix.file_exists path) (equal_to `Yes)

(* ------------------------------------------------------------------------- *)
(* Schema parity with broad-3000-2010-01-01.sexp                             *)
(*                                                                           *)
(* Verify the emitted sexp parses with the same shape PR #1103's consumer    *)
(* expects: outermost (Pinned (entries...)); each entry is two key-value     *)
(* pairs (symbol, sector). This is what Scenario_lib.Universe_file.load      *)
(* reads.                                                                    *)
(* ------------------------------------------------------------------------- *)

let test_output_matches_broad_3000_schema _ =
  let snapshots = _load_all_snapshots () in
  let outcome =
    Lib.build_universe ~snapshots ~threshold_consecutive_misses:3
      ~as_of:(_date 2020 Month.Jun 1)
  in
  let entries =
    match outcome.Lib.universe_sexp with
    | Sexp.List [ Sexp.Atom "Pinned"; Sexp.List es ] -> es
    | _ -> assert_failure "outermost shape mismatch"
  in
  let all_entries_well_formed =
    List.for_all entries ~f:(function
      | Sexp.List
          [
            Sexp.List [ Sexp.Atom "symbol"; Sexp.Atom _ ];
            Sexp.List [ Sexp.Atom "sector"; Sexp.Atom _ ];
          ] ->
          true
      | _ -> false)
  in
  assert_that all_entries_well_formed (equal_to true)

let suite =
  "build_iwv_universe_lib_test"
  >::: [
         "list_cache_entries_returns_all_in_window"
         >:: test_list_cache_entries_returns_all_in_window;
         "list_cache_entries_filters_window"
         >:: test_list_cache_entries_filters_window;
         "list_cache_entries_missing_dir_errors"
         >:: test_list_cache_entries_missing_dir_errors;
         "list_cache_entries_skips_sentinel_files"
         >:: test_list_cache_entries_skips_sentinel_files;
         "load_and_filter_drops_futures_row"
         >:: test_load_and_filter_drops_futures_row;
         "load_and_filter_no_filter_keeps_futures"
         >:: test_load_and_filter_no_filter_keeps_futures;
         "load_and_filter_full_window" >:: test_load_and_filter_full_window;
         "load_and_filter_skips_in_body_sentinel"
         >:: test_load_and_filter_skips_in_body_sentinel;
         "build_universe_yields_seven_members_at_end_of_window"
         >:: test_build_universe_yields_seven_members_at_end_of_window;
         "build_universe_sexp_shape_and_order"
         >:: test_build_universe_sexp_shape_and_order;
         "build_universe_mid_window_pi_filter"
         >:: test_build_universe_mid_window_pi_filter;
         "build_universe_threshold_one_changes_kodk_sector"
         >:: test_build_universe_threshold_one_changes_kodk_sector;
         "build_universe_empty_input_is_total"
         >:: test_build_universe_empty_input_is_total;
         "write_outcome_to_file_includes_header_and_body"
         >:: test_write_outcome_to_file_includes_header_and_body;
         "written_sexp_roundtrips_via_sexp_of_string"
         >:: test_written_sexp_roundtrips_via_sexp_of_string;
         "run_pipeline_full_stack" >:: test_run_pipeline_full_stack;
         "output_matches_broad_3000_schema"
         >:: test_output_matches_broad_3000_schema;
       ]

let () = run_test_tt_main suite
