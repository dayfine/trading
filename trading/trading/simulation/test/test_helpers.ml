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

(** Strategy that creates a position on first call, exits on second call.

    Used for testing position lifecycle: CreateEntering -> Holding -> Exiting ->
    Closed *)
module Enter_then_exit_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
  (** Reset the internal call counter for test isolation *)
end = struct
  let name = "EnterThenExit"

  (* Mutable call counter to track which day we're on *)
  let call_count = ref 0
  let reset () = call_count := 0

  let on_market_close ~get_price:_ ~get_indicator:_
      ~(positions : Trading_strategy.Position.t String.Map.t) =
    call_count := !call_count + 1;
    let open Trading_strategy.Position in
    match !call_count with
    | 1 ->
        (* Day 1: Create entering position for AAPL *)
        Ok
          {
            Trading_strategy.Strategy_interface.transitions =
              [
                {
                  position_id = "AAPL-1";
                  date = Date.of_string "2024-01-02";
                  kind =
                    CreateEntering
                      {
                        symbol = "AAPL";
                        target_quantity = 10.0;
                        entry_price = 150.0;
                        reasoning =
                          TechnicalSignal
                            { indicator = "EMA"; description = "test entry" };
                      };
                };
              ];
          }
    | 2 -> (
        (* Day 2: Trigger exit for the position *)
        match Map.find positions "AAPL-1" with
        | Some pos when not (is_closed pos) ->
            let exit_price =
              match get_state pos with
              | Holding h -> h.entry_price *. 1.05
              | _ -> 155.0
            in
            Ok
              {
                Trading_strategy.Strategy_interface.transitions =
                  [
                    {
                      position_id = "AAPL-1";
                      date = Date.of_string "2024-01-03";
                      kind =
                        TriggerExit
                          {
                            exit_reason =
                              SignalReversal { description = "test exit" };
                            exit_price;
                          };
                    };
                  ];
              }
        | _ -> Ok { Trading_strategy.Strategy_interface.transitions = [] })
    | _ ->
        (* Subsequent days: no action *)
        Ok { Trading_strategy.Strategy_interface.transitions = [] }
end

let step_exn sim =
  match Trading_simulation.Simulator.step sim with
  | Error err -> failwith ("Step failed: " ^ Status.show err)
  | Ok (Completed _) -> failwith "Expected Stepped but got Completed"
  | Ok (Stepped (sim', result)) -> (sim', result)
