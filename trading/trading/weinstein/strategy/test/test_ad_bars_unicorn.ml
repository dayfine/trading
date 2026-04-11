(** Tests for {!Weinstein_strategy.Ad_bars.Unicorn.load}. Focused on the
    unicorn.us.com CSV format quirks — two separate files, [YYYYMMDD,count]
    rows, placeholder (0,0) rows at the tail. Other source parsers will have
    their own test_ad_bars_*.ml file alongside. *)

open OUnit2
open Core
open Matchers

let date_of_string s = Date.of_string s

(** Create a temp data_dir and write [breadth/nyse_advn.csv] and
    [breadth/nyse_decln.csv] with the given raw string contents. Returns the
    tempdir path for the caller to pass to
    {!Weinstein_strategy.Ad_bars.Unicorn.load}. *)
let with_breadth_files ~advn_contents ~decln_contents f =
  let data_dir = Core_unix.mkdtemp "/tmp/test_ad_bars" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" data_dir) in
      ())
    (fun () ->
      let breadth = Filename.concat data_dir "breadth" in
      Core_unix.mkdir breadth;
      Out_channel.write_all
        (Filename.concat breadth "nyse_advn.csv")
        ~data:advn_contents;
      Out_channel.write_all
        (Filename.concat breadth "nyse_decln.csv")
        ~data:decln_contents;
      f data_dir)

(* ------------------------------------------------------------------ *)
(* Missing files -> []                                                  *)
(* ------------------------------------------------------------------ *)

let test_load_missing_data_dir _ =
  let result =
    Weinstein_strategy.Ad_bars.Unicorn.load
      ~data_dir:"/tmp/does-not-exist-ad-bars-xyz"
  in
  assert_that result is_empty

let test_load_missing_decln_file _ =
  let data_dir = Core_unix.mkdtemp "/tmp/test_ad_bars_missing" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" data_dir) in
      ())
    (fun () ->
      let breadth = Filename.concat data_dir "breadth" in
      Core_unix.mkdir breadth;
      Out_channel.write_all
        (Filename.concat breadth "nyse_advn.csv")
        ~data:"19650301, 100\n";
      (* decln file missing -> graceful [] *)
      let result = Weinstein_strategy.Ad_bars.Unicorn.load ~data_dir in
      assert_that result is_empty)

(* ------------------------------------------------------------------ *)
(* Basic happy path                                                     *)
(* ------------------------------------------------------------------ *)

let test_load_basic _ =
  with_breadth_files
    ~advn_contents:"19650301, 550\n19650302, 590\n19650303, 574\n"
    ~decln_contents:"19650301, 400\n19650302, 380\n19650303, 410\n"
    (fun data_dir ->
      let result = Weinstein_strategy.Ad_bars.Unicorn.load ~data_dir in
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
             equal_to
               ({
                  Macro.date = date_of_string "1965-03-03";
                  advancing = 574;
                  declining = 410;
                }
                 : Macro.ad_bar);
           ]))

(* ------------------------------------------------------------------ *)
(* Placeholder rows (0,0) are filtered                                  *)
(* ------------------------------------------------------------------ *)

let test_load_filters_zero_placeholders _ =
  with_breadth_files
    ~advn_contents:
      "20200206, 1404\n\
       20200207, 1053\n\
       20200210, 1721\n\
       20200211, 0\n\
       20200212, 0\n"
    ~decln_contents:
      "20200206, 1500\n\
       20200207, 1800\n\
       20200210, 1200\n\
       20200211, 0\n\
       20200212, 0\n" (fun data_dir ->
      let result = Weinstein_strategy.Ad_bars.Unicorn.load ~data_dir in
      assert_that result (size_is 3);
      let dates = List.map result ~f:(fun (b : Macro.ad_bar) -> b.date) in
      assert_that dates
        (equal_to
           [
             date_of_string "2020-02-06";
             date_of_string "2020-02-07";
             date_of_string "2020-02-10";
           ]))

(* ------------------------------------------------------------------ *)
(* Chronological ordering                                               *)
(* ------------------------------------------------------------------ *)

let test_load_sorts_by_date _ =
  (* Input is deliberately out of order. *)
  with_breadth_files
    ~advn_contents:"19650303, 574\n19650301, 550\n19650302, 590\n"
    ~decln_contents:"19650303, 410\n19650301, 400\n19650302, 380\n"
    (fun data_dir ->
      let result = Weinstein_strategy.Ad_bars.Unicorn.load ~data_dir in
      let dates = List.map result ~f:(fun (b : Macro.ad_bar) -> b.date) in
      assert_that dates
        (equal_to
           [
             date_of_string "1965-03-01";
             date_of_string "1965-03-02";
             date_of_string "1965-03-03";
           ]))

(* ------------------------------------------------------------------ *)
(* Malformed rows are silently skipped                                  *)
(* ------------------------------------------------------------------ *)

let test_load_skips_malformed_rows _ =
  with_breadth_files
    ~advn_contents:
      "19650301, 550\n\
       not-a-date, 100\n\
       19650302, 590\n\
       19650303,abc\n\
       19650304, 600\n"
    ~decln_contents:
      "19650301, 400\n19650302, 380\n19650303, 410\n19650304, 420\n"
    (fun data_dir ->
      let result = Weinstein_strategy.Ad_bars.Unicorn.load ~data_dir in
      (* Rows 1965-03-01, 1965-03-02, 1965-03-04 have valid advn rows with
         matching decln rows. 1965-03-03 has bad advn count so the whole row
         is skipped. *)
      let dates = List.map result ~f:(fun (b : Macro.ad_bar) -> b.date) in
      assert_that dates
        (equal_to
           [
             date_of_string "1965-03-01";
             date_of_string "1965-03-02";
             date_of_string "1965-03-04";
           ]))

(* ------------------------------------------------------------------ *)
(* Unmatched dates (in advn but not decln) are dropped                  *)
(* ------------------------------------------------------------------ *)

let test_load_drops_unmatched_dates _ =
  with_breadth_files
    ~advn_contents:"19650301, 550\n19650302, 590\n19650303, 574\n"
    ~decln_contents:"19650301, 400\n19650303, 410\n" (fun data_dir ->
      let result = Weinstein_strategy.Ad_bars.Unicorn.load ~data_dir in
      let dates = List.map result ~f:(fun (b : Macro.ad_bar) -> b.date) in
      assert_that dates
        (equal_to [ date_of_string "1965-03-01"; date_of_string "1965-03-03" ]))

(* ------------------------------------------------------------------ *)
(* Real-data integration check — only runs if the cached file exists   *)
(* ------------------------------------------------------------------ *)

(** If the real [data/breadth/] CSVs are cached on disk, verify that
    {!Ad_bars.load} produces a non-trivial result ordered chronologically with
    all (0,0) placeholder rows filtered. Skipped when the file is absent. *)
let test_load_real_data _ =
  let data_dir = "/workspaces/trading-1/data" in
  let advn_path = Filename.concat data_dir "breadth/nyse_advn.csv" in
  if not (Stdlib.Sys.file_exists advn_path) then
    skip_if true "no cached breadth data";
  let result = Weinstein_strategy.Ad_bars.Unicorn.load ~data_dir in
  assert_that (List.length result) (gt (module Int_ord) 10_000);
  (* No zero-zero placeholder rows. *)
  assert_that
    (List.exists result ~f:(fun (b : Macro.ad_bar) ->
         b.advancing = 0 && b.declining = 0))
    (equal_to false);
  (* Strictly chronological. *)
  let is_sorted =
    List.is_sorted result ~compare:(fun (a : Macro.ad_bar) b ->
        Date.compare a.date b.date)
  in
  assert_that is_sorted (equal_to true)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "ad_bars_unicorn"
  >::: [
         "load returns [] when data_dir does not exist"
         >:: test_load_missing_data_dir;
         "load returns [] when decln file is missing"
         >:: test_load_missing_decln_file;
         "load parses basic adv/decln pair" >:: test_load_basic;
         "load filters (0,0) placeholder rows"
         >:: test_load_filters_zero_placeholders;
         "load sorts result chronologically" >:: test_load_sorts_by_date;
         "load skips malformed rows" >:: test_load_skips_malformed_rows;
         "load drops dates present in only one file"
         >:: test_load_drops_unmatched_dates;
         "load handles real cached breadth data" >:: test_load_real_data;
       ]

let () = run_test_tt_main suite
