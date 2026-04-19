(** Unit tests for Bar_loader — 3a (Metadata tier). *)

open OUnit2
open Core
open Matchers
module Bar_loader = Bar_loader

(* Re-declare records here with [@@deriving test_matcher] so ppx_test_matcher
   generates exhaustive [match_<name>] helpers. The [type x = Module.x = { ... }]
   form keeps the test type identical to the production type. *)
type metadata = Bar_loader.Metadata.t = {
  symbol : string;
  sector : string;
  last_close : float;
  avg_vol_30d : float option;
  market_cap : float option;
}
[@@deriving test_matcher]

type stats_counts = Bar_loader.stats_counts = {
  metadata : int;
  summary : int;
  full : int;
}
[@@deriving test_matcher]

(** {1 Fixture helpers}

    Each test builds its own temp data dir with a handful of synthetic CSVs so
    we don't depend on checked-in fixtures. Symbols are chosen short and unique
    (S01 .. S10) so they land in deterministic subdirectories under
    [data_dir/<first>/<last>/<symbol>/data.csv]. *)

let _mk_bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
  }

(** Three consecutive daily bars ending on [2024-01-05]. Close on the last bar
    is the distinguishing scalar we assert on in get_metadata tests. *)
let _make_bars ~last_close =
  [
    _mk_bar
      ~date:(Date.create_exn ~y:2024 ~m:Jan ~d:3)
      ~close:(last_close -. 2.0);
    _mk_bar
      ~date:(Date.create_exn ~y:2024 ~m:Jan ~d:4)
      ~close:(last_close -. 1.0);
    _mk_bar ~date:(Date.create_exn ~y:2024 ~m:Jan ~d:5) ~close:last_close;
  ]

let _ok_or_fail ~context = function
  | Ok v -> v
  | Error (err : Status.t) ->
      assert_failure (Printf.sprintf "%s: %s" context (Status.show err))

let _write_symbol ~data_dir ~symbol ~last_close =
  let storage =
    Csv.Csv_storage.create ~data_dir symbol
    |> _ok_or_fail ~context:("Csv_storage.create " ^ symbol)
  in
  Csv.Csv_storage.save storage (_make_bars ~last_close)
  |> _ok_or_fail ~context:("Csv_storage.save " ^ symbol)

let _fresh_data_dir () =
  let dir = Filename_unix.temp_dir "bar_loader_test_" "" in
  Fpath.v dir

let _as_of = Date.create_exn ~y:2024 ~m:Jan ~d:31

(** Build a fixture of [n] symbols, each with last close = 100 + index. Returns
    the loader plus the list of symbols written (in insertion order). *)
let _fixture ~n_symbols ~sector_map_entries =
  let data_dir = _fresh_data_dir () in
  let symbols =
    List.init n_symbols ~f:(fun i -> Printf.sprintf "S%02d" (i + 1))
  in
  List.iteri symbols ~f:(fun i symbol ->
      _write_symbol ~data_dir ~symbol ~last_close:(100.0 +. Float.of_int i));
  let sector_map = String.Table.create () in
  List.iter sector_map_entries ~f:(fun (sym, sec) ->
      Hashtbl.set sector_map ~key:sym ~data:sec);
  let loader = Bar_loader.create ~data_dir ~sector_map ~universe:symbols () in
  (loader, symbols)

(** {1 Tests} *)

let test_create_empty _ =
  let loader, _ = _fixture ~n_symbols:0 ~sector_map_entries:[] in
  assert_that (Bar_loader.stats loader)
    (match_stats_counts ~metadata:(equal_to 0) ~summary:(equal_to 0)
       ~full:(equal_to 0));
  assert_that (Bar_loader.tier_of loader ~symbol:"S01") is_none;
  assert_that (Bar_loader.get_metadata loader ~symbol:"S01") is_none

let test_promote_10_symbols_stats _ =
  let loader, symbols =
    _fixture ~n_symbols:10
      ~sector_map_entries:
        [ ("S01", "Tech"); ("S02", "Tech"); ("S03", "Financials") ]
  in
  let result =
    Bar_loader.promote loader ~symbols ~to_:Metadata_tier ~as_of:_as_of
  in
  assert_that result is_ok;
  assert_that (Bar_loader.stats loader)
    (match_stats_counts ~metadata:(equal_to 10) ~summary:(equal_to 0)
       ~full:(equal_to 0))

let test_get_metadata_returns_data _ =
  let loader, symbols =
    _fixture ~n_symbols:3 ~sector_map_entries:[ ("S01", "Tech") ]
  in
  let _ =
    Bar_loader.promote loader ~symbols ~to_:Metadata_tier ~as_of:_as_of
    |> _ok_or_fail ~context:"Bar_loader.promote"
  in
  (* S01: sector set in map, last_close = 100.0 (index 0). *)
  assert_that
    (Bar_loader.get_metadata loader ~symbol:"S01")
    (is_some_and
       (match_metadata ~symbol:(equal_to "S01") ~sector:(equal_to "Tech")
          ~last_close:(float_equal 100.0) ~avg_vol_30d:is_none
          ~market_cap:is_none));
  (* S02: no sector entry — should be "" (plan: loader does not synthesize). *)
  assert_that
    (Bar_loader.get_metadata loader ~symbol:"S02")
    (is_some_and
       (match_metadata ~symbol:__ ~sector:(equal_to "")
          ~last_close:(float_equal 101.0) ~avg_vol_30d:__ ~market_cap:__));
  assert_that
    (Bar_loader.tier_of loader ~symbol:"S01")
    (is_some_and (equal_to Bar_loader.Metadata_tier))

let test_promote_is_idempotent _ =
  let loader, symbols =
    _fixture ~n_symbols:5 ~sector_map_entries:[ ("S01", "Tech") ]
  in
  let _ =
    Bar_loader.promote loader ~symbols ~to_:Metadata_tier ~as_of:_as_of
    |> _ok_or_fail ~context:"Bar_loader.promote"
  in
  let stats_before = Bar_loader.stats loader in
  (* Re-promote the same symbols to the same tier — must be a no-op. *)
  let _ =
    Bar_loader.promote loader ~symbols ~to_:Metadata_tier ~as_of:_as_of
    |> _ok_or_fail ~context:"Bar_loader.promote"
  in
  assert_that (Bar_loader.stats loader) (equal_to stats_before)

let test_promote_missing_symbol_errors _ =
  (* Symbol not in data_dir — Price_cache returns NotFound; promote surfaces it. *)
  let loader, _ = _fixture ~n_symbols:0 ~sector_map_entries:[] in
  let result =
    Bar_loader.promote loader ~symbols:[ "NOPE" ] ~to_:Metadata_tier
      ~as_of:_as_of
  in
  assert_that result is_error;
  (* The failed symbol was not inserted. *)
  assert_that (Bar_loader.tier_of loader ~symbol:"NOPE") is_none;
  assert_that (Bar_loader.stats loader)
    (match_stats_counts ~metadata:(equal_to 0) ~summary:__ ~full:__)

(** Sanity guard: the supported higher tier (Summary) must NOT return
    [Unimplemented] from this call surface. End-to-end Summary behaviour with
    full benchmark data is in [test_summary.ml]; Full-tier semantics are in
    [test_full.ml]. Here the fixture has no benchmark series, so the call may
    legitimately fail with [NotFound] — what we pin is only that the failure
    code is *not* [Unimplemented]. *)
let test_summary_promotion_supported _ =
  let loader, symbols =
    _fixture ~n_symbols:1 ~sector_map_entries:[ ("S01", "Tech") ]
  in
  let summary_result =
    Bar_loader.promote loader ~symbols ~to_:Summary_tier ~as_of:_as_of
  in
  match summary_result with
  | Ok () -> ()
  | Error (err : Status.t) ->
      if Status.equal_code err.code Status.Unimplemented then
        assert_failure
          (Printf.sprintf
             "Summary_tier must be implemented, got Unimplemented: %s"
             err.message)

let test_summary_getter_none_on_metadata_only _ =
  (* After Metadata-only promotion the Summary / Full getters must both be
     [None] — the entry exists at Metadata tier but no higher-tier data has
     been computed yet. Full-tier promotion semantics live in [test_full.ml]. *)
  let loader, symbols =
    _fixture ~n_symbols:2 ~sector_map_entries:[ ("S01", "Tech") ]
  in
  let _ =
    Bar_loader.promote loader ~symbols ~to_:Metadata_tier ~as_of:_as_of
    |> _ok_or_fail ~context:"Bar_loader.promote"
  in
  assert_that (Bar_loader.get_summary loader ~symbol:"S01") is_none;
  assert_that (Bar_loader.get_full loader ~symbol:"S01") is_none

let suite =
  "Bar_loader.Metadata"
  >::: [
         "create_empty" >:: test_create_empty;
         "promote_10_symbols_stats" >:: test_promote_10_symbols_stats;
         "get_metadata_returns_data" >:: test_get_metadata_returns_data;
         "promote_is_idempotent" >:: test_promote_is_idempotent;
         "promote_missing_symbol_errors" >:: test_promote_missing_symbol_errors;
         "summary_promotion_supported" >:: test_summary_promotion_supported;
         "summary_getter_none_on_metadata_only"
         >:: test_summary_getter_none_on_metadata_only;
       ]

let () = run_test_tt_main suite
