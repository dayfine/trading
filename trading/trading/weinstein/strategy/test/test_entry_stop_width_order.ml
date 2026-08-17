(** Defect B: §5.1's "prefer other candidates" as a rank demotion rather than a
    ban — {!Weinstein_strategy.Entry_stop_width_order} plus its wiring into the
    entry walk.

    Three layers are pinned:
    - the ordering pass itself — that wide-stop candidates move behind
      narrow-stop ones, that the partition is {b stable} within each group, and
      that the other two modes leave the list untouched;
    - the walk under ample capital, where the only observable is the {e order}
      entries are emitted (and therefore charged) in;
    - the walk under a binding budget, where that order becomes a
      {b different admitted set} — the whole behavioural difference between
      [Size_down] and [Demote_over_max], since sizing never reads the mode.

    {b Two of each width}, not one, because a single candidate per group makes
    stability unobservable: [List.rev narrow @ List.rev wide] would pass a
    membership-only assertion, and candidate order determines capital
    allocation.

    The fixture separates the groups the way the real screener would, not by
    stubbing the width: the [NARROW] history contains a 9.1% correction inside
    the support-floor lookback, so a structural floor is found ~5% under entry;
    the [WIDE] symbols have a single flat bar, no correction to find, so the
    stop falls back to [initial_stop_buffer] at 67% — far outside the 15% limit.
    The first assertion checks that separation directly, so a fixture that stops
    separating cannot masquerade as a passing demotion; the first version of it
    put the peak on the last bar, which left the counter-move scan range empty
    and made every candidate wide. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position

let _current_date = Date.of_string "2024-06-14"

(* Two of each, so the partition's STABILITY is observable. With one candidate
   per group, [List.rev narrow @ List.rev wide] — or any non-stable sort —
   passes every assertion in this file unchanged, and candidate order determines
   capital allocation, so a silent re-rank of the majority population would be a
   reproducibility defect rather than a style nit. *)
let _narrow_a = "NARROWA"
let _narrow_b = "NARROWB"
let _wide_a = "WIDEA"
let _wide_b = "WIDEB"

(* The stop the fallback installs for a symbol with no correction to anchor on.
   Chosen well outside [max_stop_distance_pct = 0.15] so [WIDE] is unambiguously
   over the book limit. Shared with the existing F3 fixture in
   [test_entry_audit_capture.ml]. *)
let _wide_buffer = 0.6667

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

(* Rise to a 110 peak, correct 9.1% to 100, recover to a 105 close. The peak
   must sit strictly {i before} the last bar: {!Support_floor} anchors on the
   window's highest high and then scans only the bars {i newer} than that anchor
   for the correction low, so a series whose final bar {i is} the high has an
   empty counter-move range and falls through to the buffer — which is how the
   first version of this fixture silently made both candidates wide.

   (110 - 100) / 110 = 9.1% clears [min_correction_pct = 0.08], so the floor
   anchors at 100 and the installed stop lands ~5% under the 105 entry: inside
   the 15% limit. *)
let _narrow_bars =
  let closes =
    [
      100.0;
      104.0;
      108.0;
      110.0;
      106.0;
      102.0;
      100.0;
      101.0;
      103.0;
      104.0;
      105.0;
    ]
  in
  List.mapi closes ~f:(fun i close ->
      _bar ~date:(Date.add_days _current_date (-10 + i)) ~close)

(* A single flat bar: no correction for the support-floor scan to anchor on, so
   the stop falls through to [initial_stop_buffer] and the candidate is wide. *)
let _flat_bars = [ _bar ~date:_current_date ~close:100.0 ]

(* [NOBARS] carries no history at all. It is here because the mli claims this is
   NOT a special case — [latest_close] returns [None], the entry falls back to
   the candidate's own [suggested_entry], the floor scan finds nothing, and the
   buffer fallback classifies it wide, exactly as the gate would. *)
let _nobars = "NOBARS"

(* [ZEROENTRY] is the OTHER unmeasurable shape, and the one the mli's second
   carve-out is about: no resident bars AND a [suggested_entry] the screener left
   at zero, so the effective entry resolves to 0.0 and [|stop - E| / E] has no
   answer. It is deliberately distinct from [NOBARS], which is measurable — its
   entry falls back to a POSITIVE [suggested_entry], so it gets classified (and
   demoted) like any other candidate. *)
let _zero_entry = "ZEROENTRY"

let _bar_reader =
  Bar_reader.of_in_memory_bars
    [
      (_narrow_a, _narrow_bars);
      (_narrow_b, _narrow_bars);
      (_wide_a, _flat_bars);
      (_wide_b, _flat_bars);
    ]

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
    suggested_entry = 100.0;
    suggested_stop = 95.0;
    risk_pct = 0.05;
    swing_target = None;
    rationale = [ "test breakout" ];
  }

(* Interleaved, and a wide one FIRST, so that leaving the order alone is
   observably different from demoting AND a non-stable partition is observably
   different from a stable one. *)
let _candidates =
  List.map
    ~f:(fun ticker -> _candidate ~ticker)
    [ _wide_a; _narrow_a; _wide_b; _narrow_b ]

let _config ?(sector_cap = None) ~mode ~ceiling () =
  let base =
    Weinstein_strategy_config.default_config
      ~universe:[ _wide_a; _wide_b; _narrow_a; _narrow_b ]
      ~index_symbol:"SPY"
  in
  {
    base with
    initial_stop_buffer = _wide_buffer;
    stop_width_mode = mode;
    stop_width_size_down_max_pct = ceiling;
    portfolio_config =
      { base.portfolio_config with max_sector_exposure_pct = sector_cap };
  }

let _order_under ~mode ~ceiling =
  Entry_stop_width_order.prefer_narrow_stops
    ~config:(_config ~mode ~ceiling ())
    ~bar_reader:_bar_reader ~current_date:_current_date _candidates
  |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.ticker)

(** The fixture is only meaningful if the candidates really do land on opposite
    sides of the 15% limit, and the assertion is on the FULL permutation rather
    than on group membership — which is what pins the partition's {b stability}.
    Input is [WIDE_A; NARROW_A; WIDE_B; NARROW_B]; a stable partition yields
    [NARROW_A; NARROW_B; WIDE_A; WIDE_B]. Any non-stable sort, or
    [List.rev narrow @ List.rev wide], produces a different permutation and
    fails here.

    Asserted first, and separately, so a failure reads as "the fixture stopped
    separating them" rather than as "the demotion broke". *)
let test_partition_is_stable_and_separates _ =
  assert_that
    (_order_under ~mode:Stop_width_mode.Demote_over_max ~ceiling:0.90)
    (elements_are
       [
         equal_to _narrow_a;
         equal_to _narrow_b;
         equal_to _wide_a;
         equal_to _wide_b;
       ])

(** Identity under the two modes that do not demote — including [Size_down],
    which admits the same wide candidates but keeps their rank. This is the R1
    half: the default path is not reordered, and does not even pay for the
    per-candidate stop recomputation. *)
let test_other_modes_leave_the_order_untouched _ =
  let unchanged =
    elements_are
      [
        equal_to _wide_a;
        equal_to _narrow_a;
        equal_to _wide_b;
        equal_to _narrow_b;
      ]
  in
  assert_that
    [
      _order_under ~mode:Stop_width_mode.Drop_over_max ~ceiling:0.90;
      _order_under ~mode:Stop_width_mode.Size_down ~ceiling:0.90;
    ]
    (elements_are [ unchanged; unchanged ])

(** A symbol with NO bars is not a special case — the mli says so, and this is
    the pin. [latest_close] returns [None], the effective entry falls back to
    [suggested_entry], the support-floor scan finds nothing, and the
    [initial_stop_buffer] fallback makes it wide — which is exactly where the
    gate would put it. It therefore sorts into the wide group, {i behind} the
    narrow candidates, rather than keeping its rank as an earlier version of the
    docstring claimed. *)
let test_a_symbol_with_no_bars_sorts_wide _ =
  let candidates = _candidate ~ticker:_nobars :: _candidates in
  assert_that
    (Entry_stop_width_order.prefer_narrow_stops
       ~config:(_config ~mode:Stop_width_mode.Demote_over_max ~ceiling:0.90 ())
       ~bar_reader:_bar_reader ~current_date:_current_date candidates
    |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.ticker))
    (elements_are
       [
         equal_to _narrow_a;
         equal_to _narrow_b;
         equal_to _nobars;
         equal_to _wide_a;
         equal_to _wide_b;
       ])

(** The one genuinely unmeasurable case the mli carves out (
    [entry_stop_width_order.mli] §"non-positive effective entry"): a candidate
    with no resident bars whose own [suggested_entry] is [0.0], so the effective
    entry is [0.0] and a distance ratio against it is undefined. The pass
    declines to classify it and it {b keeps its rank} rather than being demoted
    on a division with no answer.

    It is placed {i first} in the input, ahead of both narrow candidates, so
    "keeps its rank" is observably different from "sorted into the wide group":
    flipping [_is_wide]'s [None] branch from [false] to [true] — the one
    plausible mutation, since the guard's shape is forced by the option type —
    moves [ZEROENTRY] to the back and fails this assertion.

    Contrast {!test_a_symbol_with_no_bars_sorts_wide}, the adjacent clause:
    missing bars alone is {i not} unmeasurable, because the entry falls back to
    a positive [suggested_entry], and that candidate does sort wide. *)
let test_non_positive_effective_entry_keeps_its_rank _ =
  let zero_entry_candidate : Screener.scored_candidate =
    { (_candidate ~ticker:_zero_entry) with suggested_entry = 0.0 }
  in
  assert_that
    (Entry_stop_width_order.prefer_narrow_stops
       ~config:(_config ~mode:Stop_width_mode.Demote_over_max ~ceiling:0.90 ())
       ~bar_reader:_bar_reader ~current_date:_current_date
       (zero_entry_candidate :: _candidates)
    |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.ticker))
    (elements_are
       [
         equal_to _zero_entry;
         equal_to _narrow_a;
         equal_to _narrow_b;
         equal_to _wide_a;
         equal_to _wide_b;
       ])

(** An unset ceiling makes the mode a no-op: with
    [stop_width_size_down_max_pct = 0.0] the ceiling falls back to
    [max_stop_distance_pct], so the wide candidate is dropped by the gate anyway
    and demoting it buys nothing. The ordering pass still runs (it is keyed on
    the mode, not the ceiling), which is why this is worth pinning — the reorder
    happens, the gate then discards the demoted candidate, and the observable
    outcome is the unarmed one. *)
let test_unset_ceiling_still_drops_the_wide_candidate _ =
  assert_that
    (Stop_width_mode.gate
       ~policy:
         { mode = Stop_width_mode.Demote_over_max; size_down_max_pct = 0.0 }
       ~max_stop_distance_pct:0.15 ~stop_distance_pct:0.36)
    (equal_to (Stop_width_mode.Drop : Stop_width_mode.outcome))

(** The three distance bands under [Demote_over_max] with a 0.90 ceiling. The
    middle band is [Admit], never [Admit_sized_down] — demotion changes the walk
    order, and sizing does not read the mode at all. *)
let test_gate_demote_bands _ =
  assert_that
    ([ 0.10; 0.36; 0.95 ]
    |> List.map ~f:(fun stop_distance_pct ->
        Stop_width_mode.gate
          ~policy:
            { mode = Stop_width_mode.Demote_over_max; size_down_max_pct = 0.90 }
          ~max_stop_distance_pct:0.15 ~stop_distance_pct))
    (elements_are
       [
         equal_to (Stop_width_mode.Admit : Stop_width_mode.outcome);
         equal_to (Stop_width_mode.Admit : Stop_width_mode.outcome);
         equal_to (Stop_width_mode.Drop : Stop_width_mode.outcome);
       ])

let _entered_tickers ?sector_cap ~mode ~cash () =
  let portfolio =
    { Trading_strategy.Portfolio_view.cash; positions = String.Map.empty }
  in
  let stop_states = ref String.Map.empty in
  Entry_walk.entries_from_candidates
    ~config:(_config ?sector_cap ~mode ~ceiling:0.90 ())
    ~candidates:_candidates ~stop_states ~bar_reader:_bar_reader ~portfolio
    ~get_price:(fun _ -> None)
    ~current_date:_current_date ()
  |> List.filter_map ~f:(fun (t : Position.transition) ->
      match t.kind with Position.CreateEntering e -> Some e.symbol | _ -> None)

(** CAPITAL-RICH: everyone is funded, and the only observable is the ORDER the
    walk emits them in — which is also the order they claimed capital in.

    - [Drop_over_max] enters the narrow pair only; the wide pair is excluded.
    - [Size_down] enters all four in screener rank.
    - [Demote_over_max] enters all four, narrow pair first.

    Deleting the [Entry_stop_width_order] call from [entry_walk.ml] makes an
    armed [Demote_over_max] behave exactly like [Size_down], and every other
    test in this file still passes.

    Cash is ample here on purpose: this case is about {i priority}, and the case
    where priority becomes a different admitted set is
    {!test_capital_tight_modes_admit_different_sets}. *)
let test_walk_emits_the_narrow_stops_first _ =
  let cash = 1_000_000.0 in
  assert_that
    [
      _entered_tickers ~mode:Stop_width_mode.Drop_over_max ~cash ();
      _entered_tickers ~mode:Stop_width_mode.Size_down ~cash ();
      _entered_tickers ~mode:Stop_width_mode.Demote_over_max ~cash ();
    ]
    (elements_are
       [
         elements_are [ equal_to _narrow_a; equal_to _narrow_b ];
         elements_are
           [
             equal_to _wide_a;
             equal_to _narrow_a;
             equal_to _wide_b;
             equal_to _narrow_b;
           ];
         elements_are
           [
             equal_to _narrow_a;
             equal_to _narrow_b;
             equal_to _wide_a;
             equal_to _wide_b;
           ];
       ])

(** CAPITAL-TIGHT: the direction that matters, and the only one where the two
    non-default modes admit a {b different set} rather than the same set in a
    different order. Since sizing never reads the mode, this is the entire
    behavioural difference between [Size_down] and [Demote_over_max].

    {b The binding resource is a sector cap, not cash, and that is forced.} Cash
    cannot bind here: every position's cost is a fixed fraction of portfolio
    value ([risk$ / stop_distance], with [risk$] itself a fraction of the book),
    so scaling the book scales every cost and the same set always fits. Lowering
    cash rounds share counts to zero before it starves anyone. All four
    candidates share one sector, so the sector cap is a budget the walk consumes
    in walk order — which is exactly the resource a demotion is about.

    {b The wide-stop positions are the CHEAP ones}, which is what makes this
    test sharp rather than arbitrary. Under fixed-risk sizing the share count is
    [risk$ / (entry - stop)], so a position's {e cost} is
    [shares * entry = risk$ / stop_distance_pct] — inversely proportional to the
    stop distance, with no other term. The wide candidates sit at the 66.7%
    buffer and the narrow ones ~5% under entry, so a wide position costs about a
    {b thirteenth} of a narrow one ([0.05 / 0.667]), not a quarter as an earlier
    draft of this comment said. Under [Size_down] the two wide candidates reach
    the budget first and consume enough of it that {i neither} narrow candidate
    can be funded; under [Demote_over_max] the first narrow candidate takes the
    budget instead. Same candidates, same capital, same bars, disjoint outcomes:

    - [Size_down] → [WIDE_A; WIDE_B] — the wide pair kept its rank and crowded
      the narrow pair out entirely.
    - [Demote_over_max] → [NARROW_A] — one narrow-stop position instead of two
      wide-stop ones.

    That inversion is also the practical argument for the mechanism: under
    [Size_down] a §5.1-violating stop does not merely get admitted, it is
    {i cheaper} than a compliant one and therefore outcompetes it for a shared
    budget. *)
let test_capital_tight_modes_admit_different_sets _ =
  let entered mode =
    _entered_tickers ~sector_cap:(Some 0.14) ~mode ~cash:1_000_000.0 ()
  in
  assert_that
    [
      entered Stop_width_mode.Size_down; entered Stop_width_mode.Demote_over_max;
    ]
    (elements_are
       [
         elements_are [ equal_to _wide_a; equal_to _wide_b ];
         elements_are [ equal_to _narrow_a ];
       ])

let suite =
  "entry_stop_width_order"
  >::: [
         "the partition is stable and separates narrow from wide"
         >:: test_partition_is_stable_and_separates;
         "non-demoting modes leave the order untouched"
         >:: test_other_modes_leave_the_order_untouched;
         "a symbol with no bars sorts wide, like the gate would put it"
         >:: test_a_symbol_with_no_bars_sorts_wide;
         "a non-positive effective entry keeps its rank"
         >:: test_non_positive_effective_entry_keeps_its_rank;
         "an unset ceiling still drops the wide candidate"
         >:: test_unset_ceiling_still_drops_the_wide_candidate;
         "gate bands under Demote_over_max" >:: test_gate_demote_bands;
         "capital-rich: the walk emits the narrow stops first"
         >:: test_walk_emits_the_narrow_stops_first;
         "capital-tight: the two modes admit different sets"
         >:: test_capital_tight_modes_admit_different_sets;
       ]

let () = run_test_tt_main suite
