(** Tests for {!Live_portfolio} — the human-editable live-holdings sexp file. *)

open Core
open OUnit2
open Matchers
module Live_portfolio = Weinstein_snapshot_gen.Live_portfolio

let _date d = Date.of_string d

(* [save] returns [unit Or_error.t]. Rendering the outcome as a string lets a
   test assert the write succeeded *and* show the error text when it did not;
   discarding the result would leave a failed write to surface indirectly, as a
   confusing failure in the read that follows. *)
let _outcome = function Ok () -> "ok" | Error e -> Error.to_string_hum e

let _sample : Live_portfolio.t =
  {
    cash = 100_000.0;
    as_of = _date "2026-07-24";
    positions =
      [
        {
          symbol = "AAPL";
          shares = 100;
          entry_price = 180.0;
          entry_date = _date "2026-06-13";
          stop_price = 168.0;
        };
      ];
  }

(* Serialize -> parse yields the original value (structural equality). *)
let test_round_trip _ =
  let parsed = Live_portfolio.t_of_sexp (Live_portfolio.sexp_of_t _sample) in
  assert_that parsed (equal_to _sample)

(* The committed template shape (cash + empty positions) parses. *)
let test_template_parses _ =
  let parsed =
    Live_portfolio.t_of_sexp
      (Sexp.of_string "((cash 100000.0) (as_of 2026-07-24) (positions ()))")
  in
  assert_that parsed
    (all_of
       [
         field (fun (p : Live_portfolio.t) -> p.cash) (float_equal 100_000.0);
         field (fun (p : Live_portfolio.t) -> p.positions) (size_is 0);
       ])

(* [load] reads a sexp file from disk and returns [Ok]. *)
let test_load_from_file _ =
  let path = Filename_unix.temp_file "live_portfolio" ".sexp" in
  Out_channel.write_all path
    ~data:(Sexp.to_string (Live_portfolio.sexp_of_t _sample));
  let loaded = Live_portfolio.load ~path in
  Sys_unix.remove path;
  assert_that (Result.ok loaded) (is_some_and (equal_to _sample))

(* [load] on a missing file returns [Error], not an exception. *)
let test_load_missing_file _ =
  let loaded = Live_portfolio.load ~path:"/nonexistent/portfolio.sexp" in
  assert_that (Result.ok loaded) is_none

(* [save] then [load] yields the original value, header comment and all. *)
let test_save_load_round_trip _ =
  let path = Filename_unix.temp_file "live_portfolio" ".sexp" in
  let saved = Live_portfolio.save _sample ~path in
  let loaded = Live_portfolio.load ~path in
  Sys_unix.remove path;
  assert_that
    (Result.ok saved |> Option.map ~f:(fun () -> Result.ok loaded))
    (is_some_and (is_some_and (equal_to _sample)))

(* The schema-documenting header survives a rewrite verbatim: sexp parsing
   drops comments, so without this the CLI would silently delete it. *)
let test_save_preserves_header _ =
  let path = Filename_unix.temp_file "live_portfolio" ".sexp" in
  let saved = Live_portfolio.save _sample ~path in
  let written = In_channel.read_all path in
  Sys_unix.remove path;
  assert_that (_outcome saved) (equal_to "ok");
  assert_that written (contains_substring (Live_portfolio.header ^ "\n((cash "))

(* A dry run prints exactly the bytes a real write would produce. *)
let test_to_file_contents_matches_saved_bytes _ =
  let path = Filename_unix.temp_file "live_portfolio" ".sexp" in
  let saved = Live_portfolio.save _sample ~path in
  let written = In_channel.read_all path in
  Sys_unix.remove path;
  assert_that (_outcome saved) (equal_to "ok");
  assert_that written (equal_to (Live_portfolio.to_file_contents _sample))

(* [save] to an unwritable path returns [Error], not an exception. *)
let test_save_unwritable_path _ =
  let saved = Live_portfolio.save _sample ~path:"/nonexistent/dir/p.sexp" in
  assert_that (Result.ok saved) is_none

let suite =
  "live_portfolio"
  >::: [
         "round_trip" >:: test_round_trip;
         "template_parses" >:: test_template_parses;
         "load_from_file" >:: test_load_from_file;
         "load_missing_file" >:: test_load_missing_file;
         "save_load_round_trip" >:: test_save_load_round_trip;
         "save_preserves_header" >:: test_save_preserves_header;
         "to_file_contents_matches_saved_bytes"
         >:: test_to_file_contents_matches_saved_bytes;
         "save_unwritable_path" >:: test_save_unwritable_path;
       ]

let () = run_test_tt_main suite
