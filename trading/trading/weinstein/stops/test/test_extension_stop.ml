(** Unit tests for {!Weinstein_stops.Extension_stop} — the pure trigger + trail
    logic of the extension tail-insurance stop.

    Pins:
    - Default-off: the no-op config never fires regardless of the series.
    - No trigger below the ratio → never fires.
    - Trigger then only new highs → never fires (a new high can never fire).
    - Trigger, peak, then a close [trail_pct] below the peak → fires.
    - Width sensitivity (the AXTI April-shakeout shape): a ~-18% post-trigger
      dip SURVIVES a 0.25 trail but EXITS a 0.15 trail — the screen-pinned
      reason the build is wide (0.25), not tight.
    - WMA-warmup weeks (NaN wma) cannot trigger.
    - Degenerate inputs (empty / mismatched-length arrays) return false. *)

open OUnit2
open Core
open Matchers
module Extension_stop = Weinstein_stops.Extension_stop

let _armed = { Extension_stop.trigger_ratio = 2.0; trail_pct = 0.25 }

(* A constant WMA of 50.0 per week, so [close = 100.0] is exactly 2.0x the WMA
   (the trigger). *)
let _flat_wma n = Array.create ~len:n 50.0

(* ------------------------------------------------------------------ *)
(* Default-off: the no-op config never fires                           *)
(* ------------------------------------------------------------------ *)

(* A series that WOULD fire under an armed config: trigger at 100, peak 120,
   collapse to 60 (60 <= 120 * 0.75). *)
let _would_fire_closes = [| 60.0; 100.0; 120.0; 60.0 |]

let test_default_off_never_fires _ =
  let wmas = _flat_wma (Array.length _would_fire_closes) in
  assert_that
    (Extension_stop.fired Extension_stop.default_config
       ~closes:_would_fire_closes ~wmas)
    (equal_to false)

(* ------------------------------------------------------------------ *)
(* No trigger below the ratio → never fires                             *)
(* ------------------------------------------------------------------ *)

let test_no_trigger_below_ratio _ =
  (* Max close 90 vs WMA 50 => 1.8x, below the 2.0 trigger even though it later
     collapses hard. *)
  let closes = [| 60.0; 80.0; 90.0; 40.0 |] in
  let wmas = _flat_wma (Array.length closes) in
  assert_that (Extension_stop.fired _armed ~closes ~wmas) (equal_to false)

(* ------------------------------------------------------------------ *)
(* Trigger then only new highs → never fires                            *)
(* ------------------------------------------------------------------ *)

let test_new_highs_never_fire _ =
  (* Trigger at 100 (2.0x), then a monotone climb — a new high can never fire
     (fire-check precedes the peak update). *)
  let closes = [| 70.0; 100.0; 110.0; 130.0; 160.0 |] in
  let wmas = _flat_wma (Array.length closes) in
  assert_that (Extension_stop.fired _armed ~closes ~wmas) (equal_to false)

(* ------------------------------------------------------------------ *)
(* Trigger, peak, then collapse ≤ peak*(1-trail) → fires                *)
(* ------------------------------------------------------------------ *)

let test_collapse_below_trail_fires _ =
  (* Trigger at 100, peak 120, then 84 <= 120*0.75 (=90) => fires at 0.25. *)
  let closes = [| 70.0; 100.0; 120.0; 84.0 |] in
  let wmas = _flat_wma (Array.length closes) in
  assert_that (Extension_stop.fired _armed ~closes ~wmas) (equal_to true)

(* ------------------------------------------------------------------ *)
(* Width sensitivity — the AXTI April-shakeout shape                    *)
(* ------------------------------------------------------------------ *)

(* Trigger at 100 (2.0x WMA 50), peak 120, then a ~-18% shakeout dip to 98.4
   (120 * 0.82), then the parabola resumes to a new high. *)
let _shakeout_closes = [| 70.0; 100.0; 120.0; 98.4; 140.0 |]

let test_shakeout_survives_wide_trail _ =
  (* 98.4 > 120 * 0.75 (=90) => the 0.25 trail HOLDS through the shakeout. *)
  let wmas = _flat_wma (Array.length _shakeout_closes) in
  assert_that
    (Extension_stop.fired
       { Extension_stop.trigger_ratio = 2.0; trail_pct = 0.25 }
       ~closes:_shakeout_closes ~wmas)
    (equal_to false)

let test_shakeout_exits_tight_trail _ =
  (* 98.4 <= 120 * 0.85 (=102) => the 0.15 trail is an on-ramp KILLER: it exits
     during the shakeout, before the parabola resumes. *)
  let wmas = _flat_wma (Array.length _shakeout_closes) in
  assert_that
    (Extension_stop.fired
       { Extension_stop.trigger_ratio = 2.0; trail_pct = 0.15 }
       ~closes:_shakeout_closes ~wmas)
    (equal_to true)

(* ------------------------------------------------------------------ *)
(* WMA-warmup weeks (NaN wma) cannot trigger                            *)
(* ------------------------------------------------------------------ *)

let test_nan_wma_warmup_cannot_trigger _ =
  (* Week 0 has a huge close but a NaN WMA (window not yet filled) — it must not
     trigger; the finite-WMA weeks that follow stay below the ratio, so no fire.
  *)
  let closes = [| 500.0; 60.0; 80.0; 90.0 |] in
  let wmas = [| Float.nan; 50.0; 50.0; 50.0 |] in
  assert_that (Extension_stop.fired _armed ~closes ~wmas) (equal_to false)

(* ------------------------------------------------------------------ *)
(* Degenerate inputs                                                    *)
(* ------------------------------------------------------------------ *)

let test_empty_series_returns_false _ =
  assert_that
    (Extension_stop.fired _armed ~closes:[||] ~wmas:[||])
    (equal_to false)

let test_mismatched_lengths_returns_false _ =
  assert_that
    (Extension_stop.fired _armed ~closes:[| 100.0; 120.0; 60.0 |]
       ~wmas:[| 50.0; 50.0 |])
    (equal_to false)

let () =
  run_test_tt_main
    ("extension_stop"
    >::: [
           "default-off never fires" >:: test_default_off_never_fires;
           "no trigger below ratio never fires" >:: test_no_trigger_below_ratio;
           "new highs never fire" >:: test_new_highs_never_fire;
           "collapse below trail fires" >:: test_collapse_below_trail_fires;
           "shakeout survives wide (0.25) trail"
           >:: test_shakeout_survives_wide_trail;
           "shakeout exits tight (0.15) trail"
           >:: test_shakeout_exits_tight_trail;
           "NaN-wma warmup cannot trigger"
           >:: test_nan_wma_warmup_cannot_trigger;
           "empty series returns false" >:: test_empty_series_returns_false;
           "mismatched lengths return false"
           >:: test_mismatched_lengths_returns_false;
         ])
