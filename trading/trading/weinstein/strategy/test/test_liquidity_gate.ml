(** Unit tests for the [liquidity_gate] entry gate.

    Pins the no-op-default contract and the gating behaviour of
    {!Liquidity_gate.filter}:

    - [min_entry_dollar_adv = 0.0] (default) → identity: every candidate is
      retained, so the entry candidate list is bit-identical to prior behaviour
      and every existing golden/baseline replays unchanged.
    - [min_entry_dollar_adv > 0] → candidates (long OR short) whose
      [dollar_adv_for ticker] is below the threshold are dropped; those at/above
      are retained.
    - A candidate with no liquidity reading ([dollar_adv_for] returns [None]) is
      retained — a missing reading must never drop a candidate. *)

open OUnit2
open Core
open Matchers
open Weinstein_types

(* Minimal [scored_candidate] builder — only [ticker] / [side] are load-bearing
   for the gate; the rest carry inert placeholders. *)
let _make_candidate ~ticker ~side : Screener.scored_candidate =
  {
    ticker;
    analysis =
      Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
        ~bars:[] ~benchmark_bars:[] ~prior_stage:None
        ~as_of_date:(Date.of_string "2024-01-01");
    side;
    sector =
      {
        sector_name = "Test";
        rating = Screener.Neutral;
        stage = Stage2 { weeks_advancing = 5; late = false };
      };
    grade = C;
    score = 0;
    suggested_entry = 10.0;
    suggested_stop = 10.8;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [];
  }

let _long ticker = _make_candidate ~ticker ~side:Trading_base.Types.Long
let _short ticker = _make_candidate ~ticker ~side:Trading_base.Types.Short

(* Per-ticker dollar-ADV lookup driven by an assoc list of [ticker -> float
   option]. A missing key and an explicit [None] both yield [None] (the gate
   treats both as "no reading"). *)
let _adv_for table ticker =
  Option.join (List.Assoc.find table ticker ~equal:String.equal)

(** Default [0.0] is a no-op: every candidate is retained, in order. *)
let test_zero_threshold_is_noop _ =
  let candidates = [ _long "A"; _short "B" ] in
  let result =
    Liquidity_gate.filter ~min_entry_dollar_adv:0.0
      ~dollar_adv_for:(_adv_for [ ("A", Some 1.0); ("B", Some 1.0) ])
      candidates
  in
  assert_that
    (List.map result ~f:(fun c -> c.Screener.ticker))
    (elements_are [ equal_to "A"; equal_to "B" ])

(** Threshold drops the illiquid candidate, retains the liquid one — on both
    sides (a low-ADV short is dropped just like a low-ADV long). *)
let test_threshold_drops_illiquid_both_sides _ =
  let candidates = [ _long "LIQUID"; _short "ILLIQUID" ] in
  let result =
    Liquidity_gate.filter ~min_entry_dollar_adv:1_000_000.0
      ~dollar_adv_for:
        (_adv_for
           [ ("LIQUID", Some 5_000_000.0); ("ILLIQUID", Some 100.0) ])
      candidates
  in
  assert_that
    (List.map result ~f:(fun c -> c.Screener.ticker))
    (elements_are [ equal_to "LIQUID" ])

(** A candidate priced exactly at the threshold is retained (gate is [>=]). *)
let test_threshold_boundary_is_inclusive _ =
  let result =
    Liquidity_gate.filter ~min_entry_dollar_adv:1_000_000.0
      ~dollar_adv_for:(_adv_for [ ("EXACT", Some 1_000_000.0) ])
      [ _long "EXACT" ]
  in
  assert_that (List.length result) (equal_to 1)

(** A missing liquidity reading ([None]) never drops the candidate. *)
let test_missing_reading_is_retained _ =
  let result =
    Liquidity_gate.filter ~min_entry_dollar_adv:1_000_000.0
      ~dollar_adv_for:(_adv_for [ ("NO_DATA", None) ])
      [ _long "NO_DATA" ]
  in
  assert_that
    (List.map result ~f:(fun c -> c.Screener.ticker))
    (elements_are [ equal_to "NO_DATA" ])

let () =
  run_test_tt_main
    ("liquidity_gate"
    >::: [
           "zero threshold is a no-op" >:: test_zero_threshold_is_noop;
           "threshold drops illiquid both sides"
           >:: test_threshold_drops_illiquid_both_sides;
           "threshold boundary is inclusive"
           >:: test_threshold_boundary_is_inclusive;
           "missing reading is retained" >:: test_missing_reading_is_retained;
         ])
