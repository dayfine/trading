open Core
open OUnit2
open Matchers
module Runner = Build_composition_universes_runner_lib

(* ---------------------------------------------------------------------- *)
(* Fixture builders — mirror test_build_from_individuals at higher level   *)
(* ---------------------------------------------------------------------- *)

let _make_tmp_dir suffix =
  let dir = Stdlib.Filename.temp_file "runner_test_" ("_" ^ suffix ^ ".d") in
  (try Stdlib.Sys.remove dir with _ -> ());
  ignore
    (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote dir))
      : int);
  dir

let _cleanup_dir dir =
  ignore
    (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote dir)) : int)

let _files_in_dir dir =
  Stdlib.Sys.readdir dir |> Array.to_list |> List.sort ~compare:String.compare

let _write_bars ~bars_root sym ~year ~close ~volume ~p_end_forward =
  let l1 = String.prefix sym 1 in
  (* Sharding: first letter / last letter (matches Csv_storage). *)
  let l2 =
    if String.length sym >= 2 then
      String.sub sym ~pos:(String.length sym - 1) ~len:1
    else l1
  in
  let dir =
    Filename.concat (Filename.concat (Filename.concat bars_root l1) l2) sym
  in
  ignore
    (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote dir))
      : int);
  let path = Filename.concat dir "data.csv" in
  let buf = Buffer.create 1024 in
  Buffer.add_string buf "date,open,high,low,close,adjusted_close,volume\n";
  (* 60 trailing bars stepping back from [year]-May-29. *)
  let anchor = Date.create_exn ~y:year ~m:Month.May ~d:29 in
  for i = 0 to 59 do
    let d = Date.add_days anchor (-i) in
    Buffer.add_string buf
      (Printf.sprintf "%s,%.2f,%.2f,%.2f,%.2f,%.2f,%d\n" (Date.to_string d)
         close close close close close volume)
  done;
  Buffer.add_string buf
    (Printf.sprintf "%d-06-01,%.2f,%.2f,%.2f,%.2f,%.2f,1000\n" year close close
       close close close);
  Buffer.add_string buf
    (Printf.sprintf "%d-05-31,%.2f,%.2f,%.2f,%.2f,%.2f,1000\n" (year + 1)
       p_end_forward p_end_forward p_end_forward p_end_forward p_end_forward);
  Out_channel.write_all path ~data:(Buffer.contents buf)

let _common_stock = "(Listed \"Common Stock\")"

let _symbol_types_sexp_of entries =
  let body_lines =
    List.map entries ~f:(fun (sym, asset_type_sexp) ->
        Printf.sprintf "    ((symbol %s) (asset_type %s) (exchange \"\"))" sym
          asset_type_sexp)
  in
  "((generated_at 2020-05-30)\n (source_endpoints ())\n (symbols (\n"
  ^ String.concat ~sep:"\n" body_lines
  ^ ")))\n"

let _setup_baseline_fixture ~year =
  let root = _make_tmp_dir "runner" in
  let bars_root = Filename.concat root "bars" in
  ignore
    (Stdlib.Sys.command
       (Printf.sprintf "mkdir -p %s" (Filename.quote bars_root))
      : int);
  let specs =
    [
      ("AAA", 100.0, 1_000_000, 120.0);
      ("BBB", 50.0, 1_000_000, 60.0);
      ("CCC", 25.0, 800_000, 30.0);
      ("DDD", 10.0, 500_000, 11.0);
      ("EEE", 5.0, 100_000, 5.5);
    ]
  in
  List.iter specs ~f:(fun (sym, close, vol, pend) ->
      _write_bars ~bars_root sym ~year ~close ~volume:vol ~p_end_forward:pend);
  let symbol_types_path = Filename.concat root "symbol_types.sexp" in
  Out_channel.write_all symbol_types_path
    ~data:
      (_symbol_types_sexp_of
         (List.map specs ~f:(fun (s, _, _, _) -> (s, _common_stock))));
  let sectors_csv_path = Filename.concat root "sectors.csv" in
  Out_channel.write_all sectors_csv_path
    ~data:
      "symbol,sector\nAAA,Tech\nBBB,Tech\nCCC,Health\nDDD,Energy\nEEE,Other\n";
  let inventory_path = Filename.concat root "inventory.sexp" in
  let body =
    List.map specs ~f:(fun (s, _, _, _) ->
        Printf.sprintf
          "  ((symbol %s) (data_start_date 2010-01-01) (data_end_date \
           2022-01-01))"
          s)
    |> String.concat ~sep:"\n"
  in
  Out_channel.write_all inventory_path
    ~data:
      (Printf.sprintf "((generated_at 2020-05-30)\n (symbols (\n%s)))\n" body);
  (root, bars_root, symbol_types_path, sectors_csv_path, inventory_path)

(* ---------------------------------------------------------------------- *)
(* Tests                                                                   *)
(* ---------------------------------------------------------------------- *)

let test_smoke_writes_one_file _ =
  let root, bars_root, symbol_types_path, sectors_csv_path, inventory_path =
    _setup_baseline_fixture ~year:2020
  in
  let out_dir = Filename.concat root "out" in
  let result =
    Runner.run ~bars_root ~symbol_types_path ~sectors_csv_path ~inventory_path
      ~out_dir ~start_year:2020 ~end_year:2020 ~top_ns:[ 3 ]
  in
  let files = _files_in_dir out_dir in
  let snapshot_path = Filename.concat out_dir "top-3-2020.sexp" in
  let loaded = Universe.Snapshot.load ~path:snapshot_path in
  _cleanup_dir root;
  assert_that result
    (all_of
       [
         field (fun r -> r.Runner.written) (equal_to 1);
         field (fun r -> r.Runner.skipped) (equal_to 0);
       ]);
  assert_that files (elements_are [ equal_to "top-3-2020.sexp" ]);
  assert_that loaded
    (is_ok_and_holds
       (all_of
          [
            field (fun s -> s.Universe.Snapshot.size) (equal_to 3);
            field
              (fun s -> List.length s.Universe.Snapshot.entries)
              (equal_to 3);
          ]))

let test_skip_on_insufficient_signal _ =
  let root, bars_root, symbol_types_path, sectors_csv_path, inventory_path =
    _setup_baseline_fixture ~year:2020
  in
  let out_dir = Filename.concat root "out" in
  (* Asking for size=10 from a 5-symbol fixture must surface as a skip,
     not a crash. *)
  let result =
    Runner.run ~bars_root ~symbol_types_path ~sectors_csv_path ~inventory_path
      ~out_dir ~start_year:2020 ~end_year:2020 ~top_ns:[ 10 ]
  in
  let files = _files_in_dir out_dir in
  _cleanup_dir root;
  assert_that result
    (all_of
       [
         field (fun r -> r.Runner.written) (equal_to 0);
         field (fun r -> r.Runner.skipped) (equal_to 1);
         field
           (fun r -> r.Runner.skip_reasons)
           (elements_are
              [
                all_of
                  [
                    field (fun (y, _, _) -> y) (equal_to 2020);
                    field (fun (_, t, _) -> t) (equal_to 10);
                  ];
              ]);
       ]);
  assert_that files (elements_are [])

let test_multi_size_writes_one_file_per_size _ =
  let root, bars_root, symbol_types_path, sectors_csv_path, inventory_path =
    _setup_baseline_fixture ~year:2020
  in
  let out_dir = Filename.concat root "out" in
  let result =
    Runner.run ~bars_root ~symbol_types_path ~sectors_csv_path ~inventory_path
      ~out_dir ~start_year:2020 ~end_year:2020 ~top_ns:[ 2; 3; 5 ]
  in
  let files = _files_in_dir out_dir in
  _cleanup_dir root;
  assert_that result
    (all_of
       [
         field (fun r -> r.Runner.written) (equal_to 3);
         field (fun r -> r.Runner.skipped) (equal_to 0);
       ]);
  assert_that files
    (elements_are
       [
         equal_to "top-2-2020.sexp";
         equal_to "top-3-2020.sexp";
         equal_to "top-5-2020.sexp";
       ])

let suite =
  "Build_composition_universes_runner"
  >::: [
         "test_smoke_writes_one_file" >:: test_smoke_writes_one_file;
         "test_skip_on_insufficient_signal" >:: test_skip_on_insufficient_signal;
         "test_multi_size_writes_one_file_per_size"
         >:: test_multi_size_writes_one_file_per_size;
       ]

let () = run_test_tt_main suite
