open Core
open OUnit2
open Matchers
open Universe
open Universe.Snapshot
module BFI = Build_from_individuals

(* ---------------------------------------------------------------------- *)
(* Fixture builders                                                        *)
(* ---------------------------------------------------------------------- *)

(* All fixtures anchor at 2020-05-31. The trailing dollar-volume window is
   the default 60 calendar days back ([2020-04-01, 2020-05-31]); the
   forward return window is [2020-05-31, 2021-05-31]. *)
let _build_date = Date.create_exn ~y:2020 ~m:Month.May ~d:31

let _make_tmp_dir suffix =
  let dir = Stdlib.Filename.temp_file "bfi_test_" ("_" ^ suffix ^ ".d") in
  (try Stdlib.Sys.remove dir with _ -> ());
  ignore
    (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote dir))
      : int);
  dir

let _cleanup_dir dir =
  ignore
    (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote dir)) : int)

(* Mirror the production sharding rule: data/<L1>/<L2>/<symbol>/data.csv
   where L1 is the first letter and L2 is the LAST letter (or L1 if the
   symbol is a single character). Matches [Csv_storage.symbol_data_dir]. *)
let _bars_path ~root sym =
  let l1 = String.prefix sym 1 in
  let l2 =
    if String.length sym >= 2 then
      String.sub sym ~pos:(String.length sym - 1) ~len:1
    else l1
  in
  let dir =
    Filename.concat (Filename.concat (Filename.concat root l1) l2) sym
  in
  ignore
    (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote dir))
      : int);
  Filename.concat dir "data.csv"

(* Write a bars CSV. [trailing_bars] populates the trailing 60-day window
   ending at 2020-05-31; [forward_close_2021] sets the forward-return
   endpoint's [adjusted_close] at exactly 2021-05-31. Pricing details
   chosen for round-trip simplicity in the asserts. *)
let _write_bars ~root sym ~trailing_bars ~p_start_forward ~p_end_forward =
  let path = _bars_path ~root sym in
  let buf = Buffer.create 1024 in
  Buffer.add_string buf "date,open,high,low,close,adjusted_close,volume\n";
  List.iter trailing_bars ~f:(fun (date, close, volume) ->
      Buffer.add_string buf
        (Printf.sprintf "%s,%.2f,%.2f,%.2f,%.2f,%.2f,%d\n" (Date.to_string date)
           close close close close close volume));
  (* Forward-return endpoints; weights matter only for the aggregate
     return so we keep close = adjusted_close to keep arithmetic crisp. *)
  Buffer.add_string buf
    (Printf.sprintf "2020-06-01,%.2f,%.2f,%.2f,%.2f,%.2f,1000\n" p_start_forward
       p_start_forward p_start_forward p_start_forward p_start_forward);
  Buffer.add_string buf
    (Printf.sprintf "2021-05-31,%.2f,%.2f,%.2f,%.2f,%.2f,1000\n" p_end_forward
       p_end_forward p_end_forward p_end_forward p_end_forward);
  Out_channel.write_all path ~data:(Buffer.contents buf)

(* Build a list of (date, close, volume) trailing bars: [n_bars] daily
   business-like points stepping back from 2020-05-29 (skip 2020-05-30/31
   weekend to make the window look real). The constant per-symbol close *
   volume gives a flat dollar-volume score equal to the product. *)
let _trailing_bars ~close ~volume ~n_bars =
  let anchor = Date.create_exn ~y:2020 ~m:Month.May ~d:29 in
  List.init n_bars ~f:(fun i -> (Date.add_days anchor (-i), close, volume))

let _symbol_types_sexp_of entries =
  let body_lines =
    List.map entries ~f:(fun (sym, asset_type_sexp) ->
        Printf.sprintf
          "    ((symbol %s) (asset_type %s) (name \"\") (exchange \"\"))" sym
          asset_type_sexp)
  in
  "((generated_at 2020-05-30)\n (source_endpoints ())\n (symbols (\n"
  ^ String.concat ~sep:"\n" body_lines
  ^ ")))\n"

let _write_symbol_types ~root entries =
  let path = Filename.concat root "symbol_types.sexp" in
  Out_channel.write_all path ~data:(_symbol_types_sexp_of entries);
  path

let _write_sectors_csv ~root entries =
  let path = Filename.concat root "sectors.csv" in
  let buf = Buffer.create 256 in
  Buffer.add_string buf "symbol,sector\n";
  List.iter entries ~f:(fun (sym, sector) ->
      Buffer.add_string buf (Printf.sprintf "%s,%s\n" sym sector));
  Out_channel.write_all path ~data:(Buffer.contents buf);
  path

let _write_inventory ~root entries =
  let path = Filename.concat root "inventory.sexp" in
  let body_lines =
    List.map entries ~f:(fun (sym, start_d, end_d) ->
        Printf.sprintf "  ((symbol %s) (data_start_date %s) (data_end_date %s))"
          sym (Date.to_string start_d) (Date.to_string end_d))
  in
  let sexp =
    "((generated_at 2020-05-30)\n (symbols (\n"
    ^ String.concat ~sep:"\n" body_lines
    ^ ")))\n"
  in
  Out_channel.write_all path ~data:sexp;
  path

(* Common-Stock symbol_types entry literal. *)
let _common_stock = "(Listed \"Common Stock\")"
let _etf = "(Listed ETF)"

(* End-to-end fixture builder for the "5 active common stocks" baseline.
   Returns [(out_root, config)] where [config] points at the synthesized
   files. Caller is responsible for [_cleanup_dir out_root]. *)
let _setup_baseline_fixture ~size =
  let root = _make_tmp_dir "baseline" in
  let bars_root = Filename.concat root "bars" in
  ignore
    (Stdlib.Sys.command
       (Printf.sprintf "mkdir -p %s" (Filename.quote bars_root))
      : int);
  (* 5 active common stocks with distinct dollar-volume scores: each has
     60 trailing bars at constant (close, volume). Score = close * volume. *)
  let common_specs =
    [
      (* (symbol, close, volume, forward_p_start, forward_p_end) *)
      ("AAA", 100.0, 1_000_000, 100.0, 120.0);
      ("BBB", 50.0, 1_000_000, 50.0, 60.0);
      ("CCC", 25.0, 800_000, 25.0, 30.0);
      ("DDD", 10.0, 500_000, 10.0, 11.0);
      ("EEE", 5.0, 100_000, 5.0, 5.5);
    ]
  in
  List.iter common_specs ~f:(fun (sym, close, vol, ps, pe) ->
      let trailing_bars = _trailing_bars ~close ~volume:vol ~n_bars:60 in
      _write_bars ~root:bars_root sym ~trailing_bars ~p_start_forward:ps
        ~p_end_forward:pe);
  let symbol_types_path =
    _write_symbol_types ~root
      (List.map common_specs ~f:(fun (s, _, _, _, _) -> (s, _common_stock)))
  in
  let sectors_csv_path =
    _write_sectors_csv ~root
      [
        ("AAA", "Tech");
        ("BBB", "Tech");
        ("CCC", "Health");
        ("DDD", "Energy");
        ("EEE", "Other");
      ]
  in
  let inventory_path =
    _write_inventory ~root
      (List.map common_specs ~f:(fun (s, _, _, _, _) ->
           ( s,
             Date.create_exn ~y:2010 ~m:Month.Jan ~d:1,
             Date.create_exn ~y:2022 ~m:Month.Jan ~d:1 )))
  in
  let config =
    BFI.default_config ~size ~bars_root ~symbol_types_path ~sectors_csv_path
      ~inventory_path
  in
  (root, config)

let _build_or_fail ~config =
  match BFI.build ~date:_build_date ~config with
  | Ok snapshot -> snapshot
  | Error err -> assert_failure ("build failed: " ^ Status.show err)

(* ---------------------------------------------------------------------- *)
(* Tests                                                                   *)
(* ---------------------------------------------------------------------- *)

(* Top-3 by dollar volume from the 5-symbol baseline:
   AAA: 100 * 1M = 100M
   BBB:  50 * 1M = 50M
   CCC:  25 * 0.8M = 20M
   DDD:  10 * 0.5M = 5M
   EEE:   5 * 0.1M = 0.5M
   → AAA, BBB, CCC. *)
let test_top_n_ranked_by_dollar_volume_desc _ =
  let root, config = _setup_baseline_fixture ~size:3 in
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that snapshot
    (all_of
       [
         field (fun s -> s.size) (equal_to 3);
         field
           (fun s -> List.map s.entries ~f:(fun e -> e.symbol))
           (elements_are [ equal_to "AAA"; equal_to "BBB"; equal_to "CCC" ]);
       ])

(* Inactive symbols must be filtered before scoring. Add a 6th symbol
   whose [data_end_date] is before the build date — the active filter
   drops it before we ever try to read its bars. *)
let test_inactive_symbol_is_filtered _ =
  let root, config = _setup_baseline_fixture ~size:3 in
  (* Add an inactive symbol whose bars also rank #1 if scored — proves
     the activity filter ran before scoring. *)
  let bars_root = Filename.concat root "bars" in
  let trailing_bars =
    _trailing_bars ~close:1000.0 ~volume:1_000_000 ~n_bars:60
  in
  _write_bars ~root:bars_root "ZZZ" ~trailing_bars ~p_start_forward:1000.0
    ~p_end_forward:1000.0;
  let inventory_path = Filename.concat root "inventory.sexp" in
  (* Rewrite inventory to mark ZZZ as inactive (ended in 2019). *)
  Out_channel.write_all inventory_path
    ~data:
      "((generated_at 2020-05-30)\n\
      \ (symbols (\n\
      \  ((symbol AAA) (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol BBB) (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol CCC) (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol DDD) (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol EEE) (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol ZZZ) (data_start_date 2010-01-01) (data_end_date \
       2019-12-31)))))\n";
  let symbol_types_path = Filename.concat root "symbol_types.sexp" in
  Out_channel.write_all symbol_types_path
    ~data:
      (_symbol_types_sexp_of
         [
           ("AAA", _common_stock);
           ("BBB", _common_stock);
           ("CCC", _common_stock);
           ("DDD", _common_stock);
           ("EEE", _common_stock);
           ("ZZZ", _common_stock);
         ]);
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that snapshot
    (field
       (fun s -> List.map s.entries ~f:(fun e -> e.symbol))
       (elements_are [ equal_to "AAA"; equal_to "BBB"; equal_to "CCC" ]))

(* Symbols with fewer than [min_window_bars] bars in the trailing window
   must be dropped. Add a 6th symbol with only 5 in-window bars. *)
let test_min_window_bars_filter _ =
  let root, config = _setup_baseline_fixture ~size:3 in
  let bars_root = Filename.concat root "bars" in
  (* SPRS = "sparse": only 5 bars in window. Score would be huge if not dropped. *)
  let trailing_bars =
    _trailing_bars ~close:1000.0 ~volume:1_000_000 ~n_bars:5
  in
  _write_bars ~root:bars_root "SPRS" ~trailing_bars ~p_start_forward:1000.0
    ~p_end_forward:1000.0;
  let inventory_path = Filename.concat root "inventory.sexp" in
  Out_channel.write_all inventory_path
    ~data:
      "((generated_at 2020-05-30)\n\
      \ (symbols (\n\
      \  ((symbol AAA)  (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol BBB)  (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol CCC)  (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol DDD)  (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol EEE)  (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol SPRS) (data_start_date 2010-01-01) (data_end_date \
       2022-01-01)))))\n";
  let symbol_types_path = Filename.concat root "symbol_types.sexp" in
  Out_channel.write_all symbol_types_path
    ~data:
      (_symbol_types_sexp_of
         [
           ("AAA", _common_stock);
           ("BBB", _common_stock);
           ("CCC", _common_stock);
           ("DDD", _common_stock);
           ("EEE", _common_stock);
           ("SPRS", _common_stock);
         ]);
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that snapshot
    (field
       (fun s -> List.map s.entries ~f:(fun e -> e.symbol))
       (elements_are [ equal_to "AAA"; equal_to "BBB"; equal_to "CCC" ]))

(* Non-equity-like asset types (ETF, Mutual Fund, etc.) must be filtered
   before scoring. Add a 6th symbol classified as ETF whose bars rank #1
   if scored. *)
let test_non_equity_like_is_filtered _ =
  let root, config = _setup_baseline_fixture ~size:3 in
  let bars_root = Filename.concat root "bars" in
  let trailing_bars =
    _trailing_bars ~close:1000.0 ~volume:1_000_000 ~n_bars:60
  in
  _write_bars ~root:bars_root "SPY" ~trailing_bars ~p_start_forward:1000.0
    ~p_end_forward:1000.0;
  let inventory_path = Filename.concat root "inventory.sexp" in
  Out_channel.write_all inventory_path
    ~data:
      "((generated_at 2020-05-30)\n\
      \ (symbols (\n\
      \  ((symbol AAA) (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol BBB) (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol CCC) (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol DDD) (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol EEE) (data_start_date 2010-01-01) (data_end_date 2022-01-01))\n\
      \  ((symbol SPY) (data_start_date 2010-01-01) (data_end_date \
       2022-01-01)))))\n";
  let symbol_types_path = Filename.concat root "symbol_types.sexp" in
  Out_channel.write_all symbol_types_path
    ~data:
      (_symbol_types_sexp_of
         [
           ("AAA", _common_stock);
           ("BBB", _common_stock);
           ("CCC", _common_stock);
           ("DDD", _common_stock);
           ("EEE", _common_stock);
           ("SPY", _etf);
         ]);
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that snapshot
    (field
       (fun s -> List.map s.entries ~f:(fun e -> e.symbol))
       (elements_are [ equal_to "AAA"; equal_to "BBB"; equal_to "CCC" ]))

(* The 1-year forward aggregate return averages per-symbol returns:
   AAA: 120/100 - 1 = 0.20
   BBB:  60/50  - 1 = 0.20
   CCC:  30/25  - 1 = 0.20
   → mean = 0.20. *)
let test_aggregate_period_return_matches_forward_window _ =
  let root, config = _setup_baseline_fixture ~size:3 in
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that snapshot
    (field
       (fun s -> s.aggregate_period_return)
       (float_equal ~epsilon:0.001 0.20))

(* Sectors come from sectors.csv; missing entries default to empty string. *)
let test_sector_lookup_from_csv _ =
  let root, config = _setup_baseline_fixture ~size:3 in
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that snapshot
    (field
       (fun s -> List.map s.entries ~f:(fun e -> e.sector))
       (elements_are [ equal_to "Tech"; equal_to "Tech"; equal_to "Health" ]))

(* Weights are uniform 1/size; total_weight ≈ 1.0. *)
let test_weights_uniform_and_total_one _ =
  let root, config = _setup_baseline_fixture ~size:3 in
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that snapshot
    (all_of
       [
         field
           (fun s -> List.map s.entries ~f:(fun e -> e.weight))
           (elements_are
              [
                float_equal ~epsilon:1e-9 (1.0 /. 3.0);
                float_equal ~epsilon:1e-9 (1.0 /. 3.0);
                float_equal ~epsilon:1e-9 (1.0 /. 3.0);
              ]);
         field
           (fun s -> Snapshot.total_weight s)
           (float_equal ~epsilon:1e-9 1.0);
       ])

(* Determinism: two builds of the same fixture produce identical snapshots.
   Pure function over fixture inputs — no RNG, no clock. *)
let test_determinism_two_builds_identical _ =
  let root, config = _setup_baseline_fixture ~size:3 in
  let s1 = _build_or_fail ~config in
  let s2 = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that s2 (equal_to s1)

(* size <= 0 must produce Invalid_argument before any I/O. *)
let test_size_zero_rejected _ =
  let root, config = _setup_baseline_fixture ~size:3 in
  let bad_config = { config with size = 0 } in
  let result = BFI.build ~date:_build_date ~config:bad_config in
  _cleanup_dir root;
  assert_that result (is_error_with Status.Invalid_argument)

(* Insufficient survivors → Invalid_argument with a descriptive message.
   Asking for size=10 from a 5-symbol fixture must surface as an error,
   not a truncated snapshot. *)
let test_insufficient_survivors_rejected _ =
  let root, config = _setup_baseline_fixture ~size:10 in
  let result = BFI.build ~date:_build_date ~config in
  _cleanup_dir root;
  assert_that result (is_error_with Status.Invalid_argument)

let suite =
  "Build_from_individuals"
  >::: [
         "test_top_n_ranked_by_dollar_volume_desc"
         >:: test_top_n_ranked_by_dollar_volume_desc;
         "test_inactive_symbol_is_filtered" >:: test_inactive_symbol_is_filtered;
         "test_min_window_bars_filter" >:: test_min_window_bars_filter;
         "test_non_equity_like_is_filtered" >:: test_non_equity_like_is_filtered;
         "test_aggregate_period_return_matches_forward_window"
         >:: test_aggregate_period_return_matches_forward_window;
         "test_sector_lookup_from_csv" >:: test_sector_lookup_from_csv;
         "test_weights_uniform_and_total_one"
         >:: test_weights_uniform_and_total_one;
         "test_determinism_two_builds_identical"
         >:: test_determinism_two_builds_identical;
         "test_size_zero_rejected" >:: test_size_zero_rejected;
         "test_insufficient_survivors_rejected"
         >:: test_insufficient_survivors_rejected;
       ]

let () = run_test_tt_main suite
