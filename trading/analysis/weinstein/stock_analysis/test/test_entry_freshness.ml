open OUnit2
open Matchers
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* F1 — Entry_freshness.range_top_freshness                             *)
(*                                                                      *)
(* The armed clock's admit rule, isolated from Stock_analysis. Every    *)
(* case fixes the ticket anchor at 100.0 and the MA at 90.0 (so the     *)
(* trigger clears the MA) and varies exactly one input.                 *)
(* ------------------------------------------------------------------ *)

let anchor = 100.0
let ma_below_anchor = 90.0

(** [freshness] with the armed basis and every §4.1 condition satisfied unless a
    caller overrides it. [close] defaults to the anchor itself (a breakout that
    has just happened). *)
let freshness ?(basis = Entry_freshness.Range_top_breakout)
    ?(ma_direction = Rising) ?(ma_value = ma_below_anchor)
    ?(local_range_top = Some anchor) ?(current_close = Some anchor) () =
  Entry_freshness.range_top_freshness ~basis ~ma_direction ~ma_value
    ~local_range_top ~current_close

(* --- The default basis has no opinion (R1) ------------------------- *)

(** [Ma_cross] (the default) returns [None] on every input, including inputs
    that the armed basis would happily admit. [None] is what tells
    {!Stock_analysis.is_breakout_candidate} to keep its pre-F1 MA-cross window
    verbatim, so this is the whole no-op guarantee in one assertion. *)
let test_ma_cross_basis_has_no_opinion _ =
  assert_that (freshness ~basis:Entry_freshness.Ma_cross ()) is_none

(** ... and it stays [None] even when the armed basis would REJECT, so [None] is
    genuinely "no opinion" rather than a smuggled verdict in either direction.
*)
let test_ma_cross_basis_none_even_when_armed_would_reject _ =
  assert_that
    (freshness ~basis:Entry_freshness.Ma_cross ~ma_direction:Declining ())
    is_none

(* --- Proximity band (setup live) ----------------------------------- *)

(** A close sitting exactly at the anchor is live: the breakout is happening. *)
let test_close_at_anchor_is_live _ =
  assert_that (freshness ()) (is_some_and (equal_to true))

(** A close 3% under the anchor is still live — the book writes the GTC buy-stop
    BEFORE the breakout (§4.7), so admission must fire while the stock is coiled
    under the range top or no ticket is resting when it breaks out. *)
let test_close_inside_proximity_band_is_live _ =
  assert_that
    (freshness ~current_close:(Some (anchor *. 0.97)) ())
    (is_some_and (equal_to true))

(** The band's edge is inclusive at exactly [1 - proximity_pct]. *)
let test_close_at_band_edge_is_live _ =
  assert_that
    (freshness
       ~current_close:(Some (anchor *. (1.0 -. Entry_freshness.proximity_pct)))
       ())
    (is_some_and (equal_to true))

(** A close 8% under the anchor is outside the 5% band: the setup is not yet
    actionable, so nothing is admitted. *)
let test_close_below_proximity_band_is_not_live _ =
  assert_that
    (freshness ~current_close:(Some (anchor *. 0.92)) ())
    (is_some_and (equal_to false))

(** A close ABOVE the anchor still satisfies the band (the ticket has filled /
    is filling). There is deliberately no separate "already broke out N weeks
    ago" disjunct — that shape is the pullback second-chance buy, out of scope
    (#1366). *)
let test_close_above_anchor_is_live _ =
  assert_that
    (freshness ~current_close:(Some (anchor *. 1.01)) ())
    (is_some_and (equal_to true))

(* --- §4.1 MA conditions -------------------------------------------- *)

(** §4.1 requirement 2 + 3: a declining 30-week MA rejects the setup no matter
    how perfect the price structure is. "A breakout below a declining MA is a
    trap, not a buy" (Ch. 3, Western Union: 45 -> 8 1/2). *)
let test_declining_ma_rejects _ =
  assert_that
    (freshness ~ma_direction:Declining ())
    (is_some_and (equal_to false))

(** A flat MA is acceptable — the book requires "no longer declining", not
    "rising" (§4.1 requirement 2). *)
let test_flat_ma_accepted _ =
  assert_that (freshness ~ma_direction:Flat ()) (is_some_and (equal_to true))

(** §4.1 requirement 1: the breakout must be above the MA. The test is applied
    to the ANCHOR, not the close, because the anchor is where the resting ticket
    fills — testing the close would let a ticket fill below the MA. Here the MA
    sits above the anchor, so the eventual fill would be a sub-MA breakout. *)
let test_trigger_below_ma_rejects _ =
  assert_that
    (freshness ~ma_value:(anchor *. 1.05) ())
    (is_some_and (equal_to false))

(* --- Missing inputs ------------------------------------------------ *)

(** No ticket anchor (i.e. [entry_anchor_local_range_weeks = 0]) means there is
    no breakout level to be fresh from, so the armed basis admits nothing. It
    does NOT fall back to the MA-cross window: the two clocks are alternatives,
    not a disjunction. *)
let test_missing_anchor_admits_nothing _ =
  assert_that
    (freshness ~local_range_top:None ())
    (is_some_and (equal_to false))

(** Same for a missing close (empty / truncated bar history). *)
let test_missing_close_admits_nothing _ =
  assert_that (freshness ~current_close:None ()) (is_some_and (equal_to false))

let suite =
  "entry_freshness"
  >::: [
         "Ma_cross basis has no opinion" >:: test_ma_cross_basis_has_no_opinion;
         "Ma_cross stays None where armed would reject"
         >:: test_ma_cross_basis_none_even_when_armed_would_reject;
         "close at anchor is live" >:: test_close_at_anchor_is_live;
         "close inside proximity band is live"
         >:: test_close_inside_proximity_band_is_live;
         "close at band edge is live" >:: test_close_at_band_edge_is_live;
         "close below proximity band is not live"
         >:: test_close_below_proximity_band_is_not_live;
         "close above anchor is live" >:: test_close_above_anchor_is_live;
         "declining MA rejects" >:: test_declining_ma_rejects;
         "flat MA accepted" >:: test_flat_ma_accepted;
         "trigger below MA rejects" >:: test_trigger_below_ma_rejects;
         "missing anchor admits nothing" >:: test_missing_anchor_admits_nothing;
         "missing close admits nothing" >:: test_missing_close_admits_nothing;
       ]

let () = run_test_tt_main suite
