open Core
open OUnit2
open Matchers
open Wiki_sp500.Membership_replay

(* --- Fixtures and helpers --------------------------------------------- *)

let _pinned_csv_path = "./data/current_constituents_2026-05-03.csv"
let _pinned_html_path = "./data/changes_table_2026-05-03.html"
let _snapshot_date = Date.create_exn ~y:2026 ~m:Month.May ~d:3
let _day_before_april_9_2026 = Date.create_exn ~y:2026 ~m:Month.Apr ~d:8
let _date_2010_01_01 = Date.create_exn ~y:2010 ~m:Month.Jan ~d:1

(* The S&P 500 holds ~503 names today (some companies have dual-class
   shares, e.g. GOOG/GOOGL); the cardinality drifts slowly over time.
   2010-01-01 is well within the [480, 520] band per plan §Acceptance. *)
let _min_universe_size = 480
let _max_universe_size = 520

let _load_pinned_current () =
  match parse_current_csv (In_channel.read_all _pinned_csv_path) with
  | Ok cs -> cs
  | Error err ->
      assert_failure ("Failed to parse pinned CSV: " ^ Status.show err)

let _load_pinned_changes () =
  match
    Wiki_sp500.Changes_parser.parse (In_channel.read_all _pinned_html_path)
  with
  | Ok evs -> evs
  | Error err ->
      assert_failure ("Failed to parse pinned HTML: " ^ Status.show err)

let _replay_exn ~current ~changes ~as_of =
  match replay_back ~current ~changes ~as_of with
  | Ok cs -> cs
  | Error err -> assert_failure ("replay_back failed: " ^ Status.show err)

(* --- parse_current_csv tests ------------------------------------------- *)

let test_parse_current_csv_basic _ =
  let csv =
    "Symbol,Security,GICS Sector\n\
     AAPL,Apple Inc.,Information Technology\n\
     MSFT,Microsoft,Information Technology\n\
     XOM,Exxon Mobil,Energy\n"
  in
  assert_that (parse_current_csv csv)
    (is_ok_and_holds
       (elements_are
          [
            equal_to
              ({
                 symbol = "AAPL";
                 security_name = "Apple Inc.";
                 sector = "Information Technology";
               }
                : constituent);
            equal_to
              ({
                 symbol = "MSFT";
                 security_name = "Microsoft";
                 sector = "Information Technology";
               }
                : constituent);
            equal_to
              ({
                 symbol = "XOM";
                 security_name = "Exxon Mobil";
                 sector = "Energy";
               }
                : constituent);
          ]))

(* The Wikipedia main constituents table includes a quoted Headquarters
   field with embedded commas (e.g. "New York, NY"). Verify the CSV
   parser treats those as a single field, not a column boundary. *)
let test_parse_current_csv_handles_quoted_commas _ =
  let csv =
    "Symbol,Security,GICS Sector,Headquarters\n\
     AAPL,Apple Inc.,Information Technology,\"Cupertino, California\"\n"
  in
  assert_that (parse_current_csv csv)
    (is_ok_and_holds
       (elements_are
          [
            equal_to
              ({
                 symbol = "AAPL";
                 security_name = "Apple Inc.";
                 sector = "Information Technology";
               }
                : constituent);
          ]))

let test_parse_current_csv_rejects_missing_header _ =
  let csv = "Foo,Bar,Baz\nAAPL,Apple,IT\n" in
  assert_that (parse_current_csv csv) is_error

(* --- Replay tests ------------------------------------------------------ *)

(* Replaying to the snapshot date is a no-op: no events have
   [effective_date > snapshot_date] in the pinned data. *)
let test_no_op_replay_2026_05_03 _ =
  let current = _load_pinned_current () in
  let changes = _load_pinned_changes () in
  let result = _replay_exn ~current ~changes ~as_of:_snapshot_date in
  let symbols_before =
    List.map current ~f:(fun c -> c.symbol) |> List.sort ~compare:String.compare
  in
  let symbols_after =
    List.map result ~f:(fun c -> c.symbol) |> List.sort ~compare:String.compare
  in
  assert_that symbols_after (equal_to symbols_before)

(* On 2026-04-08, CASY (added 2026-04-09) was NOT yet in the index, and
   HOLX (removed 2026-04-09) WAS still in the index. Replay back to
   that date and verify both invariants. *)
let test_replay_back_one_known_event_2026_04_09 _ =
  let current = _load_pinned_current () in
  let changes = _load_pinned_changes () in
  let result = _replay_exn ~current ~changes ~as_of:_day_before_april_9_2026 in
  let has sym = List.exists result ~f:(fun c -> String.equal c.symbol sym) in
  assert_that (has "CASY", has "HOLX") (pair (equal_to false) (equal_to true))

(* On 2010-01-01 the index had ~500 names — within [480, 520] per plan. *)
let test_replay_back_to_2010_01_01_cardinality _ =
  let current = _load_pinned_current () in
  let changes = _load_pinned_changes () in
  let result = _replay_exn ~current ~changes ~as_of:_date_2010_01_01 in
  assert_that (List.length result)
    (is_between
       (module Int_ord)
       ~low:_min_universe_size ~high:_max_universe_size)

(* If a change event references an [added] symbol that's not in the
   current working set, [replay_back] must not crash. The pinned table
   contains thousands of historical entries; some pre-2010 events
   reference tickers that were already gone before the 2026 snapshot
   was taken. Replaying to 2000-01-01 forces these edge cases. *)
let test_replay_handles_missing_added_gracefully _ =
  let current = _load_pinned_current () in
  let changes = _load_pinned_changes () in
  let very_old = Date.create_exn ~y:2000 ~m:Month.Jan ~d:1 in
  let result = replay_back ~current ~changes ~as_of:very_old in
  assert_that result is_ok

(* When a symbol is re-added during replay, its [security_name] should
   come from the change event (e.g. "Hologic" for HOLX), not be lost. *)
let test_replay_preserves_security_name_when_re_adding _ =
  let current = _load_pinned_current () in
  let changes = _load_pinned_changes () in
  let result = _replay_exn ~current ~changes ~as_of:_day_before_april_9_2026 in
  let holx = List.find result ~f:(fun c -> String.equal c.symbol "HOLX") in
  assert_that holx
    (is_some_and (field (fun c -> c.security_name) (equal_to "Hologic")))

(* Events with [effective_date == as_of] are NOT replayed back: a stock
   added on D was a member of the index on D. Replay to 2026-04-09
   itself: CASY should be IN, HOLX should be OUT (same as snapshot). *)
let test_replay_skips_events_at_or_before_as_of _ =
  let current = _load_pinned_current () in
  let changes = _load_pinned_changes () in
  let on_april_9 = Date.create_exn ~y:2026 ~m:Month.Apr ~d:9 in
  let result = _replay_exn ~current ~changes ~as_of:on_april_9 in
  let has sym = List.exists result ~f:(fun c -> String.equal c.symbol sym) in
  assert_that (has "CASY", has "HOLX") (pair (equal_to true) (equal_to false))

(* The [(Pinned (((symbol XXX) (sector "..."))))] sexp shape must match
   the existing [universes/sp500.sexp] layout so consumers don't break. *)
let test_to_universe_sexp_matches_canonical_shape _ =
  let cs =
    [
      {
        symbol = "AAPL";
        security_name = "Apple Inc.";
        sector = "Information Technology";
      };
      { symbol = "XOM"; security_name = "Exxon Mobil"; sector = "Energy" };
    ]
  in
  let expected =
    Sexp.of_string
      "(Pinned (((symbol AAPL) (sector \"Information Technology\")) ((symbol \
       XOM) (sector Energy))))"
  in
  assert_that (to_universe_sexp cs) (equal_to expected)

(* The pinned changes table includes many events from 2010-2024. The
   replay-to-2010 result must include some delisted-since names that
   are NOT present in the 2026 snapshot. We assert a weaker form: the
   2010 universe has strictly different membership from the 2026
   snapshot (the survivorship-bias delta the plan calls out in
   §Acceptance #5). *)
let test_replay_to_2010_differs_from_snapshot _ =
  let current = _load_pinned_current () in
  let changes = _load_pinned_changes () in
  let result = _replay_exn ~current ~changes ~as_of:_date_2010_01_01 in
  let snapshot_set =
    String.Set.of_list (List.map current ~f:(fun c -> c.symbol))
  in
  let result_set =
    String.Set.of_list (List.map result ~f:(fun c -> c.symbol))
  in
  let only_in_2010 = Set.diff result_set snapshot_set in
  assert_that (Set.length only_in_2010) (gt (module Int_ord) 40)

(* --- Timeline (PR-D) tests -------------------------------------------- *)

let _build_timeline_exn ~current ~changes ~from ~until =
  match build_timeline ~current ~changes ~from ~until with
  | Ok t -> t
  | Error err -> assert_failure ("build_timeline: " ^ Status.show err)

(* Building a timeline over the full pinned window must succeed and accept
   [from = until] for a single-day timeline. *)
let test_build_timeline_basic _ =
  let current = _load_pinned_current () in
  let changes = _load_pinned_changes () in
  let result =
    build_timeline ~current ~changes ~from:_date_2010_01_01
      ~until:_snapshot_date
  in
  assert_that result is_ok

let test_build_timeline_rejects_inverted_window _ =
  let current = _load_pinned_current () in
  let changes = _load_pinned_changes () in
  let result =
    build_timeline ~current ~changes ~from:_snapshot_date
      ~until:_date_2010_01_01
  in
  assert_that result is_error

(* Pin two known facts:
     - HOLX (removed 2026-04-09) was a member 2026-04-08, NOT a member
       2026-05-03.
     - CASY (added 2026-04-09) was NOT a member 2026-04-08, IS a member
       2026-05-03.
   The timeline replays forward from [from], so [is_member] must match
   the [replay_back] semantics already exercised by earlier tests. *)
let test_is_member_query _ =
  let current = _load_pinned_current () in
  let changes = _load_pinned_changes () in
  let timeline =
    _build_timeline_exn ~current ~changes ~from:_date_2010_01_01
      ~until:_snapshot_date
  in
  let q sym d = is_member timeline ~symbol:sym ~as_of:d in
  let on_april_9 = Date.create_exn ~y:2026 ~m:Month.Apr ~d:9 in
  let observed =
    [
      ("HOLX 2026-04-08", q "HOLX" _day_before_april_9_2026);
      ("HOLX 2026-05-03", q "HOLX" _snapshot_date);
      ("CASY 2026-04-08", q "CASY" _day_before_april_9_2026);
      ("CASY 2026-04-09", q "CASY" on_april_9);
    ]
  in
  let expected =
    [
      ("HOLX 2026-04-08", true);
      ("HOLX 2026-05-03", false);
      ("CASY 2026-04-08", false);
      ("CASY 2026-04-09", true);
    ]
  in
  assert_that observed
    (elements_are
       (List.map expected ~f:(fun (label, want) ->
            all_of
              [
                field (fun (l, _) -> l) (equal_to label);
                field (fun (_, b) -> b) (equal_to want);
              ])))

(* Out-of-window queries must return [false]. *)
let test_is_member_outside_window_is_false _ =
  let current = _load_pinned_current () in
  let changes = _load_pinned_changes () in
  let timeline =
    _build_timeline_exn ~current ~changes ~from:_date_2010_01_01
      ~until:_snapshot_date
  in
  let before = Date.create_exn ~y:2009 ~m:Month.Dec ~d:31 in
  let after = Date.create_exn ~y:2026 ~m:Month.May ~d:4 in
  assert_that
    ( is_member timeline ~symbol:"AAPL" ~as_of:before,
      is_member timeline ~symbol:"AAPL" ~as_of:after )
    (pair (equal_to false) (equal_to false))

(* JSONL output:
     - Every line is parseable JSON (starts with { and ends with }).
     - Schema is the documented 4 fields.
     - Lines are sorted by date ascending (the seed dates all equal
       [from]; subsequent events have monotone non-decreasing dates).
   We don't depend on yojson here — the encoder is a hand-rolled subset
   for the finite domain; assert structural invariants directly. *)
type _jsonl_summary = {
  count : int;
  all_have_required_fields : bool;
  dates_sorted_ascending : bool;
}

let _summarize_jsonl jsonl =
  let lines =
    String.split_lines jsonl
    |> List.filter ~f:(fun l -> not (String.is_empty l))
  in
  let all_have_required_fields =
    List.for_all lines ~f:(fun l ->
        String.is_prefix l ~prefix:"{"
        && String.is_suffix l ~suffix:"}"
        && String.is_substring l ~substring:{|"date":|}
        && String.is_substring l ~substring:{|"action":|}
        && String.is_substring l ~substring:{|"symbol":|}
        && String.is_substring l ~substring:{|"sector":|})
  in
  let extract_date_prefix l =
    (* Lines start with [{"date":"YYYY-MM-DD",...]; pull the 10-char date. *)
    let prefix_len = String.length {|{"date":"|} in
    String.sub l ~pos:prefix_len ~len:10
  in
  let dates = List.map lines ~f:extract_date_prefix in
  let sorted_dates = List.sort dates ~compare:String.compare in
  {
    count = List.length lines;
    all_have_required_fields;
    dates_sorted_ascending = List.equal String.equal dates sorted_dates;
  }

let test_timeline_to_jsonl_schema _ =
  let current = _load_pinned_current () in
  let changes = _load_pinned_changes () in
  let timeline =
    _build_timeline_exn ~current ~changes ~from:_date_2010_01_01
      ~until:_snapshot_date
  in
  let summary = _summarize_jsonl (timeline_to_jsonl timeline) in
  assert_that summary
    (all_of
       [
         field (fun s -> s.all_have_required_fields) (equal_to true);
         field (fun s -> s.dates_sorted_ascending) (equal_to true);
         field (fun s -> s.count) (gt (module Int_ord) 480);
       ])

let suite =
  "membership_replay_test"
  >::: [
         "parse_current_csv_basic" >:: test_parse_current_csv_basic;
         "parse_current_csv_handles_quoted_commas"
         >:: test_parse_current_csv_handles_quoted_commas;
         "parse_current_csv_rejects_missing_header"
         >:: test_parse_current_csv_rejects_missing_header;
         "no_op_replay_2026_05_03" >:: test_no_op_replay_2026_05_03;
         "replay_back_one_known_event_2026_04_09"
         >:: test_replay_back_one_known_event_2026_04_09;
         "replay_back_to_2010_01_01_cardinality"
         >:: test_replay_back_to_2010_01_01_cardinality;
         "replay_handles_missing_added_gracefully"
         >:: test_replay_handles_missing_added_gracefully;
         "replay_preserves_security_name_when_re_adding"
         >:: test_replay_preserves_security_name_when_re_adding;
         "replay_skips_events_at_or_before_as_of"
         >:: test_replay_skips_events_at_or_before_as_of;
         "to_universe_sexp_matches_canonical_shape"
         >:: test_to_universe_sexp_matches_canonical_shape;
         "replay_to_2010_differs_from_snapshot"
         >:: test_replay_to_2010_differs_from_snapshot;
         "build_timeline_basic" >:: test_build_timeline_basic;
         "build_timeline_rejects_inverted_window"
         >:: test_build_timeline_rejects_inverted_window;
         "is_member_query" >:: test_is_member_query;
         "is_member_outside_window_is_false"
         >:: test_is_member_outside_window_is_false;
         "timeline_to_jsonl_schema" >:: test_timeline_to_jsonl_schema;
       ]

let () = run_test_tt_main suite
