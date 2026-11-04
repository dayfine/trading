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

(* OUnit runs cases in parallel processes and [with_test_data] recreates its
   directory by name, so each call gets a name no other case shares. *)
let _sim_counter = ref 0

let _with_sim f =
  Int.incr _sim_counter;
  with_test_data
    (sprintf "backtest_checkpoint_%d_%d"
       (Pid.to_int (Core_unix.getpid ()))
       !_sim_counter)
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
    Option.sexp_of_t Backtest.Candidate_log.sexp_of_snapshot s.candidate_log;
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

let _refuses_version version =
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
                      version;
                      date = _date "2024-01-05";
                      n_steps = 3;
                      identity = _identity;
                    }));
          assert_that
            (_refusal dir ~expect:_identity)
            (_mentions "checkpoint version")))

(* Version 1 predates the single-value cancel in the trade-audit bucket. *)
let test_other_version_refuses _ =
  _refuses_version (BC.version + 1);
  _refuses_version 1

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
      ~on_friday:(fun ~date hooked_sim ->
        let next = (Sim.Checkpoint.capture hooked_sim).current_date in
        assert_that next (equal_to (Date.add_days date 1));
        dates := date :: !dates)
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
              ~request:
                {
                  scenario_dir = dir;
                  every_n_fridays = 2;
                  resume = false;
                  halt_after_checkpoints = None;
                }
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

let _checkpoint_file dir name =
  Filename.concat (Filename.concat dir BC.dir_name) name

let test_candidates_round_trip _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          let state =
            {
              (_state sim) with
              candidate_log = Some Backtest.Candidate_log.(capture (create ()));
            }
          in
          _write_exn dir state;
          assert_that
            ( _load dir ~expect:_identity,
              Sys_unix.file_exists_exn (_checkpoint_file dir "candidates.sexp")
            )
            (all_of
               [
                 field fst
                   (is_ok_and_holds
                      (field
                         (fun (_, (s : BC.state)) ->
                           (Option.is_some s.candidate_log, _texts s))
                         (equal_to (true, _texts state))));
                 field snd (equal_to true);
               ])))

let test_no_candidates_loads_as_none _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          _write_exn dir (_state sim);
          assert_that
            ( _load dir ~expect:_identity,
              Sys_unix.file_exists_exn (_checkpoint_file dir "candidates.sexp")
            )
            (all_of
               [
                 field fst
                   (is_ok_and_holds
                      (field
                         (fun (_, (s : BC.state)) ->
                           Option.is_none s.candidate_log)
                         (equal_to true)));
                 field snd (equal_to false);
               ])))

let _run_key = Sexp.of_string "(cfg 2024)"
let _manifest = Sexp.of_string "(manifest 1)"

let _identity_with ~run_key =
  BC.identity_of ~run_key ~manifest:_manifest ~seed_salt:None

let test_identity_of_digests_inputs _ =
  let base = _identity_with ~run_key:_run_key in
  assert_that
    ( String.equal base.config_digest
        (_identity_with ~run_key:_run_key).config_digest,
      String.equal base.config_digest
        (_identity_with ~run_key:(Sexp.of_string "(cfg 2025)")).config_digest,
      base.build_sha )
    (equal_to (true, false, Backtest.Build_info.git_sha))

let _setup ~request ~weinstein =
  BC.setup ~resumed:None ~request ~weinstein ~run_key:_run_key
    ~manifest:_manifest
    ~stop_log:(Backtest.Stop_log.create ())
    ~trade_audit:(Backtest.Trade_audit.create ())
    ~force_liquidation_log:(Backtest.Force_liquidation_log.create ())
    ~candidate_log:None

let test_setup_without_request_arms_nothing _ =
  let state, hook = _setup ~request:None ~weinstein:true in
  assert_that
    (Option.is_none state, Option.is_none hook)
    (equal_to (true, true))

let test_setup_with_request_arms_both _ =
  let request =
    Some
      {
        BC.scenario_dir = "unused";
        every_n_fridays = 1;
        resume = false;
        halt_after_checkpoints = None;
      }
  in
  let state, hook = _setup ~request ~weinstein:true in
  assert_that
    (Option.is_some state, Option.is_some hook)
    (equal_to (true, true))

let test_setup_refuses_other_strategies _ =
  let request =
    Some
      {
        BC.scenario_dir = "unused";
        every_n_fridays = 1;
        resume = false;
        halt_after_checkpoints = None;
      }
  in
  assert_that
    (Result.is_error
       (Result.try_with (fun () -> _setup ~request ~weinstein:false)))
    (equal_to true)

let test_setup_refuses_non_positive_cadence _ =
  let outcome n =
    Result.try_with (fun () ->
        _setup
          ~request:
            (Some
               {
                 BC.scenario_dir = "unused";
                 every_n_fridays = n;
                 resume = false;
                 halt_after_checkpoints = None;
               })
          ~weinstein:true)
    |> Result.error
    |> Option.map ~f:Exn.to_string
  in
  assert_that
    [ outcome 0; outcome (-1) ]
    (elements_are [ _mentions "every_n_fridays"; _mentions "every_n_fridays" ])

let test_load_refuses_missing_component _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          _write_exn dir (_state sim);
          Core_unix.unlink (_checkpoint_file dir "strategy.sexp");
          assert_that
            (_refusal dir ~expect:_identity)
            (_mentions "strategy.sexp")))

let test_load_refuses_unparseable_component _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          _write_exn dir (_state sim);
          Out_channel.write_all
            (_checkpoint_file dir "simulator.sexp")
            ~data:"((unbalanced";
          assert_that
            (_refusal dir ~expect:_identity)
            (_mentions "simulator.sexp")))

(* A component that parses as a sexp but has the wrong structure is refused,
   naming the file ([Checkpoint_files.read_as]). *)
let test_load_refuses_wrong_shape_component _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          _write_exn dir (_state sim);
          Out_channel.write_all
            (_checkpoint_file dir "strategy.sexp")
            ~data:"(foo bar)";
          assert_that
            (_refusal dir ~expect:_identity)
            (_mentions "strategy.sexp")))

(* Resuming with a candidate collector is refused before any file is read. *)
let test_resume_with_candidate_capture_is_refused _ =
  let module M = Snapshot_pipeline.Snapshot_manifest in
  let request =
    {
      BC.scenario_dir = "/nonexistent";
      every_n_fridays = 1;
      resume = true;
      halt_after_checkpoints = None;
    }
  in
  let candidate_log = Backtest.Candidate_log.create_if true in
  assert_raises
    (Failure "Panel_runner: --resume does not support candidate capture")
    (fun () ->
      Backtest.Panel_checkpoint.load_resume ~checkpoint:(Some request)
        ~config:
          (Weinstein_strategy.default_config ~universe:[]
             ~index_symbol:"GSPC.INDX")
        ~window:(_date "2024-01-02", _date "2024-06-28", 364, 100_000.0)
        ~costs:
          {
            commission = { per_share = 0.01; minimum = 1.0 };
            slippage_bps = None;
            cost_model = None;
          }
        ~manifest:
          (M.create ~schema:Data_panel_snapshot.Snapshot_schema.default
             ~entries:[])
        ~candidate_log)

let test_failed_write_warns_and_continues _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          let blocker = Filename.concat dir "blocker" in
          Out_channel.write_all blocker ~data:"a regular file";
          let scenario_dir = Filename.concat blocker "scenario" in
          let hook =
            BC.friday_hook
              ~request:
                {
                  scenario_dir;
                  every_n_fridays = 1;
                  resume = false;
                  halt_after_checkpoints = None;
                }
              ~identity:_identity
              ~strategy_state:
                (Strategy_state.init ~initial_stop_states:String.Map.empty)
              ~stop_log:(Backtest.Stop_log.create ())
              ~trade_audit:(Backtest.Trade_audit.create ())
              ~force_liquidation_log:(Backtest.Force_liquidation_log.create ())
              ~candidate_log:None
          in
          hook ~date:(_date "2024-01-05") sim;
          assert_that
            (Sys_unix.file_exists_exn
               (Filename.concat scenario_dir BC.dir_name))
            (equal_to false)))

(* The identity of a snapshot must not depend on where a CSV-mode run built it
   or on source-file mtimes, but must follow the content. *)
let test_manifest_sexp_ignores_paths_and_mtimes _ =
  let module M = Snapshot_pipeline.Snapshot_manifest in
  let schema = Data_panel_snapshot.Snapshot_schema.default in
  let entry ?(path = "/tmp/a/AAPL.snap") ?(mtime = 1.0) ?(md5 = "abc") () =
    {
      M.symbol = "AAPL";
      path;
      byte_size = 10;
      payload_md5 = md5;
      csv_mtime = mtime;
      active_through = None;
    }
  in
  let sexp e =
    Backtest.Panel_checkpoint.manifest_sexp (M.create ~schema ~entries:[ e ])
  in
  assert_that
    ( Sexp.equal
        (sexp (entry ()))
        (sexp (entry ~path:"/tmp/b/AAPL.snap" ~mtime:2.0 ())),
      Sexp.equal (sexp (entry ())) (sexp (entry ~md5:"def" ())) )
    (equal_to (true, false))

let _config =
  Weinstein_strategy.default_config ~universe:[] ~index_symbol:"GSPC.INDX"

let _window = (_date "2024-01-02", _date "2024-06-28", 364, 100_000.0)

let _base_costs : Backtest.Panel_checkpoint.costs =
  {
    commission = { per_share = 0.01; minimum = 1.0 };
    slippage_bps = None;
    cost_model = None;
  }

let _identity_for costs =
  BC.identity_of
    ~run_key:
      (Backtest.Panel_checkpoint.run_key ~config:_config ~window:_window ~costs)
    ~manifest:(Sexp.Atom "m") ~seed_salt:None

(* A checkpoint written under one set of cost settings is refused by a resume
   under any other: commission, slippage, and the cost model. *)
let test_changed_costs_refuse_resume _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          ok_or_fail_status
            (BC.write ~scenario_dir:dir
               ~identity:(_identity_for _base_costs)
               (_state sim));
          let cases =
            [
              {
                _base_costs with
                commission = { per_share = 0.02; minimum = 1.0 };
              };
              {
                _base_costs with
                commission = { per_share = 0.01; minimum = 2.0 };
              };
              { _base_costs with slippage_bps = Some 5 };
              {
                _base_costs with
                cost_model = Some Backtest_cost_model.Cost_model.retail_default;
              };
            ]
          in
          let refused costs = _refusal dir ~expect:(_identity_for costs) in
          assert_that
            ( List.map cases ~f:(fun c -> Option.is_some (refused c)),
              refused _base_costs )
            (equal_to ([ true; true; true; true ], None))))

(* A journal with fewer lines than the header counts is refused, not loaded
   short. *)
let test_short_step_journal_refuses _ =
  _with_sim (fun sim ->
      _with_dir (fun dir ->
          _write_exn dir (_state sim);
          let path = _checkpoint_file dir Backtest.Step_journal.file_name in
          let kept = List.take (In_channel.read_lines path) 2 in
          Out_channel.write_lines path kept;
          assert_that
            (_refusal dir ~expect:_identity)
            (_mentions "has 2 lines, expected 3")))

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
         "candidates round-trip" >:: test_candidates_round_trip;
         "no candidates loads as none" >:: test_no_candidates_loads_as_none;
         "identity_of digests its inputs" >:: test_identity_of_digests_inputs;
         "setup without request arms nothing"
         >:: test_setup_without_request_arms_nothing;
         "setup with request arms both" >:: test_setup_with_request_arms_both;
         "setup refuses a non-positive cadence"
         >:: test_setup_refuses_non_positive_cadence;
         "setup refuses other strategies"
         >:: test_setup_refuses_other_strategies;
         "load refuses a missing component"
         >:: test_load_refuses_missing_component;
         "load refuses an unparseable component"
         >:: test_load_refuses_unparseable_component;
         "load refuses a wrong-shape component"
         >:: test_load_refuses_wrong_shape_component;
         "resume with candidate capture is refused"
         >:: test_resume_with_candidate_capture_is_refused;
         "failed write warns and continues"
         >:: test_failed_write_warns_and_continues;
         "manifest identity ignores paths and mtimes"
         >:: test_manifest_sexp_ignores_paths_and_mtimes;
         "changed costs refuse a resume" >:: test_changed_costs_refuse_resume;
         "short step journal refuses" >:: test_short_step_journal_refuses;
       ]

let () = run_test_tt_main suite
