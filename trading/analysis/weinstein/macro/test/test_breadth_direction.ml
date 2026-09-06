(** The five-state breadth-direction read.

    Pins {!Breadth_direction.classify}'s fallbacks (disabled, missing data),
    each rule branch, the Deteriorating-beats-Recovering precedence, and the
    default-off config contract. *)

open Core
open OUnit2
open Matchers
open Weinstein_types

let _on = { Breadth_direction.default_config with enabled = true }

(** Classify one reading. Defaults describe a healthy tape — participation well
    above the weak threshold, flat, with negligible new lows — so each test
    perturbs only the inputs its rule is about. *)
let _classify ?(config = _on) ?(trend = Neutral) ?(pct_above = 70.0)
    ?(pct_above_prior = 70.0) ?(nl_pct = 1.0) ?(nl_pct_prior = 1.0) () =
  Breadth_direction.classify ~config ~trend ~pct_above:(Some pct_above)
    ~pct_above_prior:(Some pct_above_prior) ~nl_pct:(Some nl_pct)
    ~nl_pct_prior:(Some nl_pct_prior)

(* ------------------------------------------------------------------ *)
(* Fallbacks: disabled, and missing data                                *)
(* ------------------------------------------------------------------ *)

(** R1: with the default (disabled) config, every trend projects 1:1 and the
    breadth inputs are ignored entirely — including inputs that would otherwise
    read Deteriorating. This is the bit-identical-to-baseline contract. *)
let test_disabled_projects_every_trend _ =
  let disabled = Breadth_direction.default_config in
  let states =
    List.map [ Bullish; Neutral; Bearish ] ~f:(fun trend ->
        _classify ~config:disabled ~trend ~pct_above:10.0 ~pct_above_prior:60.0
          ~nl_pct:40.0 ~nl_pct_prior:1.0 ())
  in
  assert_that states
    (elements_are
       [
         equal_to Bullish_breadth;
         equal_to Neutral_breadth;
         equal_to Bearish_breadth;
       ])

(** A partial reading is not a reading: any [None] falls back to the projection,
    rather than to a third policy. Each case drops exactly one input from a
    quadruple that would otherwise read Deteriorating. *)
let test_any_missing_input_falls_back_to_projection _ =
  let deteriorating_but_for ~pct_above ~pct_above_prior ~nl_pct ~nl_pct_prior =
    Breadth_direction.classify ~config:_on ~trend:Bullish ~pct_above
      ~pct_above_prior ~nl_pct ~nl_pct_prior
  in
  let some x = Some x in
  assert_that
    [
      deteriorating_but_for ~pct_above:None ~pct_above_prior:(some 60.0)
        ~nl_pct:(some 1.0) ~nl_pct_prior:(some 1.0);
      deteriorating_but_for ~pct_above:(some 10.0) ~pct_above_prior:None
        ~nl_pct:(some 1.0) ~nl_pct_prior:(some 1.0);
      deteriorating_but_for ~pct_above:(some 10.0) ~pct_above_prior:(some 60.0)
        ~nl_pct:None ~nl_pct_prior:(some 1.0);
      deteriorating_but_for ~pct_above:(some 10.0) ~pct_above_prior:(some 60.0)
        ~nl_pct:(some 1.0) ~nl_pct_prior:None;
    ]
    (elements_are (List.init 4 ~f:(fun _ -> equal_to Bullish_breadth)))

(* ------------------------------------------------------------------ *)
(* Rule branches                                                        *)
(* ------------------------------------------------------------------ *)

(** Rule 1: a Bearish tape is already the strongest statement the macro gate
    makes, so it short-circuits ahead of every breadth rule — even inputs that
    read Recovering. *)
let test_bearish_trend_short_circuits _ =
  assert_that
    (_classify ~trend:Bearish ~pct_above:20.0 ~pct_above_prior:10.0 ())
    (equal_to Bearish_breadth)

(** Rule 2: weak AND falling by at least [falling_points]. *)
let test_weak_and_falling_is_deteriorating _ =
  assert_that
    (_classify ~pct_above:38.0 ~pct_above_prior:50.0 ())
    (equal_to Deteriorating)

(** The direction reading is gated on weakness: the same 12-point fall from a
    healthy base is not Deteriorating. *)
let test_falling_from_a_strong_base_is_not_deteriorating _ =
  assert_that
    (_classify ~trend:Bullish ~pct_above:68.0 ~pct_above_prior:80.0 ())
    (equal_to Bullish_breadth)

(** A weak but barely-moving tape is neither branch. *)
let test_weak_but_flat_projects _ =
  assert_that
    (_classify ~trend:Bullish ~pct_above:40.0 ~pct_above_prior:42.0 ())
    (equal_to Bullish_breadth)

(** Rule 3: elevated AND expanding new lows, independent of participation — here
    participation is healthy and flat. *)
let test_expanding_new_lows_is_deteriorating _ =
  assert_that
    (_classify ~trend:Bullish ~nl_pct:12.0 ~nl_pct_prior:9.0 ())
    (equal_to Deteriorating)

(** Elevated new lows that are CONTRACTING are not a deterioration signal. *)
let test_contracting_new_lows_projects _ =
  assert_that
    (_classify ~trend:Bullish ~nl_pct:12.0 ~nl_pct_prior:20.0 ())
    (equal_to Bullish_breadth)

(** Rising new lows below the threshold are not a deterioration signal either —
    both halves of the rule are required. *)
let test_rising_but_low_new_lows_projects _ =
  assert_that
    (_classify ~trend:Bullish ~nl_pct:6.0 ~nl_pct_prior:2.0 ())
    (equal_to Bullish_breadth)

(** Rule 4: weak AND rising by at least [rising_points] — the best-performing
    cohort in the 27-year study. *)
let test_weak_and_rising_is_recovering _ =
  assert_that
    (_classify ~pct_above:20.0 ~pct_above_prior:8.0 ())
    (equal_to Recovering)

(* ------------------------------------------------------------------ *)
(* Precedence                                                           *)
(* ------------------------------------------------------------------ *)

(** Both rules fire at a turn — participation is climbing off the low while the
    new-low list is still expanding. Deteriorating is checked first and wins;
    the .mli documents this as the conservative resolution. *)
let test_deteriorating_beats_recovering _ =
  assert_that
    (_classify ~trend:Bullish ~pct_above:20.0 ~pct_above_prior:8.0 ~nl_pct:12.0
       ~nl_pct_prior:9.0 ())
    (equal_to Deteriorating)

(* ------------------------------------------------------------------ *)
(* Config contract                                                      *)
(* ------------------------------------------------------------------ *)

(** R1: the mechanism ships off, with the thresholds the 27-year study used. *)
let test_default_config_is_off_with_documented_thresholds _ =
  assert_that Breadth_direction.default_config
    (all_of
       [
         field
           (fun (c : Breadth_direction.config) -> c.enabled)
           (equal_to false);
         field
           (fun (c : Breadth_direction.config) -> c.weak_pct_above)
           (float_equal 45.0);
         field
           (fun (c : Breadth_direction.config) -> c.falling_points)
           (float_equal 5.0);
         field
           (fun (c : Breadth_direction.config) -> c.rising_points)
           (float_equal 5.0);
         field
           (fun (c : Breadth_direction.config) -> c.new_lows_pct)
           (float_equal 8.0);
         field
           (fun (c : Breadth_direction.config) -> c.lookback_weeks)
           (equal_to 4);
       ])

(** Macro's default config embeds the disabled breadth config, so a run that
    says nothing about breadth is in the projected-from-trend mode. *)
let test_macro_default_config_has_breadth_off _ =
  assert_that Macro.default_config.breadth_direction.enabled (equal_to false)

(** R2 / backward-compat: a [Macro.config] sexp written before the field existed
    still parses, and lands on the disabled default. The [[@sexp.default]] is
    what makes every pre-existing scenario spec keep working. *)
let test_macro_config_sexp_without_breadth_field_parses _ =
  let without_breadth =
    match Macro.sexp_of_config Macro.default_config with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom "breadth_direction" :: _) -> false
            | _ -> true))
    | other -> other
  in
  assert_that (Macro.config_of_sexp without_breadth).breadth_direction
    (equal_to (Breadth_direction.default_config : Breadth_direction.config))

(** R2 / axis-expressibility: the nested override spelling quoted in the [.mli]
    resolves through a plain sexp deep-merge — the same walk
    [Backtest.Overlay_validator.apply_overrides] performs — rather than silently
    dropping the key. Pinned here (in the macro library) on the [macro_config]
    subtree the overlay would address. *)
let test_nested_enabled_override_resolves _ =
  let overridden =
    match Macro.sexp_of_config Macro.default_config with
    | Sexp.List fields ->
        Sexp.List
          (List.map fields ~f:(function
            | Sexp.List [ Sexp.Atom "breadth_direction"; Sexp.List sub ] ->
                Sexp.List
                  [
                    Sexp.Atom "breadth_direction";
                    Sexp.List
                      (List.map sub ~f:(function
                        | Sexp.List [ Sexp.Atom "enabled"; _ ] ->
                            Sexp.List [ Sexp.Atom "enabled"; Sexp.Atom "true" ]
                        | other -> other));
                  ]
            | other -> other))
    | other -> other
  in
  assert_that (Macro.config_of_sexp overridden).breadth_direction.enabled
    (equal_to true)

let suite =
  "breadth_direction"
  >::: [
         "disabled projects every trend 1:1"
         >:: test_disabled_projects_every_trend;
         "any missing input falls back to the projection"
         >:: test_any_missing_input_falls_back_to_projection;
         "a Bearish trend short-circuits ahead of every rule"
         >:: test_bearish_trend_short_circuits;
         "weak and falling is Deteriorating"
         >:: test_weak_and_falling_is_deteriorating;
         "falling from a strong base is not Deteriorating"
         >:: test_falling_from_a_strong_base_is_not_deteriorating;
         "weak but flat projects the trend" >:: test_weak_but_flat_projects;
         "expanding new lows is Deteriorating"
         >:: test_expanding_new_lows_is_deteriorating;
         "contracting new lows projects the trend"
         >:: test_contracting_new_lows_projects;
         "rising but below-threshold new lows project the trend"
         >:: test_rising_but_low_new_lows_projects;
         "weak and rising is Recovering" >:: test_weak_and_rising_is_recovering;
         "Deteriorating beats Recovering when both fire"
         >:: test_deteriorating_beats_recovering;
         "default config is off with the documented thresholds"
         >:: test_default_config_is_off_with_documented_thresholds;
         "Macro.default_config has breadth direction off"
         >:: test_macro_default_config_has_breadth_off;
         "a Macro.config sexp without the field still parses"
         >:: test_macro_config_sexp_without_breadth_field_parses;
         "the nested breadth_direction.enabled override resolves"
         >:: test_nested_enabled_override_resolves;
       ]

let () = run_test_tt_main suite
