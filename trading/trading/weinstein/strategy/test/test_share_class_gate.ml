(** #3015 [max_one_share_class_per_issuer] — skip a long candidate while another
    share class of its issuer (GOOG / GOOGL) has an open or pending long.

    Two layers are pinned:

    - {b The entry walk} ({!Entry_walk.entries_from_candidates}) end to end on
      the narrow-stop fixture of [test_reserve_resting_ticket_cash.ml], so every
      candidate is fundable and only the share-class rule can exclude one: flag
      off admits both classes (R1); flag on skips the second class while the
      first is held, resting, exiting or suspended; admits it once the first has
      closed; resolves a same-week tie to the higher-ranked class; leaves
      unmapped symbols alone; and records [Share_class_held] in the walk's
      passed-over audit list.
    - {b The pure pieces} — {!Share_class_gate.classify} with a stub [decide]
      (shorts, [Already_held] precedence, a skipped first class not occupying
      its group), {!Share_class_map} parsing / loading, and the fail-loudly
      validation of an armed rule with no map. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position

let _current_date = Date.of_string "2024-06-14"
let _goog = "GOOG"
let _googl = "GOOGL"
let _unmapped_a = "AAA"
let _unmapped_b = "BBB"
let _hei = "HEI"
let _hei_a = "HEI-A"
let _groups = [ [ _goog; _googl ]; [ "BRK-A"; "BRK-B" ]; [ _hei; _hei_a ] ]

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

(* Rise to 110, correct 9.1% to 100, recover to 105: a structural stop ~5%
   under entry, well inside [max_stop_distance_pct] (see
   test_reserve_resting_ticket_cash.ml for why the peak must precede the last
   bar). *)
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
    (List.map [ _goog; _googl; _unmapped_a; _unmapped_b ] ~f:(fun s ->
         (s, _bars_for s)))

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

let _candidate ?(side = Trading_base.Types.Long) ticker :
    Screener.scored_candidate =
  {
    ticker;
    analysis = _stock_analysis ~ticker;
    sector =
      {
        sector_name = "Test";
        rating = Neutral;
        stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
      };
    side;
    grade = Weinstein_types.B;
    score = 60;
    suggested_entry = 105.0;
    suggested_stop = 100.0;
    risk_pct = 0.05;
    swing_target = None;
    rationale = [ "test breakout" ];
  }

let _config ?(covers_shorts = false) ~enabled () =
  let base =
    Weinstein_strategy_config.default_config
      ~universe:[ _goog; _googl; _unmapped_a; _unmapped_b ]
      ~index_symbol:"SPY"
  in
  {
    base with
    max_one_share_class_per_issuer = enabled;
    share_class_groups = Share_class_map.of_groups _groups;
    share_class_gate_covers_shorts = covers_shorts;
  }

let _position ?(side = Trading_base.Types.Long) ~symbol ~state () : Position.t =
  {
    id = symbol ^ "-pos";
    symbol;
    side;
    entry_reasoning = Position.PricePattern "test breakout";
    exit_reason = None;
    state;
    last_updated = _current_date;
    portfolio_lot_ids = [];
  }

let _no_risk : Position.risk_params =
  { stop_loss_price = None; take_profit_price = None; max_hold_days = None }

let _holding ?side symbol =
  _position ?side ~symbol
    ~state:
      (Position.Holding
         {
           quantity = 10.0;
           entry_price = 100.0;
           entry_date = _current_date;
           risk_params = _no_risk;
         })
    ()

let _entering symbol =
  _position ~symbol
    ~state:
      (Position.Entering
         {
           target_quantity = 10.0;
           entry_price = 100.0;
           filled_quantity = 0.0;
           created_date = _current_date;
         })
    ()

let _exiting symbol =
  _position ~symbol
    ~state:
      (Position.Exiting
         {
           quantity = 10.0;
           entry_price = 100.0;
           entry_date = _current_date;
           target_quantity = 10.0;
           exit_price = 95.0;
           filled_quantity = 0.0;
           started_date = _current_date;
           risk_params = _no_risk;
         })
    ()

let _closed symbol =
  _position ~symbol
    ~state:
      (Position.Closed
         {
           quantity = 10.0;
           entry_price = 100.0;
           exit_price = 95.0;
           gross_pnl = None;
           entry_date = _current_date;
           exit_date = _current_date;
           days_held = 0;
         })
    ()

(* Run the walk and return (entered symbols, passed-over (symbol, reason)). *)
let _walk_full ?(suspended_held = []) ?covers_shorts ~enabled ~positions tickers
    =
  let portfolio =
    {
      Trading_strategy.Portfolio_view.cash = 1_000_000.0;
      positions =
        String.Map.of_alist_exn
          (List.map positions ~f:(fun (p : Position.t) -> (p.id, p)));
    }
  in
  let considered = ref [] in
  let entered =
    Entry_walk.entries_from_candidates ~suspended_held
      ~config:(_config ?covers_shorts ~enabled ())
      ~candidates:(List.map tickers ~f:_candidate)
      ~stop_states:(ref String.Map.empty) ~bar_reader:_bar_reader ~portfolio
      ~get_price:(fun _ -> None)
      ~current_date:_current_date
      ~on_candidates_considered:(fun alts -> considered := alts)
      ()
    |> List.filter_map ~f:(fun (t : Position.transition) ->
        match t.kind with
        | Position.CreateEntering e -> Some e.symbol
        | _ -> None)
  in
  let passed =
    List.map !considered ~f:(fun (a : Audit_recorder.alternative_input) ->
        (a.candidate.ticker, a.reason))
  in
  (entered, passed)

let _walk ?suspended_held ?covers_shorts ~enabled ~positions tickers =
  fst (_walk_full ?suspended_held ?covers_shorts ~enabled ~positions tickers)

(* ---- the entry walk ---------------------------------------------------- *)

(** R1: flag off, both classes of one issuer are admitted in the same week —
    exactly today's behaviour, even though the map is populated. *)
let test_flag_off_admits_both_classes _ =
  assert_that
    (_walk ~enabled:false ~positions:[] [ _goog; _googl ])
    (elements_are [ equal_to _goog; equal_to _googl ])

(** Flag off with GOOG already held: GOOGL is still admitted (R1). *)
let test_flag_off_ignores_held_sibling _ =
  assert_that
    (_walk ~enabled:false ~positions:[ _holding _goog ] [ _googl ])
    (elements_are [ equal_to _googl ])

(** Flag on, GOOG held: the GOOGL candidate is skipped. *)
let test_flag_on_skips_second_class_while_first_held _ =
  assert_that
    (_walk ~enabled:true ~positions:[ _holding _goog ] [ _googl ])
    (size_is 0)

(** "Pending" covers a resting entry ticket and an exit still in flight: both
    are not-yet-closed long claims on the issuer. *)
let test_flag_on_pending_states_occupy_the_group _ =
  assert_that
    [
      _walk ~enabled:true ~positions:[ _entering _goog ] [ _googl ];
      _walk ~enabled:true ~positions:[ _exiting _goog ] [ _googl ];
    ]
    (elements_are [ size_is 0; size_is 0 ])

(** A ticket withdrawn by the macro suspension (not in the portfolio, only in
    [suspended_held]) is still pending: it will be re-issued unchanged. *)
let test_flag_on_suspended_ticket_occupies_the_group _ =
  assert_that
    (_walk ~suspended_held:[ _goog ] ~enabled:true ~positions:[] [ _googl ])
    (size_is 0)

(** Once the first class has closed, the second class is admitted again. *)
let test_flag_on_admits_second_class_after_first_closes _ =
  assert_that
    (_walk ~enabled:true ~positions:[ _closed _goog ] [ _googl ])
    (elements_are [ equal_to _googl ])

(** Same-week tie: both classes qualify; only the first in the screener's
    ranking order is entered — whichever class that is. *)
let test_flag_on_same_week_tie_goes_to_higher_ranked _ =
  assert_that
    [
      _walk ~enabled:true ~positions:[] [ _googl; _goog ];
      _walk ~enabled:true ~positions:[] [ _goog; _googl ];
    ]
    (elements_are
       [ elements_are [ equal_to _googl ]; elements_are [ equal_to _goog ] ])

(** Unmapped symbols are untouched: the flag-on walk equals the flag-off one,
    even alongside a held mapped symbol. *)
let test_flag_on_unmapped_symbols_unaffected _ =
  let tickers = [ _unmapped_a; _unmapped_b ] in
  let positions = [ _holding _goog ] in
  assert_that
    (_walk ~enabled:true ~positions tickers)
    (all_of
       [
         equal_to (_walk ~enabled:false ~positions tickers);
         elements_are [ equal_to _unmapped_a; equal_to _unmapped_b ];
       ])

(** The skip is recorded in the walk's passed-over audit list with its own
    reason, the same channel every other entry rejection uses. *)
let test_flag_on_records_share_class_held_reason _ =
  assert_that
    (_walk_full ~enabled:true ~positions:[] [ _goog; _googl ])
    (all_of
       [
         field fst (elements_are [ equal_to _goog ]);
         field snd
           (elements_are
              [
                equal_to
                  ( _googl,
                    (Audit_recorder.Share_class_held
                      : Audit_recorder.skip_reason) );
              ]);
       ])

(* ---- Share_class_gate.classify with a stub decide ---------------------- *)

let _gate ?(positions = []) ?covers_shorts () =
  Share_class_gate.create
    ~config:(_config ?covers_shorts ~enabled:true ())
    ~portfolio:
      {
        Trading_strategy.Portfolio_view.cash = 0.0;
        positions =
          String.Map.of_alist_exn
            (List.map positions ~f:(fun (p : Position.t) -> (p.id, p)));
      }
    ~suspended_held:[]

let _is_share_class_held = function
  | Entry_audit_capture.Skipped Audit_recorder.Share_class_held -> true
  | _ -> false

(* A [decide] stub that counts calls and returns [result]. *)
let _stub result =
  let calls = ref 0 in
  ( (fun () ->
      incr calls;
      result),
    calls )

(** The gate's default-off construction is [None]. *)
let test_create_is_none_when_flag_off _ =
  assert_that
    (Share_class_gate.create
       ~config:(_config ~enabled:false ())
       ~portfolio:
         {
           Trading_strategy.Portfolio_view.cash = 0.0;
           positions = String.Map.empty;
         }
       ~suspended_held:[ _goog ])
    is_none

(** A skipped candidate never reaches [decide]: no sizing, no stop state, no
    position id is consumed for it. *)
let test_occupied_group_short_circuits_decide _ =
  let decide, calls = _stub (Entry_audit_capture.Skipped Insufficient_cash) in
  let d =
    Share_class_gate.classify
      (_gate ~positions:[ _holding _goog ] ())
      ~held_set:String.Set.empty (_candidate _googl) ~decide
  in
  assert_that (_is_share_class_held d, !calls) (equal_to (true, 0))

(** Shorts pass through: the rule is about the long book. *)
let test_short_candidate_passes_through _ =
  let decide, calls = _stub (Entry_audit_capture.Skipped Insufficient_cash) in
  let d =
    Share_class_gate.classify
      (_gate ~positions:[ _holding _goog ] ())
      ~held_set:String.Set.empty
      (_candidate ~side:Trading_base.Types.Short _googl)
      ~decide
  in
  assert_that (_is_share_class_held d, !calls) (equal_to (false, 1))

(** A candidate whose own symbol is held is left to the walk's [Already_held]
    check (it keeps precedence): the gate defers to [decide]. *)
let test_held_symbol_defers_to_already_held _ =
  let decide, calls = _stub (Entry_audit_capture.Skipped Already_held) in
  let d =
    Share_class_gate.classify
      (_gate ~positions:[ _holding _goog ] ())
      ~held_set:(String.Set.singleton _goog)
      (_candidate _goog) ~decide
  in
  assert_that (_is_share_class_held d, !calls) (equal_to (false, 1))

(** A higher-ranked class that is skipped for another reason (here cash) does
    not occupy the group, so its sibling is still considered. *)
let test_skipped_first_class_does_not_occupy _ =
  let gate = _gate () in
  let decide_cash, _ = _stub (Entry_audit_capture.Skipped Insufficient_cash) in
  let _first =
    Share_class_gate.classify gate ~held_set:String.Set.empty (_candidate _goog)
      ~decide:decide_cash
  in
  let decide_second, calls =
    _stub (Entry_audit_capture.Skipped Sized_to_zero)
  in
  let d =
    Share_class_gate.classify gate ~held_set:String.Set.empty
      (_candidate _googl) ~decide:decide_second
  in
  assert_that (_is_share_class_held d, !calls) (equal_to (false, 1))

(* ---- #3146: share_class_gate_covers_shorts ------------------------------ *)

let _short_held symbol = _holding ~side:Trading_base.Types.Short symbol
let _short_cand symbol = _candidate ~side:Trading_base.Types.Short symbol

(* Classify [cand] against a gate seeded with [positions]; returns
   (skipped as Share_class_held?, decide calls). *)
let _classify_hei ~covers_shorts ~positions cand =
  let decide, calls = _stub (Entry_audit_capture.Skipped Insufficient_cash) in
  let d =
    Share_class_gate.classify
      (_gate ~positions ~covers_shorts ())
      ~held_set:String.Set.empty cand ~decide
  in
  (_is_share_class_held d, !calls)

(** Flag off (default): HEI held short, an HEI-A short passes straight to
    [decide] — today's long-only rule, bit-identical. *)
let test_covers_shorts_off_passes_hei_a_short _ =
  assert_that
    (_classify_hei ~covers_shorts:false
       ~positions:[ _short_held _hei ]
       (_short_cand _hei_a))
    (equal_to (false, 1))

(** Flag on: the HEI / HEI-A pair of short-only Phase A. HEI held short skips an
    HEI-A short without calling [decide]. *)
let test_covers_shorts_on_skips_hei_a_short _ =
  assert_that
    (_classify_hei ~covers_shorts:true
       ~positions:[ _short_held _hei ]
       (_short_cand _hei_a))
    (equal_to (true, 0))

(** Flag on: either side held rejects either side — a long HEI blocks an HEI-A
    short, a short HEI blocks an HEI-A long. *)
let test_covers_shorts_on_either_side_blocks _ =
  assert_that
    [
      _classify_hei ~covers_shorts:true
        ~positions:[ _holding _hei ]
        (_short_cand _hei_a);
      _classify_hei ~covers_shorts:true
        ~positions:[ _short_held _hei ]
        (_candidate _hei_a);
    ]
    (elements_are [ equal_to (true, 0); equal_to (true, 0) ])

(** Long behaviour is bit-identical under the flag: with only longs in the book
    the covers-shorts walk equals the long-only one. *)
let test_covers_shorts_on_long_walk_unchanged _ =
  let run covers_shorts =
    _walk ~covers_shorts ~enabled:true
      ~positions:[ _holding _goog ]
      [ _googl; _unmapped_a; _unmapped_b ]
  in
  assert_that (run true)
    (all_of
       [
         equal_to (run false);
         elements_are [ equal_to _unmapped_a; equal_to _unmapped_b ];
       ])

(* ---- Share_class_map --------------------------------------------------- *)

(** Both classes map to one group id; an unmapped symbol maps to nothing; the
    sexp form round-trips. *)
let test_map_lookup_and_round_trip _ =
  let m = Share_class_map.of_groups _groups in
  let round = Share_class_map.t_of_sexp (Share_class_map.sexp_of_t m) in
  assert_that
    ( Share_class_map.group_of m _goog,
      Share_class_map.group_of m _googl,
      Share_class_map.group_of m _unmapped_a,
      Share_class_map.groups round )
    (equal_to (Some _goog, Some _goog, None, _groups))

(* [true] iff [f ()] raises. *)
let _raises f = Result.is_error (Result.try_with f)

(** Malformed maps fail loudly: a ticker in two groups, a one-ticker group. *)
let test_map_rejects_malformed_groups _ =
  let raises groups = _raises (fun () -> Share_class_map.of_groups groups) in
  assert_that
    [ raises [ [ "A"; "B" ]; [ "B"; "C" ] ]; raises [ [ "A" ] ] ]
    (elements_are [ equal_to true; equal_to true ])

(** A missing map file fails loudly rather than yielding an empty map. *)
let test_map_load_missing_file_fails _ =
  assert_that
    (_raises (fun () -> Share_class_map.load "/nonexistent/share_classes.sexp"))
    (equal_to true)

(* ---- arming validation ------------------------------------------------- *)

(* Typed at [Weinstein_strategy.config] (the type [make] and
   [resolve_share_class_map] take): flag on, no map. *)
let _unarmed_config () : config =
  {
    (default_config ~universe:[ _goog ] ~index_symbol:"SPY") with
    max_one_share_class_per_issuer = true;
  }

(** Flag on with an empty map is refused at construction (never runs unarmed);
    flag off with an empty map is fine. *)
let test_make_rejects_flag_on_without_map _ =
  let refused config = _raises (fun () -> ignore (make config)) in
  assert_that
    [
      refused (_unarmed_config ());
      refused
        { (_unarmed_config ()) with max_one_share_class_per_issuer = false };
    ]
    (elements_are [ equal_to true; equal_to false ])

(** [resolve_share_class_map] with the flag off never touches the file (a bogus
    data dir is harmless); with the flag on it loads, and a missing file raises.
*)
let test_resolve_reads_file_only_when_armed _ =
  let off =
    { (_unarmed_config ()) with max_one_share_class_per_issuer = false }
  in
  assert_that
    [
      _raises (fun () -> resolve_share_class_map ~data_dir:"/nonexistent" off);
      _raises (fun () ->
          resolve_share_class_map ~data_dir:"/nonexistent" (_unarmed_config ()));
    ]
    (elements_are [ equal_to false; equal_to true ])

let suite =
  "share_class_gate"
  >::: [
         "flag off admits both classes" >:: test_flag_off_admits_both_classes;
         "flag off ignores held sibling" >:: test_flag_off_ignores_held_sibling;
         "flag on skips second class while first held"
         >:: test_flag_on_skips_second_class_while_first_held;
         "flag on pending states occupy the group"
         >:: test_flag_on_pending_states_occupy_the_group;
         "flag on suspended ticket occupies the group"
         >:: test_flag_on_suspended_ticket_occupies_the_group;
         "flag on admits second class after first closes"
         >:: test_flag_on_admits_second_class_after_first_closes;
         "flag on same-week tie goes to higher ranked"
         >:: test_flag_on_same_week_tie_goes_to_higher_ranked;
         "flag on unmapped symbols unaffected"
         >:: test_flag_on_unmapped_symbols_unaffected;
         "flag on records Share_class_held reason"
         >:: test_flag_on_records_share_class_held_reason;
         "create is None when flag off" >:: test_create_is_none_when_flag_off;
         "occupied group short-circuits decide"
         >:: test_occupied_group_short_circuits_decide;
         "short candidate passes through"
         >:: test_short_candidate_passes_through;
         "held symbol defers to Already_held"
         >:: test_held_symbol_defers_to_already_held;
         "skipped first class does not occupy"
         >:: test_skipped_first_class_does_not_occupy;
         "#3146: covers_shorts off passes HEI-A short"
         >:: test_covers_shorts_off_passes_hei_a_short;
         "#3146: covers_shorts on skips HEI-A short while HEI short held"
         >:: test_covers_shorts_on_skips_hei_a_short;
         "#3146: covers_shorts on either side held blocks either side"
         >:: test_covers_shorts_on_either_side_blocks;
         "#3146: covers_shorts on long walk unchanged"
         >:: test_covers_shorts_on_long_walk_unchanged;
         "map lookup and round trip" >:: test_map_lookup_and_round_trip;
         "map rejects malformed groups" >:: test_map_rejects_malformed_groups;
         "map load missing file fails" >:: test_map_load_missing_file_fails;
         "make rejects flag on without map"
         >:: test_make_rejects_flag_on_without_map;
         "resolve reads file only when armed"
         >:: test_resolve_reads_file_only_when_armed;
       ]

let () = run_test_tt_main suite
