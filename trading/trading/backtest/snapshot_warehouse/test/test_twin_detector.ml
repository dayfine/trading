open Core
open OUnit2
open Matchers

(* Small thresholds so the tiny fixtures below qualify as twins:
   >= 5 overlapping days, > 95% near-identical closes. Default [Levels] basis. *)
let test_config =
  {
    Twin_detector.Config.enabled = true;
    min_overlap_days = 5;
    match_fraction = 0.95;
    close_epsilon = 1e-4;
    basis = Twin_detector.Config.Levels;
    ret_epsilon = 1e-3;
    prefilter_rel_tol = 2e-2;
  }

(* Same thresholds under the returns basis. *)
let returns_config =
  { test_config with basis = Twin_detector.Config.Returns; ret_epsilon = 1e-3 }

let start = Date.of_string "2020-01-01"

(* Build a series whose i-th close sits on [start + i] days. *)
let series_of ~symbol closes =
  let dated = List.mapi closes ~f:(fun i c -> (Date.add_days start i, c)) in
  let data_end, _ = List.last_exn dated in
  { Twin_detector.symbol; data_end; closes = Array.of_list dated }

(* A truncated copy sharing the first [n] closes of [closes]. *)
let truncate_series ~symbol ~n closes = series_of ~symbol (List.take closes n)

(* A series whose i-th close sits on [start + offset + i] days — used to build
   a twin whose shared window does not begin at date index 0. *)
let series_from ~symbol ~offset closes =
  let dated =
    List.mapi closes ~f:(fun i c -> (Date.add_days start (offset + i), c))
  in
  let data_end, _ = List.last_exn dated in
  { Twin_detector.symbol; data_end; closes = Array.of_list dated }

let ramp ~n ~base = List.init n ~f:(fun i -> base +. Float.of_int i)
let group_survivor (g : Twin_detector.group) = g.survivor
let group_dropped (g : Twin_detector.group) = g.dropped

(* (a) True twin pair: identical overlapping closes, [IONS] ends later, so it
   survives and the earlier-ending [ISIS] is dropped. *)
let test_true_twin_pair _ =
  let closes = ramp ~n:20 ~base:100.0 in
  let ions = series_of ~symbol:"IONS" closes in
  let isis = truncate_series ~symbol:"ISIS" ~n:15 closes in
  let report = Twin_detector.detect test_config [ isis; ions ] in
  assert_that report.groups
    (elements_are
       [
         all_of
           [
             field group_survivor (equal_to "IONS");
             field group_dropped (equal_to [ "ISIS" ]);
           ];
       ]);
  assert_that report.dropped_symbols (equal_to [ "ISIS" ]);
  assert_that
    (Twin_detector.survivors report ~all_symbols:[ "ISIS"; "IONS" ])
    (equal_to [ "IONS" ])

(* (b) Near-miss / brief-coincidence: two series that touch the same price on a
   couple of days but diverge across the full window are NOT twins — both kept.
   Guards against the V6 BALL/TAP-style false positive. *)
let test_brief_coincidence_not_twin _ =
  let ball = series_of ~symbol:"BALL" (ramp ~n:20 ~base:50.0) in
  (* Starts at the same 50.0 for two days, then diverges steeply. *)
  let tap =
    series_of ~symbol:"TAP"
      (List.init 20 ~f:(fun i ->
           if i < 2 then 50.0 +. Float.of_int i else 200.0 +. Float.of_int i))
  in
  let report = Twin_detector.detect test_config [ ball; tap ] in
  assert_that report.groups is_empty;
  assert_that report.dropped_symbols is_empty;
  assert_that
    (Twin_detector.survivors report ~all_symbols:[ "BALL"; "TAP" ])
    (equal_to [ "BALL"; "TAP" ])

(* (c) Triple group (JW-A / JWA / WLY): all three share one series; the
   latest-ending leg survives, the other two are dropped together. *)
let test_triple_group _ =
  let closes = ramp ~n:30 ~base:80.0 in
  let wly = series_of ~symbol:"WLY" closes in
  let jwa = truncate_series ~symbol:"JWA" ~n:20 closes in
  let jw_a = truncate_series ~symbol:"JW-A" ~n:12 closes in
  let report = Twin_detector.detect test_config [ jw_a; jwa; wly ] in
  assert_that report.groups
    (elements_are
       [
         all_of
           [
             field group_survivor (equal_to "WLY");
             field group_dropped (equal_to [ "JW-A"; "JWA" ]);
           ];
       ]);
  assert_that report.dropped_symbols (equal_to [ "JW-A"; "JWA" ])

(* [_old]-suffix legs are ordinary symbols and, ending earlier, drop out. *)
let test_old_suffix_leg_dropped _ =
  let closes = ramp ~n:25 ~base:30.0 in
  let cor = series_of ~symbol:"COR" closes in
  let cor_old = truncate_series ~symbol:"COR_old" ~n:15 closes in
  let report = Twin_detector.detect test_config [ cor; cor_old ] in
  assert_that report.groups
    (elements_are
       [
         all_of
           [
             field group_survivor (equal_to "COR");
             field group_dropped (equal_to [ "COR_old" ]);
           ];
       ])

(* (d) Flag-off passthrough: a disabled config detects nothing and drops
   nothing, even on an obvious twin pair — bit-identical symbol set. *)
let test_disabled_passthrough _ =
  let closes = ramp ~n:20 ~base:100.0 in
  let ions = series_of ~symbol:"IONS" closes in
  let isis = truncate_series ~symbol:"ISIS" ~n:15 closes in
  let report =
    Twin_detector.detect { test_config with enabled = false } [ isis; ions ]
  in
  assert_that report.groups is_empty;
  assert_that report.dropped_symbols is_empty;
  assert_that
    (Twin_detector.survivors report ~all_symbols:[ "ISIS"; "IONS" ])
    (equal_to [ "ISIS"; "IONS" ])

(* Overlap shorter than [min_overlap_days] is not a twin even when identical. *)
let test_below_min_overlap_not_twin _ =
  let closes = ramp ~n:20 ~base:100.0 in
  let long = series_of ~symbol:"LONG" closes in
  (* Only 3 shared days (< min_overlap_days = 5). *)
  let short = truncate_series ~symbol:"SHORT" ~n:3 closes in
  let report = Twin_detector.detect test_config [ long; short ] in
  assert_that report.groups is_empty

(* The match-fraction reported for a detected group is measured vs the
   survivor and reflects the near-identical overlap. *)
let test_reported_match_fraction _ =
  let closes = ramp ~n:20 ~base:100.0 in
  let ions = series_of ~symbol:"IONS" closes in
  let isis = truncate_series ~symbol:"ISIS" ~n:15 closes in
  let report = Twin_detector.detect test_config [ isis; ions ] in
  assert_that report.groups
    (elements_are
       [
         field
           (fun (g : Twin_detector.group) ->
             List.map g.matches ~f:(fun m -> m.match_fraction))
           (elements_are [ float_equal 1.0 ]);
       ])

(* Tie-break: two twin legs with an IDENTICAL data_end (same full window).
   With no later-ending leg, the survivor is the lexicographically smallest
   symbol ([BFX] < [NLS]); the other is dropped. *)
let test_identical_data_end_tiebreak _ =
  let closes = ramp ~n:20 ~base:60.0 in
  let nls = series_of ~symbol:"NLS" closes in
  let bfx = series_of ~symbol:"BFX" closes in
  let report = Twin_detector.detect test_config [ nls; bfx ] in
  assert_that report.groups
    (elements_are
       [
         all_of
           [
             field group_survivor (equal_to "BFX");
             field group_dropped (equal_to [ "NLS" ]);
           ];
       ]);
  assert_that report.dropped_symbols (equal_to [ "NLS" ])

(* Prefilter completeness on an offset shared window: the dropped leg [OLD]
   starts at day 7 (> stride = min_overlap_days/2 = 2, and 7 is not a multiple
   of the stride), sharing days 7..26 with [NEW]. The twin must still be
   detected — i.e. it is not filtered out before the full compare. *)
let test_offset_window_detected _ =
  let new_closes = ramp ~n:30 ~base:80.0 in
  let newco = series_of ~symbol:"NEW" new_closes in
  (* Closes matching [NEW] on days 7..26 exactly. *)
  let old_closes = List.init 20 ~f:(fun i -> 80.0 +. Float.of_int (7 + i)) in
  let oldco = series_from ~symbol:"OLD" ~offset:7 old_closes in
  let report = Twin_detector.detect test_config [ newco; oldco ] in
  assert_that report.groups
    (elements_are
       [
         all_of
           [
             field group_survivor (equal_to "NEW");
             field group_dropped (equal_to [ "OLD" ]);
           ];
       ])

(* A scaled copy: leg B closes are leg A's closes times [factor]. Different
   adjustment basis → levels diverge by a constant ratio, returns are identical. *)
let scaled_series ~symbol ~factor closes =
  series_of ~symbol (List.map closes ~f:(fun c -> c *. factor))

(* (a) Scaled twin — leg [SML] is leg [BIG] * 0.78 (a constant adjustment-basis
   ratio). Levels diverge (0.78 gap on every day) so [Levels] misses it; the
   daily returns are identical so [Returns] catches it. [BIG] < [SML]
   lexicographically and both share every date, so [BIG] survives. *)
let test_scaled_twin_returns _ =
  let closes = ramp ~n:20 ~base:100.0 in
  let big = series_of ~symbol:"BIG" closes in
  let small = scaled_series ~symbol:"SML" ~factor:0.78 closes in
  let report = Twin_detector.detect returns_config [ big; small ] in
  assert_that report.groups
    (elements_are
       [
         all_of
           [
             field group_survivor (equal_to "BIG");
             field group_dropped (equal_to [ "SML" ]);
           ];
       ]);
  assert_that report.dropped_symbols (equal_to [ "SML" ])

(* (d) The same scaled pair under [Levels] is NOT a twin — the constant 0.78
   gap exceeds [close_epsilon] on every day. Confirms the levels basis is
   scale-sensitive (v1 behaviour, unchanged). *)
let test_scaled_twin_missed_by_levels _ =
  let closes = ramp ~n:20 ~base:100.0 in
  let big = series_of ~symbol:"BIG" closes in
  let small = scaled_series ~symbol:"SML" ~factor:0.78 closes in
  let report = Twin_detector.detect test_config [ big; small ] in
  assert_that report.groups is_empty;
  assert_that report.dropped_symbols is_empty

(* (b) Drifting-ratio twin — [OLDCO] equals [NEWCO] for the first 20 shared days
   then carries an extra 2:1 adjustment (halved) for the next 20. Returns match
   on every consecutive pair except the single boundary day (38/39 = 0.974 >
   0.95), so [Returns] catches it; levels match only half the window so [Levels]
   misses it. [NEWCO] ends 2 days later, so it survives. *)
let drifting_closes ~n ~split ~base =
  List.init n ~f:(fun i ->
      let c = base +. Float.of_int i in
      if i < split then c else c *. 0.5)

let test_drifting_ratio_twin_returns _ =
  let newco = series_of ~symbol:"NEWCO" (ramp ~n:42 ~base:100.0) in
  let oldco =
    series_of ~symbol:"OLDCO" (drifting_closes ~n:40 ~split:20 ~base:100.0)
  in
  let report = Twin_detector.detect returns_config [ newco; oldco ] in
  assert_that report.groups
    (elements_are
       [
         all_of
           [
             field group_survivor (equal_to "NEWCO");
             field group_dropped (equal_to [ "OLDCO" ]);
             field
               (fun (g : Twin_detector.group) ->
                 List.map g.matches ~f:(fun m -> m.match_fraction))
               (* Exactly 38/39: the split-boundary day is a genuine return
                  MISMATCH that the fraction must count — an all-match 1.0
                  would mean the boundary was silently absorbed. *)
               (elements_are [ float_equal (38.0 /. 39.0) ]);
           ];
       ])

(* The same drifting-ratio pair matches only half the shared days on levels,
   so [Levels] does not call it a twin. *)
let test_drifting_ratio_missed_by_levels _ =
  let newco = series_of ~symbol:"NEWCO" (ramp ~n:42 ~base:100.0) in
  let oldco =
    series_of ~symbol:"OLDCO" (drifting_closes ~n:40 ~split:20 ~base:100.0)
  in
  let report = Twin_detector.detect test_config [ newco; oldco ] in
  assert_that report.groups is_empty

(* Corrupt-bar guard — a zero close mid-series (real warehouses carry such
   rows; MSZ precedent). The pair whose PRIOR close is the zero is skipped
   rather than counted as a mismatch, so an otherwise-identical twin still
   reports a full match fraction over the valid pairs. Pins the
   [_returns_match_fraction] prior-close <= 0 guard. *)
let test_zero_close_pair_skipped_not_diluted _ =
  let closes =
    List.init 30 ~f:(fun i -> if i = 15 then 0.0 else 100.0 +. Float.of_int i)
  in
  let newco = series_of ~symbol:"NEWCO" closes in
  let oldco = truncate_series ~symbol:"OLDCO" ~n:28 closes in
  let report = Twin_detector.detect returns_config [ newco; oldco ] in
  assert_that report.groups
    (elements_are
       [
         all_of
           [
             field group_survivor (equal_to "NEWCO");
             field group_dropped (equal_to [ "OLDCO" ]);
             field
               (fun (g : Twin_detector.group) ->
                 List.map g.matches ~f:(fun m -> m.match_fraction))
               (elements_are [ float_equal 1.0 ]);
           ];
       ])

(* (c) Different-instruments control — two series that start at the same price
   but follow independent return paths ([UP] arithmetic +1/day, [GEO] geometric
   +2%/day). Returns differ on every day, so [Returns] does NOT call them
   twins. Guards against the returns basis over-matching same-priced names. *)
let test_independent_returns_not_twin _ =
  let up = series_of ~symbol:"UP" (ramp ~n:30 ~base:100.0) in
  let geo =
    series_of ~symbol:"GEO"
      (List.init 30 ~f:(fun i -> 100.0 *. (1.02 ** Float.of_int i)))
  in
  let report = Twin_detector.detect returns_config [ up; geo ] in
  assert_that report.groups is_empty;
  assert_that report.dropped_symbols is_empty;
  assert_that
    (Twin_detector.survivors report ~all_symbols:[ "UP"; "GEO" ])
    (equal_to [ "UP"; "GEO" ])

(* (e) Tie-break re-holds under [Returns]: two identical full-window legs have
   identical returns; with no later-ending leg the survivor is the smaller
   symbol ([BFX] < [NLS]). *)
let test_identical_data_end_tiebreak_returns _ =
  let closes = ramp ~n:20 ~base:60.0 in
  let nls = series_of ~symbol:"NLS" closes in
  let bfx = series_of ~symbol:"BFX" closes in
  let report = Twin_detector.detect returns_config [ nls; bfx ] in
  assert_that report.groups
    (elements_are
       [
         all_of
           [
             field group_survivor (equal_to "BFX");
             field group_dropped (equal_to [ "NLS" ]);
           ];
       ])

(* (e) Offset-window prefilter re-holds under [Returns]: [OLD] starts at day 7
   (its first bar has no prior return and is skipped by the prefilter) but its
   interior returns match [NEW] on days 8..26, so the twin is still detected. *)
let test_offset_window_detected_returns _ =
  let newco = series_of ~symbol:"NEW" (ramp ~n:30 ~base:80.0) in
  let old_closes = List.init 20 ~f:(fun i -> 80.0 +. Float.of_int (7 + i)) in
  let oldco = series_from ~symbol:"OLD" ~offset:7 old_closes in
  let report = Twin_detector.detect returns_config [ newco; oldco ] in
  assert_that report.groups
    (elements_are
       [
         all_of
           [
             field group_survivor (equal_to "NEW");
             field group_dropped (equal_to [ "OLD" ]);
           ];
       ])

let suite =
  "twin_detector"
  >::: [
         "true_twin_pair" >:: test_true_twin_pair;
         "brief_coincidence_not_twin" >:: test_brief_coincidence_not_twin;
         "triple_group" >:: test_triple_group;
         "old_suffix_leg_dropped" >:: test_old_suffix_leg_dropped;
         "disabled_passthrough" >:: test_disabled_passthrough;
         "below_min_overlap_not_twin" >:: test_below_min_overlap_not_twin;
         "reported_match_fraction" >:: test_reported_match_fraction;
         "identical_data_end_tiebreak" >:: test_identical_data_end_tiebreak;
         "offset_window_detected" >:: test_offset_window_detected;
         "scaled_twin_returns" >:: test_scaled_twin_returns;
         "scaled_twin_missed_by_levels" >:: test_scaled_twin_missed_by_levels;
         "drifting_ratio_twin_returns" >:: test_drifting_ratio_twin_returns;
         "drifting_ratio_missed_by_levels"
         >:: test_drifting_ratio_missed_by_levels;
         "zero_close_pair_skipped_not_diluted"
         >:: test_zero_close_pair_skipped_not_diluted;
         "independent_returns_not_twin" >:: test_independent_returns_not_twin;
         "identical_data_end_tiebreak_returns"
         >:: test_identical_data_end_tiebreak_returns;
         "offset_window_detected_returns"
         >:: test_offset_window_detected_returns;
       ]

let () = run_test_tt_main suite
