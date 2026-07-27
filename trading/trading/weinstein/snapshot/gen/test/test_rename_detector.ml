(** Tests for {!Rename_detector} — live ticker-rename (succession) detection
    from price series alone (issue #2083 Finding 2).

    Every fixture is built from ONE underlying 200-weekday price path [_path],
    sampled at explicitly chosen bar indices. Sampling from a shared path is
    what lets a test say "same company, different ticker" (sample the same path,
    optionally on a different adjustment basis) versus "different company"
    (sample a perturbed path whose {e levels} stay close but whose {e returns}
    diverge) without any randomness. *)

open Core
open OUnit2
open Matchers
module Detector = Weinstein_snapshot_gen.Rename_detector

(* ------------------------------------------------------------------ *)
(* Calendar + price path                                              *)
(* ------------------------------------------------------------------ *)

let _bars_total = 200

(* Index of the changeover: the successor's first bar. 178 leaves 22 trading
   days of overlap, matching the incident (rename 2026-06-16, report
   2026-07-17). *)
let _changeover_idx = 178

let _next_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Fri -> Date.add_days d 3
  | Day_of_week.Sat -> Date.add_days d 2
  | _ -> Date.add_days d 1

(* [_bars_total] consecutive weekdays starting 2026-01-05 (a Monday). *)
let _calendar =
  let rec loop d acc n =
    if n <= 0 then Array.of_list (List.rev acc)
    else loop (_next_weekday d) (d :: acc) (n - 1)
  in
  loop (Date.create_exn ~y:2026 ~m:Month.Jan ~d:5) [] _bars_total

let _date i = _calendar.(i)
let _as_of = _calendar.(_bars_total - 1)

(* A deterministic, non-degenerate price path: compounding sinusoidal returns.
   No randomness, so every assertion below is reproducible. *)
let _path =
  let closes = Array.create ~len:_bars_total 100.0 in
  for i = 1 to _bars_total - 1 do
    let r = 0.02 *. Float.sin (Float.of_int (i * 7)) in
    closes.(i) <- closes.(i - 1) *. (1.0 +. r)
  done;
  closes

(* Levels within ~2% of [_path] but with materially different day-to-day moves
   — a genuinely different company that happens to trade near the same price. *)
let _lookalike_path =
  Array.mapi _path ~f:(fun i p ->
      p *. (1.0 +. (0.02 *. Float.sin (Float.of_int (i * 3)))))

let _series ~symbol ~path indices : Detector.series =
  {
    symbol;
    closes = Array.of_list_map indices ~f:(fun i -> (_date i, path.(i) *. 1.0));
  }

(* Same company on a different split/dividend adjustment basis: the LEVELS are
   37% apart, the RETURNS are identical. Detection must survive this — it is
   why the detector scores returns rather than levels. *)
let _rebased ~symbol indices : Detector.series =
  {
    symbol;
    closes =
      Array.of_list_map indices ~f:(fun i -> (_date i, _path.(i) *. 1.37));
  }

let _range lo hi = List.range lo (hi + 1)

(* ------------------------------------------------------------------ *)
(* Fixtures                                                            *)
(* ------------------------------------------------------------------ *)

(* Predecessor: dense from day 0 to the changeover, then a zombie tail of 6
   scattered prints (indices 179/183/187/191/195/199) — the SNSE shape. *)
let _zombie_indices = [ 179; 183; 187; 191; 195; 199 ]
let _predecessor_indices = _range 0 (_changeover_idx - 1) @ _zombie_indices
let _successor_indices = _range _changeover_idx (_bars_total - 1)
let _old_series = _series ~symbol:"OLDCO" ~path:_path _predecessor_indices
let _new_series = _rebased ~symbol:"NEWCO" _successor_indices

(* Different company, similar price levels, same succession-shaped timing. *)
let _lookalike_series =
  _series ~symbol:"OTHERCO" ~path:_lookalike_path _successor_indices

(* A CONCURRENT twin — the thing {!Twin_detector} reports and this module must
   not. [TWINB] starts late enough to satisfy every succession test except the
   handover: both legs stay dense through [as_of]. *)
let _twin_start_idx = 100
let _twin_a = _series ~symbol:"TWINA" ~path:_path (_range 0 (_bars_total - 1))

let _twin_b =
  _rebased ~symbol:"TWINB" (_range _twin_start_idx (_bars_total - 1))

(* A dense, unrelated series spanning the whole calendar. Used where a fixture's
   own legs are too sparse to establish the trading calendar on their own. *)
let _market =
  _series ~symbol:"MARKET" ~path:_lookalike_path (_range 0 (_bars_total - 1))

(* A predecessor with too little history behind the changeover. *)
let _shallow_series =
  _series ~symbol:"SHALLOW" ~path:_path
    (_range 150 (_changeover_idx - 1) @ _zombie_indices)

(* --- Successor ranking (highest match fraction wins) --------------- *)

(* The main fixture's overlap is 6 dates -> 5 return pairs, so under a 0.95
   threshold the ONLY admissible score is a perfect 1.0 and two successors can
   never differ. This predecessor stays dense for 7 bars past the changeover
   before going zombie, giving an 11-date overlap (10 return pairs) so that
   intermediate scores exist; [_ranked] lowers the threshold to admit one. *)
let _ranked_predecessor_indices =
  _range 0 (_changeover_idx - 1)
  @ _range _changeover_idx (_changeover_idx + 6)
  @ [ 187; 191; 195; 199 ]

let _ranked_predecessor =
  _series ~symbol:"PRED" ~path:_path _ranked_predecessor_indices

(* Interior overlap bar to displace. Both its neighbours are shared dates, so
   moving it breaks exactly the two return pairs that touch it. *)
let _nicked_idx = _changeover_idx + 2

(* [_rebased] with that one bar moved 5% — far beyond [ret_epsilon] — so 8 of
   the 10 overlap return pairs still match: a match fraction of 0.8. *)
let _nicked ~symbol indices : Detector.series =
  {
    symbol;
    closes =
      Array.of_list_map indices ~f:(fun i ->
          let nick = if i = _nicked_idx then 1.05 else 1.0 in
          (_date i, _path.(i) *. 1.37 *. nick));
  }

let _weaker_successor = _nicked ~symbol:"ALPHACO" _successor_indices
let _stronger_successor = _rebased ~symbol:"ZETACO" _successor_indices

(* --- [as_of] truncation ------------------------------------------- *)

(* A second succession, complete well before the end of the calendar, so the
   legs can be extended PAST the as-of date. Same shape as the main fixture:
   dense predecessor, changeover, zombie tail, dense successor. *)
let _trunc_changeover_idx = 128
let _trunc_as_of_idx = 149
let _trunc_as_of = _date _trunc_as_of_idx
let _trunc_zombie_indices = [ 128; 132; 136; 140; 144; 148 ]

let _trunc_old_indices =
  _range 0 (_trunc_changeover_idx - 1) @ _trunc_zombie_indices

let _trunc_old = _series ~symbol:"TRUNCOLD" ~path:_path _trunc_old_indices

let _trunc_new =
  _rebased ~symbol:"TRUNCNEW" (_range _trunc_changeover_idx _trunc_as_of_idx)

(* The same two legs, each continuing densely past [_trunc_as_of]. The
   predecessor's continuation is what makes the truncation load-bearing: read
   whole, it is dense right through the final session and stops being the
   stale leg at all. *)
let _future_indices = _range (_trunc_as_of_idx + 1) (_bars_total - 1)

let _trunc_old_extended =
  _series ~symbol:"TRUNCOLD" ~path:_path (_trunc_old_indices @ _future_indices)

let _trunc_new_extended =
  _rebased ~symbol:"TRUNCNEW" (_range _trunc_changeover_idx (_bars_total - 1))

let _armed = Detector.Config.armed ~min_overlap_days:5 ~match_fraction:0.95

(* Admits a partially-matching successor, which the 0.95 default cannot. *)
let _ranked = Detector.Config.armed ~min_overlap_days:5 ~match_fraction:0.5

let _detect ?(config = _armed) series =
  Detector.detect config ~as_of:_as_of series

(* ------------------------------------------------------------------ *)
(* 1. True positive                                                    *)
(* ------------------------------------------------------------------ *)

(* The SNSE -> FTH shape is detected, in the right DIRECTION, with the evidence
   that justified it: changeover date, overlap length, returns score, and the
   tail-bar counts on each side. *)
let test_detects_snse_shaped_succession _ =
  let report = _detect [ _old_series; _new_series ] in
  assert_that report.renames
    (elements_are
       [
         all_of
           [
             field
               (fun (r : Detector.rename) -> r.old_symbol)
               (equal_to "OLDCO");
             field
               (fun (r : Detector.rename) -> r.new_symbol)
               (equal_to "NEWCO");
             field
               (fun (r : Detector.rename) -> r.changeover)
               (equal_to (_date _changeover_idx));
             field (fun (r : Detector.rename) -> r.overlap_days) (equal_to 6);
             field
               (fun (r : Detector.rename) -> r.match_fraction)
               (float_equal 1.0);
             field (fun (r : Detector.rename) -> r.old_tail_bars) (equal_to 4);
             field (fun (r : Detector.rename) -> r.new_tail_bars) (equal_to 15);
             field
               (fun (r : Detector.rename) -> r.tail_window_trading_days)
               (equal_to 15);
           ];
       ])

(* Order of the input list must not change the verdict (purity / determinism). *)
let test_detection_is_input_order_independent _ =
  let forward = _detect [ _old_series; _new_series ] in
  let reversed = _detect [ _new_series; _old_series ] in
  assert_that reversed.renames
    (elements_are
       (List.map forward.renames ~f:(fun r ->
            equal_to ~cmp:Detector.equal_rename r)))

(* ------------------------------------------------------------------ *)
(* 2. True negative — similar LEVELS, different RETURNS                *)
(* ------------------------------------------------------------------ *)

(* Two different companies whose prices happen to sit within ~2% of each other
   over the whole overlap, with the exact same succession-shaped timing. Only
   the returns basis separates them; a levels comparison would call these a
   match. *)
let test_level_lookalike_is_not_a_rename _ =
  let report = _detect [ _old_series; _lookalike_series ] in
  assert_that report.renames (elements_are [])

(* The premise of the test above: the two series really are level-similar, so
   its negative verdict is about returns and not about prices being far apart. *)
let test_lookalike_levels_really_are_close _ =
  let max_gap =
    List.fold _zombie_indices ~init:0.0 ~f:(fun acc i ->
        Float.max acc (Float.abs (_lookalike_path.(i) -. _path.(i)) /. _path.(i)))
  in
  assert_that max_gap (le (module Float_ord) 0.02)

(* ------------------------------------------------------------------ *)
(* 3. Near-miss negative — a CONCURRENT twin is not a succession       *)
(* ------------------------------------------------------------------ *)

(* [TWINA]/[TWINB] pass every other test: TWINB is younger, they overlap for
   100 days, TWINA has 100 bars of prior history, and their returns match
   exactly. The ONLY thing that rejects them is the handover — both legs stay
   dense through [as_of]. This is the line between this module and
   {!Twin_detector}. *)
let test_concurrent_twin_is_not_a_rename _ =
  let report = _detect [ _twin_a; _twin_b ] in
  assert_that report.renames (elements_are [])

(* ...and the near-miss really is a near-miss: the same pair, once the older leg
   is thinned to a zombie tail, IS reported. Without this the test above could
   pass for the wrong reason (e.g. the returns never matched at all). *)
let test_same_pair_with_a_zombie_tail_is_a_rename _ =
  let thinned =
    _series ~symbol:"TWINA" ~path:_path
      (_range 0 (_bars_total - 30) @ _zombie_indices)
  in
  let report = _detect [ thinned; _twin_b ] in
  assert_that report.renames
    (elements_are
       [
         all_of
           [
             field
               (fun (r : Detector.rename) -> r.old_symbol)
               (equal_to "TWINA");
             field
               (fun (r : Detector.rename) -> r.new_symbol)
               (equal_to "TWINB");
           ];
       ])

(* The mirror image of the near-miss: a younger leg that is ITSELF sparse is not
   a successor. [GHOST] samples only the zombie dates, so it matches [OLDCO]'s
   returns exactly and clears every other test — only the successor-density half
   of the handover rejects it. A ticker that is barely trading is not something
   to hand a trader in place of the dropped pick.

   [_market] is present only to supply the trading calendar: the detector reads
   the calendar off the union of its inputs, and two sparse legs alone do not
   span one. It is never itself a candidate (it starts on day 0, so it is not
   the younger leg, and its returns differ). *)
let test_sparse_successor_is_rejected _ =
  let ghost = _rebased ~symbol:"GHOST" _zombie_indices in
  let report = _detect [ _market; _old_series; ghost ] in
  assert_that report.renames (elements_are [])

(* ------------------------------------------------------------------ *)
(* 4. Default-off                                                      *)
(* ------------------------------------------------------------------ *)

let test_default_config_is_disabled _ =
  assert_that Detector.Config.default.enabled (equal_to false)

let test_default_config_detects_nothing _ =
  let report =
    Detector.detect Detector.Config.default ~as_of:_as_of
      [ _old_series; _new_series ]
  in
  assert_that report.renames (elements_are [])

(* Both strategy-config knobs are at their disabling value (0 / 0.0) by default;
   either one alone must not arm the detector. *)
let test_armed_requires_both_knobs _ =
  let enabled ~min_overlap_days ~match_fraction =
    (Detector.Config.armed ~min_overlap_days ~match_fraction).enabled
  in
  assert_that
    [
      enabled ~min_overlap_days:0 ~match_fraction:0.0;
      enabled ~min_overlap_days:5 ~match_fraction:0.0;
      enabled ~min_overlap_days:0 ~match_fraction:0.95;
      enabled ~min_overlap_days:5 ~match_fraction:0.95;
    ]
    (elements_are
       [ equal_to false; equal_to false; equal_to false; equal_to true ])

(* An overlap requirement below 2 carries no returns evidence, so it disables
   detection rather than admitting everything. *)
let test_overlap_below_two_disables_detection _ =
  let config = Detector.Config.armed ~min_overlap_days:1 ~match_fraction:0.95 in
  let report = _detect ~config [ _old_series; _new_series ] in
  assert_that report.renames (elements_are [])

let test_empty_input_yields_empty_report _ =
  let report = _detect [] in
  assert_that report.renames (elements_are [])

(* ------------------------------------------------------------------ *)
(* 5. Both sides of the seam                                           *)
(* ------------------------------------------------------------------ *)

(* [survivors] must do BOTH halves: drop the predecessor AND keep the successor.
   Asserting the exact resulting list pins both, plus the untouched neighbours
   and the input order. *)
let test_survivors_drop_predecessor_and_keep_successor _ =
  let report = _detect [ _old_series; _new_series ] in
  assert_that
    (Detector.survivors report
       ~all_symbols:[ "AAA"; "OLDCO"; "BBB"; "NEWCO"; "CCC" ])
    (elements_are
       [ equal_to "AAA"; equal_to "BBB"; equal_to "NEWCO"; equal_to "CCC" ])

let test_survivors_passthrough_when_disabled _ =
  let report =
    Detector.detect Detector.Config.default ~as_of:_as_of
      [ _old_series; _new_series ]
  in
  assert_that
    (Detector.survivors report ~all_symbols:[ "OLDCO"; "NEWCO" ])
    (elements_are [ equal_to "OLDCO"; equal_to "NEWCO" ])

let test_mapping_is_old_to_new _ =
  let report = _detect [ _old_series; _new_series ] in
  assert_that (Detector.mapping report)
    (elements_are [ equal_to ("OLDCO", "NEWCO") ])

(* The warning must name BOTH tickers — the dropped one so the disappearance is
   explained, and the successor so the trader knows what to look at instead. *)
let test_warning_names_both_tickers _ =
  let report = _detect [ _old_series; _new_series ] in
  assert_that (Detector.warnings report)
    (elements_are
       [
         matching ~msg:"warning naming OLDCO, NEWCO and the changeover date"
           (fun msg ->
             if
               String.is_substring msg ~substring:"OLDCO"
               && String.is_substring msg ~substring:"NEWCO"
               && String.is_substring msg
                    ~substring:(Date.to_string (_date _changeover_idx))
             then Some ()
             else None)
           (equal_to ());
       ])

let test_warnings_empty_when_disabled _ =
  let report =
    Detector.detect Detector.Config.default ~as_of:_as_of
      [ _old_series; _new_series ]
  in
  assert_that (Detector.warnings report) (elements_are [])

let test_render_lists_the_succession _ =
  let report = _detect [ _old_series; _new_series ] in
  assert_that (Detector.render report)
    (matching ~msg:"render mentions both tickers and the count"
       (fun s ->
         if
           String.is_substring s ~substring:"OLDCO -> NEWCO"
           && String.is_substring s ~substring:"1 succession(s)"
         then Some ()
         else None)
       (equal_to ()))

(* ------------------------------------------------------------------ *)
(* Threshold guards                                                    *)
(* ------------------------------------------------------------------ *)

(* The zombie tail yields only 6 shared dates; requiring 10 rejects it. *)
let test_overlap_threshold_rejects_short_overlap _ =
  let config =
    Detector.Config.armed ~min_overlap_days:10 ~match_fraction:0.95
  in
  let report = _detect ~config [ _old_series; _new_series ] in
  assert_that report.renames (elements_are [])

(* A ticker with only 28 bars behind the changeover is not a renamed company. *)
let test_shallow_predecessor_is_rejected _ =
  let report = _detect [ _shallow_series; _new_series ] in
  assert_that report.renames (elements_are [])

(* The successor must be the YOUNGER leg. [EARLY] spans the whole calendar and
   [LATE] starts on day 100, so calling [LATE] a rename of [EARLY] would invert
   the succession. Everything else lines up — same path, 76 shared dates, exact
   returns match, and [min_predecessor_bars] relaxed to 0 so only the
   first-bar-ordering test can reject the pair. *)
let test_successor_must_be_younger _ =
  let config = { _armed with min_predecessor_bars = 0 } in
  let late =
    _series ~symbol:"LATE" ~path:_path (_range 100 169 @ _zombie_indices)
  in
  let early = _rebased ~symbol:"EARLY" (_range 0 (_bars_total - 1)) in
  let report = _detect ~config [ late; early ] in
  assert_that report.renames (elements_are [])

(* One predecessor, two equally-good successors: the mapping must stay a
   function, and the tie must break deterministically on the smaller successor
   symbol. Pins the EQUAL-fraction arm of the ranking only — see below for the
   ordering arm. *)
let test_one_entry_per_predecessor _ =
  let alt = _rebased ~symbol:"ALTCO" _successor_indices in
  let report = _detect [ _old_series; _new_series; alt ] in
  assert_that (Detector.mapping report)
    (elements_are [ equal_to ("OLDCO", "ALTCO") ])

(* The ORDERING arm: two qualifying successors with DIFFERENT match fractions,
   arranged so the two arms of the ranking disagree — [ZETACO] scores 1.0 and
   [ALPHACO] 0.8, but [ALPHACO] is the lexicographically smaller symbol. Only
   "highest fraction wins" yields [ZETACO]; both "lowest wins" and a
   tie-break-only rule yield [ALPHACO]. *)
let test_highest_match_fraction_wins _ =
  let report =
    _detect ~config:_ranked
      [ _ranked_predecessor; _weaker_successor; _stronger_successor ]
  in
  assert_that report.renames
    (elements_are
       [
         all_of
           [
             field (fun (r : Detector.rename) -> r.old_symbol) (equal_to "PRED");
             field
               (fun (r : Detector.rename) -> r.new_symbol)
               (equal_to "ZETACO");
             field
               (fun (r : Detector.rename) -> r.match_fraction)
               (float_equal 1.0);
           ];
       ])

(* The premise of the test above: the loser genuinely qualifies on its own, at
   the lower score. Without this, the ranking test could pass because
   [ALPHACO] was never a candidate at all. *)
let test_weaker_successor_qualifies_on_its_own _ =
  let report =
    _detect ~config:_ranked [ _ranked_predecessor; _weaker_successor ]
  in
  assert_that report.renames
    (elements_are
       [
         all_of
           [
             field
               (fun (r : Detector.rename) -> r.new_symbol)
               (equal_to "ALPHACO");
             field (fun (r : Detector.rename) -> r.overlap_days) (equal_to 11);
             field
               (fun (r : Detector.rename) -> r.match_fraction)
               (float_equal 0.8);
           ];
       ])

(* ------------------------------------------------------------------ *)
(* [as_of] truncation                                                  *)
(* ------------------------------------------------------------------ *)

(* Bars dated after [as_of] must not reach ANY part of the verdict. Both legs
   here run dense to the end of the calendar, 50 trading days past [as_of]:

   - read whole, the predecessor is dense through the final session, so the
     trailing window no longer sees a zombie tail and NOTHING is reported;
   - counted whole, the overlap is 56 shared dates rather than 6.

   So the asserted record fails if the truncation is dropped from either the
   trailing-window calendar or the per-leg bar filter. *)
let test_bars_after_as_of_are_ignored _ =
  let report =
    Detector.detect _armed ~as_of:_trunc_as_of
      [ _trunc_old_extended; _trunc_new_extended ]
  in
  assert_that report.renames
    (elements_are
       [
         all_of
           [
             field
               (fun (r : Detector.rename) -> r.old_symbol)
               (equal_to "TRUNCOLD");
             field
               (fun (r : Detector.rename) -> r.new_symbol)
               (equal_to "TRUNCNEW");
             field
               (fun (r : Detector.rename) -> r.changeover)
               (equal_to (_date _trunc_changeover_idx));
             field (fun (r : Detector.rename) -> r.overlap_days) (equal_to 6);
             field
               (fun (r : Detector.rename) -> r.match_fraction)
               (float_equal 1.0);
             field (fun (r : Detector.rename) -> r.old_tail_bars) (equal_to 4);
             field (fun (r : Detector.rename) -> r.new_tail_bars) (equal_to 15);
             field
               (fun (r : Detector.rename) -> r.tail_window_trading_days)
               (equal_to 15);
           ];
       ])

(* ...and the stronger statement: feeding the extended series is INDISTINGUISH-
   ABLE from feeding series already cut at [as_of]. *)
let test_as_of_matches_pre_truncated_input _ =
  let cut =
    Detector.detect _armed ~as_of:_trunc_as_of [ _trunc_old; _trunc_new ]
  in
  let extended =
    Detector.detect _armed ~as_of:_trunc_as_of
      [ _trunc_old_extended; _trunc_new_extended ]
  in
  assert_that extended.renames
    (elements_are
       (List.map cut.renames ~f:(fun r -> equal_to ~cmp:Detector.equal_rename r)))

let suite =
  "rename_detector"
  >::: [
         "detects the SNSE-shaped succession"
         >:: test_detects_snse_shaped_succession;
         "detection is input-order independent"
         >:: test_detection_is_input_order_independent;
         "level lookalike is not a rename"
         >:: test_level_lookalike_is_not_a_rename;
         "lookalike levels really are close"
         >:: test_lookalike_levels_really_are_close;
         "concurrent twin is not a rename"
         >:: test_concurrent_twin_is_not_a_rename;
         "same pair with a zombie tail is a rename"
         >:: test_same_pair_with_a_zombie_tail_is_a_rename;
         "sparse successor is rejected" >:: test_sparse_successor_is_rejected;
         "default config is disabled" >:: test_default_config_is_disabled;
         "default config detects nothing"
         >:: test_default_config_detects_nothing;
         "arming requires both knobs" >:: test_armed_requires_both_knobs;
         "overlap below two disables detection"
         >:: test_overlap_below_two_disables_detection;
         "empty input yields empty report"
         >:: test_empty_input_yields_empty_report;
         "survivors drop predecessor and keep successor"
         >:: test_survivors_drop_predecessor_and_keep_successor;
         "survivors passthrough when disabled"
         >:: test_survivors_passthrough_when_disabled;
         "mapping is old -> new" >:: test_mapping_is_old_to_new;
         "warning names both tickers" >:: test_warning_names_both_tickers;
         "warnings empty when disabled" >:: test_warnings_empty_when_disabled;
         "render lists the succession" >:: test_render_lists_the_succession;
         "overlap threshold rejects a short overlap"
         >:: test_overlap_threshold_rejects_short_overlap;
         "shallow predecessor is rejected"
         >:: test_shallow_predecessor_is_rejected;
         "successor must be younger" >:: test_successor_must_be_younger;
         "one entry per predecessor" >:: test_one_entry_per_predecessor;
         "highest match fraction wins" >:: test_highest_match_fraction_wins;
         "weaker successor qualifies on its own"
         >:: test_weaker_successor_qualifies_on_its_own;
         "bars after as_of are ignored" >:: test_bars_after_as_of_are_ignored;
         "as_of result matches pre-truncated input"
         >:: test_as_of_matches_pre_truncated_input;
       ]

let () = run_test_tt_main suite
