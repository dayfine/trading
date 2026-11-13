(** Axis pins for the #3404 [Seeded] tiebreak
    ([dev/plans/path-stability-fixes-2026-10-23.md] §"Step 1").

    R1: the default is [Seeded] with [tiebreak_seed = 0] since the #3404 flip
    (user-approved 2026-10-25); [Alphabetical] stays selectable. R2: both fields
    resolve through the real [Overlay_validator.apply_overrides] (the sweep /
    WF-CV path) under [screening_config], so the stability chain can set
    [tiebreak_seed] per salt. The default-off [Price_band_seeded] mode and its
    [ranking_price_band_edges] resolve the same way. *)

open OUnit2
open Core
open Matchers

let _default_config () =
  Weinstein_strategy.default_config ~universe:[ "GOOG" ] ~index_symbol:"GSPCX"

let _after overlays =
  Backtest.Overlay_validator.apply_overrides (_default_config ())
    (List.map overlays ~f:Sexp.of_string)

let _fields (c : Weinstein_strategy.config) =
  (c.screening_config.candidate_ranking, c.screening_config.tiebreak_seed)

let test_default_is_seeded_seed_zero _ =
  assert_that (_fields (_default_config ())) (equal_to (Screener.Seeded, 0))

let test_seeded_axis_resolves_via_overlay_validator _ =
  assert_that
    [
      _fields (_after [ "((screening_config ((candidate_ranking Seeded))))" ]);
      _fields
        (_after
           [
             "((screening_config ((candidate_ranking Seeded) (tiebreak_seed \
              5))))";
           ]);
      _fields
        (_after
           [
             "((screening_config ((candidate_ranking Seeded) (tiebreak_seed \
              2))))";
             "((screening_config ((tiebreak_seed 3))))";
           ]);
      _fields
        (_after [ "((screening_config ((candidate_ranking Alphabetical))))" ]);
    ]
    (elements_are
       [
         equal_to (Screener.Seeded, 0);
         equal_to (Screener.Seeded, 5);
         equal_to (Screener.Seeded, 3);
         equal_to (Screener.Alphabetical, 0);
       ])

(* The default-off [Price_band_seeded] mode and its band edges resolve through
   the same [Overlay_validator] path; the default config keeps [Seeded] and the
   [8; 14; 33] edges. *)
let test_price_band_axis_resolves_via_overlay_validator _ =
  let band (c : Weinstein_strategy.config) =
    ( c.screening_config.candidate_ranking,
      c.screening_config.ranking_price_band_edges )
  in
  assert_that
    [
      band (_default_config ());
      band
        (_after
           [
             "((screening_config ((candidate_ranking Price_band_seeded) \
              (ranking_price_band_edges (5 10 20)))))";
           ]);
    ]
    (elements_are
       [
         equal_to (Screener.Seeded, [ 8.0; 14.0; 33.0 ]);
         equal_to (Screener.Price_band_seeded, [ 5.0; 10.0; 20.0 ]);
       ])

let suite =
  "seeded_tiebreak_overlays"
  >::: [
         "default is Seeded, seed 0" >:: test_default_is_seeded_seed_zero;
         "Seeded + tiebreak_seed resolve via Overlay_validator"
         >:: test_seeded_axis_resolves_via_overlay_validator;
         "Price_band_seeded + edges resolve via Overlay_validator"
         >:: test_price_band_axis_resolves_via_overlay_validator;
       ]

let () = run_test_tt_main suite
