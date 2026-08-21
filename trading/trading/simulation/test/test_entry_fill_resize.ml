(** Unit tests for {!Entry_fill_resize} — G2b, the affordable-size clamp a
    portfolio-refused entry fill gets instead of the ticket being destroyed
    ([dev/plans/ticket-funding-2026-08-16.md] §G2b).

    The contracts pinned here, one test each:

    - {b R1 no-op when disabled.} The three inputs come back untouched — no
      clamped fill, no portfolio movement — so the simulator's fill/cancel
      pipeline sees exactly what it saw before G2b existed.
    - {b The near-miss case.} A 0.3% shortfall — the plan's motivating [PRGS]
      case — becomes a 99-of-100-share fill at the triggered price.
    - {b The minimum size is real.} A 60% shortfall is refused at the default
      [0.5] and claimed at [0.0], so the guard tracks the config value rather
      than being hardcoded.
    - {b The caps still bind.} With cash to spare the clamp stops at the
      {e designed} quantity — the number
      [Weinstein_portfolio_risk.compute_position_size] already capped by
      [max_position_pct] and the exposure limits — never above it.
    - {b G2a precedence.} A refusal the resize claims never reaches
      {!Entry_fill_retry}, so no retry budget is spent on it.
    - {b Issue #2466.} A rejected {e exit} is never claimed (wrong side), and a
      claimed {e entry} never reaches {!Cancel_handler.revert_rejected_exits} —
      whose symbol-only match would otherwise revert an [Exiting] sibling on the
      same symbol.
    - {b The cash-floor solve.} {!Entry_fill_resize.affordable_quantity} is the
      exact inverse of [Portfolio]'s floor, paper-loss drag included. *)

open OUnit2
open Core
open Matchers
module Entry_fill_resize = Trading_simulation.Entry_fill_resize
module Entry_fill_retry = Trading_simulation.Entry_fill_retry
module Cancel_handler = Trading_simulation.Cancel_handler
module Position = Trading_strategy.Position
module Manager = Trading_orders.Manager
module Order_types = Trading_orders.Types
module Portfolio = Trading_portfolio.Portfolio

let _date ~y ~m ~d = Date.create_exn ~y ~m ~d
let _fixture_date = _date ~y:2024 ~m:Month.Jan ~d:10

(* The ticket under test throughout: 100 shares of SPY designed at $50, i.e.
   $5,000 of stock plus $1 of commission. *)
let _designed_quantity = 100.0
let _fill_price = 50.0
let _commission = 1.0
let _designed_cost = (_designed_quantity *. _fill_price) +. _commission

let _entering_position ?(id = "SPY-entering") ?(symbol = "SPY")
    ?(side = Trading_base.Types.Long) () : Position.t =
  {
    id;
    symbol;
    side;
    entry_reasoning = Position.ManualDecision { description = "test fixture" };
    exit_reason = None;
    state =
      Position.Entering
        {
          target_quantity = _designed_quantity;
          entry_price = _fill_price;
          filled_quantity = 0.0;
          created_date = _fixture_date;
        };
    last_updated = _fixture_date;
    portfolio_lot_ids = [];
  }

let _exiting_position ?(id = "SPY-exiting") ?(symbol = "SPY") () : Position.t =
  {
    id;
    symbol;
    side = Trading_base.Types.Long;
    entry_reasoning = Position.ManualDecision { description = "test fixture" };
    exit_reason = None;
    state =
      Position.Exiting
        {
          quantity = 40.0;
          entry_price = 30.0;
          entry_date = _fixture_date;
          target_quantity = 40.0;
          exit_price = 28.0;
          filled_quantity = 0.0;
          started_date = _fixture_date;
          risk_params =
            {
              stop_loss_price = None;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
    last_updated = _fixture_date;
    portfolio_lot_ids = [];
  }

let _positions_with entries : Position.t String.Map.t =
  List.fold entries ~init:String.Map.empty ~f:(fun acc (pos : Position.t) ->
      Map.set acc ~key:pos.id ~data:pos)

let _trade ?(symbol = "SPY") ?(side = Trading_base.Types.Buy)
    ?(quantity = _designed_quantity) ?(order_id = "2024-01-10-001") () :
    Trading_base.Types.trade =
  {
    id = "trade-1";
    order_id;
    symbol;
    side;
    quantity;
    price = _fill_price;
    commission = _commission;
    timestamp = Time_ns_unix.epoch;
  }

let _portfolio ~cash = Portfolio.create ~initial_cash:cash ()

(* Claim one refused trade against a book holding [cash], with the standard
   long-entry ticket resting. *)
let _claim_one ?(positions = _positions_with [ _entering_position () ])
    ?(trade = _trade ()) ~policy ~cash () =
  Entry_fill_resize.claim policy ~initial_long_margin_req:1.0
    ~portfolio:(_portfolio ~cash) ~positions ~accepted:[]
    ~rejected_trades:[ trade ]

let _quantities trades =
  List.map trades ~f:(fun (t : Trading_base.Types.trade) -> t.quantity)

let _armed ?(min_size_fraction = 0.5) () =
  Entry_fill_resize.create ~enabled:true ~min_size_fraction

(** R1: disabled is an exact no-op. The refused trade comes back for the
    unchanged death path, nothing is added to the accepted list, and the
    portfolio's cash is untouched — the three surfaces the pre-G2b pipeline had.
*)
let test_disabled_is_a_no_op _ =
  let portfolio, accepted, still_rejected =
    _claim_one ~policy:Entry_fill_resize.disabled ~cash:1.0 ()
  in
  assert_that
    (_quantities accepted, _quantities still_rejected, portfolio.current_cash)
    (equal_to ([], [ _designed_quantity ], 1.0))

(** The plan's motivating case: [PRGS] was short by {b 0.3%} of the ticket's
    cost and lost the whole ticket. Here the book is short by the same margin,
    and the clamp turns that into a 99-of-100-share fill — at [_fill_price], the
    price the ticket triggered at, with no timing tax. Cash falls by the clamped
    cost, so the fill really was booked. *)
let test_near_miss_shortfall_becomes_a_near_full_fill _ =
  let cash = _designed_cost *. 0.997 in
  let portfolio, accepted, still_rejected =
    _claim_one ~policy:(_armed ()) ~cash ()
  in
  assert_that
    ( _quantities accepted,
      _quantities still_rejected,
      Float.round_decimal ~decimal_digits:4 (cash -. portfolio.current_cash) )
    (equal_to ([ 99.0 ], [], (99.0 *. _fill_price) +. _commission))

(** A 60% shortfall clamps to well under half the designed size, so the default
    [0.5] guard refuses it: the ticket dies exactly as it does today and the
    portfolio is untouched. Without the guard this would book a token position
    carrying the trade's costs and a fraction of its intended exposure. *)
let test_deep_shortfall_is_refused_by_the_minimum_fraction _ =
  let cash = _designed_cost *. 0.4 in
  let portfolio, accepted, still_rejected =
    _claim_one ~policy:(_armed ()) ~cash ()
  in
  assert_that
    (_quantities accepted, _quantities still_rejected, portfolio.current_cash)
    (equal_to ([], [ _designed_quantity ], cash))

(** The same 60% shortfall {e is} claimed at [min_size_fraction = 0.0], so the
    refusal above is the configured guard firing and not an internal floor. 39
    shares is [floor ((0.4 * 5001 - 1) / 50)]. *)
let test_minimum_fraction_zero_accepts_the_deep_clamp _ =
  let _portfolio_out, accepted, still_rejected =
    _claim_one
      ~policy:(_armed ~min_size_fraction:0.0 ())
      ~cash:(_designed_cost *. 0.4) ()
  in
  assert_that
    (_quantities accepted, _quantities still_rejected)
    (equal_to ([ 39.0 ], []))

(** The caps still bind. With cash for ~20,000 shares the clamp stops at the
    designed 100 — the quantity [Weinstein_portfolio_risk.compute_position_size]
    already capped by [max_position_pct], the side-exposure limit and the risk
    budget. A resize only ever moves {e down} from that number. *)
let test_clamp_never_exceeds_the_designed_quantity _ =
  let _portfolio_out, accepted, still_rejected =
    _claim_one ~policy:(_armed ()) ~cash:1_000_000.0 ()
  in
  assert_that
    (_quantities accepted, _quantities still_rejected)
    (equal_to ([ _designed_quantity ], []))

(** [min_size_fraction = 1.0] is {b not} a no-op — the config docstring pins
    this. The guard is a strict [<] against [fraction *. designed], so a clamp
    {e equal} to the designed quantity books (ample-cash case), while one share
    short of designed is refused. A grid control cell must use the disabled
    flag, never [1.0]. *)
let test_fraction_one_books_only_a_full_size_clamp _ =
  let full_portfolio, full_accepted, full_rejected =
    _claim_one ~policy:(_armed ~min_size_fraction:1.0 ()) ~cash:1_000_000.0 ()
  in
  ignore full_portfolio;
  assert_that
    (_quantities full_accepted, _quantities full_rejected)
    (equal_to ([ _designed_quantity ], []));
  let short_portfolio, short_accepted, short_rejected =
    _claim_one
      ~policy:(_armed ~min_size_fraction:1.0 ())
      ~cash:(_designed_cost *. 0.997) ()
  in
  assert_that
    ( _quantities short_accepted,
      _quantities short_rejected,
      short_portfolio.current_cash )
    (equal_to ([], [ _designed_quantity ], _designed_cost *. 0.997))

(** A refused {e short} entry is never claimed: its cash change is an inflow, so
    shrinking the quantity makes the floor {e harder} to satisfy and no clamp
    can rescue it. It passes straight through to the unchanged path. *)
let test_short_entry_refusal_is_never_claimed _ =
  let _portfolio_out, accepted, still_rejected =
    _claim_one
      ~positions:
        (_positions_with
           [ _entering_position ~side:Trading_base.Types.Short () ])
      ~trade:(_trade ~side:Trading_base.Types.Sell ())
      ~policy:(_armed ()) ~cash:1.0 ()
  in
  assert_that
    (_quantities accepted, _quantities still_rejected)
    (equal_to ([], [ _designed_quantity ]))

(** {!Entry_fill_resize.affordable_quantity} inverts [Portfolio]'s cash floor
    exactly, paper-loss drag included: with \$5,000 cash and \$500 of open paper
    losses the budget is \$4,499 after the \$1 commission, i.e. 89 whole shares
    at \$50. A Sell has no affordable size at all. *)
let test_affordable_quantity_solves_the_cash_floor _ =
  let portfolio =
    {
      (_portfolio ~cash:5_000.0) with
      unrealized_pnl_per_position = [ ("AAA", -500.0); ("BBB", 250.0) ];
    }
  in
  assert_that
    ( Entry_fill_resize.affordable_quantity ~portfolio ~trade:(_trade ()),
      Entry_fill_resize.affordable_quantity ~portfolio
        ~trade:(_trade ~side:Trading_base.Types.Sell ()) )
    (equal_to (89.0, 0.0))

(* One refusal routed through the real G2b -> G2a chain the simulator runs, at
   a cash level the resize can serve. Returns the retries G2a spent. *)
let _retries_spent_after_resize ~policy =
  let positions = _positions_with [ _entering_position () ] in
  let manager = Manager.create () in
  let submitted =
    Manager.submit_orders manager
      [
        {
          Order_types.id = "2024-01-10-001";
          symbol = "SPY";
          side = Trading_base.Types.Buy;
          order_type = Trading_base.Types.Market;
          quantity = _designed_quantity;
          time_in_force = Order_types.Day;
          status = Order_types.Filled;
          filled_quantity = _designed_quantity;
          avg_fill_price = Some _fill_price;
          created_at = Time_ns_unix.epoch;
          updated_at = Time_ns_unix.epoch;
        };
      ]
  in
  assert_that submitted (elements_are [ is_ok ]);
  let ledger = Entry_fill_retry.create ~max_retries:2 in
  let _portfolio_out, _accepted, still_rejected =
    _claim_one ~positions ~policy ~cash:(_designed_cost *. 0.997) ()
  in
  let (_ : Trading_base.Types.trade list) =
    Entry_fill_retry.handle_rejected_entries ledger ~order_manager:manager
      ~positions ~rejected_trades:still_rejected
  in
  Entry_fill_retry.retries_used ledger ~position_id:"SPY-entering"

(** Precedence: the resize is offered first, so a refusal it claims never
    reaches G2a and spends no retry budget. With the resize disabled the same
    refusal consumes one retry — which is what makes the ordering observable
    rather than incidental. *)
let test_resize_claims_before_retry_budget_is_spent _ =
  assert_that
    ( _retries_spent_after_resize ~policy:(_armed ()),
      _retries_spent_after_resize ~policy:Entry_fill_resize.disabled )
    (equal_to (0, 1))

(** Issue #2466, half one: a rejected {e exit} is never claimed here, because
    the [Entering] match requires the side that {e opens} the position ([Buy]
    for a long) and an exit fill is a [Sell]. It therefore still reaches
    {!Cancel_handler.revert_rejected_exits}, which reverts the stuck [Exiting]
    position to [Holding] as it has since #1553. *)
let test_rejected_exit_passes_through_to_the_exit_revert _ =
  let positions =
    _positions_with [ _entering_position (); _exiting_position () ]
  in
  let _portfolio_out, accepted, still_rejected =
    _claim_one ~positions
      ~trade:(_trade ~side:Trading_base.Types.Sell ~quantity:40.0 ())
      ~policy:(_armed ()) ~cash:1_000_000.0 ()
  in
  let reverted =
    Cancel_handler.revert_rejected_exits ~date:_fixture_date ~positions
      ~rejected_trades:still_rejected
  in
  assert_that
    (_quantities accepted, Map.find reverted "SPY-exiting")
    (equal_to
       ( [],
         Some
           (Map.find_exn
              (_positions_with
                 [
                   {
                     (_exiting_position ()) with
                     state =
                       Position.Holding
                         {
                           quantity = 40.0;
                           entry_price = 30.0;
                           entry_date = _fixture_date;
                           risk_params =
                             {
                               stop_loss_price = None;
                               take_profit_price = None;
                               max_hold_days = None;
                             };
                         };
                     exit_reason = None;
                   };
                 ])
              "SPY-exiting") ))

(** Issue #2466, half two: a claimed {e entry} rejection is removed from the
    list the caller hands to {!Cancel_handler.revert_rejected_exits}, so the
    [Exiting] sibling on the same symbol survives. That scan matches on symbol
    alone, so leaving the claimed entry in the list would silently revert a live
    exit — the hazard #2466 records. *)
let test_claimed_entry_never_reaches_the_exit_revert_scan _ =
  let positions =
    _positions_with [ _entering_position (); _exiting_position () ]
  in
  let _portfolio_out, accepted, still_rejected =
    _claim_one ~positions ~policy:(_armed ()) ~cash:1_000_000.0 ()
  in
  let after_revert =
    Cancel_handler.revert_rejected_exits ~date:_fixture_date ~positions
      ~rejected_trades:still_rejected
  in
  assert_that
    ( _quantities accepted,
      _quantities still_rejected,
      Map.find after_revert "SPY-exiting" |> Option.map ~f:Position.get_state )
    (equal_to
       ( [ _designed_quantity ],
         [],
         Some (Position.get_state (_exiting_position ())) ))

let suite =
  "entry_fill_size_to_available"
  >::: [
         "disabled is a no-op" >:: test_disabled_is_a_no_op;
         "near-miss shortfall becomes a near-full fill"
         >:: test_near_miss_shortfall_becomes_a_near_full_fill;
         "deep shortfall is refused by the minimum fraction"
         >:: test_deep_shortfall_is_refused_by_the_minimum_fraction;
         "minimum fraction 0.0 accepts the deep clamp"
         >:: test_minimum_fraction_zero_accepts_the_deep_clamp;
         "clamp never exceeds the designed quantity"
         >:: test_clamp_never_exceeds_the_designed_quantity;
         "fraction 1.0 books only a full-size clamp"
         >:: test_fraction_one_books_only_a_full_size_clamp;
         "short entry refusal is never claimed"
         >:: test_short_entry_refusal_is_never_claimed;
         "affordable_quantity solves the cash floor"
         >:: test_affordable_quantity_solves_the_cash_floor;
         "resize claims before retry budget is spent"
         >:: test_resize_claims_before_retry_budget_is_spent;
         "rejected exit passes through to the exit revert"
         >:: test_rejected_exit_passes_through_to_the_exit_revert;
         "claimed entry never reaches the exit revert scan"
         >:: test_claimed_entry_never_reaches_the_exit_revert_scan;
       ]

let () = run_test_tt_main suite
