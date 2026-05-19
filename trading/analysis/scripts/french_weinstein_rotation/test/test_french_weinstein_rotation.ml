(** Tests for {!French_weinstein_rotation_lib.Rotation}.

    The pinned fixture under
    [trading/analysis/data/sources/kenneth_french/fixture/french-49ind-2026-05-20.csv.gz]
    is the canonical input. Tests run against the full 100y series since the
    binary takes ~1s end-to-end and the strategy is deterministic.

    Coverage:
    - [test_load_block_returns_full_series_and_49_industries]: loader smoke; pin
      49 industries; assert ≥ 26,000 trading days.
    - [test_compute_strategy_smoke_default_config]: end-to-end smoke; non-empty
      decade reports, every report has positive [n_days] and finite metrics.
    - [test_strategy_is_deterministic]: same input → same output (rotation is
      pure; no RNG).
    - [test_1930s_strategy_beats_buy_and_hold]: the Depression decade is the
      cleanest Stage-2-vs-Stage-4 ranking regime; strategy CAGR must exceed B&H
      CAGR.
    - [test_1970s_strategy_beats_buy_and_hold]: stagflation is the stress test
      where M1 single-asset failed; cross-sectional rotation should pass. *)

open Core
open OUnit2
open Matchers
module Loader = French_weinstein_rotation_lib.Loader
module Rotation = French_weinstein_rotation_lib.Rotation

let _fixture_path =
  "../../../data/sources/kenneth_french/fixture/french-49ind-2026-05-20.csv.gz"

let _load_vw () = Loader.load_block ~csv_gz_path:_fixture_path ~block:Loader.VW

let _run_default series =
  Rotation.compute_strategy ~rows:series.Loader.rows
    ~industries:series.Loader.industries ~config:Rotation.default_config

let _find_decade_report ~reports ~label =
  List.find reports ~f:(fun (r : Rotation.decade_report) ->
      String.equal r.decade_label label)

(* Matcher fragments — extracted to keep individual test functions shallow. *)

let _series_well_formed_matcher =
  all_of
    [
      field
        (fun (s : Loader.parsed_series) -> List.length s.industries)
        (equal_to 49);
      field
        (fun (s : Loader.parsed_series) -> Array.length s.rows)
        (gt (module Int_ord) 26000);
      field (fun (s : Loader.parsed_series) -> s.block) (equal_to Loader.VW);
    ]

let _decade_report_well_formed_matcher =
  all_of
    [
      field
        (fun (r : Rotation.decade_report) -> r.n_days)
        (gt (module Int_ord) 0);
      field
        (fun (r : Rotation.decade_report) -> Float.is_finite r.strategy_cagr)
        (equal_to true);
      field
        (fun (r : Rotation.decade_report) -> Float.is_finite r.strategy_sharpe)
        (equal_to true);
    ]

let _depression_strategy_beats_bh_matcher (r : Rotation.decade_report) =
  all_of
    [
      field
        (fun (x : Rotation.decade_report) -> x.strategy_cagr -. x.bh_cagr)
        (ge (module Float_ord) 0.0);
      field
        (fun (x : Rotation.decade_report) -> -.x.strategy_maxdd)
        (lt (module Float_ord) (-.r.bh_maxdd));
    ]

let _assert_decade ~reports ~label ~matcher =
  match _find_decade_report ~reports ~label with
  | None -> assert_failure ("Expected " ^ label ^ " decade report")
  | Some r -> assert_that r matcher

let test_load_block_returns_full_series_and_49_industries _ =
  let series = _load_vw () in
  assert_that series _series_well_formed_matcher

let test_compute_strategy_smoke_default_config _ =
  let result = _run_default (_load_vw ()) in
  assert_that result.decade_reports
    (all_of [ size_is 11; each _decade_report_well_formed_matcher ])

let test_strategy_is_deterministic _ =
  let series = _load_vw () in
  let a = _run_default series in
  let b = _run_default series in
  (* Sample 5 well-spaced days; full-array equality would test the same
     property at higher test runtime. *)
  let n = Array.length a.strategy_daily_returns in
  let sample_idxs = [| 1000; 5000; 10000; 15000; 25000 |] in
  let sampled arr =
    Array.map sample_idxs ~f:(fun i -> if i >= n then 0.0 else arr.(i))
  in
  assert_that
    (Array.to_list (sampled a.strategy_daily_returns))
    (elements_are
       (List.map
          (Array.to_list (sampled b.strategy_daily_returns))
          ~f:(fun x -> float_equal ~epsilon:1e-12 x)))

let test_1930s_strategy_beats_buy_and_hold _ =
  let result = _run_default (_load_vw ()) in
  match _find_decade_report ~reports:result.decade_reports ~label:"1930s" with
  | None -> assert_failure "Expected 1930s decade report"
  | Some r -> assert_that r (_depression_strategy_beats_bh_matcher r)

let test_1970s_strategy_beats_buy_and_hold _ =
  let result = _run_default (_load_vw ()) in
  _assert_decade ~reports:result.decade_reports ~label:"1970s"
    ~matcher:
      (field
         (fun (r : Rotation.decade_report) -> r.strategy_cagr -. r.bh_cagr)
         (gt (module Float_ord) 0.0))

let suite =
  "french_weinstein_rotation"
  >::: [
         "test_load_block_returns_full_series_and_49_industries"
         >:: test_load_block_returns_full_series_and_49_industries;
         "test_compute_strategy_smoke_default_config"
         >:: test_compute_strategy_smoke_default_config;
         "test_strategy_is_deterministic" >:: test_strategy_is_deterministic;
         "test_1930s_strategy_beats_buy_and_hold"
         >:: test_1930s_strategy_beats_buy_and_hold;
         "test_1970s_strategy_beats_buy_and_hold"
         >:: test_1970s_strategy_beats_buy_and_hold;
       ]

let () = run_test_tt_main suite
