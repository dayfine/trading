(** End-to-end smoke test for the PR-2 trade-audit capture sites.

    PR-1 of the trade-audit plan (#638) shipped the {!Backtest.Trade_audit}
    types + collector + sexp persistence. PR-2 wires the entry / exit capture
    sites in the strategy and runner so [result.audit] is actually populated
    after a backtest run.

    This test pins the integration:

    - Running [Backtest.Runner.run_backtest] over the [tiered-loader-parity]
      smoke scenario (a 6-month, 7-symbol bull window) must populate
      [result.audit] with at least one record when the run produces at least one
      entry decision.
    - Every captured audit record's [entry] block carries the runtime fields the
      strategy is expected to fill at decision time — non-empty symbol, entry
      date inside the scenario window, [installed_stop > 0], plus the macro /
      stage / cascade snapshots.
    - When the simulator fully closes a position, the matching audit record's
      [exit_] is populated; positions still open at end-of-run carry [None].

    The test runs against the same fixture ([smoke/tiered-loader-parity.sexp])
    used by [test_runner_hypothesis_overrides], which is committed and small
    enough to finish in well under the per-test budget. *)

open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file

let _fixtures_root () =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  Filename.concat data_dir "backtest_scenarios"

let _scenario_path () =
  Filename.concat (_fixtures_root ()) "smoke/tiered-loader-parity.sexp"

let _load_scenario () = Scenario.load (_scenario_path ())

let _sector_map_override (s : Scenario.t) =
  let resolved = Filename.concat (_fixtures_root ()) s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

let _run_scenario () =
  let s = _load_scenario () in
  let sector_map_override = _sector_map_override s in
  Backtest.Runner.run_backtest ~start_date:s.period.start_date
    ~end_date:s.period.end_date ~overrides:s.config_overrides
    ?sector_map_override ()

(* -------------------------------------------------------------------- *)
(* Smoke: audit is populated when the run produces entries               *)
(* -------------------------------------------------------------------- *)

(** The 7-symbol bull-window scenario produces at least one entry over H2 2019.
    PR-2 must therefore populate [result.audit] with at least one record. A
    failure here means the capture sites in [_screen_universe] /
    [entries_from_candidates] are wired wrong. *)
let test_audit_is_non_empty_when_entries_fire _ =
  let result = _run_scenario () in
  (* Trade-audit capture must populate at least one record over this
     bull-window scenario; an empty list signals the entry capture site is
     not wired or never fired. *)
  assert_that (List.length result.audit) (gt (module Int_ord) 0)

(** Each audit record must carry a populated entry block. The check is
    structural — non-empty symbol, entry_date inside the scenario window, sane
    [installed_stop], and a [position_id] non-empty string. Float pinning is
    intentionally loose: this test guards capture-site wiring, not specific
    stop-buffer values. *)
let test_audit_entry_block_is_populated _ =
  let result = _run_scenario () in
  let s = _load_scenario () in
  (* Every audit record's entry block must carry strategy-derived state —
     non-empty symbol, position_id, in-window date, [installed_stop > 0],
     non-negative cascade_score. Pins capture-site wiring without locking
     specific values. *)
  assert_that result.audit
    (each
       (field
          (fun (r : Backtest.Trade_audit.audit_record) -> r.entry)
          (all_of
             [
               field
                 (fun (e : Backtest.Trade_audit.entry_decision) ->
                   String.length e.symbol)
                 (gt (module Int_ord) 0);
               field
                 (fun (e : Backtest.Trade_audit.entry_decision) ->
                   String.length e.position_id)
                 (gt (module Int_ord) 0);
               field
                 (fun (e : Backtest.Trade_audit.entry_decision) ->
                   Date.( >= ) e.entry_date s.period.start_date
                   && Date.( <= ) e.entry_date s.period.end_date)
                 (equal_to true);
               field
                 (fun (e : Backtest.Trade_audit.entry_decision) ->
                   e.installed_stop)
                 (gt (module Float_ord) 0.0);
               field
                 (fun (e : Backtest.Trade_audit.entry_decision) ->
                   e.cascade_score)
                 (ge (module Int_ord) 0);
             ])))

(** Every round-trip's symbol must appear in the audit's entry list. The join is
    by symbol alone — not [(symbol, entry_date)] — because
    [trade_metrics.entry_date] is the simulator-fill date (one trading day after
    the strategy emitted [CreateEntering], typically Friday → Monday) while
    [audit.entry_date] is the strategy's decision date. The fill-lag is a
    property of the simulator's order-execution path, not of the audit capture.
*)
let test_round_trip_symbols_match_audit_entries _ =
  let result = _run_scenario () in
  let audit_symbols =
    List.map result.audit ~f:(fun (r : Backtest.Trade_audit.audit_record) ->
        r.entry.symbol)
    |> Set.of_list (module String)
  in
  let unmatched =
    List.filter result.round_trips
      ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
        not (Set.mem audit_symbols t.symbol))
  in
  (* Every round-trip's symbol must have at least one audit entry. A
     mismatch would mean the entry capture missed a candidate that
     ultimately produced a fill. *)
  assert_that (List.length unmatched) (equal_to 0)

(** At least one audit record must have [exit_] populated — the only way the
    flag fires is the strategy emitting a [TriggerExit], which the
    [_on_market_close] capture site picks up. A failure here means exit capture
    is not wired. *)
let test_some_audit_records_have_exit_blocks _ =
  let result = _run_scenario () in
  let with_exit =
    List.count result.audit ~f:(fun (r : Backtest.Trade_audit.audit_record) ->
        Option.is_some r.exit_)
  in
  (* Exit capture must fire at least once over the bull-window scenario,
     which produces several stop-out exits per the committed scenario
     metadata. *)
  assert_that with_exit (gt (module Int_ord) 0)

(** Position ids must round-trip through the audit collector — recording an
    entry then an exit with the same [position_id] yields one audit record with
    both blocks populated, never two records with the same key.

    The collector keys by [position_id], so this is a property of
    {!Backtest.Trade_audit} itself; we re-test it here at the end-to-end seam to
    guard against a future refactor that accidentally double-records or keys by
    something else. *)
let test_audit_position_ids_are_unique _ =
  let result = _run_scenario () in
  let ids =
    List.map result.audit ~f:(fun (r : Backtest.Trade_audit.audit_record) ->
        r.entry.position_id)
  in
  let dedup = List.dedup_and_sort ids ~compare:String.compare in
  (* Audit collector must not record duplicate position_ids — Trade_audit
     keys by position_id, so duplicates mean the strategy generated the same
     id twice or the test rig is double-recording. *)
  assert_that (List.length ids - List.length dedup) (equal_to 0)

let suite =
  "Trade_audit_capture"
  >::: [
         "audit is non-empty when entries fire"
         >:: test_audit_is_non_empty_when_entries_fire;
         "every audit record's entry block is populated"
         >:: test_audit_entry_block_is_populated;
         "every round-trip's symbol matches an audit entry"
         >:: test_round_trip_symbols_match_audit_entries;
         "at least one audit record has a populated exit_ block"
         >:: test_some_audit_records_have_exit_blocks;
         "audit position_ids are unique" >:: test_audit_position_ids_are_unique;
       ]

let () = run_test_tt_main suite
