(** Tests for {!Weinstein_snapshot_gen.Participation_gate} — the weekly picks'
    entry ADV-participation cap (issue #3681), its arming path through the
    [--config-overrides] loader, and where its warnings sit in
    {!Weinstein_snapshot_gen.Candidate_gates.apply}. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot
module Participation_gate = Weinstein_snapshot_gen.Participation_gate

module Config_overrides_loader =
  Snapshot_config_overrides.Config_overrides_loader

let _as_of = Date.of_string "2026-11-13"
let _symbol = "TEST"

(* 30 daily bars ending at [_as_of], closing [close] each day except the last,
   which closes [last_close]; volume [volume] throughout. *)
let _bars ?(last_close = 100.0) ~volume () =
  let bar i : Types.Daily_price.t =
    let close = if i = 29 then last_close else 100.0 in
    {
      date = Date.add_days _as_of (i - 29);
      open_price = close;
      high_price = close;
      low_price = close;
      close_price = close;
      adjusted_close = close;
      volume;
      active_through = None;
    }
  in
  List.init 30 ~f:bar

(* Flat close 100, volume 1000: dollar ADV exactly $100,000. *)
let _bar_reader =
  Weinstein_strategy.Bar_reader.of_in_memory_bars
    [ (_symbol, _bars ~volume:1000 ()) ]

let _candidate ?(symbol = _symbol) value : Weekly_snapshot.candidate =
  {
    symbol;
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

(* {!Candidate_gates.apply} returns the participation warnings first, then the
   long spike warnings, then the short spike warnings (its .mli contract). The
   long list puts the spiking name before the dropped one, so the order of the
   warnings comes from the gate order, not from the input order. *)
let test_gate_warning_order _ =
  let reader =
    Weinstein_strategy.Bar_reader.of_in_memory_bars
      [
        ("DROP", _bars ~volume:1000 ());
        ("LSPIKE", _bars ~last_close:160.0 ~volume:1_000_000 ());
        ("SSPIKE", _bars ~last_close:160.0 ~volume:1_000_000 ());
      ]
  in
  let base =
    Weinstein_strategy.default_config ~universe:[] ~index_symbol:"GSPC.INDX"
  in
  let config =
    {
      base with
      spike_bar_threshold_pct = 50.0;
      liquidity_config =
        { base.liquidity_config with max_entry_adv_participation = Some 0.1 };
    }
  in
  let longs, _, warnings =
    Weinstein_snapshot_gen.Candidate_gates.apply ~config reader ~as_of:_as_of
      ~longs:
        [
          _candidate ~symbol:"LSPIKE" 10_000.0;
          _candidate ~symbol:"DROP" 20_000.0;
        ]
      ~shorts:[ _candidate ~symbol:"SSPIKE" 10_000.0 ]
  in
  assert_that
    ( List.map longs ~f:(fun c -> c.Weekly_snapshot.symbol),
      List.map warnings ~f:(fun w -> List.hd_exn (String.split w ~on:' ')) )
    (equal_to ([ "LSPIKE" ], [ "DROP"; "LSPIKE:"; "SSPIKE:" ]))

(* The live-size profile (issue #3693): weekly.sh writes the record overrides
   followed by dev/weekly-picks/live-size-overrides.sexp into one file. The
   three live-size lines below are that file's (weekly_picks_dry_run_check.sh
   pins them to it); the record lines are the record's values of the same
   fields plus one it leaves alone. Each later line replaces just its field. *)
let _record_lines =
  "((liquidity_config ((min_entry_dollar_adv 1000000.0))))\n\
   ((liquidity_config ((min_hold_dollar_adv 500000.0))))\n\
   ((portfolio_config ((max_position_pct_long 0.14))))\n"

let _live_size_lines =
  "((liquidity_config ((max_entry_adv_participation (0.10)))))\n\
   ((liquidity_config ((min_entry_dollar_adv 100000.0))))\n\
   ((liquidity_config ((min_hold_dollar_adv 50000.0))))\n"

let test_live_size_layering _ =
  let path = Filename_unix.temp_file "layered_overrides" ".sexp" in
  Out_channel.write_all path ~data:(_record_lines ^ _live_size_lines);
  let config =
    Config_overrides_loader.load_and_apply ~overrides_path:path
      (Weinstein_strategy.default_config ~universe:[ _symbol ]
         ~index_symbol:"GSPC.INDX")
  in
  let liq (c : Weinstein_strategy.config) = c.liquidity_config in
  assert_that config
    (all_of
       [
         field
           (fun c -> (liq c).max_entry_adv_participation)
           (is_some_and (float_equal 0.10));
         field (fun c -> (liq c).min_entry_dollar_adv) (float_equal 100_000.0);
         field (fun c -> (liq c).min_hold_dollar_adv) (float_equal 50_000.0);
         field
           (fun (c : Weinstein_strategy.config) ->
             c.portfolio_config.max_position_pct_long)
           (float_equal 0.14);
         field
           (fun c -> (liq c).adv_lookback_days)
           (equal_to
              Weinstein_strategy.Liquidity_config.default_config
                .adv_lookback_days);
       ])

let suite =
  "participation_gate"
  >::: [
         "cutoff both sides and None" >:: test_cutoff_both_sides_and_none;
         "override arms field" >:: test_override_arms_field;
         "gate warning order" >:: test_gate_warning_order;
         "live-size layering" >:: test_live_size_layering;
       ]

let () = run_test_tt_main suite
