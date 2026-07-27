(** Tests for {!Stop_thread} — carrying a held position's trailing stop from
    week to week.

    Fixtures are built as explicit [Daily_price.t] lists so every close, low and
    high the state machine reads is controlled per test. The weekly series are
    long enough (40 weeks) for {!Stage.classify} to produce a real MA and stage
    rather than its short-series fallback. *)

open Core
open OUnit2
open Matchers
module Stop_thread = Weinstein_snapshot_gen.Stop_thread
module Stop_track = Weinstein_snapshot_gen.Stop_track

let _stops_config = Weinstein_stops.default_config
let _stage_config = Stage.default_config
let _initial_stop_buffer = 0.92
let _weeks = 40
let _monday = Date.of_string "2024-01-01"
let _week_end i = Date.add_days _monday ((i * 7) + 4)

let _bar ?high ?low ~close date : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = Option.value high ~default:(close *. 1.01);
    low_price = Option.value low ~default:(close *. 0.99);
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* A steadily advancing weekly series — a Stage-2 uptrend with a rising MA, so
   the machine trails rather than tightening. *)
let _uptrend ?(n = _weeks) ?(start = 100.0) ?(step = 2.0) () =
  List.init n ~f:(fun i ->
      _bar ~close:(start +. (Float.of_int i *. step)) (_week_end i))

let _last_close bars = (List.last_exn bars).Types.Daily_price.close_price

let _track ~level ~updated : Stop_track.t =
  {
    state = Initial { stop_level = level; reference_level = level +. 5.0 };
    updated;
    raises = 0;
  }

(* [Triggered] carries an inline record, which cannot escape its match; project
   it into a tuple so a matcher can read the fields by name. *)
let _triggered = function
  | Stop_thread.Triggered { track; week; close; stop_level } ->
      Some (track, week, close, stop_level)
  | Holding _ -> None

let _holding = function Stop_thread.Holding t -> Some t | Triggered _ -> None

let _advance ~weekly_bars ~prior =
  Stop_thread.advance ~stops_config:_stops_config ~stage_config:_stage_config
    ~weekly_bars ~prior

(* --- seed ---------------------------------------------------------------- *)

(* A daily series holding a clear ~17% correction, then a PARTIAL recovery.
   The recovery deliberately stops short of the prior peak: the floor primitive
   anchors on the highest high in the window, so a series that makes a new high
   on its last bar has no counter-move after the anchor and yields no floor at
   all. That is the real shape of a stock bought after a base. *)
let _correction_low = 88.0
let _entry = 102.0

let _daily_with_correction () =
  let closes =
    [
      100.0;
      102.0;
      104.0;
      106.0;
      100.0;
      94.0;
      _correction_low;
      92.0;
      98.0;
      _entry;
    ]
  in
  List.mapi closes ~f:(fun i close ->
      _bar ~high:close ~low:close ~close (Date.add_days _monday i))

let _seed ~daily_bars ~working_stop ~entry_price =
  Stop_thread.seed ~stops_config:_stops_config
    ~initial_stop_buffer:_initial_stop_buffer ~entry_price ~working_stop
    ~daily_bars
    ~as_of:(Date.add_days _monday (List.length daily_bars - 1))

(* L1: the seeded stop is anchored to the prior correction low, sitting just
   below it — not at an arbitrary percentage of the entry price. *)
let test_seed_places_stop_below_the_correction_low _ =
  assert_that
    (Stop_track.level
       (_seed
          ~daily_bars:(_daily_with_correction ())
          ~working_stop:1.0 ~entry_price:_entry))
    (is_between
       (module Float_ord)
       ~low:(_correction_low *. 0.9) ~high:_correction_low)

(* L2 at seed time: a position held long enough to have trailed its stop up
   keeps that stop. Seeding must never lower the order resting at the broker. *)
let test_seed_ratchets_to_a_higher_working_stop _ =
  assert_that
    (Stop_track.level
       (_seed
          ~daily_bars:(_daily_with_correction ())
          ~working_stop:105.0 ~entry_price:_entry))
    (float_equal 105.0)

(* Symmetrically, a working stop BELOW the derived floor does not drag the
   seeded stop down. *)
let test_seed_ignores_a_lower_working_stop _ =
  let derived =
    Stop_track.level
      (_seed
         ~daily_bars:(_daily_with_correction ())
         ~working_stop:1.0 ~entry_price:_entry)
  in
  assert_that
    (Stop_track.level
       (_seed
          ~daily_bars:(_daily_with_correction ())
          ~working_stop:50.0 ~entry_price:_entry))
    (float_equal derived)

(* With no qualifying correction in the window the floor primitive falls back to
   the fixed buffer, which lands somewhere else entirely — so the structural
   branch above is doing real work rather than agreeing with the fallback. *)
let test_seed_falls_back_without_a_qualifying_correction _ =
  let flat =
    List.init 10 ~f:(fun i -> _bar ~close:_entry (Date.add_days _monday i))
  in
  let structural =
    Stop_track.level
      (_seed
         ~daily_bars:(_daily_with_correction ())
         ~working_stop:1.0 ~entry_price:_entry)
  in
  assert_that
    (Stop_track.level
       (_seed ~daily_bars:flat ~working_stop:1.0 ~entry_price:_entry))
    (gt (module Float_ord) structural)

let test_seed_starts_the_ratchet_history_at_zero _ =
  assert_that
    (_seed
       ~daily_bars:(_daily_with_correction ())
       ~working_stop:1.0 ~entry_price:_entry)
    (field (fun (t : Stop_track.t) -> t.raises) (equal_to 0))

(* --- advance: idempotence ------------------------------------------------ *)

(* Replaying a week already carried forward changes nothing, so re-running the
   weekly report cannot double-count ratchets. *)
let test_advance_is_idempotent _ =
  let weekly_bars = _uptrend () in
  let prior = _track ~level:50.0 ~updated:(_week_end (_weeks - 1)) in
  assert_that
    (_advance ~weekly_bars ~prior)
    (equal_to (Stop_thread.Holding prior))

(* An empty series is the degenerate case of the same rule. *)
let test_advance_with_no_bars_returns_the_prior_track _ =
  let prior = _track ~level:50.0 ~updated:(_week_end 0) in
  assert_that
    (_advance ~weekly_bars:[] ~prior)
    (equal_to (Stop_thread.Holding prior))

(* Weeks strictly after [updated] are replayed: the track's own [updated] moves
   to the last bar. *)
let test_advance_moves_updated_to_the_last_week _ =
  let weekly_bars = _uptrend () in
  let prior = _track ~level:50.0 ~updated:(_week_end (_weeks - 4)) in
  assert_that
    (_advance ~weekly_bars ~prior)
    (matching ~msg:"Holding" _holding
       (field
          (fun (t : Stop_track.t) -> t.updated)
          (equal_to (_week_end (_weeks - 1)))))

(* The first replayed week takes Initial -> Trailing (book §5.2's INITIAL ->
   TRAILING transition), which is state the recomputed-floor design could not
   carry. *)
let test_advance_transitions_initial_to_trailing _ =
  let weekly_bars = _uptrend () in
  let prior = _track ~level:50.0 ~updated:(_week_end (_weeks - 4)) in
  assert_that
    (_advance ~weekly_bars ~prior)
    (matching ~msg:"Holding" _holding
       (field
          (fun (t : Stop_track.t) -> Stop_track.state_name t.state)
          (equal_to "Trailing")))

(* --- advance: the weekly-close trigger (L3) ------------------------------ *)

(* A final week that CLOSES through the stop exits. *)
let _uptrend_then_close_below ~stop =
  _uptrend ~n:(_weeks - 1) ()
  @ [ _bar ~close:(stop -. 1.0) (_week_end (_weeks - 1)) ]

(* A final week that DIPS through the stop intra-week but closes back above it
   does not. This is Weinstein's weekly-close rule: an intra-week shakeout is
   not an exit. *)
let _uptrend_then_wick_below ~stop =
  _uptrend ~n:(_weeks - 1) ()
  @ [
      _bar ~low:(stop -. 5.0) ~high:(stop +. 40.0) ~close:(stop +. 30.0)
        (_week_end (_weeks - 1));
    ]

let _stop_under_the_trend = 120.0

let test_advance_triggers_on_a_weekly_close_below_the_stop _ =
  let weekly_bars = _uptrend_then_close_below ~stop:_stop_under_the_trend in
  let prior =
    _track ~level:_stop_under_the_trend ~updated:(_week_end (_weeks - 3))
  in
  assert_that
    (_advance ~weekly_bars ~prior)
    (matching ~msg:"Triggered" _triggered
       (all_of
          [
            field
              (fun (_, week, _, _) -> week)
              (equal_to (_week_end (_weeks - 1)));
            field
              (fun (_, _, close, _) -> close)
              (float_equal (_stop_under_the_trend -. 1.0));
          ]))

let test_advance_ignores_an_intra_week_wick_below_the_stop _ =
  let weekly_bars = _uptrend_then_wick_below ~stop:_stop_under_the_trend in
  let prior =
    _track ~level:_stop_under_the_trend ~updated:(_week_end (_weeks - 3))
  in
  assert_that
    (_advance ~weekly_bars ~prior)
    (matching ~msg:"Holding" _holding
       (field
          (fun (t : Stop_track.t) -> t.updated)
          (equal_to (_week_end (_weeks - 1)))))

(* Replay stops at the exit week — a sold position does not keep trading. The
   triggering week is followed by two more bars that would otherwise advance
   [updated] past it. *)
let test_advance_stops_replaying_at_the_trigger _ =
  let stop = _stop_under_the_trend in
  let weekly_bars =
    _uptrend ~n:(_weeks - 3) ()
    @ [
        _bar ~close:(stop -. 1.0) (_week_end (_weeks - 3));
        _bar ~close:(stop +. 20.0) (_week_end (_weeks - 2));
        _bar ~close:(stop +. 30.0) (_week_end (_weeks - 1));
      ]
  in
  let prior = _track ~level:stop ~updated:(_week_end (_weeks - 5)) in
  assert_that
    (_advance ~weekly_bars ~prior)
    (matching ~msg:"Triggered" _triggered
       (all_of
          [
            field
              (fun (_, week, _, _) -> week)
              (equal_to (_week_end (_weeks - 3)));
            field (fun (_, _, _, stop_level) -> stop_level) (float_equal stop);
            field
              (fun ((t : Stop_track.t), _, _, _) -> t.updated)
              (equal_to (_week_end (_weeks - 3)));
          ]))

(* --- advance: the ratchet history ---------------------------------------- *)

(* A correction of more than [min_correction_pct] followed by a recovery back to
   the prior peak completes a cycle, which is what raises the stop (book §5.2
   TRAILING). The count is the history the report needs. *)
let _uptrend_with_correction_cycle () =
  let peak = _last_close (_uptrend ~n:(_weeks - 4) ()) in
  _uptrend ~n:(_weeks - 4) ()
  @ [
      _bar ~close:(peak *. 0.88) (_week_end (_weeks - 4));
      _bar ~close:(peak *. 0.86) (_week_end (_weeks - 3));
      _bar ~close:(peak *. 1.02) (_week_end (_weeks - 2));
      _bar ~close:(peak *. 1.05) (_week_end (_weeks - 1));
    ]

let test_advance_counts_a_completed_correction_cycle _ =
  let weekly_bars = _uptrend_with_correction_cycle () in
  let prior = _track ~level:50.0 ~updated:(_week_end (_weeks - 6)) in
  assert_that
    (_advance ~weekly_bars ~prior)
    (matching ~msg:"Holding" _holding
       (field (fun (t : Stop_track.t) -> t.raises) (gt (module Int_ord) 0)))

(* A raise moves the stop UP and only up — the never-lower rule seen through the
   machine rather than through a manual edit. *)
let test_advance_never_lowers_the_stop _ =
  let weekly_bars = _uptrend_with_correction_cycle () in
  let prior = _track ~level:50.0 ~updated:(_week_end (_weeks - 6)) in
  assert_that
    (_advance ~weekly_bars ~prior)
    (matching ~msg:"Holding" _holding
       (field Stop_track.level (ge (module Float_ord) 50.0)))

(* --- advance: the level TRAILS, over several cycles (L2) ----------------- *)

(* Everything above pins the bookkeeping AROUND the stop — which arm, how many
   raises, which week. None of it pins the number the whole item exists to
   move. Freeze [stop_level] and let the arms, events and [raises] advance
   normally, and every test above still passes while the report prints
   "Trailing (2 raises, ...)" beside a stop that has not budged.

   Book §5.2's worked example trails the stop through THREE correction cycles
   (its points E, G and I), so one cycle is not enough either: a single raise
   cannot distinguish a stop that trails from a stop that moved once and then
   stuck. *)

let _cycles = 3
let _cycle_weeks = 3
let _base_weeks = _weeks - (_cycles * _cycle_weeks)

(* Start the replay several weeks INSIDE the base rather than at the first dip.
   [Initial -> Trailing] seeds [last_trend_extreme] from the first replayed
   bar's close, so a replay starting on a dip week would anchor the trend to the
   bottom of that dip and never measure a [min_correction_pct] pullback. *)
let _replay_from = _base_weeks - 6
let _prior_level = 50.0

(* One cycle: two weeks falling well past [min_correction_pct] below [peak],
   then a week closing back above it. The recovery close is the next cycle's
   peak, so each cycle starts from a higher trend extreme than the last — which
   is why the raises are strictly increasing rather than merely repeated. *)
let _cycle_bars ~peak ~first_week =
  [
    _bar ~close:(peak *. 0.90) (_week_end first_week);
    _bar ~close:(peak *. 0.88) (_week_end (first_week + 1));
    _bar ~close:(peak *. 1.04) (_week_end (first_week + 2));
  ]

let _three_cycle_series () =
  let base = _uptrend ~n:_base_weeks () in
  List.fold (List.init _cycles ~f:Fn.id) ~init:base ~f:(fun bars c ->
      bars
      @ _cycle_bars ~peak:(_last_close bars)
          ~first_week:(_base_weeks + (c * _cycle_weeks)))

let _holding_exn outcome =
  match _holding outcome with
  | Some track -> track
  | None ->
      assert_failure "expected Holding; the fixture stopped the position out"

(* Advance ONE cycle at a time, keeping the track after each. Replaying the
   whole series in a single call would only expose the final level; the claim
   under test is that the level moves on every cycle. Each call is handed the
   bar prefix ending at that cycle's recovery week and the previous call's
   track, which is exactly how the weekly report resumes week to week. *)
let _tracks_across_cycles () =
  let bars = _three_cycle_series () in
  let prior = _track ~level:_prior_level ~updated:(_week_end _replay_from) in
  List.folding_map (List.init _cycles ~f:Fn.id) ~init:prior ~f:(fun track c ->
      let weekly_bars =
        List.take bars (_base_weeks + ((c + 1) * _cycle_weeks))
      in
      let advanced = _holding_exn (_advance ~weekly_bars ~prior:track) in
      (advanced, advanced))

(* How many steps of [_prior_level, l0, l1, l2] were strictly upward. A frozen
   stop scores zero here however faithfully the arms and [raises] advance
   around it; a stop that trails once and then sticks scores one. *)
let _strict_rises ~from levels =
  List.zip_exn (from :: List.drop_last_exn levels) levels
  |> List.count ~f:(fun (prev, next) -> Float.( > ) next prev)

let test_advance_raises_the_stop_level_on_every_cycle _ =
  assert_that
    (_strict_rises ~from:_prior_level
       (List.map (_tracks_across_cycles ()) ~f:Stop_track.level))
    (equal_to _cycles)

(* And the ratchet history the report prints agrees with the level: one raise
   per cycle, so [label]'s "N raises" is not counting something else. *)
let test_advance_records_one_raise_per_cycle _ =
  assert_that
    (List.last_exn (_tracks_across_cycles ()))
    (field (fun (t : Stop_track.t) -> t.raises) (equal_to _cycles))

let suite =
  "stop_thread"
  >::: [
         "seed_places_stop_below_the_correction_low"
         >:: test_seed_places_stop_below_the_correction_low;
         "seed_ratchets_to_a_higher_working_stop"
         >:: test_seed_ratchets_to_a_higher_working_stop;
         "seed_ignores_a_lower_working_stop"
         >:: test_seed_ignores_a_lower_working_stop;
         "seed_falls_back_without_a_qualifying_correction"
         >:: test_seed_falls_back_without_a_qualifying_correction;
         "seed_starts_the_ratchet_history_at_zero"
         >:: test_seed_starts_the_ratchet_history_at_zero;
         "advance_is_idempotent" >:: test_advance_is_idempotent;
         "advance_with_no_bars_returns_the_prior_track"
         >:: test_advance_with_no_bars_returns_the_prior_track;
         "advance_moves_updated_to_the_last_week"
         >:: test_advance_moves_updated_to_the_last_week;
         "advance_transitions_initial_to_trailing"
         >:: test_advance_transitions_initial_to_trailing;
         "advance_triggers_on_a_weekly_close_below_the_stop"
         >:: test_advance_triggers_on_a_weekly_close_below_the_stop;
         "advance_ignores_an_intra_week_wick_below_the_stop"
         >:: test_advance_ignores_an_intra_week_wick_below_the_stop;
         "advance_stops_replaying_at_the_trigger"
         >:: test_advance_stops_replaying_at_the_trigger;
         "advance_counts_a_completed_correction_cycle"
         >:: test_advance_counts_a_completed_correction_cycle;
         "advance_never_lowers_the_stop" >:: test_advance_never_lowers_the_stop;
         "advance_raises_the_stop_level_on_every_cycle"
         >:: test_advance_raises_the_stop_level_on_every_cycle;
         "advance_records_one_raise_per_cycle"
         >:: test_advance_records_one_raise_per_cycle;
       ]

let () = run_test_tt_main suite
