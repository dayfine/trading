(** Tests for the long-side maintenance force-reduce (margin M2).

    Pins the design center — the weakest-first incremental reduce ORDERING and
    the default-off (R1) invariant — at unit scope on the pure
    {!Trading_simulation.Long_maintenance} selector, plus the wired
    transition-builder (Friday cadence, [maintenance_reduce] exit tag, equity
    derived from the M1b-2 long-margin debit). *)

open OUnit2
open Core
open Matchers
module Long_maintenance = Trading_simulation.Long_maintenance
module Portfolio = Trading_portfolio.Portfolio
module Position = Trading_strategy.Position

(* ------------------------------------------------------------------ *)
(* Fixtures                                                            *)
(* ------------------------------------------------------------------ *)

(* Three longs, all 100 shares @ entry 100, marked so their unrealized returns
   are distinct: C = -20% (weakest), A = -10%, B = +10% (strongest).
   Marked values: A = 9_000, B = 11_000, C = 8_000; total exposure = 28_000. *)
let _hold ~id ~mark =
  {
    Long_maintenance.position_id = id;
    symbol = id;
    quantity = 100.0;
    entry_price = 100.0;
    mark;
  }

let _holdings =
  [
    _hold ~id:"A" ~mark:90.0;
    _hold ~id:"B" ~mark:110.0;
    _hold ~id:"C" ~mark:80.0;
  ]

let _friday = Date.of_string "2024-04-05" (* Friday *)
let _monday = Date.of_string "2024-04-08" (* Monday *)
let _prices = [ ("A", 90.0); ("B", 110.0); ("C", 80.0) ]

let _ids reductions =
  List.map reductions ~f:(fun h -> h.Long_maintenance.position_id)

(* Exposure remaining after the selector sheds [reductions]. *)
let _remaining_exposure reductions =
  let shed = String.Set.of_list (_ids reductions) in
  List.sum
    (module Float)
    _holdings
    ~f:(fun h ->
      if Set.mem shed h.Long_maintenance.position_id then 0.0
      else h.quantity *. h.mark)

(* Build a Position.t in the Holding state (mirrors the strategy runner tests). *)
let _make_holding ~id ~entry ~qty =
  let make_trans kind = { Position.position_id = id; date = _friday; kind } in
  let unwrap = function
    | Ok p -> p
    | Error _ -> assert_failure "position setup failed"
  in
  let open Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol = id;
              side = Trading_base.Types.Long;
              target_quantity = qty;
              entry_price = entry;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = qty; fill_price = entry }))
    |> unwrap
  in
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

let _positions_map ids =
  List.map ids ~f:(fun id -> (id, _make_holding ~id ~entry:100.0 ~qty:100.0))
  |> Map.of_alist_exn (module String)

(* Portfolio whose [equity_cash = current_cash - long_margin_debit]. With the
   28_000 marked exposure, [equity = equity_cash + 28_000]. *)
let _portfolio ~current_cash ~debit =
  let base = Portfolio.create ~initial_cash:100_000.0 () in
  { base with current_cash; long_margin_debit = debit }

(* ------------------------------------------------------------------ *)
(* Pure selector — the design center                                  *)
(* ------------------------------------------------------------------ *)

(* R1: at the default pct the reduce never fires, even with equity wiped far
   below any exposure — old baselines replay bit-identically. *)
let test_default_pct_never_fires _ =
  assert_that
    (Long_maintenance.select_reductions ~equity:(-50_000.0)
       ~maintenance_long_pct:0.0 ~holdings:_holdings)
    (size_is 0)

(* An unlevered / well-capitalised book (ratio above the requirement) is not
   reduced. equity 33_600 / exposure 28_000 = 1.2 >= 0.30. *)
let test_no_breach_returns_empty _ =
  assert_that
    (Long_maintenance.select_reductions ~equity:33_600.0
       ~maintenance_long_pct:0.30 ~holdings:_holdings)
    (size_is 0)

let test_empty_holdings_no_op _ =
  assert_that
    (Long_maintenance.select_reductions ~equity:6_000.0
       ~maintenance_long_pct:0.30 ~holdings:[])
    (size_is 0)

(* Breach (equity 6_000 / 28_000 = 0.214 < 0.30): sheds weakest first — C
   (-20%) then A (-10%) — and stops, leaving the strongest (B, +10%) untouched.
   target ratio = 0.30*1.02 = 0.306, target exposure = 6000/0.306 = 19_608:
   shed C (28_000->20_000), shed A (20_000->11_000 <= 19_608) stop. *)
let test_breach_sheds_weakest_first _ =
  assert_that
    (_ids
       (Long_maintenance.select_reductions ~equity:6_000.0
          ~maintenance_long_pct:0.30 ~holdings:_holdings))
    (elements_are [ equal_to "C"; equal_to "A" ])

(* Incremental: the restored ratio (equity / remaining exposure) clears the
   buffered target, confirming we sold exactly enough and no more. Remaining is
   just B (11_000): 6_000 / 11_000 = 0.545 >= 0.30. *)
let test_reduction_restores_ratio _ =
  let reductions =
    Long_maintenance.select_reductions ~equity:6_000.0
      ~maintenance_long_pct:0.30 ~holdings:_holdings
  in
  assert_that
    (6_000.0 /. _remaining_exposure reductions)
    (ge (module Float_ord) 0.30)

(* An insolvent book (equity <= 0) cannot restore the ratio at any positive
   exposure, so every holding is shed (weakest-first order preserved). *)
let test_equity_wiped_liquidates_all _ =
  assert_that
    (_ids
       (Long_maintenance.select_reductions ~equity:(-1_000.0)
          ~maintenance_long_pct:0.30 ~holdings:_holdings))
    (elements_are [ equal_to "C"; equal_to "A"; equal_to "B" ])

(* ------------------------------------------------------------------ *)
(* Wired transition builder                                            *)
(* ------------------------------------------------------------------ *)

(* Matcher: the transition is a TriggerExit tagged [maintenance_reduce] with the
   given exit price (the mark). *)
let _is_maintenance_exit ~exit_price =
  field
    (fun (t : Position.transition) -> t.kind)
    (matching ~msg:"TriggerExit maintenance_reduce"
       (function
         | Position.TriggerExit
             {
               exit_reason = Position.StrategySignal { label; _ };
               exit_price = ep;
             }
           when String.equal label "maintenance_reduce" ->
             Some ep
         | _ -> None)
       (float_equal exit_price))

(* On a Friday under a levered breach (current_cash 0, debit 22_000 =>
   equity_cash -22_000 => equity 6_000), the runner emits maintenance_reduce
   exits for the weakest-first pick C then A. Pins both the exit tag and the
   fact that equity is derived from the long-margin debit. *)
let test_friday_breach_emits_tagged_reduces _ =
  assert_that
    (Long_maintenance.maintenance_reduce_transitions ~maintenance_long_pct:0.30
       ~portfolio:(_portfolio ~current_cash:0.0 ~debit:22_000.0)
       ~positions:(_positions_map [ "A"; "B"; "C" ])
       ~prices:_prices ~date:_friday)
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Position.transition) -> t.position_id)
               (equal_to "C");
             _is_maintenance_exit ~exit_price:80.0;
           ];
         all_of
           [
             field
               (fun (t : Position.transition) -> t.position_id)
               (equal_to "A");
             _is_maintenance_exit ~exit_price:90.0;
           ];
       ])

(* Weekly cadence: the same breaching state on a Monday emits nothing. *)
let test_non_friday_no_op _ =
  assert_that
    (Long_maintenance.maintenance_reduce_transitions ~maintenance_long_pct:0.30
       ~portfolio:(_portfolio ~current_cash:0.0 ~debit:22_000.0)
       ~positions:(_positions_map [ "A"; "B"; "C" ])
       ~prices:_prices ~date:_monday)
    (size_is 0)

(* No debit (equity_cash = current_cash = 5_000 => equity 33_000, ratio 1.18):
   an unlevered book never fires even at a positive requirement on a Friday. *)
let test_unlevered_no_debit_no_op _ =
  assert_that
    (Long_maintenance.maintenance_reduce_transitions ~maintenance_long_pct:0.30
       ~portfolio:(_portfolio ~current_cash:5_000.0 ~debit:0.0)
       ~positions:(_positions_map [ "A"; "B"; "C" ])
       ~prices:_prices ~date:_friday)
    (size_is 0)

(* No held positions => nothing to reduce, even under a live requirement. *)
let test_no_positions_no_op _ =
  assert_that
    (Long_maintenance.maintenance_reduce_transitions ~maintenance_long_pct:0.30
       ~portfolio:(_portfolio ~current_cash:0.0 ~debit:22_000.0)
       ~positions:(Map.empty (module String))
       ~prices:_prices ~date:_friday)
    (size_is 0)

let suite =
  "long_maintenance"
  >::: [
         "default pct never fires (R1)" >:: test_default_pct_never_fires;
         "no breach => empty" >:: test_no_breach_returns_empty;
         "empty holdings => no-op" >:: test_empty_holdings_no_op;
         "breach sheds weakest-first" >:: test_breach_sheds_weakest_first;
         "reduction restores ratio (incremental)"
         >:: test_reduction_restores_ratio;
         "equity wiped => liquidates all" >:: test_equity_wiped_liquidates_all;
         "friday breach emits tagged reduces"
         >:: test_friday_breach_emits_tagged_reduces;
         "non-friday => no-op (weekly cadence)" >:: test_non_friday_no_op;
         "unlevered (no debit) => no-op" >:: test_unlevered_no_debit_no_op;
         "no positions => no-op" >:: test_no_positions_no_op;
       ]

let () = run_test_tt_main suite
