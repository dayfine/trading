(** Tests for {!Entry_reconciliation} — the pure close-vs-entry classifier
    behind issue #2103.

    Every fixture keeps [entry = 100.0] so the overshoot reads directly off the
    close, and the three classes get {b deliberately distinguishable} closes: a
    long at 96.0 / 107.3 / 134.5 lands one candidate in each class (the last is
    the 2026-07-24 MBX shape, +34.5% past its own breakout). A collapsed
    implementation that returned one class for everything cannot satisfy all
    three.

    The class is read through {!Entry_reconciliation.label} and the payload
    through {!Entry_reconciliation.levels_of}, so those two accessors are pinned
    by every case rather than needing tests of their own. The payload is
    asserted through [float_equal]: the computed overshoot carries the usual
    binary-float residue ([(107.3 - 100) / 100 * 100 = 7.300000000000011]), so
    the derived structural equality would reject a hand-written [7.3]. *)

open OUnit2
open Matchers
module ER = Weinstein_snapshot.Entry_reconciliation

(* The armed thresholds: a 1-point de-minimis band, a 15-point chase cap — the
   issue's own bucketing of the 2026-07-24 list, and the values armed in
   dev/weekly-picks/live-config-overrides.sexp. *)
let _band = 1.0
let _cap = 15.0
let _entry = 100.0

let _classify ?(side = `Long) ?(entry = _entry) ?(through_band_pct = _band)
    ?(extension_max_pct = _cap) close =
  ER.classify ~side ~entry ~close ~through_band_pct ~extension_max_pct

(* One matcher for "this is class [name] carrying [close] / [overshoot]". *)
let _is ~name ~close ~overshoot =
  all_of
    [
      field ER.label (is_some_and (equal_to name));
      field ER.levels_of
        (is_some_and
           (all_of
              [
                field (fun (l : ER.levels) -> l.close) (float_equal close);
                field
                  (fun (l : ER.levels) -> l.overshoot_pct)
                  (float_equal overshoot);
              ]));
    ]

(* ---- The three classes, LONG side ---- *)

(* Price has not reached the breakout level: the resting buy-stop is still the
   right ticket, and the overshoot is reported NEGATIVE (4% below entry). *)
let test_long_below_entry_is_valid_stop _ =
  assert_that (_classify 96.0)
    (_is ~name:"valid-stop" ~close:96.0 ~overshoot:(-4.0))

(* Price is through the trigger but inside the chase cap: the ticket re-anchors
   to a market fill. The CLMB shape from the 2026-07-24 list (+7.3%). *)
let test_long_through_entry _ =
  assert_that (_classify 107.3)
    (_is ~name:"through-entry" ~close:107.3 ~overshoot:7.3)

(* Price is far past the breakout: do not chase. The MBX shape (+34.5%), whose
   stale $46.08 buy-stop understated real risk 14x. *)
let test_long_extended _ =
  assert_that (_classify 134.5)
    (_is ~name:"EXTENDED" ~close:134.5 ~overshoot:34.5)

(* ---- The same three, SHORT side: the mirror ---- *)

(* A short's entry is a breakdown level, so "not yet reached" means the close is
   ABOVE it. The same 104.0 close that would be a +4% overshoot for a long is a
   -4% (not-yet-reached) valid stop for a short. *)
let test_short_above_entry_is_valid_stop _ =
  assert_that
    (_classify ~side:`Short 104.0)
    (_is ~name:"valid-stop" ~close:104.0 ~overshoot:(-4.0))

(* Mirrored through-entry: the short has already broken down 7.3% past its
   level. Note the close (92.7) is BELOW entry — the exact input that a
   side-blind classifier would call "valid-stop". *)
let test_short_through_entry _ =
  assert_that
    (_classify ~side:`Short 92.7)
    (_is ~name:"through-entry" ~close:92.7 ~overshoot:7.3)

let test_short_extended _ =
  assert_that
    (_classify ~side:`Short 65.5)
    (_is ~name:"EXTENDED" ~close:65.5 ~overshoot:34.5)

(* The side genuinely flips the verdict on ONE close: 92.7 is a not-yet-reached
   valid stop for a long and a through-entry for a short. A classifier that
   ignored [side] could not produce both. *)
let test_same_close_classifies_oppositely_by_side _ =
  assert_that (_classify 92.7)
    (_is ~name:"valid-stop" ~close:92.7 ~overshoot:(-7.3))

(* ---- Boundaries: both fall to the LOWER class ---- *)

(* An overshoot exactly at the de-minimis band is still a resting stop. *)
let test_overshoot_at_band_is_valid_stop _ =
  assert_that
    (_classify (_entry +. _band))
    (_is ~name:"valid-stop" ~close:101.0 ~overshoot:1.0)

(* Just past the band it re-anchors — proving the band boundary is real and not
   a wider region. *)
let test_overshoot_just_past_band_is_through_entry _ =
  assert_that (_classify 102.0)
    (_is ~name:"through-entry" ~close:102.0 ~overshoot:2.0)

(* An overshoot exactly at the chase cap is still tradeable at the market. *)
let test_overshoot_at_cap_is_through_entry _ =
  assert_that
    (_classify (_entry +. _cap))
    (_is ~name:"through-entry" ~close:115.0 ~overshoot:15.0)

(* Just past the cap the ticket is suppressed. *)
let test_overshoot_just_past_cap_is_extended _ =
  assert_that (_classify 115.5)
    (_is ~name:"EXTENDED" ~close:115.5 ~overshoot:15.5)

(* A zero band means any overshoot at all re-anchors the ticket. *)
let test_zero_band_reanchors_any_overshoot _ =
  assert_that
    (_classify ~through_band_pct:0.0 100.5)
    (_is ~name:"through-entry" ~close:100.5 ~overshoot:0.5)

(* ---- The disarmed default (experiment-flag-discipline R1) ---- *)

(* [extension_max_pct = 0.0] is the arming switch: even the 34.5%-extended MBX
   shape classifies as [Not_reconciled], so a default-config run behaves exactly
   as it did before #2103 — sizing and ticket anchored to [entry]. *)
let test_disarmed_is_not_reconciled _ =
  assert_that
    (_classify ~extension_max_pct:0.0 134.5)
    (equal_to ER.Not_reconciled)

let test_negative_cap_is_disarmed _ =
  assert_that
    (_classify ~extension_max_pct:(-1.0) 134.5)
    (equal_to ER.Not_reconciled)

(* A non-positive entry leaves the overshoot undefined; report honestly rather
   than dividing by zero. *)
let test_zero_entry_is_not_reconciled _ =
  assert_that (_classify ~entry:0.0 134.5) (equal_to ER.Not_reconciled)

(* [label] / [levels_of] have nothing to show for an unreconciled candidate. *)
let test_not_reconciled_has_no_label_or_levels _ =
  assert_that ER.Not_reconciled
    (all_of [ field ER.label is_none; field ER.levels_of is_none ])

(* ---- [overshoot_pct] on its own ---- *)

let test_overshoot_pct_is_side_signed _ =
  assert_that
    (ER.overshoot_pct ~side:`Short ~entry:_entry ~close:92.7)
    (float_equal 7.3)

let test_overshoot_pct_zero_entry_is_zero _ =
  assert_that
    (ER.overshoot_pct ~side:`Long ~entry:0.0 ~close:92.7)
    (float_equal 0.0)

(* ---- [cap_price]: the do-not-chase ceiling (issue #2158) ---- *)

(* Long cap sits one extension ABOVE the entry: 15% above 100 = 115. *)
let test_cap_price_long_is_above_entry _ =
  assert_that
    (ER.cap_price ~side:`Long ~entry:_entry ~extension_max_pct:_cap)
    (float_equal 115.0)

(* Short cap mirrors BELOW the entry: 15% below 100 = 85. *)
let test_cap_price_short_is_below_entry _ =
  assert_that
    (ER.cap_price ~side:`Short ~entry:_entry ~extension_max_pct:_cap)
    (float_equal 85.0)

(* Disarmed ([extension_max_pct <= 0]) collapses the cap onto the entry, so the
   worst admissible fill is just the entry. *)
let test_cap_price_disarmed_is_the_entry _ =
  assert_that
    (ER.cap_price ~side:`Long ~entry:_entry ~extension_max_pct:0.0)
    (float_equal _entry)

(* [classify] stores the cap on the levels of a reconciled candidate — a long
   through-entry at $107.30 with the 15% cap carries cap $115.00. *)
let test_classify_stores_the_cap_on_levels _ =
  assert_that
    (ER.levels_of (_classify 107.3))
    (is_some_and (field (fun (l : ER.levels) -> l.cap) (float_equal 115.0)))

let suite =
  "entry_reconciliation"
  >::: [
         "long below entry is valid-stop"
         >:: test_long_below_entry_is_valid_stop;
         "long through entry" >:: test_long_through_entry;
         "long extended" >:: test_long_extended;
         "short above entry is valid-stop"
         >:: test_short_above_entry_is_valid_stop;
         "short through entry" >:: test_short_through_entry;
         "short extended" >:: test_short_extended;
         "same close classifies oppositely by side"
         >:: test_same_close_classifies_oppositely_by_side;
         "overshoot at the band is valid-stop"
         >:: test_overshoot_at_band_is_valid_stop;
         "overshoot just past the band is through-entry"
         >:: test_overshoot_just_past_band_is_through_entry;
         "overshoot at the cap is through-entry"
         >:: test_overshoot_at_cap_is_through_entry;
         "overshoot just past the cap is extended"
         >:: test_overshoot_just_past_cap_is_extended;
         "zero band re-anchors any overshoot"
         >:: test_zero_band_reanchors_any_overshoot;
         "disarmed is not-reconciled" >:: test_disarmed_is_not_reconciled;
         "negative cap is disarmed" >:: test_negative_cap_is_disarmed;
         "zero entry is not-reconciled" >:: test_zero_entry_is_not_reconciled;
         "not-reconciled has no label or levels"
         >:: test_not_reconciled_has_no_label_or_levels;
         "overshoot_pct is side-signed" >:: test_overshoot_pct_is_side_signed;
         "overshoot_pct on a zero entry is zero"
         >:: test_overshoot_pct_zero_entry_is_zero;
         "cap_price long is above entry" >:: test_cap_price_long_is_above_entry;
         "cap_price short is below entry"
         >:: test_cap_price_short_is_below_entry;
         "cap_price disarmed is the entry"
         >:: test_cap_price_disarmed_is_the_entry;
         "classify stores the cap on levels"
         >:: test_classify_stores_the_cap_on_levels;
       ]

let () = run_test_tt_main suite
