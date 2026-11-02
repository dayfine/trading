(** [Backtest.Backtest_checkpoint]: directory round-trip, header validation,
    atomic write and the Friday hook (#3477 PR 6). *)

open OUnit2
open Core
open Matchers
open Test_helpers
module BC = Backtest.Backtest_checkpoint
module Sim = Trading_simulation.Simulator
module Strategy_state = Weinstein_strategy.Weinstein_strategy_state

let _date = Date.of_string
let _commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

let _bar d : Types.Daily_price.t =
  {
    date = _date d;
    open_price = 100.0;
    high_price = 101.0;
    low_price = 99.0;
    close_price = 100.0;
    adjusted_close = 100.0;
    volume = 1_000_000;
    active_through = None;
  }

let _bars =
  List.map ~f:_bar
    [
      "2024-01-02";
      "2024-01-03";
      "2024-01-04";
      "2024-01-05";
      "2024-01-08";
      "2024-01-09";
      "2024-01-10";
      "2024-01-11";
      "2024-01-12";
    ]

module Idle : Trading_strategy.Strategy_interface.STRATEGY = struct
  let name = "Idle"

  let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
    Ok { Trading_strategy.Strategy_interface.transitions = [] }
end

let _config =
  {
    Sim.start_date = _date "2024-01-02";
    end_date = _date "2024-01-20";
    initial_cash = 100_000.0;
    commission = _commission;
    strategy_cadence = Types.Cadence.Daily;
  }

let _fresh_sim data_dir =
  let deps =
    Sim.create_deps ~symbols:[ "AAPL" ] ~data_dir
      ~strategy:(module Idle)
      ~commission:_commission ~entry_extension_max_pct:5.0 ()
  in
  create_exn ~config:_config ~deps

let _with_sim f =
  with_test_data "backtest_checkpoint"
    [ ("AAPL", _bars) ]
    ~f:(fun d -> f (_fresh_sim d))

let _with_dir f =
  let dir = Filename_unix.temp_dir "backtest_checkpoint" "" in
  protect
    ~f:(fun () -> f dir)
    ~finally:(fun () ->
      ignore (Sys_unix.command (sprintf "rm -rf %s" (Filename.quote dir))))

let _identity : BC.identity =
  {
    config_digest = "cfg";
    build_sha = "sha";
    manifest_digest = "man";
    seed_salt = Some "7";
  }

(* A state captured after three steps, with empty recorders. *)
let _state sim : BC.state =
  let sim = List.fold [ 1; 2; 3 ] ~init:sim ~f:(fun s _ -> fst (step_exn s)) in
  {
    simulator = Sim.Checkpoint.capture sim;
    strategy =
      Strategy_state.capture
        (Strategy_state.init ~initial_stop_states:String.Map.empty);
    stop_log = Backtest.Stop_log.(capture (create ()));
    trade_audit = Backtest.Trade_audit.(capture (create ()));
    force_liquidation_log = Backtest.Force_liquidation_log.(capture (create ()));
    candidate_log = None;
  }

(* Every component as text, so states compare by value. *)
let _texts (s : BC.state) =
  [
    Sim.Checkpoint.sexp_of_snapshot s.simulator;
    Strategy_state.sexp_of_snapshot s.strategy;
    Backtest.Stop_log.sexp_of_snapshot s.stop_log;
    Backtest.Trade_audit.sexp_of_snapshot s.trade_audit;
    Backtest.Force_liquidation_log.sexp_of_snapshot s.force_liquidation_log;
  ]
  |> List.map ~f:Sexp.to_string

let _write_exn dir state =
  ok_or_fail_status (BC.write ~scenario_dir:dir ~identity:_identity state)

let _load dir ~expect = BC.load ~scenario_dir:dir ~expect

let test_write_then_read_round_trips _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          let state = _state sim in
          _write_exn dir state;
          assert_that
            (_load dir ~expect:_identity)
            (is_ok_and_holds
               (all_of
                  [
                    field
                      (fun ((h : BC.header), _) ->
                        Sexp.to_string (BC.sexp_of_header h))
                      (equal_to
                         (Sexp.to_string
                            (BC.sexp_of_header
                               {
                                 version = BC.version;
                                 date = _date "2024-01-05";
                                 n_steps = 3;
                                 identity = _identity;
                               })));
                    field (fun (_, s) -> _texts s) (equal_to (_texts state));
                  ]))))

let _refusal dir ~expect =
  Result.error (_load dir ~expect) |> Option.map ~f:Status.show

let _mentions substring =
  is_some_and (field (String.is_substring ~substring) (equal_to true))

let test_each_identity_field_refuses _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          _write_exn dir (_state sim);
          let cases =
            [
              ("config digest", { _identity with config_digest = "other" });
              ("build sha", { _identity with build_sha = "other" });
              ( "snapshot manifest digest",
                { _identity with manifest_digest = "other" } );
              ("TRADING_PATH_SEED_SALT", { _identity with seed_salt = None });
            ]
          in
          List.iter cases ~f:(fun (field_name, expect) ->
              assert_that (_refusal dir ~expect) (_mentions field_name))))

let test_other_version_refuses _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          _write_exn dir (_state sim);
          let header =
            Filename.concat (Filename.concat dir BC.dir_name) "header.sexp"
          in
          Out_channel.write_all header
            ~data:
              (Sexp.to_string
                 (BC.sexp_of_header
                    {
                      version = BC.version + 1;
                      date = _date "2024-01-05";
                      n_steps = 3;
                      identity = _identity;
                    }));
          assert_that
            (_refusal dir ~expect:_identity)
            (_mentions "checkpoint version")))

let test_missing_checkpoint_refuses _ =
  _with_dir (fun dir ->
      assert_that (_refusal dir ~expect:_identity) (_mentions "no checkpoint"))

let _crash () = failwith "simulated crash"

let test_crash_mid_write_leaves_no_partial_dir _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          let result =
            BC.write ~before_commit:_crash ~scenario_dir:dir ~identity:_identity
              (_state sim)
          in
          assert_that
            ( Result.is_error result,
              Sys_unix.file_exists_exn (Filename.concat dir BC.dir_name) )
            (equal_to (true, false))))

let test_crash_keeps_the_previous_checkpoint _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          let first = _state sim in
          _write_exn dir first;
          let later = _state (fst (step_exn sim)) in
          ignore
            (BC.write ~before_commit:_crash ~scenario_dir:dir
               ~identity:_identity later
              : unit Status.status_or);
          assert_that
            (_load dir ~expect:_identity)
            (is_ok_and_holds
               (field (fun (_, s) -> _texts s) (equal_to (_texts first))))))

let test_rewrite_replaces_the_checkpoint _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          _write_exn dir (_state sim);
          let longer = _state (fst (step_exn sim)) in
          _write_exn dir longer;
          assert_that
            (_load dir ~expect:_identity, Sys_unix.ls_dir dir)
            (all_of
               [
                 field fst
                   (is_ok_and_holds
                      (field
                         (fun (_, s) -> _texts s)
                         (equal_to (_texts longer))));
                 field snd (equal_to [ BC.dir_name ]);
               ])))

let _hook_dates sim =
  let dates = ref [] in
  let _ =
    Backtest.Panel_step_loop.run_simulator_with_gc_trace
      ~on_friday:(fun ~date _ -> dates := date :: !dates)
      ~stop_log:(Backtest.Stop_log.create ())
      sim
  in
  List.rev !dates

let test_hook_fires_only_on_fridays _ =
  _with_sim (fun sim ->
      assert_that (_hook_dates sim)
        (equal_to
           [ _date "2024-01-05"; _date "2024-01-12"; _date "2024-01-19" ]))

let test_friday_hook_writes_every_nth_friday _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          let state = _state sim in
          let hook =
            BC.friday_hook
              ~request:{ scenario_dir = dir; every_n_fridays = 2 }
              ~identity:_identity
              ~strategy_state:
                (Strategy_state.init ~initial_stop_states:String.Map.empty)
              ~stop_log:(Backtest.Stop_log.create ())
              ~trade_audit:(Backtest.Trade_audit.create ())
              ~force_liquidation_log:(Backtest.Force_liquidation_log.create ())
              ~candidate_log:None
          in
          ignore state;
          let at_first =
            hook ~date:(_date "2024-01-05") sim;
            Sys_unix.file_exists_exn (Filename.concat dir BC.dir_name)
          in
          hook ~date:(_date "2024-01-12") sim;
          assert_that
            ( at_first,
              Sys_unix.file_exists_exn (Filename.concat dir BC.dir_name) )
            (equal_to (false, true))))

let suite =
  "backtest_checkpoint"
  >::: [
         "write then read round-trips" >:: test_write_then_read_round_trips;
         "each identity field refuses" >:: test_each_identity_field_refuses;
         "other version refuses" >:: test_other_version_refuses;
         "missing checkpoint refuses" >:: test_missing_checkpoint_refuses;
         "crash mid-write leaves no partial dir"
         >:: test_crash_mid_write_leaves_no_partial_dir;
         "crash keeps the previous checkpoint"
         >:: test_crash_keeps_the_previous_checkpoint;
         "rewrite replaces the checkpoint"
         >:: test_rewrite_replaces_the_checkpoint;
         "hook fires only on Fridays" >:: test_hook_fires_only_on_fridays;
         "friday hook writes every nth Friday"
         >:: test_friday_hook_writes_every_nth_friday;
       ]

let () = run_test_tt_main suite
