(** Simulator-level integration test for
    [Weinstein_stops.config.stop_skip_entry_bar].

    {1 What this pins that the unit tests cannot}

    [test_stops_runner.ml] pins the guard against a hand-built [Holding] whose
    [entry_date] the test chose. This test reproduces the actual
    {b step-ordering} that creates the defect: [Simulator._process_step_day]
    runs fills BEFORE the strategy, so an entry order placed on day D-1 fills at
    day D's open, the position is already [Holding { entry_date = D }] when the
    strategy runs on that same step, and the stop runner then evaluates it
    against day D's completed bar — whose low was printed before the fill. See
    [dev/experiments/arc-rerun-2026-09-01/README.md] §D2 and the
    [stop_skip_entry_bar] docstring in [stop_types.mli].

    {1 The strategy under test}

    Wiring the real {!Weinstein_strategy} would require a synthetic Stage-2
    breakout that also happens to print a deep entry-bar wick — data-shaping
    that would obscure what is being pinned. Instead this uses the smallest
    strategy that installs a stop through {!Stops_runner}: it emits one Market
    entry on its first call and thereafter does nothing but seed an [Initial]
    stop state and delegate to [Stops_runner.update]. Every code path this
    exercises downstream of the entry ({!Stops_runner._handle_stop},
    {!Weinstein_stops.update}, {!Stop_transitions}) is the production one. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* Zero commission / slippage: the assertions count fills per step, not cost. *)
let sample_commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }
let symbol = "AAPL"
let position_id = "AAPL-ENTRY-BAR"
let entry_quantity = 10.0
let entry_price = 100.0

(* The stop sits below the entry, above the entry bar's low and below the two
   following bars' lows — so every bar from the entry bar on would trigger it. *)
let stop_level = 96.0

let _bar ~date ~open_price ~high ~low ~close =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(** Four consecutive trading days (Mon-Thu, no weekend gap so each step's bar
    date equals the step date — the condition [stop_skip_entry_bar] compares
    on).

    - 01-08: the decision bar. The strategy emits its entry here.
    - 01-09: the ENTRY bar. The order fills at this bar's open (100.0), so
      [entry_date = 2024-01-09]. Its low (90.0) pierces the 96.0 stop while the
      bar closes at 102.0, well above it — the WSM shape from §D2: the low was
      printed before the buy filled.
    - 01-10: a genuine breach (low 94.0) on a bar the position actually held. *)
let aapl_bars =
  [
    _bar ~date:"2024-01-08" ~open_price:100.0 ~high:102.0 ~low:99.0 ~close:101.0;
    _bar ~date:"2024-01-09" ~open_price:100.0 ~high:103.0 ~low:90.0 ~close:102.0;
    _bar ~date:"2024-01-10" ~open_price:101.0 ~high:102.0 ~low:94.0 ~close:95.0;
    _bar ~date:"2024-01-11" ~open_price:95.0 ~high:96.0 ~low:94.0 ~close:95.0;
  ]

(* ------------------------------------------------------------------ *)
(* The strategy: one Market entry, then Stops_runner on every step      *)
(* ------------------------------------------------------------------ *)

module Entry_then_stops_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : skip_entry_bar:bool -> unit
end = struct
  let name = "EntryThenStops"
  let emitted = ref false
  let stop_states = ref String.Map.empty
  let stops_config = ref Weinstein_stops.default_config

  let reset ~skip_entry_bar =
    emitted := false;
    stop_states := String.Map.empty;
    stops_config :=
      {
        Weinstein_stops.default_config with
        Weinstein_stops.stop_skip_entry_bar = skip_entry_bar;
      }

  let _entry_transition ~date =
    {
      Trading_strategy.Position.position_id;
      date;
      kind =
        CreateEntering
          {
            symbol;
            side = Trading_strategy.Position.Long;
            target_quantity = entry_quantity;
            entry_price;
            reasoning = ManualDecision { description = "entry-bar stop test" };
          };
    }

  (* Install the initial stop the moment the position reaches Holding. This
     mirrors what the real strategy does at entry-decision time; the level is
     fixed here so the assertions are about the guard, not about floor
     derivation. *)
  let _seed_stop_states (portfolio : Trading_strategy.Portfolio_view.t) =
    Map.iter portfolio.positions ~f:(fun (pos : Trading_strategy.Position.t) ->
        match Trading_strategy.Position.get_state pos with
        | Trading_strategy.Position.Holding _
          when not (Map.mem !stop_states pos.symbol) ->
            stop_states :=
              Map.set !stop_states ~key:pos.symbol
                ~data:
                  (Weinstein_stops.Initial
                     { stop_level; reference_level = stop_level })
        | _ -> ())

  let _run_stops ~get_price ~portfolio ~as_of =
    _seed_stop_states portfolio;
    let exits, adjusts =
      Stops_runner.update ~stops_config:!stops_config
        ~stage_config:Stage.default_config ~lookback_bars:52
        ~positions:portfolio.Trading_strategy.Portfolio_view.positions
        ~get_price ~stop_states ~bar_reader:(Bar_reader.empty ()) ~as_of
        ~prior_stages:(Hashtbl.create (module String))
        ()
    in
    exits @ adjusts

  let on_market_close ~get_price ~get_indicator:_ ~portfolio =
    match get_price symbol with
    | None -> Ok { Trading_strategy.Strategy_interface.transitions = [] }
    | Some bar ->
        let as_of = bar.Types.Daily_price.date in
        let entry =
          if !emitted then []
          else begin
            emitted := true;
            [ _entry_transition ~date:as_of ]
          end
        in
        Ok
          {
            Trading_strategy.Strategy_interface.transitions =
              entry @ _run_stops ~get_price ~portfolio ~as_of;
          }
end

(* ------------------------------------------------------------------ *)
(* Harness                                                              *)
(* ------------------------------------------------------------------ *)

let _write_bars ~data_dir bars =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> assert_failure ("csv create: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage ~override:true bars with
      | Error e -> assert_failure ("csv save: " ^ Status.show e)
      | Ok () -> ())

let _sim_config =
  Trading_simulation.Simulator.
    {
      start_date = Date.of_string "2024-01-08";
      end_date = Date.of_string "2024-01-12";
      initial_cash = 100_000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }

(** Run the four-day simulation with the flag in the given position. Returns
    [(step date, number of fills on that step)] per step — the shape that makes
    the entry-bar exit visible as a fill one step after the offending stop
    evaluation. *)
let _run_fills_per_step ~skip_entry_bar =
  let data_dir = Core_unix.mkdtemp "/tmp/test_stop_skip_entry_bar" in
  Fun.protect
    ~finally:(fun () ->
      let (_ : Core_unix.Exit_or_signal.t) =
        Core_unix.system (Printf.sprintf "rm -rf %s" data_dir)
      in
      ())
    (fun () ->
      _write_bars ~data_dir aapl_bars;
      Entry_then_stops_strategy.reset ~skip_entry_bar;
      let deps =
        Trading_simulation.Simulator.create_deps ~symbols:[ symbol ]
          ~data_dir:(Fpath.v data_dir)
          ~strategy:(module Entry_then_stops_strategy)
          ~commission:sample_commission ()
      in
      let sim =
        match Trading_simulation.Simulator.create ~config:_sim_config ~deps with
        | Ok s -> s
        | Error e -> assert_failure ("create failed: " ^ Status.show e)
      in
      match Trading_simulation.Simulator.run sim with
      | Error e -> assert_failure ("run failed: " ^ Status.show e)
      | Ok result ->
          List.map result.steps ~f:(fun step ->
              (Date.to_string step.date, List.length step.trades)))

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

(** R1 pin — flag OFF reproduces today's behaviour end to end: the entry fills
    on 01-09, the stop runner immediately "hits" on that same bar's pre-fill low
    of 90.0, and the resulting exit order fills on 01-10 — a one-day round trip
    the position never actually took. *)
let test_off_stops_out_on_its_own_entry_bar _ =
  assert_that
    (_run_fills_per_step ~skip_entry_bar:false)
    (elements_are
       [
         equal_to ("2024-01-08", 0);
         equal_to ("2024-01-09", 1);
         equal_to ("2024-01-10", 1);
         equal_to ("2024-01-11", 0);
       ])

(** Flag ON: the 01-09 entry bar produces no exit, so the position is still open
    when 01-10 is evaluated. 01-10's low (94.0) is a genuine breach of a bar the
    position held, so the exit fires there and fills on 01-11 — the stop is
    deferred by exactly one bar, not disabled. *)
let test_on_survives_entry_bar_and_exits_on_the_next_breach _ =
  assert_that
    (_run_fills_per_step ~skip_entry_bar:true)
    (elements_are
       [
         equal_to ("2024-01-08", 0);
         equal_to ("2024-01-09", 1);
         equal_to ("2024-01-10", 0);
         equal_to ("2024-01-11", 1);
       ])

let () =
  run_test_tt_main
    ("stop_skip_entry_bar_sim"
    >::: [
           "OFF: position stops out on its own entry bar (R1 pin)"
           >:: test_off_stops_out_on_its_own_entry_bar;
           "ON: entry bar survives, next breach still exits"
           >:: test_on_survives_entry_bar_and_exits_on_the_next_breach;
         ])
