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

(** Position side for parameterized strategies *)
type position_side = Long | Short

type enter_exit_config = {
  side : position_side;
  symbol : string;
  target_quantity : float;
  entry_price : float;
}
(** Configuration for enter-then-exit test strategy *)

let default_enter_exit_config =
  { side = Long; symbol = "AAPL"; target_quantity = 10.0; entry_price = 150.0 }

(** Parameterized strategy that creates a position on first call, exits on
    second call.

    Used for testing position lifecycle: CreateEntering -> Holding -> Exiting ->
    Closed

    Note: The order_generator currently only supports long positions (hardcodes
    Buy for entry, Sell for exit). Short position support requires adding a side
    field to CreateEntering. *)
module Make_enter_then_exit_strategy (Config : sig
  val config : enter_exit_config
end) : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
  (** Reset the internal call counter for test isolation *)

  val side : position_side
  (** The position side this strategy uses *)
end = struct
  let name =
    match Config.config.side with
    | Long -> "EnterThenExitLong"
    | Short -> "EnterThenExitShort"

  let side = Config.config.side

  (* Mutable call counter to track which day we're on *)
  let call_count = ref 0
  let reset () = call_count := 0

  let on_market_close ~get_price:_ ~get_indicator:_
      ~(positions : Trading_strategy.Position.t String.Map.t) =
    call_count := !call_count + 1;
    let open Trading_strategy.Position in
    let config = Config.config in
    let position_id = config.symbol ^ "-1" in
    match !call_count with
    | 1 ->
        (* Day 1: Create entering position *)
        Ok
          {
            Trading_strategy.Strategy_interface.transitions =
              [
                {
                  position_id;
                  date = Date.of_string "2024-01-02";
                  kind =
                    CreateEntering
                      {
                        symbol = config.symbol;
                        target_quantity = config.target_quantity;
                        entry_price = config.entry_price;
                        reasoning =
                          TechnicalSignal
                            {
                              indicator = "EMA";
                              description =
                                (match config.side with
                                | Long -> "test long entry"
                                | Short -> "test short entry");
                            };
                      };
                };
              ];
          }
    | 2 -> (
        (* Day 2: Trigger exit for the position *)
        match Map.find positions position_id with
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
                      position_id;
                      date = Date.of_string "2024-01-03";
                      kind =
                        TriggerExit
                          {
                            exit_reason =
                              SignalReversal
                                {
                                  description =
                                    (match config.side with
                                    | Long -> "test long exit"
                                    | Short -> "test short exit");
                                };
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

(** Long position strategy - creates long position on day 1, exits on day 2 *)
module Long_strategy = Make_enter_then_exit_strategy (struct
  let config = default_enter_exit_config
end)

(** Short position strategy - creates short position on day 1, exits on day 2.

    Note: Short positions are not yet fully supported by the order_generator,
    which hardcodes Buy for entry and Sell for exit. This strategy is for future
    use when short position support is added. *)
module Short_strategy = Make_enter_then_exit_strategy (struct
  let config = { default_enter_exit_config with side = Short }
end)

module Enter_then_exit_strategy = Long_strategy
(** Backward-compatible alias for Long_strategy *)

let step_exn sim =
  match Trading_simulation.Simulator.step sim with
  | Error err -> failwith ("Step failed: " ^ Status.show err)
  | Ok (Completed _) -> failwith "Expected Stepped but got Completed"
  | Ok (Stepped (sim', result)) -> (sim', result)
