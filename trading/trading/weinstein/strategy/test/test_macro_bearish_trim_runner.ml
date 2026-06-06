(** Unit tests for {!Macro_bearish_trim_runner}.

    Pins the trim contract: caps held long exposure at the configured fraction
    of portfolio value on a Bearish tape, exits weakest-RS-first, is a no-op
    when already under the cap, never emits a buy, and respects the single-exit
    collision rule via [skip_position_ids]. The macro-trend / Friday gating is
    the {e caller}'s responsibility (see [test_weinstein_strategy] integration),
    so these unit tests drive the pure runner directly. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let _date s = Date.of_string s

let _make_bar ~date ~close =
  Types.Daily_price.
    {
      date;
      open_price = close;
      high_price = close *. 1.01;
      low_price = close *. 0.99;
      close_price = close;
      adjusted_close = close;
      volume = 1_000_000;
      active_through = None;
    }

(** Build a [Holding] position via the canonical entry chain so the result is
    bit-equal to what the simulator would have produced. *)
let _make_holding ~symbol ~side ~entry_date ~quantity ~entry_price =
  let pos_id = symbol ^ "-1" in
  let unwrap = function
    | Ok p -> p
    | Error err -> assert_failure ("position setup failed: " ^ Status.show err)
  in
  let trans kind = { Position.position_id = pos_id; date = entry_date; kind } in
  let p =
    Position.create_entering
      (trans
         (Position.CreateEntering
            {
              symbol;
              side;
              target_quantity = quantity;
              entry_price;
              reasoning =
                Position.TechnicalSignal
                  { indicator = "trim"; description = "test-entry" };
            }))
    |> unwrap
  in
  let p =
    Position.apply_transition p
      (trans
         (Position.EntryFill
            { filled_quantity = quantity; fill_price = entry_price }))
    |> unwrap
  in
  Position.apply_transition p
    (trans
       (Position.EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

let _make_long ~symbol ~quantity ~entry_price =
  _make_holding ~symbol ~side:Trading_base.Types.Long
    ~entry_date:(_date "2024-01-02") ~quantity ~entry_price

(* A [get_price] returning every symbol at its [(symbol, close)] mapping. *)
let _get_price_of alist s =
  List.Assoc.find alist s ~equal:String.equal
  |> Option.map ~f:(fun close -> _make_bar ~date:(_date "2024-04-29") ~close)

(* RS-ranking from an explicit [(symbol, score)] alist; unknown symbols return
   [None]. Lower score = weaker. *)
let _rs_of alist (pos : Position.t) =
  List.Assoc.find alist pos.symbol ~equal:String.equal

let _exit_symbols_of (transitions : Position.transition list) ~positions =
  List.filter_map transitions ~f:(fun (t : Position.transition) ->
      Map.data positions
      |> List.find ~f:(fun (p : Position.t) -> String.equal p.id t.position_id)
      |> Option.map ~f:(fun (p : Position.t) -> p.symbol))

(* ------------------------------------------------------------------ *)
(* Trims to cap                                                         *)
(* ------------------------------------------------------------------ *)

(** Three equal $30k longs (held $90k) in a $100k portfolio; cap 0.35 → target
    $35k. The weakest two ($60k worth) must be exited so the remaining one
    ($30k) sits under the $35k cap. *)
let test_trims_excess_to_cap _ =
  let positions =
    String.Map.of_alist_exn
      [
        ( "STRONG",
          _make_long ~symbol:"STRONG" ~quantity:300.0 ~entry_price:100.0 );
        ("MID", _make_long ~symbol:"MID" ~quantity:300.0 ~entry_price:100.0);
        ("WEAK", _make_long ~symbol:"WEAK" ~quantity:300.0 ~entry_price:100.0);
      ]
  in
  let get_price =
    _get_price_of [ ("STRONG", 100.0); ("MID", 100.0); ("WEAK", 100.0) ]
  in
  let rs_ranking =
    _rs_of [ ("STRONG", 0.20); ("MID", 0.00); ("WEAK", -0.30) ]
  in
  let transitions =
    Macro_bearish_trim_runner.update ~max_long_exposure_pct:0.35
      ~portfolio_value:100_000.0 ~positions ~get_price ~rs_ranking
      ~skip_position_ids:String.Set.empty ~current_date:(_date "2024-04-29")
  in
  (* Weakest-first: WEAK then MID exit; STRONG survives. Order is preserved. *)
  assert_that
    (_exit_symbols_of transitions ~positions)
    (elements_are [ equal_to "WEAK"; equal_to "MID" ])

(** Full-flat cap (0.0): every held long is exited regardless of RS. *)
let test_full_flat_exits_all _ =
  let positions =
    String.Map.of_alist_exn
      [
        ("AAA", _make_long ~symbol:"AAA" ~quantity:100.0 ~entry_price:100.0);
        ("BBB", _make_long ~symbol:"BBB" ~quantity:100.0 ~entry_price:100.0);
      ]
  in
  let get_price = _get_price_of [ ("AAA", 100.0); ("BBB", 100.0) ] in
  let rs_ranking = _rs_of [ ("AAA", 0.1); ("BBB", 0.2) ] in
  let transitions =
    Macro_bearish_trim_runner.update ~max_long_exposure_pct:0.0
      ~portfolio_value:100_000.0 ~positions ~get_price ~rs_ranking
      ~skip_position_ids:String.Set.empty ~current_date:(_date "2024-04-29")
  in
  assert_that transitions (size_is 2)

(* ------------------------------------------------------------------ *)
(* No-op cases                                                          *)
(* ------------------------------------------------------------------ *)

(** Already under the cap → no trim. Held $20k, cap 0.35 of $100k = $35k. *)
let test_under_cap_is_noop _ =
  let positions =
    String.Map.singleton "AAA"
      (_make_long ~symbol:"AAA" ~quantity:200.0 ~entry_price:100.0)
  in
  let get_price = _get_price_of [ ("AAA", 100.0) ] in
  let rs_ranking = _rs_of [ ("AAA", 0.1) ] in
  let transitions =
    Macro_bearish_trim_runner.update ~max_long_exposure_pct:0.35
      ~portfolio_value:100_000.0 ~positions ~get_price ~rs_ranking
      ~skip_position_ids:String.Set.empty ~current_date:(_date "2024-04-29")
  in
  assert_that transitions is_empty

(** No-op cap (1.0): even a fully-long book is left untouched. *)
let test_noop_cap_leaves_book _ =
  let positions =
    String.Map.singleton "AAA"
      (_make_long ~symbol:"AAA" ~quantity:900.0 ~entry_price:100.0)
  in
  let get_price = _get_price_of [ ("AAA", 100.0) ] in
  let rs_ranking = _rs_of [ ("AAA", 0.1) ] in
  let transitions =
    Macro_bearish_trim_runner.update ~max_long_exposure_pct:1.0
      ~portfolio_value:100_000.0 ~positions ~get_price ~rs_ranking
      ~skip_position_ids:String.Set.empty ~current_date:(_date "2024-04-29")
  in
  assert_that transitions is_empty

(** Degenerate portfolio value (<= 0) → no trim. *)
let test_nonpositive_portfolio_value_is_noop _ =
  let positions =
    String.Map.singleton "AAA"
      (_make_long ~symbol:"AAA" ~quantity:100.0 ~entry_price:100.0)
  in
  let get_price = _get_price_of [ ("AAA", 100.0) ] in
  let rs_ranking = _rs_of [ ("AAA", 0.1) ] in
  let transitions =
    Macro_bearish_trim_runner.update ~max_long_exposure_pct:0.0
      ~portfolio_value:0.0 ~positions ~get_price ~rs_ranking
      ~skip_position_ids:String.Set.empty ~current_date:(_date "2024-04-29")
  in
  assert_that transitions is_empty

(* ------------------------------------------------------------------ *)
(* Side & ranking semantics                                            *)
(* ------------------------------------------------------------------ *)

(** Shorts are never trimmed and never counted toward held long exposure. A book
    of one $90k SHORT in a $100k portfolio with cap 0.0 produces no exit — the
    trim caps {e long} exposure only. *)
let test_shorts_not_trimmed _ =
  let positions =
    String.Map.singleton "SH"
      (_make_holding ~symbol:"SH" ~side:Trading_base.Types.Short
         ~entry_date:(_date "2024-01-02") ~quantity:900.0 ~entry_price:100.0)
  in
  let get_price = _get_price_of [ ("SH", 100.0) ] in
  let rs_ranking = _rs_of [ ("SH", -0.5) ] in
  let transitions =
    Macro_bearish_trim_runner.update ~max_long_exposure_pct:0.0
      ~portfolio_value:100_000.0 ~positions ~get_price ~rs_ranking
      ~skip_position_ids:String.Set.empty ~current_date:(_date "2024-04-29")
  in
  assert_that transitions is_empty

(** Every emitted transition is a [TriggerExit] with the ["macro_bearish_trim"]
    StrategySignal label — the runner never force-buys. Verifies the exit reason
    \+ price for the trimmed weakest position. *)
let test_emits_only_macro_bearish_trim_exits _ =
  let positions =
    String.Map.of_alist_exn
      [
        ("KEEP", _make_long ~symbol:"KEEP" ~quantity:300.0 ~entry_price:100.0);
        ("DROP", _make_long ~symbol:"DROP" ~quantity:300.0 ~entry_price:100.0);
      ]
  in
  let get_price = _get_price_of [ ("KEEP", 100.0); ("DROP", 90.0) ] in
  let rs_ranking = _rs_of [ ("KEEP", 0.5); ("DROP", -0.5) ] in
  let transitions =
    Macro_bearish_trim_runner.update ~max_long_exposure_pct:0.35
      ~portfolio_value:100_000.0 ~positions ~get_price ~rs_ranking
      ~skip_position_ids:String.Set.empty ~current_date:(_date "2024-04-29")
  in
  assert_that transitions
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Position.transition) -> t.position_id)
               (equal_to "DROP-1");
             field
               (fun (t : Position.transition) -> t.kind)
               (matching ~msg:"Expected macro_bearish_trim TriggerExit"
                  (function
                    | Position.TriggerExit
                        {
                          exit_reason = Position.StrategySignal { label; _ };
                          exit_price;
                        } ->
                        Some (label, exit_price)
                    | _ -> None)
                  (all_of
                     [
                       field fst (equal_to "macro_bearish_trim");
                       field snd (float_equal 90.0);
                     ]));
           ];
       ])

(** A position whose RS is unknown ([None]) is excluded from trimming and from
    the held total — it is left held rather than exited arbitrarily. Held = only
    the RS-known long ($30k); cap 0.35 of $100k = $35k → no trim. *)
let test_unranked_position_excluded _ =
  let positions =
    String.Map.of_alist_exn
      [
        ( "RANKED",
          _make_long ~symbol:"RANKED" ~quantity:300.0 ~entry_price:100.0 );
        ( "NORANK",
          _make_long ~symbol:"NORANK" ~quantity:900.0 ~entry_price:100.0 );
      ]
  in
  let get_price = _get_price_of [ ("RANKED", 100.0); ("NORANK", 100.0) ] in
  (* NORANK absent from the alist → rs_ranking returns None for it. *)
  let rs_ranking = _rs_of [ ("RANKED", -0.5) ] in
  let transitions =
    Macro_bearish_trim_runner.update ~max_long_exposure_pct:0.35
      ~portfolio_value:100_000.0 ~positions ~get_price ~rs_ranking
      ~skip_position_ids:String.Set.empty ~current_date:(_date "2024-04-29")
  in
  assert_that transitions is_empty

(* ------------------------------------------------------------------ *)
(* Single-exit collision                                               *)
(* ------------------------------------------------------------------ *)

(** A position already exiting this tick (its id in [skip_position_ids]) is
    excluded from the candidate set and from the held total — never
    double-exited. WEAK is already stop-exiting; with WEAK excluded the held
    total is the remaining two $30k longs = $60k, cap 0.35 → target $35k, so
    only MID (the now-weakest eligible) is trimmed, not WEAK. *)
let test_skip_ids_prevents_double_exit _ =
  let positions =
    String.Map.of_alist_exn
      [
        ( "STRONG",
          _make_long ~symbol:"STRONG" ~quantity:300.0 ~entry_price:100.0 );
        ("MID", _make_long ~symbol:"MID" ~quantity:300.0 ~entry_price:100.0);
        ("WEAK", _make_long ~symbol:"WEAK" ~quantity:300.0 ~entry_price:100.0);
      ]
  in
  let get_price =
    _get_price_of [ ("STRONG", 100.0); ("MID", 100.0); ("WEAK", 100.0) ]
  in
  let rs_ranking =
    _rs_of [ ("STRONG", 0.20); ("MID", 0.00); ("WEAK", -0.30) ]
  in
  let transitions =
    Macro_bearish_trim_runner.update ~max_long_exposure_pct:0.35
      ~portfolio_value:100_000.0 ~positions ~get_price ~rs_ranking
      ~skip_position_ids:(String.Set.singleton "WEAK-1")
      ~current_date:(_date "2024-04-29")
  in
  assert_that
    (_exit_symbols_of transitions ~positions)
    (elements_are [ equal_to "MID" ])

let suite =
  "macro_bearish_trim_runner"
  >::: [
         "trims excess to cap" >:: test_trims_excess_to_cap;
         "full flat exits all" >:: test_full_flat_exits_all;
         "under cap is no-op" >:: test_under_cap_is_noop;
         "no-op cap leaves book" >:: test_noop_cap_leaves_book;
         "non-positive portfolio value is no-op"
         >:: test_nonpositive_portfolio_value_is_noop;
         "shorts not trimmed" >:: test_shorts_not_trimmed;
         "emits only macro_bearish_trim exits"
         >:: test_emits_only_macro_bearish_trim_exits;
         "unranked position excluded" >:: test_unranked_position_excluded;
         "skip ids prevents double exit" >:: test_skip_ids_prevents_double_exit;
       ]

let () = run_test_tt_main suite
