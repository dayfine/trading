(** Shared test helpers for simulation tests *)

open Core

let ok_or_fail_status = function
  | Ok x -> x
  | Error (err : Status.t) -> failwith err.message

(** Set up test CSV data for a given test name *)
let setup_test_data test_name prices_by_symbol =
  let test_data_dir = Fpath.v (Printf.sprintf "test_data/%s" test_name) in
  let dir_str = Fpath.to_string test_data_dir in
  (match Sys_unix.file_exists dir_str with
  | `Yes -> ignore (Bos.OS.Dir.delete ~recurse:true test_data_dir)
  | _ -> ());
  ignore (Bos.OS.Dir.create ~path:true test_data_dir);
  (* Save prices for each symbol *)
  List.iter prices_by_symbol ~f:(fun (symbol, prices) ->
      let storage =
        Csv.Csv_storage.create ~data_dir:test_data_dir symbol
        |> ok_or_fail_status
      in
      ignore (Csv.Csv_storage.save storage prices |> ok_or_fail_status));
  test_data_dir

let teardown_test_data test_data_dir =
  let dir_str = Fpath.to_string test_data_dir in
  match Sys_unix.file_exists dir_str with
  | `Yes -> ignore (Bos.OS.Dir.delete ~recurse:true test_data_dir)
  | _ -> ()

(** RAII-style test data setup with automatic cleanup.

    Usage:
    {[
      with_test_data "my_test"
        [ ("AAPL", prices) ]
        ~f:(fun data_dir ->
          (* test code here *)
          ())
    ]} *)
let with_test_data test_name prices_by_symbol ~f =
  let data_dir = setup_test_data test_name prices_by_symbol in
  Fun.protect
    ~finally:(fun () -> teardown_test_data data_dir)
    (fun () -> f data_dir)

(** No-op strategy for tests that don't need strategy logic *)
module Noop_strategy : Trading_strategy.Strategy_interface.STRATEGY = struct
  let name = "Noop"

  let on_market_close ~get_price:_ ~get_indicator:_ ~positions:_ =
    Ok { Trading_strategy.Strategy_interface.transitions = [] }
end
