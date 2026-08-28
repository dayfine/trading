(** G3 [reserve_cash_for_resting_tickets] — hold back the unfilled cost of
    still-resting entry tickets from the cash the entry walk may commit.

    {b The leak.} {!Entry_audit_capture.check_cash_and_deduct} already enforces
    cash discipline {i within} one tick, but its [remaining_cash] ref is
    re-seeded from [portfolio.cash] every tick. A ticket placed in week [N] and
    still resting in week [N+1] has drawn no cash, so the next walk commits the
    same money again. The observable consequence is that the walk keeps writing
    tickets the book cannot collectively fund.

    Four claims are pinned, each of which fails differently:

    - {b default is a no-op} — flag off admits exactly what it admitted before,
      whatever is resting. This is the R1 backward-compat claim, and it is the
      one a careless implementation breaks by reading the reserve
      unconditionally.
    - {b the reserve binds} — with the flag on, a resting ticket's cost is
      unavailable and a candidate that would otherwise be funded is not.
    - {b partial fills are not double-counted} — only the UNFILLED remainder is
      held back. An implementation charging [target_quantity] reserves cash that
      already left the book, and this is the case that catches it.
    - {b shorts are excluded} — an entering short credits cash on fill, so
      reserving against it would shrink the budget for a claim that pays in.

    Two more properties are pinned because they are cheap and their failure is
    silent: an empty book reserves exactly [0.0], and an over-committed book
    floors at [0.0] rather than producing a negative budget.

    The fixture reuses the narrow-stop construction from
    {!Test_entry_stop_width_order}: a 9.1% correction inside the support-floor
    lookback anchors a structural stop ~5% under entry, so every candidate here
    is comfortably inside [max_stop_distance_pct] and the stop-width gate is
    never what excludes anything. The only thing under test is the budget. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position

let _current_date = Date.of_string "2024-06-14"
let _sym_a = "AAA"
let _sym_b = "BBB"
let _resting = "RESTING"

let _bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* Rise to 110, correct 9.1% to 100, recover to a 105 close. The peak sits
   strictly before the last bar so {!Support_floor}'s counter-move scan range is
   non-empty — a series whose final bar IS the high falls through to the buffer
   and would make every candidate wide (the trap documented in
   test_entry_stop_width_order.ml). *)
let _closes =
  [
    100.0; 104.0; 108.0; 110.0; 106.0; 102.0; 100.0; 101.0; 103.0; 104.0; 105.0;
  ]

let _bars_for _symbol =
  List.mapi _closes ~f:(fun i close ->
      _bar
        ~date:(Date.add_days _current_date (i - List.length _closes + 1))
        ~close)

let _bar_reader =
  Bar_reader.of_in_memory_bars
    (List.map [ _sym_a; _sym_b; _resting ] ~f:(fun s -> (s, _bars_for s)))

let _stage_result : Stage.result =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
    ma_value = 100.0;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.01;
    transition = None;
    above_ma_count = 8;
  }

let _stock_analysis ~ticker : Stock_analysis.t =
  {
    ticker;
    stage = _stage_result;
    rs = None;
    volume = None;
    resistance = None;
    support = None;
    breakout_price = None;
    breakdown_price = None;
    local_range_top = None;
    prior_stage = None;
    continuation = None;
    supply = None;
    virgin_readmission = false;
    range_top_freshness = None;
    require_breakout_volume = true;
    current_close = None;
    as_of_date = _current_date;
  }

let _sector_context : Screener.sector_context =
  {
    sector_name = "Test";
    rating = Neutral;
    stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
  }

let _candidate ~ticker : Screener.scored_candidate =
  {
    ticker;
    analysis = _stock_analysis ~ticker;
    sector = _sector_context;
    side = Trading_base.Types.Long;
    grade = Weinstein_types.B;
    score = 60;
    suggested_entry = 105.0;
    suggested_stop = 100.0;
    risk_pct = 0.05;
    swing_target = None;
    rationale = [ "test breakout" ];
  }

let _candidates = [ _candidate ~ticker:_sym_a; _candidate ~ticker:_sym_b ]

let _config ~reserve =
  let base =
    Weinstein_strategy_config.default_config
      ~universe:[ _sym_a; _sym_b; _resting ]
      ~index_symbol:"SPY"
  in
  { base with reserve_cash_for_resting_tickets = reserve }

(* A position still in [Entering]: the ticket is written, the order rests. *)
let _entering ~symbol ~side ~target_quantity ~filled_quantity ~entry_price :
    Position.t =
  {
    id = symbol ^ "-pos";
    symbol;
    side;
    entry_reasoning = Position.PricePattern "test breakout";
    exit_reason = None;
    state =
      Position.Entering
        {
          target_quantity;
          entry_price;
          filled_quantity;
          created_date = _current_date;
        };
    last_updated = _current_date;
    portfolio_lot_ids = [];
  }

let _walk ~reserve ~cash ~positions =
  let portfolio =
    {
      Trading_strategy.Portfolio_view.cash;
      positions =
        String.Map.of_alist_exn
          (List.map positions ~f:(fun (p : Position.t) -> (p.id, p)));
    }
  in
  let stop_states = ref String.Map.empty in
  Entry_walk.entries_from_candidates ~config:(_config ~reserve)
    ~candidates:_candidates ~stop_states ~bar_reader:_bar_reader ~portfolio
    ~get_price:(fun _ -> None)
    ~current_date:_current_date ()
  |> List.filter_map ~f:(fun (t : Position.transition) ->
      match t.kind with Position.CreateEntering e -> Some e.symbol | _ -> None)

(* One resting LONG ticket for 500 shares at $100 = $50,000 committed, nothing
   filled yet. *)
let _resting_long ?(filled_quantity = 0.0) () =
  _entering ~symbol:_resting ~side:Trading_base.Types.Long
    ~target_quantity:500.0 ~filled_quantity ~entry_price:100.0

(** R1: with the flag OFF the resting ticket is invisible to the budget, so the
    walk admits exactly what it admits with an empty book. Asserted as an
    equality between the two admitted lists rather than against a hardcoded
    expectation, so the claim stays "the flag changes nothing" even if the
    fixture's funding arithmetic later shifts. *)
let test_default_off_is_a_no_op _ =
  let cash = 60_000.0 in
  assert_that
    (_walk ~reserve:false ~cash ~positions:[ _resting_long () ])
    (equal_to (_walk ~reserve:false ~cash ~positions:[]))

(** The reserve binds: $60k cash minus a $50k resting commitment leaves $10k,
    which funds strictly fewer candidates than the unreserved $60k does.

    Asserted as a strict-subset relation rather than an exact list because the
    point is that the budget shrank, not which particular name survived it. *)
let test_reserve_shrinks_the_admitted_set _ =
  let cash = 60_000.0 in
  let unreserved = _walk ~reserve:false ~cash ~positions:[ _resting_long () ] in
  let reserved = _walk ~reserve:true ~cash ~positions:[ _resting_long () ] in
  assert_that
    (List.length reserved < List.length unreserved
    && List.for_all reserved ~f:(List.mem unreserved ~equal:String.equal))
    (equal_to true)

(** Only the UNFILLED remainder is reserved. The ticket is 500 \@ $100, but 400
    are already filled — that $40,000 left [portfolio.cash] when the fill was
    applied, so reserving it again would charge it twice.

    With 400 filled, the reserve is $10,000, not $50,000, so the walk must admit
    the same set it would with a $10,000-smaller book and no ticket at all. An
    implementation that charges [target_quantity] reserves $50,000 here and
    admits strictly less. *)
let test_partial_fill_reserves_only_the_remainder _ =
  let cash = 60_000.0 in
  let with_partial =
    _walk ~reserve:true ~cash
      ~positions:[ _resting_long ~filled_quantity:400.0 () ]
  in
  let equivalent_smaller_book =
    _walk ~reserve:true ~cash:(cash -. 10_000.0) ~positions:[]
  in
  assert_that with_partial (equal_to equivalent_smaller_book)

(** An entering SHORT credits cash on fill, so it must not be reserved against.
    Same $50k-notional ticket as the long case; the admitted set must match the
    no-ticket book exactly. *)
let test_entering_short_is_not_reserved _ =
  let cash = 60_000.0 in
  let short_ticket =
    _entering ~symbol:_resting ~side:Trading_base.Types.Short
      ~target_quantity:500.0 ~filled_quantity:0.0 ~entry_price:100.0
  in
  assert_that
    (_walk ~reserve:true ~cash ~positions:[ short_ticket ])
    (equal_to (_walk ~reserve:true ~cash ~positions:[]))

(** An over-committed book — more resting than cash — floors the budget at zero
    rather than going negative. Reaching this state is possible by arming the
    flag on a book that over-committed while it was off, so it is a real path
    and not a defensive nicety. A negative budget would compare as
    [cost <= remaining_cash] false for everything, which happens to look like
    the right answer; the failure it guards is a negative number reaching the
    sizing math, so the assertion is that nothing is admitted and the walk
    returns cleanly. *)
let test_over_committed_book_floors_at_zero _ =
  let over_committed =
    _entering ~symbol:_resting ~side:Trading_base.Types.Long
      ~target_quantity:5_000.0 ~filled_quantity:0.0 ~entry_price:100.0
  in
  assert_that
    (_walk ~reserve:true ~cash:10_000.0 ~positions:[ over_committed ])
    (size_is 0)

(** With nothing resting the reserve is exactly zero, so an armed book and an
    unarmed one admit the same set. Guards the arming itself from carrying a
    constant cost — the shape [cash - something_always_positive] would pass
    every test above and fail this one. *)
let test_empty_book_reserves_nothing _ =
  let cash = 60_000.0 in
  assert_that
    (_walk ~reserve:true ~cash ~positions:[])
    (equal_to (_walk ~reserve:false ~cash ~positions:[]))

let suite =
  "reserve_cash_for_resting_tickets"
  >::: [
         "default off is a no-op" >:: test_default_off_is_a_no_op;
         "reserve shrinks the admitted set"
         >:: test_reserve_shrinks_the_admitted_set;
         "partial fill reserves only the remainder"
         >:: test_partial_fill_reserves_only_the_remainder;
         "entering short is not reserved"
         >:: test_entering_short_is_not_reserved;
         "over-committed book floors at zero"
         >:: test_over_committed_book_floors_at_zero;
         "empty book reserves nothing" >:: test_empty_book_reserves_nothing;
       ]

let () = run_test_tt_main suite
