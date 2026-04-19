(** Unit tests for Bar_loader — 3a (Metadata tier). *)

open OUnit2
open Core
open Matchers
module Bar_loader = Bar_loader

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
  let loader = Bar_loader.create ~data_dir ~sector_map ~universe:symbols in
  (loader, symbols)

(** {1 Tests} *)

let test_create_empty _ =
  let loader, _ = _fixture ~n_symbols:0 ~sector_map_entries:[] in
  assert_that (Bar_loader.stats loader)
    (all_of
       [
         field (fun s -> s.Bar_loader.metadata) (equal_to 0);
         field (fun s -> s.Bar_loader.summary) (equal_to 0);
         field (fun s -> s.Bar_loader.full) (equal_to 0);
       ]);
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
    (all_of
       [
         field (fun s -> s.Bar_loader.metadata) (equal_to 10);
         field (fun s -> s.Bar_loader.summary) (equal_to 0);
         field (fun s -> s.Bar_loader.full) (equal_to 0);
       ])

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
       (all_of
          [
            field (fun m -> m.Bar_loader.Metadata.symbol) (equal_to "S01");
            field (fun m -> m.Bar_loader.Metadata.sector) (equal_to "Tech");
            field
              (fun m -> m.Bar_loader.Metadata.last_close)
              (float_equal 100.0);
            field (fun m -> m.Bar_loader.Metadata.avg_vol_30d) is_none;
            field (fun m -> m.Bar_loader.Metadata.market_cap) is_none;
          ]));
  (* S02: no sector entry — should be "" (plan: loader does not synthesize). *)
  assert_that
    (Bar_loader.get_metadata loader ~symbol:"S02")
    (is_some_and
       (all_of
          [
            field (fun m -> m.Bar_loader.Metadata.sector) (equal_to "");
            field
              (fun m -> m.Bar_loader.Metadata.last_close)
              (float_equal 101.0);
          ]));
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
    (field (fun s -> s.Bar_loader.metadata) (equal_to 0))

let test_higher_tier_promotions_unimplemented _ =
  let loader, symbols = _fixture ~n_symbols:2 ~sector_map_entries:[] in
  let summary_result =
    Bar_loader.promote loader ~symbols ~to_:Summary_tier ~as_of:_as_of
  in
  assert_that summary_result (is_error_with Unimplemented);
  let full_result =
    Bar_loader.promote loader ~symbols ~to_:Full_tier ~as_of:_as_of
  in
  assert_that full_result (is_error_with Unimplemented)

let test_summary_full_getters_return_none _ =
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
         "higher_tier_promotions_unimplemented"
         >:: test_higher_tier_promotions_unimplemented;
         "summary_full_getters_return_none"
         >:: test_summary_full_getters_return_none;
       ]

let () = run_test_tt_main suite
