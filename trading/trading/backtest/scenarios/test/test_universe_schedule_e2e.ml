(** End-to-end wiring of {!Scenario_lib.Universe_schedule} through
    [Backtest.Runner.run_backtest]'s [?universe_membership_at] seam.

    Runs the tier-1 smoke scenario [smoke/panel-golden-2019-full.sexp]
    (universes/parity-7sym.sexp, 2019-05-01..2020-01-03) in three arms and
    compares full round-trip lists:

    - {b baseline} — no schedule, resolved from [universe_path];
    - {b single-entry schedule} covering the same 7 symbols — must be BIT-EQUAL
      to the baseline, which is the evidence for "an empty / degenerate schedule
      changes nothing";
    - {b two-list schedule} that drops AAPL, JPM and JNJ from 2019-05-06 — must
      lose the JNJ trade (entered 2019-06-22, after the drop, so the candidate
      gate bites) while keeping the AAPL and JPM round trips BIT-EQUAL (both
      were entered 2019-05-04, before the drop, and exit 2019-05-08 /
      2019-05-10, after it). That second half is decision D4: a held position in
      a symbol that leaves the universe is held to its normal exit. *)

open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file
module Universe_schedule = Scenario_lib.Universe_schedule
module Metrics = Trading_simulation.Metrics

(* Local projection of [Metrics.trade_metrics] for structural equality — same
   shape and rationale as [test_scenario_runner_isolation.ml]'s. *)
type trade = {
  symbol : string;
  entry_date : Date.t;
  exit_date : Date.t;
  entry_price : float;
  exit_price : float;
  quantity : float;
  pnl_dollars : float;
}
[@@deriving eq, show]

let _to_trade (t : Metrics.trade_metrics) =
  {
    symbol = t.symbol;
    entry_date = t.entry_date;
    exit_date = t.exit_date;
    entry_price = t.entry_price;
    exit_price = t.exit_price;
    quantity = t.quantity;
    pnl_dollars = t.pnl_dollars;
  }

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

let _fixtures_root () =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  Filename.concat data_dir "backtest_scenarios"

let _scenario_relpath = "smoke/panel-golden-2019-full.sexp"

let _scenario () =
  Scenario.load (Filename.concat (_fixtures_root ()) _scenario_relpath)

let _run ?universe_membership_at ~sector_map_override (s : Scenario.t) =
  let result =
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:s.config_overrides
      ?sector_map_override ?universe_membership_at ()
  in
  List.map result.round_trips ~f:_to_trade

(* The scenario's own universe, resolved exactly as [Scenario_runner] does on
   the no-schedule path. *)
let _baseline_sector_map (s : Scenario.t) =
  Universe_file.to_sector_map_override
    (Universe_file.load (Filename.concat (_fixtures_root ()) s.universe_path))

(* The 7 parity symbols with their sectors, copied from
   [universes/parity-7sym.sexp]. Written into a temp fixtures root so the
   schedule's own lists are self-contained and independent of the committed
   fixture's future edits. *)
let _parity_entries =
  [
    ("AAPL", "Information Technology");
    ("MSFT", "Information Technology");
    ("JPM", "Financials");
    ("JNJ", "Health Care");
    ("CVX", "Energy");
    ("KO", "Consumer Staples");
    ("HD", "Consumer Discretionary");
  ]

(* Symbols dropped by the two-list schedule's second list. JNJ enters AFTER the
   drop date (gate must bite); AAPL and JPM enter BEFORE it and exit after
   (D4 — held to their normal exit). *)
let _dropped = [ "AAPL"; "JPM"; "JNJ" ]
let _drop_date = _ymd 2019 5 6

let _write_universe ~root ~name entries =
  let body =
    List.map entries ~f:(fun (symbol, sector) ->
        sprintf "((symbol %s) (sector %S))" symbol sector)
    |> String.concat ~sep:"\n"
  in
  let path = Filename.concat root name in
  Out_channel.write_all path ~data:(sprintf "(Pinned (\n%s))\n" body);
  name

let _temp_root () =
  Core_unix.mkdtemp (Filename.concat Filename.temp_dir_name "uschedule-e2e")

let _schedule_or_fail ~fixtures_root entries =
  match Universe_schedule.load ~fixtures_root entries with
  | Ok sched -> sched
  | Error err ->
      assert_failure ("Universe_schedule.load failed: " ^ Status.show err)

(* Arm 2: one entry, dated well before the scenario window, listing exactly the
   scenario's own 7 symbols. Semantically identical to the [universe_path]
   path, so the run must be bit-equal. *)
let _single_entry_schedule () =
  let root = _temp_root () in
  let name = _write_universe ~root ~name:"all7.sexp" _parity_entries in
  _schedule_or_fail ~fixtures_root:root [ (_ymd 1990 1 1, name) ]

(* Arm 3: the same 7 symbols until [_drop_date], then the 4 survivors. *)
let _two_list_schedule () =
  let root = _temp_root () in
  let all7 = _write_universe ~root ~name:"all7.sexp" _parity_entries in
  let survivors =
    _write_universe ~root ~name:"survivors.sexp"
      (List.filter _parity_entries ~f:(fun (symbol, _) ->
           not (List.mem _dropped symbol ~equal:String.equal)))
  in
  _schedule_or_fail ~fixtures_root:root
    [ (_ymd 1990 1 1, all7); (_drop_date, survivors) ]

let _baseline_trades () =
  let s = _scenario () in
  _run ~sector_map_override:(_baseline_sector_map s) s

(** A single-entry schedule over the scenario's own symbols reproduces the
    baseline round-trips exactly — the schedule seam is inert when it admits
    every symbol on every date. *)
let test_single_entry_schedule_is_bit_equal _ =
  let s = _scenario () in
  let sched = _single_entry_schedule () in
  assert_that
    (_run s
       ~sector_map_override:(Some (Universe_schedule.union_sector_map sched))
       ~universe_membership_at:(Universe_schedule.is_member sched))
    (elements_are (List.map (_baseline_trades ()) ~f:equal_to))

(** D6 staging invariant: the union sector map a scheduled run passes to the
    runner spans every list, so a name dropped by a later list still prices. *)
let test_union_sector_map_spans_every_list _ =
  let sched = _two_list_schedule () in
  assert_that
    (Universe_schedule.union_sector_map sched
    |> Hashtbl.keys
    |> List.sort ~compare:String.compare)
    (elements_are
       (List.map _parity_entries ~f:fst
       |> List.sort ~compare:String.compare
       |> List.map ~f:equal_to))

(** The candidate gate bites: JNJ would have been entered 2019-06-22, after
    2019-05-06 drops it from the universe, so that round trip disappears. *)
let test_dropped_symbol_entered_after_drop_is_gone _ =
  let s = _scenario () in
  let sched = _two_list_schedule () in
  assert_that
    (_run s
       ~sector_map_override:(Some (Universe_schedule.union_sector_map sched))
       ~universe_membership_at:(Universe_schedule.is_member sched)
    |> List.count ~f:(fun t -> String.equal t.symbol "JNJ"))
    (equal_to 0)

(** D4: AAPL and JPM were entered 2019-05-04, before 2019-05-06 drops them, and
    exit 2019-05-08 / 2019-05-10 — after the drop. Their round trips must be
    bit-equal to the baseline's: no exit surface consults the schedule. *)
let test_positions_held_through_dropout_exit_normally _ =
  let s = _scenario () in
  let sched = _two_list_schedule () in
  let held_before_drop trades =
    List.filter trades ~f:(fun t -> Date.( < ) t.entry_date _drop_date)
  in
  assert_that
    (_run s
       ~sector_map_override:(Some (Universe_schedule.union_sector_map sched))
       ~universe_membership_at:(Universe_schedule.is_member sched)
    |> held_before_drop)
    (elements_are
       (held_before_drop (_baseline_trades ()) |> List.map ~f:equal_to))

let suite =
  "universe_schedule_e2e_tests"
  >::: [
         "single-entry schedule is bit-equal to universe_path"
         >:: test_single_entry_schedule_is_bit_equal;
         "union sector map spans every list"
         >:: test_union_sector_map_spans_every_list;
         "symbol dropped before its entry is never entered"
         >:: test_dropped_symbol_entered_after_drop_is_gone;
         "position held across a dropout exits normally"
         >:: test_positions_held_through_dropout_exit_normally;
       ]

let () = run_test_tt_main suite
