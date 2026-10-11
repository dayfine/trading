(** Tests for the composition logic in {!Weinstein_strategy.Ad_bars.load} that
    merges Unicorn and Synthetic sources. The Unicorn-specific CSV parsing tests
    live in [test_ad_bars_unicorn.ml]; this file focuses on the merge behavior:
    overlap precedence, gap handling, ordering, and missing files. *)

open OUnit2
open Core
open Matchers

let date_of_string s = Date.of_string s

(** Create a temp data_dir and write the four breadth CSVs (Unicorn + Synthetic)
    with the given raw string contents. Accepts optional contents; [None] means
    the file is not created (simulating missing file). *)
let with_breadth_files ?(unicorn_advn = None) ?(unicorn_decln = None)
    ?(synthetic_advn = None) ?(synthetic_decln = None) f =
  let data_dir = Core_unix.mkdtemp "/tmp/test_ad_bars_compose" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" data_dir) in
      ())
    (fun () ->
      let breadth = Filename.concat data_dir "breadth" in
      Core_unix.mkdir breadth;
      let write_opt filename contents =
        match contents with
        | Some data ->
            Out_channel.write_all (Filename.concat breadth filename) ~data
        | None -> ()
      in
      write_opt "nyse_advn.csv" unicorn_advn;
      write_opt "nyse_decln.csv" unicorn_decln;
      write_opt "synthetic_advn.csv" synthetic_advn;
      write_opt "synthetic_decln.csv" synthetic_decln;
      f data_dir)

(* ------------------------------------------------------------------ *)
(* Unicorn-only (no Synthetic files)                                    *)
(* ------------------------------------------------------------------ *)

let test_unicorn_only _ =
  with_breadth_files ~unicorn_advn:(Some "19650301, 550\n19650302, 590\n")
    ~unicorn_decln:(Some "19650301, 400\n19650302, 380\n") (fun data_dir ->
      let result = Weinstein_strategy.Ad_bars.load ~data_dir in
      assert_that result
        (elements_are
           [
             equal_to
               ({
                  Macro.date = date_of_string "1965-03-01";
                  advancing = 550;
                  declining = 400;
                }
                 : Macro.ad_bar);
             equal_to
               ({
                  Macro.date = date_of_string "1965-03-02";
                  advancing = 590;
                  declining = 380;
                }
                 : Macro.ad_bar);
           ]))

(* ------------------------------------------------------------------ *)
(* Synthetic-only (no Unicorn files)                                    *)
(* ------------------------------------------------------------------ *)

let test_synthetic_only _ =
  with_breadth_files ~synthetic_advn:(Some "20200301, 1200\n20200302, 1300\n")
    ~synthetic_decln:(Some "20200301, 800\n20200302, 700\n") (fun data_dir ->
      let result = Weinstein_strategy.Ad_bars.load ~data_dir in
      assert_that result
        (elements_are
           [
             equal_to
               ({
                  Macro.date = date_of_string "2020-03-01";
                  advancing = 1200;
                  declining = 800;
                }
                 : Macro.ad_bar);
             equal_to
               ({
                  Macro.date = date_of_string "2020-03-02";
                  advancing = 1300;
                  declining = 700;
                }
                 : Macro.ad_bar);
           ]))

(* ------------------------------------------------------------------ *)
(* Both present, no overlap — Synthetic fills the tail                  *)
(* ------------------------------------------------------------------ *)

let test_compose_no_overlap _ =
  with_breadth_files ~unicorn_advn:(Some "20200206, 1404\n20200207, 1053\n")
    ~unicorn_decln:(Some "20200206, 1500\n20200207, 1800\n")
    ~synthetic_advn:(Some "20200210, 1200\n20200211, 1300\n")
    ~synthetic_decln:(Some "20200210, 800\n20200211, 700\n") (fun data_dir ->
      let result = Weinstein_strategy.Ad_bars.load ~data_dir in
      assert_that result (size_is 4);
      let dates = List.map result ~f:(fun (b : Macro.ad_bar) -> b.date) in
      assert_that dates
        (equal_to
           [
             date_of_string "2020-02-06";
             date_of_string "2020-02-07";
             date_of_string "2020-02-10";
             date_of_string "2020-02-11";
           ]))

(* ------------------------------------------------------------------ *)
(* Both present, overlap — Unicorn wins on overlapping dates            *)
(* ------------------------------------------------------------------ *)

let test_compose_unicorn_wins_on_overlap _ =
  with_breadth_files
    ~unicorn_advn:(Some "20200206, 1404\n20200207, 1053\n20200210, 1721\n")
    ~unicorn_decln:(Some "20200206, 1500\n20200207, 1800\n20200210, 1200\n")
      (* Synthetic covers 2020-02-07 onwards — overlap on 02-07 and 02-10 *)
    ~synthetic_advn:(Some "20200207, 9999\n20200210, 8888\n20200211, 1300\n")
    ~synthetic_decln:(Some "20200207, 7777\n20200210, 6666\n20200211, 700\n")
    (fun data_dir ->
      let result = Weinstein_strategy.Ad_bars.load ~data_dir in
      assert_that result (size_is 4);
      (* 2020-02-07 and 2020-02-10 use Unicorn values, not Synthetic 9999/8888 *)
      let feb07 =
        List.find_exn result ~f:(fun (b : Macro.ad_bar) ->
            Date.equal b.date (date_of_string "2020-02-07"))
      in
      assert_that feb07
        (all_of
           [
             field (fun (b : Macro.ad_bar) -> b.advancing) (equal_to 1053);
             field (fun (b : Macro.ad_bar) -> b.declining) (equal_to 1800);
           ]);
      (* 2020-02-11 comes from Synthetic *)
      let feb11 =
        List.find_exn result ~f:(fun (b : Macro.ad_bar) ->
            Date.equal b.date (date_of_string "2020-02-11"))
      in
      assert_that feb11
        (all_of
           [
             field (fun (b : Macro.ad_bar) -> b.advancing) (equal_to 1300);
             field (fun (b : Macro.ad_bar) -> b.declining) (equal_to 700);
           ]))

(* ------------------------------------------------------------------ *)
(* Chronological ordering of composed result                            *)
(* ------------------------------------------------------------------ *)

let test_compose_result_is_sorted _ =
  with_breadth_files ~unicorn_advn:(Some "19650301, 550\n")
    ~unicorn_decln:(Some "19650301, 400\n")
    ~synthetic_advn:(Some "20200301, 1200\n")
    ~synthetic_decln:(Some "20200301, 800\n") (fun data_dir ->
      let result = Weinstein_strategy.Ad_bars.load ~data_dir in
      let is_sorted =
        List.is_sorted result ~compare:(fun (a : Macro.ad_bar) b ->
            Date.compare a.date b.date)
      in
      assert_that is_sorted (equal_to true))

(* ------------------------------------------------------------------ *)
(* Missing both sources — graceful empty                                *)
(* ------------------------------------------------------------------ *)

let test_compose_both_missing _ =
  with_breadth_files (fun data_dir ->
      let result = Weinstein_strategy.Ad_bars.load ~data_dir in
      assert_that result is_empty)

(* ------------------------------------------------------------------ *)
(* Synthetic submodule loads independently                              *)
(* ------------------------------------------------------------------ *)

let test_synthetic_load_direct _ =
  with_breadth_files ~synthetic_advn:(Some "20200301, 1200\n20200302, 1300\n")
    ~synthetic_decln:(Some "20200301, 800\n20200302, 700\n") (fun data_dir ->
      let result = Weinstein_strategy.Ad_bars.Synthetic.load ~data_dir in
      assert_that result (size_is 2))

let test_synthetic_load_missing_files _ =
  let result =
    Weinstein_strategy.Ad_bars.Synthetic.load
      ~data_dir:"/tmp/does-not-exist-synthetic-xyz"
  in
  assert_that result is_empty

(* ------------------------------------------------------------------ *)
(* Real-data integration check                                          *)
(* ------------------------------------------------------------------ *)

let test_load_real_data_composed _ =
  let data_dir = "/workspaces/trading-1/data" in
  let advn_path = Filename.concat data_dir "breadth/nyse_advn.csv" in
  let syn_path = Filename.concat data_dir "breadth/synthetic_advn.csv" in
  if not (Stdlib.Sys.file_exists advn_path) then
    skip_if true "no cached Unicorn breadth data";
  if not (Stdlib.Sys.file_exists syn_path) then
    skip_if true "no cached Synthetic breadth data";
  let result = Weinstein_strategy.Ad_bars.load ~data_dir in
  (* Should have more than Unicorn alone (which is ~13,700 rows) *)
  assert_that (List.length result) (gt (module Int_ord) 14_000);
  (* Strictly chronological *)
  let is_sorted =
    List.is_sorted result ~compare:(fun (a : Macro.ad_bar) b ->
        Date.compare a.date b.date)
  in
  assert_that is_sorted (equal_to true);
  (* No duplicates by date *)
  let dates = List.map result ~f:(fun (b : Macro.ad_bar) -> b.date) in
  let unique_count =
    List.dedup_and_sort dates ~compare:Date.compare |> List.length
  in
  assert_that unique_count (equal_to (List.length dates))

(* ------------------------------------------------------------------ *)
(* Interior-gap fill (issue #3238)                                      *)
(* ------------------------------------------------------------------ *)

let _bar date advancing declining : Macro.ad_bar =
  { Macro.date = date_of_string date; advancing; declining }

(* Unicorn: 1965-03-01, then 2017-01-02 and 2017-01-03 — the shape of the old
   fixture. Synthetic covers 1998-01-05, 1998-01-06 (inside the hole), 1964-12-31
   (before Unicorn starts) and 2017-01-03 (overlap). *)
let test_compose_fills_interior_gap _ =
  with_breadth_files
    ~unicorn_advn:(Some "19650301, 550\n20170102, 1360\n20170103, 2308\n")
    ~unicorn_decln:(Some "19650301, 400\n20170102, 1600\n20170103, 700\n")
    ~synthetic_advn:
      (Some "19641231, 1\n19980105, 184\n19980106, 112\n20170103, 9999\n")
    ~synthetic_decln:
      (Some "19641231, 2\n19980105, 120\n19980106, 190\n20170103, 8888\n")
    (fun data_dir ->
      assert_that
        (Weinstein_strategy.Ad_bars.load ~data_dir)
        (elements_are
           [
             equal_to (_bar "1965-03-01" 550 400);
             equal_to (_bar "1998-01-05" 184 120);
             equal_to (_bar "1998-01-06" 112 190);
             equal_to (_bar "2017-01-02" 1360 1600);
             equal_to (_bar "2017-01-03" 2308 700);
           ]))

(* A Unicorn hole exactly at the threshold (2001-09-10 -> 2001-09-17, 7 days)
   is a real market closure and stays unfilled; Synthetic bars inside it are
   dropped. *)
let test_compose_leaves_hole_at_threshold _ =
  with_breadth_files ~unicorn_advn:(Some "20010910, 1000\n20010917, 500\n")
    ~unicorn_decln:(Some "20010910, 900\n20010917, 2500\n")
    ~synthetic_advn:(Some "20010912, 7\n")
    ~synthetic_decln:(Some "20010912, 8\n") (fun data_dir ->
      assert_that
        (Weinstein_strategy.Ad_bars.load ~data_dir)
        (elements_are
           [
             equal_to (_bar "2001-09-10" 1000 900);
             equal_to (_bar "2001-09-17" 500 2500);
           ]))

(* The threshold is configurable: with [load_with ~max_interior_gap_days:3] the
   same 7-day hole is filled. *)
let test_load_with_custom_threshold_fills _ =
  with_breadth_files ~unicorn_advn:(Some "20010910, 1000\n20010917, 500\n")
    ~unicorn_decln:(Some "20010910, 900\n20010917, 2500\n")
    ~synthetic_advn:(Some "20010912, 7\n")
    ~synthetic_decln:(Some "20010912, 8\n") (fun data_dir ->
      assert_that
        (Weinstein_strategy.Ad_bars.load_with ~max_interior_gap_days:3 ~data_dir)
        (elements_are
           [
             equal_to (_bar "2001-09-10" 1000 900);
             equal_to (_bar "2001-09-12" 7 8);
             equal_to (_bar "2001-09-17" 500 2500);
           ]))

(* ------------------------------------------------------------------ *)
(* Gap detection                                                        *)
(* ------------------------------------------------------------------ *)

let _d = date_of_string

let _gap_bars =
  [
    _bar "2000-01-03" 1 1;
    _bar "2000-01-04" 1 1;
    _bar "2000-01-20" 1 1;
    _bar "2000-01-21" 1 1;
    _bar "2000-03-01" 1 1;
  ]

let test_gaps_reports_wide_holes_in_order _ =
  assert_that
    (Weinstein_strategy.Ad_bars.gaps _gap_bars ~max_gap_days:14)
    (equal_to
       [
         (_d "2000-01-04", _d "2000-01-20"); (_d "2000-01-21", _d "2000-03-01");
       ])

let test_gaps_exact_threshold_not_reported _ =
  (* 2000-01-04 -> 2000-01-20 is 16 days: reported at 15, not at 16. *)
  assert_that
    ( Weinstein_strategy.Ad_bars.gaps _gap_bars ~max_gap_days:15,
      Weinstein_strategy.Ad_bars.gaps _gap_bars ~max_gap_days:40 )
    (equal_to
       ( [
           (_d "2000-01-04", _d "2000-01-20"); (_d "2000-01-21", _d "2000-03-01");
         ],
         [] ))

let test_gaps_short_series _ =
  assert_that
    ( Weinstein_strategy.Ad_bars.gaps [] ~max_gap_days:1,
      Weinstein_strategy.Ad_bars.gaps [ _bar "2000-01-03" 1 1 ] ~max_gap_days:1
    )
    (equal_to ([], []))

let test_gaps_in_window_edges_and_clip _ =
  (* Window 1999-12-01 .. 2000-02-01: leading sentinel gap to the first bar,
     the interior hole, and a trailing gap to the end sentinel; the March bar
     is outside the window. *)
  assert_that
    (Weinstein_strategy.Ad_bars.gaps_in_window _gap_bars
       ~start_date:(_d "1999-12-01") ~end_date:(_d "2000-02-01") ~max_gap_days:7)
    (equal_to
       [
         (_d "1999-12-01", _d "2000-01-03");
         (_d "2000-01-04", _d "2000-01-20");
         (_d "2000-01-21", _d "2000-02-01");
       ])

let test_gaps_in_window_empty_series _ =
  assert_that
    (Weinstein_strategy.Ad_bars.gaps_in_window [] ~start_date:(_d "2000-01-01")
       ~end_date:(_d "2000-12-31") ~max_gap_days:14)
    (equal_to [ (_d "2000-01-01", _d "2000-12-31") ])

let test_gaps_in_window_covered _ =
  assert_that
    (Weinstein_strategy.Ad_bars.gaps_in_window _gap_bars
       ~start_date:(_d "2000-01-03") ~end_date:(_d "2000-01-04")
       ~max_gap_days:14)
    is_empty

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "ad_bars_compose"
  >::: [
         "Unicorn-only when no Synthetic files" >:: test_unicorn_only;
         "Synthetic-only when no Unicorn files" >:: test_synthetic_only;
         "compose: no overlap fills the tail" >:: test_compose_no_overlap;
         "compose: Unicorn wins on overlapping dates"
         >:: test_compose_unicorn_wins_on_overlap;
         "compose: result is chronologically sorted"
         >:: test_compose_result_is_sorted;
         "compose: both missing returns empty" >:: test_compose_both_missing;
         "Synthetic.load works directly" >:: test_synthetic_load_direct;
         "Synthetic.load returns [] for missing files"
         >:: test_synthetic_load_missing_files;
         "real data: composed result is valid" >:: test_load_real_data_composed;
         "compose: Synthetic fills an interior Unicorn gap"
         >:: test_compose_fills_interior_gap;
         "compose: hole at the threshold stays unfilled"
         >:: test_compose_leaves_hole_at_threshold;
         "load_with: custom threshold fills the hole"
         >:: test_load_with_custom_threshold_fills;
         "gaps: wide holes reported in order"
         >:: test_gaps_reports_wide_holes_in_order;
         "gaps: hole equal to threshold not reported"
         >:: test_gaps_exact_threshold_not_reported;
         "gaps: empty and single-bar series" >:: test_gaps_short_series;
         "gaps_in_window: edge sentinels and clipping"
         >:: test_gaps_in_window_edges_and_clip;
         "gaps_in_window: empty series is one gap"
         >:: test_gaps_in_window_empty_series;
         "gaps_in_window: covered window has no gap"
         >:: test_gaps_in_window_covered;
       ]

let () = run_test_tt_main suite
