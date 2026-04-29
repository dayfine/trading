open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let make_bar date ~close ?low ?high () =
  let low = Option.value low ~default:(close *. 0.99) in
  let high = Option.value high ~default:(close *. 1.01) in
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
  }

let get_price_of bars symbol = List.Assoc.find bars symbol ~equal:String.equal

(** Build a Position.t in the [Holding] state for [ticker] at [price]. Defaults
    to [Long]; pass [~side:Short] for short positions (used by the G1
    short-stop-direction reproducer tests below). *)
let make_holding_pos ?(side = Trading_base.Types.Long) ticker price date =
  let pos_id = ticker in
  let make_trans kind =
    { Trading_strategy.Position.position_id = pos_id; date; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error _ -> OUnit2.assert_failure "position setup failed"
  in
  let open Trading_strategy.Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol = ticker;
              side;
              target_quantity = 10.0;
              entry_price = price;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = 10.0; fill_price = price }))
    |> unwrap
  in
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

let default_cfg = Weinstein_stops.default_config
let default_stage_cfg = Stage.default_config

(* ------------------------------------------------------------------ *)
(* Empty and no-op cases                                                *)
(* ------------------------------------------------------------------ *)

let test_update_no_positions_returns_empty _ =
  let stop_states = ref String.Map.empty in
  let exits, adjusts =
    Stops_runner.update ~stops_config:default_cfg
      ~stage_config:default_stage_cfg ~lookback_bars:52
      ~positions:String.Map.empty
      ~get_price:(fun _ -> None)
      ~stop_states ~bar_reader:(Bar_reader.empty ())
      ~as_of:(Date.of_string "2024-12-31")
      ~prior_stages:(Hashtbl.create (module String))
      ()
  in
  assert_that exits is_empty;
  assert_that adjusts is_empty

let test_update_position_without_stop_state_returns_empty _ =
  (* Position is held but has no entry in stop_states — the fold skips it. *)
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  let stop_states = ref String.Map.empty in
  let exits, adjusts =
    Stops_runner.update ~stops_config:default_cfg
      ~stage_config:default_stage_cfg ~lookback_bars:52 ~positions
      ~get_price:(fun _ -> Some (make_bar "2024-01-12" ~close:95.0 ()))
      ~stop_states ~bar_reader:(Bar_reader.empty ())
      ~as_of:(Date.of_string "2024-12-31")
      ~prior_stages:(Hashtbl.create (module String))
      ()
  in
  assert_that exits is_empty;
  assert_that adjusts is_empty

let test_update_position_without_bar_returns_empty _ =
  (* Position is held, stop_state is set, but get_price returns None — skip. *)
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  let stop_state =
    Weinstein_stops.Initial { stop_level = 90.0; reference_level = 95.0 }
  in
  let stop_states = ref (String.Map.singleton ticker stop_state) in
  let exits, adjusts =
    Stops_runner.update ~stops_config:default_cfg
      ~stage_config:default_stage_cfg ~lookback_bars:52 ~positions
      ~get_price:(fun _ -> None)
      ~stop_states ~bar_reader:(Bar_reader.empty ())
      ~as_of:(Date.of_string "2024-12-31")
      ~prior_stages:(Hashtbl.create (module String))
      ()
  in
  assert_that exits is_empty;
  assert_that adjusts is_empty

(* ------------------------------------------------------------------ *)
(* Stop hit → TriggerExit                                              *)
(* ------------------------------------------------------------------ *)

let test_update_stop_hit_emits_trigger_exit _ =
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  let stop_state =
    Weinstein_stops.Initial { stop_level = 90.0; reference_level = 95.0 }
  in
  let stop_states = ref (String.Map.singleton ticker stop_state) in
  (* Bar's low of 85 crosses the stop level at 90 *)
  let bar = make_bar "2024-01-12" ~close:95.0 ~low:85.0 () in
  let exits, adjusts =
    Stops_runner.update ~stops_config:default_cfg
      ~stage_config:default_stage_cfg ~lookback_bars:52 ~positions
      ~get_price:(get_price_of [ (ticker, bar) ])
      ~stop_states ~bar_reader:(Bar_reader.empty ())
      ~as_of:(Date.of_string "2024-12-31")
      ~prior_stages:(Hashtbl.create (module String))
      ()
  in
  assert_that adjusts is_empty;
  assert_that exits
    (elements_are
       [
         all_of
           [
             field
               (fun (tr : Trading_strategy.Position.transition) ->
                 tr.position_id)
               (equal_to ticker);
             field
               (fun (tr : Trading_strategy.Position.transition) -> tr.kind)
               (matching ~msg:"Expected TriggerExit"
                  (function
                    | Trading_strategy.Position.TriggerExit _ -> Some ()
                    | _ -> None)
                  (equal_to ()));
             field
               (fun (tr : Trading_strategy.Position.transition) -> tr.date)
               (equal_to (Date.of_string "2024-01-12"));
           ];
       ])

(* ------------------------------------------------------------------ *)
(* stop_states mutation                                                 *)
(* ------------------------------------------------------------------ *)

let test_update_mutates_stop_states_ref _ =
  (* Even when no transition is emitted, the stop_states ref receives the
     updated state from the state machine. *)
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  let initial =
    Weinstein_stops.Initial { stop_level = 90.0; reference_level = 95.0 }
  in
  let stop_states = ref (String.Map.singleton ticker initial) in
  let bar = make_bar "2024-01-12" ~close:100.0 () in
  let _ =
    Stops_runner.update ~stops_config:default_cfg
      ~stage_config:default_stage_cfg ~lookback_bars:52 ~positions
      ~get_price:(get_price_of [ (ticker, bar) ])
      ~stop_states ~bar_reader:(Bar_reader.empty ())
      ~as_of:(Date.of_string "2024-12-31")
      ~prior_stages:(Hashtbl.create (module String))
      ()
  in
  (* Entry for AAPL still exists in the ref (may be same state or advanced). *)
  assert_that (Map.find !stop_states ticker) (is_some_and (fun _ -> ()))

(* ------------------------------------------------------------------ *)
(* G1 reproducer — ALB short-stop anomaly                              *)
(*                                                                      *)
(* Audit evidence (dev/notes/short-side-gaps-2026-04-29.md): ALB short  *)
(* with stop $103.58 exits at $77.49 on 2019-01-29 when ALB was at      *)
(* ~$76 — profitable territory for a short, NOT a stop trigger.         *)
(*                                                                      *)
(* Reproduction strategy: drive Stops_runner.update over a multi-bar    *)
(* sequence where ALB declines from $100 to ~$76 over 4 weekly bars.    *)
(* Bar high stays well below the stop level ($103.58) on every bar.    *)
(* Contract: zero TriggerExit transitions across all bars; the runner   *)
(* must keep the stop ABOVE entry throughout (a short stop never moves  *)
(* DOWN through entry — that would be moving the stop AGAINST the       *)
(* position, which docs/design/eng-design-3-portfolio-stops.md          *)
(* explicitly forbids).                                                 *)
(* ------------------------------------------------------------------ *)

(** Drive [Stops_runner.update] for a short [Holding] across a sequence of bars,
    threading [stop_states] across calls. Returns the cumulative
    [(exits, adjusts)] across all bars. The position, prior_stages, and
    stop_states ref are constructed once and mutated by the runner. *)
let _run_short_sequence ~ticker ~entry_price ~entry_date ~stop_level ~bars =
  let pos =
    make_holding_pos ~side:Trading_base.Types.Short ticker entry_price
      entry_date
  in
  let positions = String.Map.singleton ticker pos in
  let stop_states =
    ref
      (String.Map.singleton ticker
         (Weinstein_stops.Initial { stop_level; reference_level = stop_level }))
  in
  let prior_stages = Hashtbl.create (module String) in
  List.fold bars ~init:([], []) ~f:(fun (exits_acc, adjusts_acc) bar ->
      let exits, adjusts =
        Stops_runner.update ~stops_config:default_cfg
          ~stage_config:default_stage_cfg ~lookback_bars:52 ~positions
          ~get_price:(get_price_of [ (ticker, bar) ])
          ~stop_states ~bar_reader:(Bar_reader.empty ())
          ~as_of:bar.Types.Daily_price.date ~prior_stages ()
      in
      (exits_acc @ exits, adjusts_acc @ adjusts))
  |> fun (exits, adjusts) -> (exits, adjusts, !stop_states)

(** Reproducer 1: ALB short, stop $103.58 above entry $100. Two bars: an initial
    pullback bar (close $95, high $98), then a small counter- bounce bar (high
    $99.5) — comfortably below the $103.58 entry-stop.

    On current main (pre-G1 fix), [Stops_runner._handle_stop] hardcodes
    [stage = Stage2] regardless of position side when calling
    [Weinstein_stops.update]. [_should_tighten_short] matches
    [Stage1 | Stage2 -> tighten], so on bar 1 the runner immediately tightens
    the short's stop from $103.58 down to ~$99.13 (the bar high $98 plus the
    trailing buffer). Bar 2 (high $99.5) then prints above the eroded stop,
    firing a spurious [Stop_hit]. This is exactly the ALB pathology shape: a
    short in profitable territory exits on a small counter-bounce because the
    stop drifted through entry into loss territory.

    Post-fix: the runner passes the position-favourable warmup default
    ([Stage4 + Declining MA] for shorts), no spurious tightening fires on bar 1,
    the stop stays at $103.58, and bar 2's $99.5 high doesn't cross it. Zero
    exits emitted.

    Contract: zero [TriggerExit] transitions across the sequence. *)
let test_g1_short_no_exit_on_counter_bounce _ =
  let ticker = "ALB" in
  let entry_date = Date.of_string "2019-01-15" in
  let entry_price = 100.0 in
  let stop_level = 103.58 in
  (* Two bars: initial pullback then a small counter-bounce.  Both bar
     highs stay below the $103.58 entry-stop, but the bounce high
     ($99.5) is above the stop level the Stage2-hardcode bug drifts to
     (~$99.13) on bar 1. *)
  let bars =
    [
      make_bar "2019-01-22" ~close:95.0 ~low:94.0 ~high:98.0 ();
      make_bar "2019-01-29" ~close:80.0 ~low:79.0 ~high:99.5 ();
    ]
  in
  let exits, _adjusts, _final_stop_states =
    _run_short_sequence ~ticker ~entry_price ~entry_date ~stop_level ~bars
  in
  (* Contract: no exit transitions emitted on either bar.  Neither bar
     prints above the $103.58 entry-stop; a short held profitably must
     not exit when the stop machinery is functioning correctly. *)
  assert_that exits is_empty

(** Reproducer 2: the canonical ALB audit anomaly.

    On a single violent down-day where the bar high crosses the short stop
    (intraday spike before close), [check_stop_hit] correctly fires — but
    [_make_exit_transition] then records [actual_price = bar.low_price]
    regardless of position side. For a SHORT covered when price rallies UP
    through the stop, the worst-case fill is at [bar.high_price] (or the stop
    level), not [bar.low_price]. Recording bar.low produces audit log entries
    like ALB on 2019-01-29 — stop $103.58, actual_price $77.49, when ALB closed
    at $76 — that look as if the stop fired against profitable territory.

    This pins the audit-record contract: when a short stop fires on a bar whose
    high crosses the stop, the recorded [actual_price] (and [exit_price]) must
    reflect the trigger side (high or stop level), not the bar's low. *)
let test_g1_short_exit_records_high_not_low _ =
  let ticker = "ALB" in
  let entry_date = Date.of_string "2019-01-15" in
  let entry_price = 100.0 in
  let stop_level = 103.58 in
  let pos =
    make_holding_pos ~side:Trading_base.Types.Short ticker entry_price
      entry_date
  in
  let positions = String.Map.singleton ticker pos in
  let stop_states =
    ref
      (String.Map.singleton ticker
         (Weinstein_stops.Initial { stop_level; reference_level = stop_level }))
  in
  (* Violent down-day: open above stop, intraday spike crosses stop,
     close near the day's low. Mirrors the ALB 2019-01-29 audit shape:
     intraday high $104 (above stop $103.58) → trigger fires; close /
     low at $76–$77 (the misleading "actual_price" in the audit log). *)
  let bar = make_bar "2019-01-29" ~close:76.0 ~low:75.5 ~high:104.0 () in
  let exits, _adjusts =
    Stops_runner.update ~stops_config:default_cfg
      ~stage_config:default_stage_cfg ~lookback_bars:52 ~positions
      ~get_price:(get_price_of [ (ticker, bar) ])
      ~stop_states ~bar_reader:(Bar_reader.empty ())
      ~as_of:(Date.of_string "2019-01-29")
      ~prior_stages:(Hashtbl.create (module String))
      ()
  in
  (* The trigger fired (correct: high $104 >= stop $103.58). Now pin
     the audit record: actual_price must be the trigger side — the
     short cover hits at bar.high or the stop level, not bar.low. *)
  assert_that exits
    (elements_are
       [
         field
           (fun (tr : Trading_strategy.Position.transition) -> tr.kind)
           (matching ~msg:"Expected TriggerExit with StopLoss"
              (function
                | Trading_strategy.Position.TriggerExit
                    { exit_reason = StopLoss s; exit_price } ->
                    Some (s.actual_price, exit_price)
                | _ -> None)
              (all_of
                 [
                   (* actual_price must be at or above the stop level —
                      a short cover triggers at the trigger price (high
                      or stop), never at the bar's low. *)
                   field (fun (a, _) -> a) (ge (module Float_ord) stop_level);
                   field (fun (_, e) -> e) (ge (module Float_ord) stop_level);
                 ]));
       ])

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("stops_runner"
    >::: [
           "update with no positions returns empty"
           >:: test_update_no_positions_returns_empty;
           "update with position but no stop state returns empty"
           >:: test_update_position_without_stop_state_returns_empty;
           "update with position but no current bar returns empty"
           >:: test_update_position_without_bar_returns_empty;
           "update emits TriggerExit when stop is hit"
           >:: test_update_stop_hit_emits_trigger_exit;
           "update mutates stop_states ref for held positions"
           >:: test_update_mutates_stop_states_ref;
           "G1: short stop emits no exit on counter-bounce below entry stop"
           >:: test_g1_short_no_exit_on_counter_bounce;
           "G1: short exit records high (not low) on violent down-day"
           >:: test_g1_short_exit_records_high_not_low;
         ])
