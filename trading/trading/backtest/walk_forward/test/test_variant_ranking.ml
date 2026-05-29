open OUnit2
open Matchers
module T = Walk_forward.Walk_forward_types
module VR = Walk_forward.Variant_ranking

(* Build a [variant_stability] from just the three ranked objectives; the other
   metric columns (return, cagr, holding) are not part of the Pareto comparison
   so they get a neutral stat. *)
let stat mean : T.per_metric_stats =
  { mean; stdev = 0.0; min = mean; max = mean }

let make_variant ~label ~sharpe ~calmar ~max_dd : T.variant_stability =
  {
    variant_label = label;
    total_return_pct = stat 0.0;
    sharpe_ratio = stat sharpe;
    max_drawdown_pct = stat max_dd;
    calmar_ratio = stat calmar;
    cagr_pct = stat 0.0;
    avg_holding_days = stat 0.0;
  }

(* Four-variant set with a known frontier (objectives: Sharpe up, Calmar up,
   MaxDD% down):
     A (1.0, 0.8, 20)  - frontier (best Sharpe)
     B (0.9, 0.9, 25)  - frontier (best Calmar)
     C (0.5, 0.4, 30)  - dominated by A, B and D
     D (0.8, 0.7, 15)  - frontier (best MaxDD)
   Only C is dominated; the other three trade off on a distinct axis. *)
let variants =
  [
    make_variant ~label:"A" ~sharpe:1.0 ~calmar:0.8 ~max_dd:20.0;
    make_variant ~label:"B" ~sharpe:0.9 ~calmar:0.9 ~max_dd:25.0;
    make_variant ~label:"C" ~sharpe:0.5 ~calmar:0.4 ~max_dd:30.0;
    make_variant ~label:"D" ~sharpe:0.8 ~calmar:0.7 ~max_dd:15.0;
  ]

let test_dominates_true _ =
  (* A strictly dominates C on all three axes. *)
  assert_that
    (VR.dominates
       (make_variant ~label:"A" ~sharpe:1.0 ~calmar:0.8 ~max_dd:20.0)
       (make_variant ~label:"C" ~sharpe:0.5 ~calmar:0.4 ~max_dd:30.0))
    (equal_to true)

let test_dominates_false_tradeoff _ =
  (* A has higher Sharpe but worse (larger) MaxDD than D, so neither dominates. *)
  assert_that
    (VR.dominates
       (make_variant ~label:"A" ~sharpe:1.0 ~calmar:0.8 ~max_dd:20.0)
       (make_variant ~label:"D" ~sharpe:0.8 ~calmar:0.7 ~max_dd:15.0))
    (equal_to false)

let test_dominates_false_equal _ =
  (* Equal on every axis: at-least-as-good holds but no strict improvement. *)
  assert_that
    (VR.dominates
       (make_variant ~label:"A" ~sharpe:1.0 ~calmar:0.8 ~max_dd:20.0)
       (make_variant ~label:"A2" ~sharpe:1.0 ~calmar:0.8 ~max_dd:20.0))
    (equal_to false)

let test_rank_frontier_and_dominators _ =
  let ranking = VR.rank variants in
  (* Frontier is A, B, D in input order; C is dominated by all three. *)
  assert_that ranking.frontier
    (elements_are [ equal_to "A"; equal_to "B"; equal_to "D" ]);
  assert_that ranking.variants
    (elements_are
       [
         all_of
           [
             field (fun v -> v.VR.label) (equal_to "A");
             field (fun v -> v.VR.on_frontier) (equal_to true);
             field (fun v -> v.VR.dominated_by) (elements_are []);
           ];
         all_of
           [
             field (fun v -> v.VR.label) (equal_to "B");
             field (fun v -> v.VR.on_frontier) (equal_to true);
             field (fun v -> v.VR.dominated_by) (elements_are []);
           ];
         all_of
           [
             field (fun v -> v.VR.label) (equal_to "C");
             field (fun v -> v.VR.on_frontier) (equal_to false);
             field
               (fun v -> v.VR.dominated_by)
               (elements_are [ equal_to "A"; equal_to "B"; equal_to "D" ]);
           ];
         all_of
           [
             field (fun v -> v.VR.label) (equal_to "D");
             field (fun v -> v.VR.on_frontier) (equal_to true);
             field (fun v -> v.VR.dominated_by) (elements_are []);
           ];
       ])

let test_rank_rejects_duplicate_labels _ =
  assert_raises
    (Invalid_argument
       "Variant_ranking.rank: duplicate variant label; labels must be unique")
    (fun () ->
      VR.rank
        [
          make_variant ~label:"A" ~sharpe:1.0 ~calmar:0.8 ~max_dd:20.0;
          make_variant ~label:"A" ~sharpe:0.5 ~calmar:0.4 ~max_dd:30.0;
        ])

(* Deterministic renderer: pin the exact markdown for the 4-variant set with a
   DSR provided for A only (so C/B/D show "n/a"). *)
let test_render_deterministic _ =
  let ranking = VR.rank variants in
  let md =
    VR.render ranking ~deflated_sharpe_by_label:[ ("A", 0.6281656469) ]
  in
  assert_that md
    (equal_to
       "## Pareto frontier (Sharpe up, Calmar up, MaxDD down)\n\n\
        - A\n\
        - B\n\
        - D\n\n\
        ## Variants\n\n\
        | Variant | Sharpe | Calmar | MaxDD % | Frontier | Deflated Sharpe |\n\
        |---------|-------:|-------:|--------:|:--------:|----------------:|\n\
        | A | 1.000 | 0.800 | 20.00 | yes | 0.6282 |\n\
        | B | 0.900 | 0.900 | 25.00 | yes | n/a |\n\
        | C | 0.500 | 0.400 | 30.00 | no | n/a |\n\
        | D | 0.800 | 0.700 | 15.00 | yes | n/a |")

let suite =
  "variant_ranking"
  >::: [
         "dominates_true" >:: test_dominates_true;
         "dominates_false_tradeoff" >:: test_dominates_false_tradeoff;
         "dominates_false_equal" >:: test_dominates_false_equal;
         "rank_frontier_and_dominators" >:: test_rank_frontier_and_dominators;
         "rank_rejects_duplicate_labels" >:: test_rank_rejects_duplicate_labels;
         "render_deterministic" >:: test_render_deterministic;
       ]

let () = run_test_tt_main suite
