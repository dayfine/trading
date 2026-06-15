open Core
open OUnit2
open Matchers
open Universe
open Universe.Snapshot
module BEU = Build_eligible_universe

(* ---------------------------------------------------------------------- *)
(* Fixture builders                                                        *)
(* ---------------------------------------------------------------------- *)

(* All fixtures anchor at 2020-05-31. The trailing dollar-volume window is
   the default 60 calendar days back ([2020-04-01, 2020-05-31]). *)
let _build_date = Date.create_exn ~y:2020 ~m:Month.May ~d:31

let _make_tmp_dir suffix =
  let dir = Stdlib.Filename.temp_file "beu_test_" ("_" ^ suffix ^ ".d") in
  (try Stdlib.Sys.remove dir with _ -> ());
  ignore
    (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote dir))
      : int);
  dir

let _cleanup_dir dir =
  ignore
    (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote dir)) : int)

(* Mirror the production sharding rule: data/<L1>/<L2>/<symbol>/data.csv. *)
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

(* Write [n_bars] daily trailing bars at constant (close, volume), stepping
   back from 2020-05-29. Score = close * volume; latest close = close. *)
let _write_bars ~root sym ~close ~volume ~n_bars =
  let path = _bars_path ~root sym in
  let anchor = Date.create_exn ~y:2020 ~m:Month.May ~d:29 in
  let buf = Buffer.create 1024 in
  Buffer.add_string buf "date,open,high,low,close,adjusted_close,volume\n";
  List.iter (List.init n_bars ~f:Fn.id) ~f:(fun i ->
      let date = Date.add_days anchor (-i) in
      Buffer.add_string buf
        (Printf.sprintf "%s,%.2f,%.2f,%.2f,%.2f,%.2f,%d\n" (Date.to_string date)
           close close close close close volume));
  Out_channel.write_all path ~data:(Buffer.contents buf)

let _symbol_types_sexp_of entries =
  let body_lines =
    List.map entries ~f:(fun (sym, asset_type_sexp) ->
        Printf.sprintf "    ((symbol %s) (asset_type %s) (exchange \"\"))" sym
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

let _write_inventory ~root symbols =
  let path = Filename.concat root "inventory.sexp" in
  let body_lines =
    List.map symbols ~f:(fun sym ->
        Printf.sprintf
          "  ((symbol %s) (data_start_date 2010-01-01) (data_end_date \
           2022-01-01))"
          sym)
  in
  let sexp =
    "((generated_at 2020-05-30)\n (symbols (\n"
    ^ String.concat ~sep:"\n" body_lines
    ^ ")))\n"
  in
  Out_channel.write_all path ~data:sexp;
  path

(* Asset-type literals for symbol_types.sexp. *)
let _common = "(Listed \"Common Stock\")"
let _etf = "(Listed ETF)"
let _preferred = "(Listed \"Preferred Stock\")"
let _adr = "(Listed ADR)"

(* A symbol spec: name, close, volume, n_bars, asset-type literal, sector. *)
type spec = {
  sym : string;
  close : float;
  volume : int;
  n_bars : int;
  asset_type : string;
  sector : string;
}

let _spec ?(close = 50.0) ?(volume = 1_000_000) ?(n_bars = 60)
    ?(asset_type = _common) ?(sector = "Tech") sym =
  { sym; close; volume; n_bars; asset_type; sector }

(* Materialize the fixture from a spec list and return [(root, config)] using
   the live-universe spec_config gates. Caller must [_cleanup_dir root]. *)
let _setup ~specs =
  let root = _make_tmp_dir "fix" in
  let bars_root = Filename.concat root "bars" in
  ignore
    (Stdlib.Sys.command
       (Printf.sprintf "mkdir -p %s" (Filename.quote bars_root))
      : int);
  List.iter specs ~f:(fun s ->
      _write_bars ~root:bars_root s.sym ~close:s.close ~volume:s.volume
        ~n_bars:s.n_bars);
  let symbol_types_path =
    _write_symbol_types ~root
      (List.map specs ~f:(fun s -> (s.sym, s.asset_type)))
  in
  let sectors_csv_path =
    _write_sectors_csv ~root (List.map specs ~f:(fun s -> (s.sym, s.sector)))
  in
  let inventory_path =
    _write_inventory ~root (List.map specs ~f:(fun s -> s.sym))
  in
  let config =
    BEU.spec_config ~bars_root ~symbol_types_path ~sectors_csv_path
      ~inventory_path
  in
  (root, config)

let _build_or_fail ~config =
  match BEU.build ~date:_build_date ~config with
  | Ok snapshot -> snapshot
  | Error err -> assert_failure ("build failed: " ^ Status.show err)

let _symbols snapshot = List.map snapshot.entries ~f:(fun e -> e.symbol)

(* ---------------------------------------------------------------------- *)
(* Tests                                                                   *)
(* ---------------------------------------------------------------------- *)

(* min_price boundary: spec floor is 5.0. A symbol at exactly 5.0 is kept; a
   symbol at 4.99 is dropped. Both clear the dollar-volume floor (high volume).
   KEEP at 5.0 needs 5.0 * volume >= 1M ⇒ volume 1M gives 5M. *)
let test_min_price_boundary _ =
  let specs =
    [
      _spec "ATFLOOR" ~close:5.0 ~volume:1_000_000;
      _spec "BELOW" ~close:4.99 ~volume:1_000_000;
    ]
  in
  let root, config = _setup ~specs in
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that (_symbols snapshot) (elements_are [ equal_to "ATFLOOR" ])

(* min_avg_dollar_volume: spec floor is 1_000_000.0. ABOVE (50 * 100k = 5M)
   kept; BELOW (50 * 10k = 500k) dropped. Both clear the price floor. *)
let test_min_dollar_volume_gate _ =
  let specs =
    [
      _spec "ABOVE" ~close:50.0 ~volume:100_000;
      _spec "BELOWADV" ~close:50.0 ~volume:10_000;
    ]
  in
  let root, config = _setup ~specs in
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that (_symbols snapshot) (elements_are [ equal_to "ABOVE" ])

(* min_window_bars: a symbol with only 5 trailing bars is dropped even though
   its per-bar dollar volume clears the floor. *)
let test_min_window_bars_gate _ =
  let specs =
    [
      _spec "DENSE" ~close:50.0 ~volume:1_000_000 ~n_bars:60;
      _spec "SPARSE" ~close:50.0 ~volume:1_000_000 ~n_bars:5;
    ]
  in
  let root, config = _setup ~specs in
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that (_symbols snapshot) (elements_are [ equal_to "DENSE" ])

(* Asset-type / junk filters: a common stock and an ADR are kept; an ETF, a
   preferred share, and a REIT (sector = "Real Estate") are dropped. Output is
   rank-ordered by dollar volume; CMN (close 80) ranks above the ADR (close 50). *)
let test_asset_type_and_junk_filters _ =
  let specs =
    [
      _spec "CMN" ~close:80.0 ~volume:1_000_000 ~asset_type:_common;
      _spec "ADRX" ~close:50.0 ~volume:1_000_000 ~asset_type:_adr;
      _spec "ETFX" ~close:90.0 ~volume:1_000_000 ~asset_type:_etf;
      _spec "PFD" ~close:70.0 ~volume:1_000_000 ~asset_type:_preferred;
      _spec "REITX" ~close:60.0 ~volume:1_000_000 ~asset_type:_common
        ~sector:"Real Estate";
    ]
  in
  let root, config = _setup ~specs in
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that (_symbols snapshot)
    (elements_are [ equal_to "CMN"; equal_to "ADRX" ])

(* No top-N truncation: K eligible common stocks ⇒ exactly K entries, all of
   them, regardless of count. Here K = 6. *)
let test_no_size_cap _ =
  let specs =
    List.init 6 ~f:(fun i ->
        _spec (Printf.sprintf "SYM%d" i)
          ~close:(Float.of_int (10 + i))
          ~volume:1_000_000)
  in
  let root, config = _setup ~specs in
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that snapshot
    (all_of
       [
         field (fun s -> s.size) (equal_to 6);
         field (fun s -> List.length s.entries) (equal_to 6);
       ])

(* Equal weight 1/K and total weight ≈ 1.0 (K = 4). *)
let test_equal_weight _ =
  let specs =
    List.init 4 ~f:(fun i ->
        _spec (Printf.sprintf "EQ%d" i)
          ~close:(Float.of_int (20 + i))
          ~volume:1_000_000)
  in
  let root, config = _setup ~specs in
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that snapshot
    (all_of
       [
         field
           (fun s -> List.map s.entries ~f:(fun e -> e.weight))
           (elements_are
              [
                float_equal ~epsilon:1e-9 0.25;
                float_equal ~epsilon:1e-9 0.25;
                float_equal ~epsilon:1e-9 0.25;
                float_equal ~epsilon:1e-9 0.25;
              ]);
         field
           (fun s -> Snapshot.total_weight s)
           (float_equal ~epsilon:1e-9 1.0);
       ])

(* default_config is a keep-all no-op: with min_price = 0 and
   min_avg_dollar_volume = 0 and reit_policy = Include and
   exclude_preferred = false, a penny stock + a preferred + a REIT all survive
   (only the equity-like filter, which drops ETFs, still applies). K = 3. *)
let test_default_config_keeps_all _ =
  let specs =
    [
      _spec "PENNY" ~close:0.10 ~volume:1;
      _spec "PFD2" ~close:70.0 ~volume:1 ~asset_type:_preferred;
      _spec "REIT2" ~close:60.0 ~volume:1 ~sector:"Real Estate";
    ]
  in
  let root, _spec_cfg = _setup ~specs in
  let bars_root = Filename.concat root "bars" in
  let config =
    BEU.default_config ~bars_root
      ~symbol_types_path:(Filename.concat root "symbol_types.sexp")
      ~sectors_csv_path:(Filename.concat root "sectors.csv")
      ~inventory_path:(Filename.concat root "inventory.sexp")
  in
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that snapshot (field (fun s -> s.size) (equal_to 3))

(* Empty universe (every symbol dropped by the gates) is a Failed_precondition
   error, not an empty snapshot. All symbols are sub-price penny stocks. *)
let test_empty_universe_is_error _ =
  let specs =
    [
      _spec "P1" ~close:1.0 ~volume:1_000_000;
      _spec "P2" ~close:2.0 ~volume:1_000_000;
    ]
  in
  let root, config = _setup ~specs in
  let result = BEU.build ~date:_build_date ~config in
  _cleanup_dir root;
  assert_that result (is_error_with Status.Failed_precondition)

(* Determinism: two builds of the same fixture are identical. *)
let test_determinism _ =
  let specs =
    [
      _spec "AAA" ~close:80.0 ~volume:1_000_000;
      _spec "BBB" ~close:50.0 ~volume:1_000_000;
    ]
  in
  let root, config = _setup ~specs in
  let s1 = _build_or_fail ~config in
  let s2 = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that s2 (equal_to s1)

(* Entries carry avg_dollar_volume = Some (close * volume) and the live-build
   tag: synthetic = false, aggregate_period_return = 0.0. *)
let test_entry_metadata _ =
  let specs = [ _spec "ONE" ~close:50.0 ~volume:1_000_000 ] in
  let root, config = _setup ~specs in
  let snapshot = _build_or_fail ~config in
  _cleanup_dir root;
  assert_that snapshot
    (all_of
       [
         field
           (fun s -> List.map s.entries ~f:(fun e -> e.avg_dollar_volume))
           (elements_are
              [ is_some_and (float_equal ~epsilon:1.0 50_000_000.0) ]);
         field
           (fun s -> List.map s.entries ~f:(fun e -> e.synthetic))
           (elements_are [ equal_to false ]);
         field (fun s -> s.aggregate_period_return) (float_equal 0.0);
       ])

let suite =
  "Build_eligible_universe"
  >::: [
         "test_min_price_boundary" >:: test_min_price_boundary;
         "test_min_dollar_volume_gate" >:: test_min_dollar_volume_gate;
         "test_min_window_bars_gate" >:: test_min_window_bars_gate;
         "test_asset_type_and_junk_filters" >:: test_asset_type_and_junk_filters;
         "test_no_size_cap" >:: test_no_size_cap;
         "test_equal_weight" >:: test_equal_weight;
         "test_default_config_keeps_all" >:: test_default_config_keeps_all;
         "test_empty_universe_is_error" >:: test_empty_universe_is_error;
         "test_determinism" >:: test_determinism;
         "test_entry_metadata" >:: test_entry_metadata;
       ]

let () = run_test_tt_main suite
