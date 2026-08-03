(** Contract tests for {!Snapshot_pipeline.Adjusted_basis}.

    Two contracts are pinned here, neither of which the rest of the sketch suite
    can reach (every other fixture in these suites sets
    [adjusted_close = close_price] and carries no corrupt bar):

    - {b the corrupt-bar guard} — a non-positive / NaN raw [close_price] admits
      no factor ([f = 1.0]), so O/H/L stay raw and only [close_price] takes
      [adjusted_close]. Without the guard these inputs produce NaN / infinite /
      negative bars.
    - {b the real no-op precondition} — the rescale is bit-identity exactly when
      [adjusted_close = close_price], NOT merely when the data is split-free. A
      dividend-only adjustment (no split) already moves every O/H/L bit, which
      is why the fixtures below deliberately include one. *)

open OUnit2
open Core
open Matchers
module Adjusted_basis = Snapshot_pipeline.Adjusted_basis

let _as_of = Date.of_string "2020-06-05"

(* One bar with fixed O/H/L; only the (close, adjusted_close) pair varies, which
   is the only input the rescale factor depends on. *)
let _bar ~close ~adjusted : Types.Daily_price.t =
  {
    date = _as_of;
    open_price = 96.0;
    high_price = 104.0;
    low_price = 92.0;
    close_price = close;
    adjusted_close = adjusted;
    volume = 1_000_000;
    active_through = None;
  }

let _equal_bar (expected : Types.Daily_price.t) =
  equal_to ~cmp:Types.Daily_price.equal
    ~msg:("Expected " ^ Types.Daily_price.show expected)
    expected

(* IEEE-754 bit patterns, so "bit-identical" is asserted rather than
   approximated — a [float_equal] with an epsilon cannot tell identity from a
   1-ulp drift. *)
let _bits (b : Types.Daily_price.t) =
  ( Int64.bits_of_float b.open_price,
    Int64.bits_of_float b.high_price,
    Int64.bits_of_float b.low_price,
    Int64.bits_of_float b.close_price )

(* The guarded outcome shared by all three corrupt-close cases: factor 1.0, so
   O/H/L keep their raw values and the close takes [adjusted_close]. *)
let _unscaled_with_adjusted_close = _bar ~close:25.0 ~adjusted:25.0

(* ------------------------------------------------------------------ *)
(* Corrupt raw close -> factor 1.0                                     *)
(* ------------------------------------------------------------------ *)

(* Unguarded, [25.0 /. nan = nan] poisons every O/H/L. *)
let test_nan_raw_close_admits_no_factor _ =
  assert_that
    (Adjusted_basis.to_adjusted_basis (_bar ~close:Float.nan ~adjusted:25.0))
    (_equal_bar _unscaled_with_adjusted_close)

(* Unguarded, [25.0 /. 0.0 = infinity]. *)
let test_zero_raw_close_admits_no_factor _ =
  assert_that
    (Adjusted_basis.to_adjusted_basis (_bar ~close:0.0 ~adjusted:25.0))
    (_equal_bar _unscaled_with_adjusted_close)

(* Unguarded, a negative raw close yields a negative factor -> negative prices. *)
let test_negative_raw_close_admits_no_factor _ =
  assert_that
    (Adjusted_basis.to_adjusted_basis (_bar ~close:(-2.0) ~adjusted:25.0))
    (_equal_bar _unscaled_with_adjusted_close)

(* ------------------------------------------------------------------ *)
(* Rescale + idempotence                                               *)
(* ------------------------------------------------------------------ *)

(* 4:1 forward split: factor 0.25 scales O/H/L, close takes the adjusted close. *)
let test_split_rescales_ohl _ =
  assert_that
    (Adjusted_basis.to_adjusted_basis (_bar ~close:100.0 ~adjusted:25.0))
    (_equal_bar
       {
         _unscaled_with_adjusted_close with
         open_price = 24.0;
         high_price = 26.0;
         low_price = 23.0;
       })

(* Re-applying to an already-adjusted bar is a bitwise no-op: its close now
   equals its adjusted close, so the factor is exactly 1.0. *)
let test_idempotent_on_already_adjusted_bar _ =
  let once =
    Adjusted_basis.to_adjusted_basis (_bar ~close:100.0 ~adjusted:25.0)
  in
  assert_that
    (_bits (Adjusted_basis.to_adjusted_basis once))
    (equal_to (_bits once))

(* ------------------------------------------------------------------ *)
(* The real no-op precondition                                         *)
(* ------------------------------------------------------------------ *)

(* [adjusted_close = close_price] — and only that — is bit-identity. Probed
   across seven magnitudes because [x /. x = 1.0] and [h *. 1.0 = h] are exact
   in IEEE-754 for every finite non-zero [x]. *)
let test_equal_closes_is_bitwise_identity _ =
  let bars =
    List.map [ 1e-8; 0.01; 1.0; 3.7; 123.456789; 99_999.99; 1e9 ] ~f:(fun p ->
        _bar ~close:p ~adjusted:p)
  in
  assert_that
    (List.map bars ~f:(fun b -> _bits (Adjusted_basis.to_adjusted_basis b)))
    (elements_are (List.map bars ~f:(fun b -> equal_to (_bits b))))

(* The precondition is NOT "split-free". A dividend-only adjustment involves no
   split, yet every O/H/L bit moves — which is why [compute_windowed] /
   [of_daily_bars] output changes for essentially every real dividend payer. *)
let test_dividend_only_adjustment_is_not_a_no_op _ =
  let b = _bar ~close:100.0 ~adjusted:99.87 in
  let out = Adjusted_basis.to_adjusted_basis b in
  assert_that out
    (all_of
       [
         field
           (fun r -> Poly.equal (_bits r) (_bits b))
           (equal_to ~msg:"dividend-only adjustment must not be bit-identity"
              false);
         field
           (fun (r : Types.Daily_price.t) -> r.high_price)
           (float_equal ~epsilon:1e-12 (104.0 *. 0.9987));
         field
           (fun (r : Types.Daily_price.t) -> r.close_price)
           (float_equal 99.87);
       ])

(* ------------------------------------------------------------------ *)
(* Cross-file sync with Svg_series's private duplicate                 *)
(* ------------------------------------------------------------------ *)

(* {!Weinstein_snapshot.Svg_series} (trading/trading/weinstein/snapshot)
   duplicates this exact rescale privately as [_to_adjusted_basis] — see its
   .ml docstring: "kept as a private, intentional duplicate ... Keep both in
   sync by hand if this formula changes." Nothing else observes both sides
   (every other [to_adjusted_basis] reference is pipeline-side; every
   [weekly_bars] test is snapshot-side), so a formula drift between the two
   copies would go undetected — that is the gap this test closes.
   [_to_adjusted_basis] itself is private, but [Svg_series.weekly_bars] on a
   SINGLE bar reduces to it: [_fold_week] on a one-element list folds that
   element's own open/high/low/close/adjusted_close back out unchanged, just
   re-built through [Daily_price.make] with [active_through] defaulted to
   [None] rather than carried through — the one field the two copies provably
   do NOT agree on (see the .mli). Each test below first asserts the returned
   list has exactly one element, since the reduction to [_to_adjusted_basis]
   only holds for a singleton input — [List.hd_exn] alone would not catch a
   regression that silently dropped or duplicated weeks. The factor here
   ([10.0 /. 70.0], a 7:1-style ratio) is deliberately not a power of two, so
   an inexact-rescale divergence between the two copies can't hide behind a
   factor that happens to be exact in binary. *)
module Svg_series = Weinstein_snapshot.Svg_series

let test_svg_series_weekly_bars_matches_adjusted_basis_on_a_split _ =
  let b =
    { (_bar ~close:70.0 ~adjusted:10.0) with active_through = Some _as_of }
  in
  let via_pipeline = Adjusted_basis.to_adjusted_basis b in
  let weekly = Svg_series.weekly_bars [ b ] in
  assert_that weekly (size_is 1);
  assert_that via_pipeline.active_through (is_some_and (equal_to _as_of));
  assert_that (List.hd_exn weekly)
    (_equal_bar { via_pipeline with active_through = None })

(* Same cross-file comparison, but on a corrupt-close input that trips the
   guard ([f = 1.0]) instead of a real rescale. Every guard case above
   ("admits no factor") exercises only [Adjusted_basis.to_adjusted_basis]
   directly — none go through [Svg_series.weekly_bars] — so deleting the
   guard from the private duplicate would otherwise go undetected. *)
let test_svg_series_weekly_bars_matches_adjusted_basis_on_guarded_input _ =
  let b = _bar ~close:0.0 ~adjusted:25.0 in
  let via_pipeline = Adjusted_basis.to_adjusted_basis b in
  let weekly = Svg_series.weekly_bars [ b ] in
  assert_that weekly (size_is 1);
  assert_that (List.hd_exn weekly) (_equal_bar via_pipeline)

(* Pins the one known, deliberate divergence named above so a future fix to
   either side that changes this behavior is caught rather than silently
   drifting further out of sync. *)
let test_svg_series_weekly_bars_drops_active_through _ =
  let b =
    { (_bar ~close:100.0 ~adjusted:25.0) with active_through = Some _as_of }
  in
  let weekly = Svg_series.weekly_bars [ b ] in
  assert_that weekly (size_is 1);
  assert_that (List.hd_exn weekly).active_through is_none

let suite =
  "Adjusted_basis"
  >::: [
         "NaN raw close admits no factor"
         >:: test_nan_raw_close_admits_no_factor;
         "Zero raw close admits no factor"
         >:: test_zero_raw_close_admits_no_factor;
         "Negative raw close admits no factor"
         >:: test_negative_raw_close_admits_no_factor;
         "Split rescales O/H/L" >:: test_split_rescales_ohl;
         "Idempotent on an already-adjusted bar"
         >:: test_idempotent_on_already_adjusted_bar;
         "Equal closes is bitwise identity"
         >:: test_equal_closes_is_bitwise_identity;
         "Dividend-only adjustment is not a no-op"
         >:: test_dividend_only_adjustment_is_not_a_no_op;
         "Svg_series.weekly_bars matches Adjusted_basis on a split"
         >:: test_svg_series_weekly_bars_matches_adjusted_basis_on_a_split;
         "Svg_series.weekly_bars matches Adjusted_basis on guarded input"
         >:: test_svg_series_weekly_bars_matches_adjusted_basis_on_guarded_input;
         "Svg_series.weekly_bars drops active_through"
         >:: test_svg_series_weekly_bars_drops_active_through;
       ]

let () = run_test_tt_main suite
