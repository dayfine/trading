(** Issue #3681 [Liquidity_config.max_entry_adv_participation]: block an entry
    whose planned position dollars exceed [p] times its trailing dollar-ADV.

    Pinned at three layers:

    - {b The pure check} ({!Entry_liquidity_gate.participation_allows}): both
      sides of the cutoff, [None] admits, a missing ADV reading admits.
    - {b The entry walk} ({!Entry_walk.entries_from_candidates}) with the field
      set on the strategy config: [None] places the entry exactly as today; a
      cap just above the position's share of ADV places it; a cap just below
      blocks it and records [Adv_participation_cap].
    - {b The dust floor}: [min_entry_dollar_adv] still drops a candidate even
      when the participation cap would admit it.

    Plus the sexp: a config without the field reads [None], so every existing
    spec and override file parses unchanged. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position

let _current_date = Date.of_string "2024-06-14"
let _ticker = "AAA"

(* Volume of every fixture bar; with closes ~100-110 the 20-day dollar ADV is
   ~$1e8, well above the default $1M dust floor. *)
let _volume = 1_000_000

let _bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = _volume;
    active_through = None;
  }

(* Same narrow-stop shape as test_share_class_gate.ml: rise to 110, correct to
   100, recover to 105, so the structural stop sits ~5% under entry and the
   candidate is always fundable. *)
let _closes =
  [
    100.0; 104.0; 108.0; 110.0; 106.0; 102.0; 100.0; 101.0; 103.0; 104.0; 105.0;
  ]

let _bars =
  List.mapi _closes ~f:(fun i close ->
      _bar
        ~date:(Date.add_days _current_date (i - List.length _closes + 1))
        ~close)

let _bar_reader = Bar_reader.of_in_memory_bars [ (_ticker, _bars) ]

let _stock_analysis : Stock_analysis.t =
  {
    ticker = _ticker;
    stage =
      {
        stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
        ma_value = 100.0;
        ma_direction = Weinstein_types.Rising;
        ma_slope_pct = 0.01;
        transition = None;
        above_ma_count = 8;
      };
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
    current_raw_close = None;
    as_of_date = _current_date;
  }

let _candidate : Screener.scored_candidate =
  {
    ticker = _ticker;
    analysis = _stock_analysis;
    sector =
      {
        sector_name = "Test";
        rating = Neutral;
        stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
      };
    side = Trading_base.Types.Long;
    grade = Weinstein_types.B;
    score = 60;
    suggested_entry = 105.0;
    suggested_stop = 100.0;
    risk_pct = 0.05;
    swing_target = None;
    rationale = [ "test breakout" ];
  }

let _base_config =
  Weinstein_strategy_config.default_config ~universe:[ _ticker ]
    ~index_symbol:"SPY"

let _config
    ?(min_entry_dollar_adv =
      Liquidity_config.default_config.min_entry_dollar_adv) participation =
  {
    _base_config with
    liquidity_config =
      {
        _base_config.liquidity_config with
        max_entry_adv_participation = participation;
        min_entry_dollar_adv;
      };
  }

let _dollar_adv () =
  Option.value_exn
    (Entry_liquidity_gate.dollar_adv_for ~config:_base_config.liquidity_config
       ~bar_reader:_bar_reader ~current_date:_current_date _ticker)

(* Run the walk: (position dollars of each entry placed, skip reasons). *)
let _walk ?(cash = 1_000_000.0) participation =
  let portfolio =
    { Trading_strategy.Portfolio_view.cash; positions = String.Map.empty }
  in
  let considered = ref [] in
  let placed =
    Entry_walk.entries_from_candidates ~config:(_config participation)
      ~candidates:[ _candidate ] ~stop_states:(ref String.Map.empty)
      ~bar_reader:_bar_reader ~portfolio
      ~get_price:(fun _ -> None)
      ~current_date:_current_date
      ~on_candidates_considered:(fun ds -> considered := ds)
      ()
    |> List.filter_map ~f:(fun (t : Position.transition) ->
        match t.kind with
        | Position.CreateEntering e -> Some (e.target_quantity *. e.entry_price)
        | _ -> None)
  in
  let skipped =
    List.filter_map !considered ~f:(fun (d : Audit_recorder.walk_decision) ->
        match d.outcome with Skipped r -> Some r | Placed -> None)
  in
  (placed, skipped)

(* The share of ADV today's (uncapped) entry takes. *)
let _uncapped_share () =
  match _walk None with
  | [ dollars ], [] -> dollars /. _dollar_adv ()
  | _ -> assert_failure "uncapped walk did not place exactly one entry"

let _epsilon = 1e-6

(* ---- the pure check ---------------------------------------------------- *)

let test_allows_at_and_below_cutoff _ =
  assert_that
    ( Entry_liquidity_gate.participation_allows ~max_participation:(Some 0.1)
        ~position_dollars:10_000.0 ~dollar_adv:(Some 100_000.0),
      Entry_liquidity_gate.participation_allows ~max_participation:(Some 0.1)
        ~position_dollars:9_999.0 ~dollar_adv:(Some 100_000.0) )
    (equal_to (true, true))

let test_blocks_above_cutoff _ =
  assert_that
    (Entry_liquidity_gate.participation_allows ~max_participation:(Some 0.1)
       ~position_dollars:10_001.0 ~dollar_adv:(Some 100_000.0))
    (equal_to false)

let test_none_and_missing_adv_allow _ =
  assert_that
    ( Entry_liquidity_gate.participation_allows ~max_participation:None
        ~position_dollars:1e12 ~dollar_adv:(Some 1.0),
      Entry_liquidity_gate.participation_allows ~max_participation:(Some 0.1)
        ~position_dollars:1e12 ~dollar_adv:None )
    (equal_to (true, true))

(* ---- the entry walk ---------------------------------------------------- *)

(** [None] (the default): the entry is placed, nothing is skipped. *)
let test_walk_none_places_entry _ =
  let placed, skipped = _walk None in
  assert_that (List.length placed, skipped) (equal_to (1, []))

(** A cap just above the entry's share of ADV places the same entry. *)
let test_walk_cap_above_share_places _ =
  let share = _uncapped_share () in
  assert_that
    (_walk (Some (share +. _epsilon)))
    (equal_to (fst (_walk None), []))

(** A cap just below the entry's share of ADV blocks it (no resize) and records
    [Adv_participation_cap]. *)
let test_walk_cap_below_share_blocks _ =
  let share = _uncapped_share () in
  assert_that
    (_walk (Some (share -. _epsilon)))
    (equal_to ([], [ Audit_recorder.Adv_participation_cap ]))

(** The position dollars are sized from the CURRENT portfolio value at the
    decision, not initial cash or a static size: same stock and ADV, a cap just
    above the share the entry takes at a $1M NAV admits it there and blocks it
    at a $2M NAV, where the sizer doubles the position. *)
let test_walk_cap_scales_with_current_nav _ =
  let cap = Some (_uncapped_share () +. _epsilon) in
  let admitted ~cash = List.length (fst (_walk ~cash cap)) in
  assert_that
    (admitted ~cash:1_000_000.0, admitted ~cash:2_000_000.0)
    (equal_to (1, 0))

(* ---- the dust floor ---------------------------------------------------- *)

(** [min_entry_dollar_adv] above the ADV still drops the candidate before the
    walk, however loose the participation cap. *)
let test_dust_floor_still_applies _ =
  let adv = _dollar_adv () in
  let kept min_entry_dollar_adv =
    Entry_liquidity_gate.apply
      ~config:(_config ~min_entry_dollar_adv (Some 1e9)).liquidity_config
      ~bar_reader:_bar_reader ~current_date:_current_date [ _candidate ]
    |> List.length
  in
  assert_that (kept (adv *. 2.0), kept (adv /. 2.0)) (equal_to (0, 1))

(* ---- sexp -------------------------------------------------------------- *)

let test_sexp_absent_field_is_none _ =
  let base =
    "((adv_lookback_days 20) (min_entry_dollar_adv 1000000) \
     (min_hold_dollar_adv 0)"
  in
  let read s =
    (Liquidity_config.t_of_sexp (Sexp.of_string s)).max_entry_adv_participation
  in
  assert_that
    (read (base ^ ")"), read (base ^ " (max_entry_adv_participation (0.1)))"))
    (equal_to (None, Some 0.1))

let suite =
  "adv_participation"
  >::: [
         "allows at and below cutoff" >:: test_allows_at_and_below_cutoff;
         "blocks above cutoff" >:: test_blocks_above_cutoff;
         "None and missing ADV allow" >:: test_none_and_missing_adv_allow;
         "walk: None places entry" >:: test_walk_none_places_entry;
         "walk: cap above share places" >:: test_walk_cap_above_share_places;
         "walk: cap below share blocks" >:: test_walk_cap_below_share_blocks;
         "walk: cap scales with current NAV"
         >:: test_walk_cap_scales_with_current_nav;
         "dust floor still applies" >:: test_dust_floor_still_applies;
         "sexp: absent field is None" >:: test_sexp_absent_field_is_none;
       ]

let () = run_test_tt_main suite
