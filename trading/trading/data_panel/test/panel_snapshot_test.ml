open OUnit2
open Core
open Matchers
module Symbol_index = Data_panel.Symbol_index
module Panel_snapshot = Data_panel.Panel_snapshot
module BA2 = Bigarray.Array2

let _make_idx universe =
  match Symbol_index.create ~universe with
  | Ok t -> t
  | Error err ->
      assert_failure (Printf.sprintf "create failed: %s" err.Status.message)

let _make_panel ~n_rows ~n_cols ~fill =
  let p = BA2.create Bigarray.Float64 Bigarray.C_layout n_rows n_cols in
  for r = 0 to n_rows - 1 do
    for c = 0 to n_cols - 1 do
      BA2.unsafe_set p r c (fill r c)
    done
  done;
  p

let _bit_identical a b =
  let r = BA2.dim1 a in
  let c = BA2.dim2 a in
  if r <> BA2.dim1 b || c <> BA2.dim2 b then false
  else
    let mismatch = ref None in
    (try
       for i = 0 to r - 1 do
         for j = 0 to c - 1 do
           let av = BA2.unsafe_get a i j in
           let bv = BA2.unsafe_get b i j in
           let same =
             if Float.is_nan av && Float.is_nan bv then true
             else Int64.equal (Int64.bits_of_float av) (Int64.bits_of_float bv)
           in
           if not same then begin
             mismatch := Some (i, j, av, bv);
             raise Exit
           end
         done
       done
     with Exit -> ());
    Option.is_none !mismatch

let _tmp_path () =
  Filename_unix.temp_file ~in_dir:"/tmp" "panel_snapshot_test_" ".bin"

let test_single_panel_round_trip _ =
  let idx = _make_idx [ "AAPL"; "MSFT"; "GOOG" ] in
  let panel =
    _make_panel ~n_rows:3 ~n_cols:5 ~fill:(fun r c ->
        Float.of_int ((r * 10) + c) +. 0.25)
  in
  let path = _tmp_path () in
  Panel_snapshot.dump ~path idx ~panels:[| panel |] ~panel_names:[ "close" ];
  let loaded_idx, loaded_panels, loaded_names = Panel_snapshot.load ~path in
  assert_that
    (loaded_idx, loaded_panels, loaded_names)
    (all_of
       [
         field
           (fun (i, _, _) -> Symbol_index.symbols i)
           (equal_to [ "AAPL"; "MSFT"; "GOOG" ]);
         field (fun (_, ps, _) -> Array.length ps) (equal_to 1);
         field (fun (_, _, names) -> names) (equal_to [ "close" ]);
         field (fun (_, ps, _) -> _bit_identical panel ps.(0)) (equal_to true);
       ])

let test_multi_panel_round_trip _ =
  let idx = _make_idx [ "S1"; "S2" ] in
  let p1 =
    _make_panel ~n_rows:2 ~n_cols:4 ~fill:(fun r c ->
        (Float.of_int (r + 1) *. 100.0) +. Float.of_int c)
  in
  let p2 =
    _make_panel ~n_rows:2 ~n_cols:4 ~fill:(fun r c ->
        (Float.of_int (r + 1) *. 1000.0) +. Float.of_int (c * 10))
  in
  let p3 =
    _make_panel ~n_rows:2 ~n_cols:4 ~fill:(fun r c ->
        if r = 0 && c = 0 then Float.nan else Float.neg_infinity +. 0.0)
  in
  let path = _tmp_path () in
  Panel_snapshot.dump ~path idx ~panels:[| p1; p2; p3 |]
    ~panel_names:[ "open"; "close"; "edge" ];
  let _, loaded_panels, loaded_names = Panel_snapshot.load ~path in
  assert_that
    (loaded_panels, loaded_names)
    (all_of
       [
         field (fun (ps, _) -> Array.length ps) (equal_to 3);
         field (fun (_, n) -> n) (equal_to [ "open"; "close"; "edge" ]);
         field (fun (ps, _) -> _bit_identical p1 ps.(0)) (equal_to true);
         field (fun (ps, _) -> _bit_identical p2 ps.(1)) (equal_to true);
         field (fun (ps, _) -> _bit_identical p3 ps.(2)) (equal_to true);
       ])

(* Dump-twice byte-equality: a panel + same-symbol-index dumped twice to
   different paths must produce byte-identical files. Required for
   reproducible golden fixtures across machines. *)
let test_dump_twice_byte_identical _ =
  let idx = _make_idx [ "AAPL"; "MSFT" ] in
  let panel =
    _make_panel ~n_rows:2 ~n_cols:6 ~fill:(fun r c ->
        if r = 0 && c = 1 then Float.nan else Float.of_int ((r * 10) + c) +. 0.5)
  in
  let path_a = _tmp_path () in
  let path_b = _tmp_path () in
  Panel_snapshot.dump ~path:path_a idx ~panels:[| panel |]
    ~panel_names:[ "close" ];
  Panel_snapshot.dump ~path:path_b idx ~panels:[| panel |]
    ~panel_names:[ "close" ];
  let bytes_a = In_channel.read_all path_a in
  let bytes_b = In_channel.read_all path_b in
  assert_that bytes_a (equal_to bytes_b)

let test_dump_rejects_shape_mismatch _ =
  let idx = _make_idx [ "S1"; "S2" ] in
  let p1 = _make_panel ~n_rows:2 ~n_cols:3 ~fill:(fun _ _ -> 0.0) in
  let p2 = _make_panel ~n_rows:2 ~n_cols:5 ~fill:(fun _ _ -> 0.0) in
  let path = _tmp_path () in
  assert_raises
    (Invalid_argument "Panel_snapshot.dump: panel 1 shape 2x5, expected 2x3")
    (fun () ->
      Panel_snapshot.dump ~path idx ~panels:[| p1; p2 |]
        ~panel_names:[ "a"; "b" ])

let test_dump_rejects_name_count_mismatch _ =
  let idx = _make_idx [ "S1" ] in
  let p1 = _make_panel ~n_rows:1 ~n_cols:3 ~fill:(fun _ _ -> 0.0) in
  let path = _tmp_path () in
  assert_raises (Invalid_argument "Panel_snapshot.dump: 1 panels but 2 names")
    (fun () ->
      Panel_snapshot.dump ~path idx ~panels:[| p1 |] ~panel_names:[ "a"; "b" ])

let suite =
  "Panel_snapshot tests"
  >::: [
         "test_single_panel_round_trip" >:: test_single_panel_round_trip;
         "test_multi_panel_round_trip" >:: test_multi_panel_round_trip;
         "test_dump_twice_byte_identical" >:: test_dump_twice_byte_identical;
         "test_dump_rejects_shape_mismatch" >:: test_dump_rejects_shape_mismatch;
         "test_dump_rejects_name_count_mismatch"
         >:: test_dump_rejects_name_count_mismatch;
       ]

let () = run_test_tt_main suite
