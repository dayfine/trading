(** Tests for the Win #4 production opt-in wiring — per-fold universe pruning
    via [active_through] — surfaced at the panel runner / strategy builder seam.

    The pure pruning helpers + the [Simulator.create_deps] /
    [Weinstein_strategy] plumbing landed in #1318 (commit ebe4a01d). This PR
    wires the {b production opt-in}: {!Backtest.Panel_runner.run}'s
    [?prune_universe_by_active_through] flag, when [true], resolves the fold's
    [start_date] into the point-in-time cutoff threaded onto both surfaces —

    - the strategy screener (via {!Panel_strategy_builder.build}'s
      [?fold_start_date] → {!Weinstein_strategy.make}'s [?fold_start_date]), and
    - the simulator's per-step bar-fetch loop (via
      {!Trading_simulation.Simulator.create_deps}'s [?active_through_for]).

    This file pins two contracts:

    1. {b The flag→cutoff mapping} ({!Panel_runner.fold_start_date_of_opt_in}):
    [false] (the default) → [None] (no pruning → bit-equal baselines); [true] →
    [Some start_date]. This is the load-bearing default-off invariant
    ([.claude/rules/experiment-flag-discipline.md] R1): an un-opted-in caller
    behaves identically to pre-Win-#4.

    2. {b The acceptance criterion} — "with the opt-in ENABLED, fewer symbols
    reach classification than with it OFF". The universe that reaches Phase-1
    stage classification is the universe AFTER the screener's pre-prune; pruned
    symbols pay no per-symbol weekly-view / classification cost (the Win #4
    speedup). We assert on that pruned universe via
    {!Weinstein_strategy.prune_universe_by_active_through}, fed
    [active_through_for] derived from the [Bar_reader]'s snapshot callbacks —
    the EXACT production derivation in [Weinstein_strategy_macro._prune_args_of]
    that the runner activates when it threads [fold_start_date]. With the opt-in
    ON a pre-fold-delisted symbol is dropped before classification; with it OFF
    the full loaded universe is classified.

    Domain framing: the cutoff is the FOLD's start date (a past date), so this
    is point-in-time correct, NOT survivor bias. Authority:
    [dev/plans/v7-sweep-speedup-2026-05-26.md] §Win #4. Follows
    [.claude/rules/test-patterns.md]. *)

open OUnit2
open Core
open Matchers
module Bar_reader = Weinstein_strategy.Bar_reader
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

(* ------------------------------------------------------------------ *)
(* Contract 1: flag -> cutoff mapping (default-off invariant)          *)
(* ------------------------------------------------------------------ *)

let test_opt_in_off_yields_no_cutoff _ =
  (* The default ([prune_universe_by_active_through = false]) MUST resolve to
     [None] so neither surface prunes — bit-equal baselines. *)
  let cutoff =
    Backtest.Panel_runner.fold_start_date_of_opt_in
      ~prune_universe_by_active_through:false ~start_date:(_ymd 1998 1 2)
  in
  assert_that cutoff is_none

let test_opt_in_on_yields_fold_start_cutoff _ =
  (* Opting in resolves to [Some start_date] — the fold's first day becomes the
     point-in-time cutoff. *)
  let start_date = _ymd 1998 1 2 in
  let cutoff =
    Backtest.Panel_runner.fold_start_date_of_opt_in
      ~prune_universe_by_active_through:true ~start_date
  in
  assert_that cutoff (is_some_and (equal_to start_date))

(* ------------------------------------------------------------------ *)
(* Contract 2: opt-in ON => fewer symbols reach classification         *)
(* ------------------------------------------------------------------ *)

(* Weekly Fridays starting [start_friday] for [n] bars. *)
let _fridays ~start_friday ~n =
  List.init n ~f:(fun i -> Date.add_days start_friday (i * 7))

(* A rising weekly series that classifies as Stage 2 (price above a rising MA),
   so the symbol survives the lazy stage filter and reaches Phase-1
   classification. [active_through] marks the last active day. *)
let _series ~start_friday ~n ~start_price ~active_through =
  let dates = _fridays ~start_friday ~n in
  List.mapi dates ~f:(fun i date ->
      let p = start_price +. (Float.of_int i *. 1.0) in
      {
        Types.Daily_price.date;
        open_price = p;
        high_price = p *. 1.01;
        low_price = p *. 0.99;
        close_price = p;
        adjusted_close = p;
        volume = 1_000_000;
        active_through;
      })

(* Derive the screener's [active_through_for] from the bar_reader exactly as
   [Weinstein_strategy_macro._prune_args_of] does in production. *)
let _active_through_for bar_reader symbol =
  let cb = Bar_reader.snapshot_callbacks bar_reader in
  cb.Snapshot_callbacks.active_through_for ~symbol

let test_opt_in_on_prunes_pre_fold_delisted_from_classification _ =
  (* Three-symbol universe. LIVE_A / LIVE_B are still active (no marker); GONE
     was delisted in 1996, strictly before the 1998 fold start.

     "Symbols reaching classification" == the universe AFTER the screener's
     pre-prune (each surviving symbol pays the per-symbol weekly-view read +
     stage-classification cost; pruned symbols pay nothing — the whole point of
     Win #4). We assert directly on the pruned universe the screener will
     iterate, using the EXACT production derivation: [active_through_for] read
     off the [Bar_reader]'s snapshot callbacks, exactly as
     [Weinstein_strategy_macro._prune_args_of] does when the runner threads
     [fold_start_date]. *)
  let start_friday = _ymd 1994 1 7 in
  let live_a =
    _series ~start_friday ~n:260 ~start_price:50.0 ~active_through:None
  in
  let live_b =
    _series ~start_friday ~n:260 ~start_price:60.0 ~active_through:None
  in
  let gone =
    _series ~start_friday ~n:120 ~start_price:55.0
      ~active_through:(Some (_ymd 1996 6 28))
  in
  let bar_reader =
    Bar_reader.of_in_memory_bars
      [ ("LIVE_A", live_a); ("LIVE_B", live_b); ("GONE", gone) ]
  in
  let universe = [ "LIVE_A"; "LIVE_B"; "GONE" ] in
  let fold_start = _ymd 1998 1 2 in
  let active_through_for = _active_through_for bar_reader in
  (* The universe that reaches classification with the opt-in ON: GONE is pruned
     (active_through 1996 < fold_start 1998); the two live symbols remain. *)
  let reaching_on =
    Weinstein_strategy.prune_universe_by_active_through ~universe
      ~active_through_for ~fold_start_date:fold_start
    |> List.sort ~compare:String.compare
  in
  (* With the opt-in OFF the runner never builds [active_through_for] / a cutoff,
     so the screener iterates the full loaded universe — every symbol reaches
     classification. *)
  let reaching_off = List.sort universe ~compare:String.compare in
  (* Strictly fewer symbols reach classification with the opt-in ON (2 < 3). *)
  assert_that
    (List.length reaching_off, reaching_on)
    (equal_to ((3, [ "LIVE_A"; "LIVE_B" ]) : int * string list))

let suite =
  "Panel_runner_active_through"
  >::: [
         "opt-in OFF => no cutoff (bit-equal baseline)"
         >:: test_opt_in_off_yields_no_cutoff;
         "opt-in ON => fold-start cutoff"
         >:: test_opt_in_on_yields_fold_start_cutoff;
         "opt-in ON => fewer symbols reach classification"
         >:: test_opt_in_on_prunes_pre_fold_delisted_from_classification;
       ]

let () = run_test_tt_main suite
