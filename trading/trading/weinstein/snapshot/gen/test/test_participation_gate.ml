(** Tests for {!Weinstein_snapshot_gen.Participation_gate} — the weekly picks'
    entry ADV-participation cap (issue #3681), and its arming path through the
    [--config-overrides] loader. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot
module Participation_gate = Weinstein_snapshot_gen.Participation_gate

module Config_overrides_loader =
  Snapshot_config_overrides.Config_overrides_loader

let _as_of = Date.of_string "2026-11-13"
let _symbol = "TEST"

(* 30 bars at close 100, volume 1000: dollar ADV exactly $100,000. *)
let _bar_reader =
  let bar i : Types.Daily_price.t =
    {
      date = Date.add_days _as_of (i - 29);
      open_price = 100.0;
      high_price = 100.0;
      low_price = 100.0;
      close_price = 100.0;
      adjusted_close = 100.0;
      volume = 1000;
      active_through = None;
    }
  in
  Weinstein_strategy.Bar_reader.of_in_memory_bars
    [ (_symbol, List.init 30 ~f:bar) ]

let _candidate value : Weekly_snapshot.candidate =
  {
    symbol = _symbol;
    score = 100.0;
    grade = "A";
    entry = 100.0;
    stop = 90.0;
    sector = "XLK";
    rationale = "test";
    rs_vs_spy = None;
    resistance_grade = None;
    sized_shares = Float.to_int (value /. 100.0);
    sized_position_value = value;
    sized_position_pct = 0.0;
    sized_risk_amount = 0.0;
    sizing_note = None;
    stop_is_structural = false;
    data_suspect = false;
    reconciliation = Entry_reconciliation.Not_reconciled;
    score_components = [];
  }

let _kept participation value =
  let liquidity_config =
    {
      Weinstein_strategy.Liquidity_config.default_config with
      max_entry_adv_participation = participation;
    }
  in
  let kept, warnings =
    Participation_gate.partition ~liquidity_config _bar_reader ~as_of:_as_of
      [ _candidate value ]
  in
  (List.length kept, List.length warnings)

(* p = 0.1 of $100k ADV = $10k: at the cutoff kept, a dollar over dropped with
   one warning; [None] keeps even a position far above the ADV. *)
let test_cutoff_both_sides_and_none _ =
  assert_that
    [ _kept (Some 0.1) 10_000.0; _kept (Some 0.1) 10_100.0; _kept None 1e9 ]
    (elements_are [ equal_to (1, 0); equal_to (0, 1); equal_to (1, 0) ])

(* The arming line documented in record-config-overrides.sexp resolves through
   the real loader (Overlay_validator), not a hand-built record. *)
let test_override_arms_field _ =
  let path = Filename_unix.temp_file "config_overrides" ".sexp" in
  Out_channel.write_all path
    ~data:"((liquidity_config ((max_entry_adv_participation (0.10)))))\n";
  let config =
    Config_overrides_loader.load_and_apply ~overrides_path:path
      (Weinstein_strategy.default_config ~universe:[ _symbol ]
         ~index_symbol:"GSPC.INDX")
  in
  assert_that config.liquidity_config.max_entry_adv_participation
    (is_some_and (float_equal 0.10))

let suite =
  "participation_gate"
  >::: [
         "cutoff both sides and None" >:: test_cutoff_both_sides_and_none;
         "override arms field" >:: test_override_arms_field;
       ]

let () = run_test_tt_main suite
