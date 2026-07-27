(** Tests for {!Live_portfolio} — the human-editable live-holdings sexp file. *)

open Core
open OUnit2
open Matchers
module Live_portfolio = Weinstein_snapshot_gen.Live_portfolio
module Stop_track = Weinstein_snapshot_gen.Stop_track

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
          stop_state = None;
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

(* --- stop_state back-compat + round-trip (item 4c.b) --------------------- *)

(* The exact shape every [portfolio.sexp] written before item 4c.b has: a
   position record with NO [stop_state] field. Written as a literal string on
   purpose — round-tripping the new type would serialise the field and never
   exercise the [@sexp.default None] that makes those files keep loading. *)
let _pre_4cb_sexp =
  "((cash 82000.0) (as_of 2026-07-24) (positions (((symbol AAPL) (shares 100) \
   (entry_price 180.0) (entry_date 2026-06-13) (stop_price 168.0)))))"

let test_pre_4cb_file_still_loads _ =
  assert_that
    (Live_portfolio.t_of_sexp (Sexp.of_string _pre_4cb_sexp))
    (all_of
       [
         field (fun (p : Live_portfolio.t) -> p.cash) (float_equal 82_000.0);
         field
           (fun (p : Live_portfolio.t) -> p.positions)
           (elements_are
              [
                all_of
                  [
                    field
                      (fun (p : Live_portfolio.position) -> p.stop_price)
                      (float_equal 168.0);
                    field
                      (fun (p : Live_portfolio.position) -> p.stop_state)
                      is_none;
                  ];
              ]);
       ])

(* A populated track survives serialize -> parse, state arm and all. *)
let test_stop_state_round_trips _ =
  let track : Stop_track.t =
    {
      state =
        Trailing
          {
            stop_level = 172.5;
            last_correction_extreme = 175.0;
            last_trend_extreme = 195.0;
            ma_at_last_adjustment = 170.0;
            correction_count = 2;
            correction_observed_since_reset = true;
          };
      updated = _date "2026-07-24";
      raises = 3;
    }
  in
  let sample =
    {
      _sample with
      positions =
        List.map _sample.positions ~f:(fun (p : Live_portfolio.position) ->
            { p with stop_state = Some track });
    }
  in
  assert_that
    (Live_portfolio.t_of_sexp (Live_portfolio.sexp_of_t sample))
    (equal_to sample)

(* The schema-drift obligation (dev/status/cleanup.md §Backlog): [header] is a
   hand-written comment block with nothing tying it to [type position], so a new
   field must be documented in the same change or the file's own documentation
   silently goes stale. *)
let test_header_documents_stop_state _ =
  assert_that Live_portfolio.header
    (all_of
       [
         contains_substring "stop_state";
         contains_substring "--allow-lower-stop";
       ])

(* The header ships to the trader, so what it promises has to be what the code
   does. Two claims are pinned here because both were wrong before this test
   existed: the header told the trader "the tooling writes and updates it" when
   nothing writes the field at all (item 4c.c), and it described
   [--allow-lower-stop] as resetting the state without saying that nothing then
   recreates it. Both now say so, and the words appear in [header] itself rather
   than only in a doc-comment the trader never sees. *)
let test_header_does_not_promise_an_unwired_write_back _ =
  assert_that Live_portfolio.header
    (all_of
       [
         contains_substring "Nothing writes this field yet";
         contains_substring "nothing recreates it";
       ])

(* Extracts the top-level field names of a record's derived sexp, without
   recursing into nested substructure. Sexplib renders a record as a list of
   [(field_name value)] pairs, so each field is a 2-element [List (Atom name ::
   _)]; the payload itself is opaque here on purpose — recursing into it would
   also surface e.g. [Stop_track.t]'s internal field names, which [header]
   never claims to document. *)
let _record_field_names (sexp : Sexp.t) : string list =
  match sexp with
  | Sexp.List items ->
      List.filter_map items ~f:(function
        | Sexp.List (Sexp.Atom name :: _) -> Some name
        | _ -> None)
  | Sexp.Atom _ -> []

(* Ties [header]'s field list to the ACTUAL fields of [type t] / [type
   position], via their derived sexp representations, rather than to a second
   hand-maintained list in this test: renaming or adding a field changes what
   [sexp_of_t]/[sexp_of_position] emit, so this catches the drift the schema-
   drift finding (dev/status/cleanup.md §Backlog) describes without touching
   live_portfolio.ml/.mli. *)
let test_header_names_every_schema_field _ =
  let t_fields = _record_field_names (Live_portfolio.sexp_of_t _sample) in
  let position_fields =
    _record_field_names
      (Live_portfolio.sexp_of_position (List.hd_exn _sample.positions))
  in
  let undocumented =
    List.filter (t_fields @ position_fields) ~f:(fun name ->
        not (String.is_substring Live_portfolio.header ~substring:name))
  in
  assert_that undocumented (size_is 0)

let suite =
  "live_portfolio"
  >::: [
         "round_trip" >:: test_round_trip;
         "pre_4cb_file_still_loads" >:: test_pre_4cb_file_still_loads;
         "stop_state_round_trips" >:: test_stop_state_round_trips;
         "header_documents_stop_state" >:: test_header_documents_stop_state;
         "header_does_not_promise_an_unwired_write_back"
         >:: test_header_does_not_promise_an_unwired_write_back;
         "header_names_every_schema_field"
         >:: test_header_names_every_schema_field;
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
