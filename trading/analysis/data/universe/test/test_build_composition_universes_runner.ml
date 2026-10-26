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

let _yearly_2020 = Runner.Yearly { start_year = 2020; end_year = 2020 }
let _d = Date.of_string

let test_smoke_writes_one_file _ =
  let root, bars_root, symbol_types_path, sectors_csv_path, inventory_path =
    _setup_baseline_fixture ~year:2020
  in
  let out_dir = Filename.concat root "out" in
  let result =
    Runner.run ~dollar_volume:Universe.Dollar_volume_basis.legacy_config
      ~bars_root ~symbol_types_path ~sectors_csv_path ~inventory_path ~out_dir
      ~schedule:_yearly_2020 ~top_ns:[ 3 ]
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
    Runner.run ~dollar_volume:Universe.Dollar_volume_basis.legacy_config
      ~bars_root ~symbol_types_path ~sectors_csv_path ~inventory_path ~out_dir
      ~schedule:_yearly_2020 ~top_ns:[ 10 ]
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
                    field (fun (d, _, _) -> Date.year d) (equal_to 2020);
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
    Runner.run ~dollar_volume:Universe.Dollar_volume_basis.legacy_config
      ~bars_root ~symbol_types_path ~sectors_csv_path ~inventory_path ~out_dir
      ~schedule:_yearly_2020 ~top_ns:[ 2; 3; 5 ]
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

let _mk_committed () =
  let root = _make_tmp_dir "committed" in
  let dir = Filename.concat root "goldens-custom-universe/composition" in
  ignore
    (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote dir))
      : int);
  (root, dir)

let _refused ~out_dir =
  Result.is_error (Runner.dollar_volume_of_flag ~true_dollars:true ~out_dir)

let test_committed_dir_refused _ =
  let root, dir = _mk_committed () in
  let other = Filename.concat root "other" in
  ignore
    (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote other))
      : int);
  let link = Filename.concat root "link" in
  Core_unix.symlink ~target:dir ~link_name:link;
  assert_that
    [
      _refused ~out_dir:dir;
      _refused ~out_dir:(dir ^ "/");
      _refused ~out_dir:(dir ^ "/.");
      _refused ~out_dir:(other ^ "/../goldens-custom-universe/composition");
      _refused ~out_dir:link;
    ]
    (elements_are
       [
         equal_to true;
         equal_to true;
         equal_to true;
         equal_to true;
         equal_to true;
       ]);
  _cleanup_dir root

let test_other_dir_and_legacy_accepted _ =
  let root, dir = _mk_committed () in
  let other = Filename.concat root "elsewhere" in
  assert_that
    ( _refused ~out_dir:other,
      Result.ok (Runner.dollar_volume_of_flag ~true_dollars:false ~out_dir:dir)
    )
    (all_of
       [
         field (fun (a, _) -> a) (equal_to false);
         field
           (fun (_, b) -> b)
           (is_some_and (equal_to Universe.Dollar_volume_basis.legacy_config));
       ]);
  _cleanup_dir root

(* ---------------------------------------------------------------------- *)
(* Anchor schedules (arm SM prerequisite 1)                                *)
(* ---------------------------------------------------------------------- *)

let test_month_ends_spans_year_and_leap_february _ =
  assert_that
    (Runner.month_ends ~first:(_d "2019-11-15") ~last:(_d "2020-03-31"))
    (elements_are
       [
         equal_to (_d "2019-11-30");
         equal_to (_d "2019-12-31");
         equal_to (_d "2020-01-31");
         equal_to (_d "2020-02-29");
         equal_to (_d "2020-03-31");
       ])

let test_month_ends_excludes_partial_last_month _ =
  assert_that
    ( Runner.month_ends ~first:(_d "2020-04-30") ~last:(_d "2020-06-29"),
      Runner.month_ends ~first:(_d "2020-05-01") ~last:(_d "2020-05-30") )
    (all_of
       [
         field
           (fun (a, _) -> a)
           (elements_are
              [ equal_to (_d "2020-04-30"); equal_to (_d "2020-05-31") ]);
         field (fun (_, b) -> b) (elements_are []);
       ])

let test_yearly_anchor_dates_are_may_31 _ =
  assert_that
    (Runner.anchor_dates (Yearly { start_year = 1999; end_year = 2001 }))
    (elements_are
       [
         equal_to (_d "1999-05-31");
         equal_to (_d "2000-05-31");
         equal_to (_d "2001-05-31");
       ])

let test_snapshot_file_names _ =
  let date = _d "2010-05-31" in
  assert_that
    ( Runner.snapshot_file_name ~schedule:_yearly_2020 ~top_n:3000 ~date,
      Runner.snapshot_file_name
        ~schedule:(Month_ends { first = date; last = date })
        ~top_n:3000 ~date )
    (equal_to ("top-3000-2010.sexp", "top-3000-2010-05-31.sexp"))

let test_schedule_of_flags _ =
  let parse month_ends =
    Runner.schedule_of_flags ~start_year:1998 ~end_year:2025 ~month_ends
    |> Result.ok
  in
  assert_that
    [
      parse None;
      parse (Some "1999-05-31,2025-12-31");
      parse (Some " 2020-01-01 , 2020-01-31 ");
    ]
    (elements_are
       [
         is_some_and
           (equal_to (Runner.Yearly { start_year = 1998; end_year = 2025 }));
         is_some_and
           (equal_to
              (Runner.Month_ends
                 { first = _d "1999-05-31"; last = _d "2025-12-31" }));
         is_some_and
           (equal_to
              (Runner.Month_ends
                 { first = _d "2020-01-01"; last = _d "2020-01-31" }));
       ]);
  assert_that
    [
      parse (Some "2020-05-31");
      parse (Some "2020-06-30,2020-05-31");
      parse (Some "2020-13-01,2020-12-31");
      parse (Some "a,b,c");
    ]
    (elements_are [ is_none; is_none; is_none; is_none ])

let _run_into ~schedule ~out_dir
    (_root, bars_root, symbol_types_path, sectors_csv_path, inventory_path) =
  Runner.run ~dollar_volume:Universe.Dollar_volume_basis.true_dollars_config
    ~bars_root ~symbol_types_path ~sectors_csv_path ~inventory_path ~out_dir
    ~schedule ~top_ns:[ 3; 5 ]

let test_month_ends_writes_one_dated_file_per_anchor _ =
  let ((root, _, _, _, _) as fixture) = _setup_baseline_fixture ~year:2020 in
  let out_dir = Filename.concat root "monthly" in
  let schedule =
    Runner.Month_ends { first = _d "2020-04-01"; last = _d "2020-05-31" }
  in
  let result = _run_into ~schedule ~out_dir fixture in
  let files = _files_in_dir out_dir in
  let april =
    Universe.Snapshot.load
      ~path:(Filename.concat out_dir "top-3-2020-04-30.sexp")
  in
  _cleanup_dir root;
  assert_that result
    (all_of
       [
         field (fun r -> r.Runner.written) (equal_to 4);
         field (fun r -> r.Runner.skipped) (equal_to 0);
       ]);
  assert_that files
    (elements_are
       [
         equal_to "top-3-2020-04-30.sexp";
         equal_to "top-3-2020-05-31.sexp";
         equal_to "top-5-2020-04-30.sexp";
         equal_to "top-5-2020-05-31.sexp";
       ]);
  assert_that april
    (is_ok_and_holds
       (field (fun s -> s.Universe.Snapshot.date) (equal_to (_d "2020-04-30"))))

(* Prerequisite 2's code path: the month-end path's May 31 file is the yearly
   path's file byte for byte, so the monthly lists differ from the yearly ones
   only by date. *)
let test_month_end_may_31_is_byte_identical_to_yearly _ =
  let ((root, _, _, _, _) as fixture) = _setup_baseline_fixture ~year:2020 in
  let yearly_dir = Filename.concat root "yearly" in
  let monthly_dir = Filename.concat root "monthly" in
  let yearly = _run_into ~schedule:_yearly_2020 ~out_dir:yearly_dir fixture in
  let monthly =
    _run_into
      ~schedule:(Month_ends { first = _d "2020-04-15"; last = _d "2020-05-31" })
      ~out_dir:monthly_dir fixture
  in
  let read dir name = In_channel.read_all (Filename.concat dir name) in
  let pairs =
    List.map [ 3; 5 ] ~f:(fun n ->
        ( read yearly_dir (Printf.sprintf "top-%d-2020.sexp" n),
          read monthly_dir (Printf.sprintf "top-%d-2020-05-31.sexp" n) ))
  in
  _cleanup_dir root;
  assert_that (yearly.Runner.written, monthly.Runner.written) (equal_to (2, 4));
  assert_that pairs
    (elements_are
       (List.init 2 ~f:(fun _ ->
            all_of
              [
                field (fun (y, _) -> String.length y) (gt (module Int_ord) 0);
                field (fun (y, m) -> String.equal y m) (equal_to true);
              ])))

let suite =
  "Build_composition_universes_runner"
  >::: [
         "test_month_ends_spans_year_and_leap_february"
         >:: test_month_ends_spans_year_and_leap_february;
         "test_month_ends_excludes_partial_last_month"
         >:: test_month_ends_excludes_partial_last_month;
         "test_yearly_anchor_dates_are_may_31"
         >:: test_yearly_anchor_dates_are_may_31;
         "test_snapshot_file_names" >:: test_snapshot_file_names;
         "test_schedule_of_flags" >:: test_schedule_of_flags;
         "test_month_ends_writes_one_dated_file_per_anchor"
         >:: test_month_ends_writes_one_dated_file_per_anchor;
         "test_month_end_may_31_is_byte_identical_to_yearly"
         >:: test_month_end_may_31_is_byte_identical_to_yearly;
         "test_smoke_writes_one_file" >:: test_smoke_writes_one_file;
         "test_skip_on_insufficient_signal" >:: test_skip_on_insufficient_signal;
         "test_multi_size_writes_one_file_per_size"
         >:: test_multi_size_writes_one_file_per_size;
         "test_committed_dir_refused" >:: test_committed_dir_refused;
         "test_other_dir_and_legacy_accepted"
         >:: test_other_dir_and_legacy_accepted;
       ]

let () = run_test_tt_main suite
