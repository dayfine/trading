open OUnit2
open Core
open Matchers
module Sector = Weinstein_strategy.Sector_rotation_weinstein_strategy
module Bar_reader = Weinstein_strategy.Bar_reader
module Strategy_interface = Trading_strategy.Strategy_interface
module Portfolio_view = Trading_strategy.Portfolio_view
module Position = Trading_strategy.Position

let benchmark = "SPY"

(* One daily bar; [open]/[high]/[low] default around [close]. *)
let make_bar date ~close ?low ?high () : Types.Daily_price.t =
  let low = Option.value low ~default:(close *. 0.99) in
  let high = Option.value high ~default:(close *. 1.01) in
  {
    date = Date.of_string date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* [n] weekly bars, one per consecutive Friday ending at [last_friday], with
   [close i] giving the close of the i-th bar (0 = oldest). One Friday-dated
   daily bar aggregates to one weekly bar, so the weekly series is exactly the
   [close] trajectory. *)
let weekly_closes ~last_friday ~n ~close : Types.Daily_price.t list =
  let last = Date.of_string last_friday in
  List.init n ~f:(fun i ->
      let d = Date.add_days last (-7 * (n - 1 - i)) in
      make_bar (Date.to_string d) ~close:(close i) ())

(* A smoothly rising trajectory at [slope] per week off [base] — price climbs
   well above a rising 30-week MA → Stage 2. A steeper slope vs the benchmark
   yields a higher RS. *)
let rising ~base ~slope i = base +. (Float.of_int i *. slope)

(* A smoothly falling trajectory off [peak] — price below a declining 30-week MA
   → Stage 4. *)
let falling ~peak i = peak -. (Float.of_int i *. 1.5)

(* A long, choppy-but-flat tape that never establishes a Stage-2 advance. *)
let flat _ = 50.0
let last_friday = "2021-12-31"

(* 60 weeks comfortably exceeds the 52-week RS window, so RS is computable. *)
let n_weeks = 60

let make_portfolio ~cash ?(positions = []) () : Portfolio_view.t =
  let positions =
    List.fold positions ~init:String.Map.empty ~f:(fun acc (p : Position.t) ->
        Map.set acc ~key:p.id ~data:p)
  in
  { cash; positions }

(* Build a Holding long position for [symbol] at [entry_price] / [entry_date]
   using the strategy's deterministic position id. *)
let make_holding ~symbol ~entry_price ~entry_date ~quantity () : Position.t =
  let pos_id = symbol ^ "-sector-rotation-weinstein" in
  let make_trans kind =
    { Position.position_id = pos_id; date = entry_date; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error e ->
        OUnit2.assert_failure ("position setup failed: " ^ Status.show e)
  in
  let open Position in
  create_entering
    (make_trans
       (CreateEntering
          {
            symbol;
            side = Long;
            target_quantity = quantity;
            entry_price;
            reasoning = ManualDecision { description = "test" };
          }))
  |> unwrap
  |> fun p ->
  apply_transition p
    (make_trans
       (EntryFill { filled_quantity = quantity; fill_price = entry_price }))
  |> unwrap
  |> fun p ->
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

let no_indicator : Strategy_interface.get_indicator_fn = fun _ _ _ _ -> None

(* Run [on_market_close] with [today_bars] = (symbol, bar) for the symbols the
   simulator presents this tick; [get_price] returns [None] for any other. *)
let run_once (module M : Strategy_interface.STRATEGY) ~today_bars ~portfolio =
  let lookup s = List.Assoc.find today_bars ~equal:String.equal s in
  M.on_market_close ~get_price:lookup ~get_indicator:no_indicator ~portfolio

(* The symbols entered via CreateEntering(Long) in [result], sorted ascending so
   the result is order-independent and compares with [equal_to] on a plain list
   (a [String.Set.t] carries a functional comparator that breaks polymorphic
   compare). *)
let entered_symbols (result : (Strategy_interface.output, _) Result.t) :
    string list =
  match result with
  | Error _ -> []
  | Ok output ->
      List.filter_map output.transitions ~f:(fun (t : Position.transition) ->
          match t.kind with
          | Position.CreateEntering c -> Some c.symbol
          | _ -> None)
      |> List.sort ~compare:String.compare

(* ---------------------------------------------------------------- *)
(* Fixtures: two/four sectors at distinct rising slopes + a flat SPY *)
(* benchmark. A steeper slope ranks higher on RS.                    *)
(* ---------------------------------------------------------------- *)

let spy_bars =
  weekly_closes ~last_friday ~n:n_weeks ~close:(rising ~base:50.0 ~slope:0.2)

(* Stage-2 sector bars at a given slope; [base] keeps prices comparable. *)
let stage2_bars ~slope =
  weekly_closes ~last_friday ~n:n_weeks ~close:(rising ~base:50.0 ~slope)

let stage4_bars =
  weekly_closes ~last_friday ~n:n_weeks ~close:(falling ~peak:140.0)

let flat_bars = weekly_closes ~last_friday ~n:n_weeks ~close:flat
let bar_reader_of pairs = Bar_reader.of_in_memory_bars pairs

(* Friday bar (last) for [bars]. *)
let friday_bar bars = List.last_exn bars

let config_k ~k ~symbols =
  Sector.config_with ~k ~ma_period_weeks:30 ~symbols ~benchmark_symbol:benchmark
    ()

(* Same as [config_k] but with the broad-tape macro gate turned on. *)
let config_gate ~k ~symbols =
  Sector.config_with ~k ~ma_period_weeks:30 ~symbols ~benchmark_symbol:benchmark
    ~enable_macro_gate:true ()

(* Same as [config_k] but with a per-sector concentration cap and an explicit
   symbol→sector lookup (mirrors the runner's [ticker_sectors] map). *)
let config_cap ~k ~symbols ~sector_cap ~sector_of =
  Sector.config_with ~k ~ma_period_weeks:30 ~symbols ~benchmark_symbol:benchmark
    ~sector_cap ~sector_of ()

(* A fixture symbol→GICS-sector lookup matching [trading/test_data/sectors.csv]:
   AAPL + MSFT share Information Technology; JPM is Financials. Any other symbol
   maps to [None] (its own singleton sector — never capped). *)
let fixture_sector_of = function
  | "AAPL" | "MSFT" -> Some "Information Technology"
  | "JPM" -> Some "Financials"
  | _ -> None

(* A benchmark (SPY) in Stage 4 — a steadily falling tape — used to fire the
   macro gate. Distinct from [spy_bars] (rising = Stage 2). *)
let spy_stage4_bars =
  weekly_closes ~last_friday ~n:n_weeks ~close:(falling ~peak:140.0)

(* ---------------------------------------------------------------- *)
(* Tests.                                                            *)
(* ---------------------------------------------------------------- *)

let test_k1_picks_higher_rs _ =
  (* Two Stage-2 sectors; XLK climbs faster than XLF, so XLK has the higher RS
     vs SPY and is the single name entered at k=1. *)
  let xlk = stage2_bars ~slope:2.0 in
  let xlf = stage2_bars ~slope:0.8 in
  let bar_reader =
    bar_reader_of [ (benchmark, spy_bars); ("XLK", xlk); ("XLF", xlf) ]
  in
  let strat =
    Sector.make ~config:(config_k ~k:1 ~symbols:[ "XLK"; "XLF" ]) ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:[ ("XLK", friday_bar xlk); ("XLF", friday_bar xlf) ]
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that (entered_symbols result) (equal_to [ "XLK" ])

let test_k1_all_cash_sizing _ =
  (* k=1, flat portfolio: the single entry is sized against ALL cash (one open
     slot), matching [floor(cash / (close * 1.01))]. *)
  let xlk = stage2_bars ~slope:2.0 in
  let today = friday_bar xlk in
  let bar_reader = bar_reader_of [ (benchmark, spy_bars); ("XLK", xlk) ] in
  let strat =
    Sector.make ~config:(config_k ~k:1 ~symbols:[ "XLK" ]) ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:[ ("XLK", today) ]
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  let expected_qty =
    Float.round_down (100_000.0 /. (today.close_price *. 1.01))
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (o : Strategy_interface.output) -> o.transitions)
          (elements_are
             [
               field
                 (fun (t : Position.transition) -> t.kind)
                 (matching ~msg:"Expected CreateEntering XLK with all-cash qty"
                    (function
                      | Position.CreateEntering c ->
                          Some (c.symbol, c.target_quantity)
                      | _ -> None)
                    (all_of
                       [
                         field (fun (s, _) -> s) (equal_to "XLK");
                         field (fun (_, q) -> q) (float_equal expected_qty);
                       ]));
             ])))

let test_rotation_out_exits_weaker _ =
  (* Holding XLF; a stronger XLK appears so XLF leaves the top-1 target set and
     is exited (rotation_out), while XLK is entered. XLF's entry is anchored at
     today's close so its trailing stop sits ~8% below and does not fire —
     isolating the rotation-out path. The portfolio still holds free cash so the
     replacement entry can be funded the same tick. *)
  let xlk = stage2_bars ~slope:2.0 in
  let xlf = stage2_bars ~slope:0.8 in
  let xlf_today = friday_bar xlf in
  let pos =
    make_holding ~symbol:"XLF" ~entry_price:xlf_today.close_price
      ~entry_date:xlf_today.date ~quantity:100.0 ()
  in
  let bar_reader =
    bar_reader_of [ (benchmark, spy_bars); ("XLK", xlk); ("XLF", xlf) ]
  in
  let strat =
    Sector.make ~config:(config_k ~k:1 ~symbols:[ "XLK"; "XLF" ]) ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:[ ("XLK", friday_bar xlk); ("XLF", xlf_today) ]
      ~portfolio:(make_portfolio ~cash:100_000.0 ~positions:[ pos ] ())
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (o : Strategy_interface.output) -> o.transitions)
          (elements_are
             [
               (* The rotation-out exit on XLF (StrategySignal "rotation_out"). *)
               field
                 (fun (t : Position.transition) -> (t.position_id, t.kind))
                 (matching ~msg:"Expected rotation_out exit for XLF"
                    (function
                      | id, Position.TriggerExit e -> (
                          match e.exit_reason with
                          | Position.StrategySignal s -> Some (id, s.label)
                          | _ -> None)
                      | _ -> None)
                    (equal_to ("XLF-sector-rotation-weinstein", "rotation_out")));
               (* The replacement entry on XLK. *)
               field
                 (fun (t : Position.transition) -> t.kind)
                 (matching ~msg:"Expected CreateEntering XLK"
                    (function
                      | Position.CreateEntering c -> Some c.symbol | _ -> None)
                    (equal_to "XLK"));
             ])))

let test_stage4_holding_exits _ =
  (* Holding XLE which has rolled to Stage 4 → exit via the stage signal. Anchor
     the entry at today's close so the trailing stop sits ~8% below and does not
     fire, isolating the stage-exit path. No other sector is Stage 2, so nothing
     is entered. *)
  let xle = stage4_bars in
  let today = friday_bar xle in
  let pos =
    make_holding ~symbol:"XLE" ~entry_price:today.close_price
      ~entry_date:today.date ~quantity:100.0 ()
  in
  let bar_reader = bar_reader_of [ (benchmark, spy_bars); ("XLE", xle) ] in
  let strat =
    Sector.make ~config:(config_k ~k:1 ~symbols:[ "XLE" ]) ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:[ ("XLE", today) ]
      ~portfolio:(make_portfolio ~cash:0.0 ~positions:[ pos ] ())
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (o : Strategy_interface.output) -> o.transitions)
          (elements_are
             [
               field
                 (fun (t : Position.transition) -> t.kind)
                 (matching ~msg:"Expected StrategySignal stage4_exit for XLE"
                    (function
                      | Position.TriggerExit e -> (
                          match e.exit_reason with
                          | Position.StrategySignal s -> Some s.label
                          | _ -> None)
                      | _ -> None)
                    (equal_to "stage4_exit"));
             ])))

let test_k3_holds_top_three _ =
  (* Four Stage-2 sectors at descending slopes. At k=3 exactly the top-3 by RS
     (XLK, XLF, XLI) are entered; XLB (weakest) is not. *)
  let xlk = stage2_bars ~slope:2.0 in
  let xlf = stage2_bars ~slope:1.6 in
  let xli = stage2_bars ~slope:1.2 in
  let xlb = stage2_bars ~slope:0.6 in
  let symbols = [ "XLK"; "XLF"; "XLI"; "XLB" ] in
  let bar_reader =
    bar_reader_of
      [
        (benchmark, spy_bars);
        ("XLK", xlk);
        ("XLF", xlf);
        ("XLI", xli);
        ("XLB", xlb);
      ]
  in
  let strat = Sector.make ~config:(config_k ~k:3 ~symbols) ~bar_reader () in
  let result =
    run_once strat
      ~today_bars:
        [
          ("XLK", friday_bar xlk);
          ("XLF", friday_bar xlf);
          ("XLI", friday_bar xli);
          ("XLB", friday_bar xlb);
        ]
      ~portfolio:(make_portfolio ~cash:120_000.0 ())
  in
  assert_that (entered_symbols result) (equal_to [ "XLF"; "XLI"; "XLK" ])

let test_stop_hit_exits_holding _ =
  (* Holding XLK; today's bar gaps the low far below entry so the trailing-stop
     trigger fires immediately, producing a StopLoss exit independent of the
     day-of-week. *)
  let xlk = stage2_bars ~slope:2.0 in
  let entry_price = (rising ~base:50.0 ~slope:2.0) (n_weeks - 1) in
  let crash_bar =
    make_bar "2021-12-30" ~close:(entry_price *. 0.5) ~low:(entry_price *. 0.5)
      ~high:entry_price ()
  in
  let pos =
    make_holding ~symbol:"XLK" ~entry_price
      ~entry_date:(Date.of_string "2021-12-24")
      ~quantity:100.0 ()
  in
  let bar_reader = bar_reader_of [ (benchmark, spy_bars); ("XLK", xlk) ] in
  let strat =
    Sector.make ~config:(config_k ~k:1 ~symbols:[ "XLK" ]) ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:[ ("XLK", crash_bar) ]
      ~portfolio:(make_portfolio ~cash:0.0 ~positions:[ pos ] ())
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (o : Strategy_interface.output) -> o.transitions)
          (elements_are
             [
               field
                 (fun (t : Position.transition) -> t.kind)
                 (matching ~msg:"Expected StopLoss for XLK"
                    (function
                      | Position.TriggerExit e -> (
                          match e.exit_reason with
                          | Position.StopLoss s -> Some s.actual_price
                          | _ -> None)
                      | _ -> None)
                    (float_equal (entry_price *. 0.5)));
             ])))

let test_no_stage2_no_entry _ =
  (* A flat, choppy tape that never establishes a Stage-2 advance across all
     sectors → no entries (no eligible candidates). *)
  let xlk = flat_bars in
  let xlf = flat_bars in
  let bar_reader =
    bar_reader_of [ (benchmark, spy_bars); ("XLK", xlk); ("XLF", xlf) ]
  in
  let strat =
    Sector.make ~config:(config_k ~k:2 ~symbols:[ "XLK"; "XLF" ]) ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:[ ("XLK", friday_bar xlk); ("XLF", friday_bar xlf) ]
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that result
    (is_ok_and_holds
       (field (fun (o : Strategy_interface.output) -> o.transitions) is_empty))

let test_mid_week_no_rotation _ =
  (* Same strong Stage-2 tape, but mid-week (Wednesday) when flat → no entry; the
     rotation decision only fires on a Friday weekly close. *)
  let xlk = stage2_bars ~slope:2.0 in
  let wed_bar =
    make_bar "2021-12-29"
      ~close:((rising ~base:50.0 ~slope:2.0) (n_weeks - 1))
      ()
  in
  let bar_reader = bar_reader_of [ (benchmark, spy_bars); ("XLK", xlk) ] in
  let strat =
    Sector.make ~config:(config_k ~k:1 ~symbols:[ "XLK" ]) ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:[ ("XLK", wed_bar) ]
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that result
    (is_ok_and_holds
       (field (fun (o : Strategy_interface.output) -> o.transitions) is_empty))

let test_macro_gate_blocks_entry _ =
  (* Gate ON and SPY itself in Stage 4: a Stage-2 sector (XLK, high RS vs the
     falling benchmark) that would normally be entered is blocked — the macro
     gate forces the target set empty. *)
  let xlk = stage2_bars ~slope:2.0 in
  let bar_reader =
    bar_reader_of [ (benchmark, spy_stage4_bars); ("XLK", xlk) ]
  in
  let strat =
    Sector.make ~config:(config_gate ~k:1 ~symbols:[ "XLK" ]) ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:[ ("XLK", friday_bar xlk) ]
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that result
    (is_ok_and_holds
       (field (fun (o : Strategy_interface.output) -> o.transitions) is_empty))

let test_macro_gate_force_exits_holding _ =
  (* Gate ON and SPY in Stage 4: a held Stage-2 sector (XLK) that would normally
     stay (it is the top-1 target) is force-flat via the rotation-out path
     because the gate empties the target. Entry anchored at today's close so the
     trailing stop does not fire — isolating the macro force-exit. No entry. *)
  let xlk = stage2_bars ~slope:2.0 in
  let today = friday_bar xlk in
  let pos =
    make_holding ~symbol:"XLK" ~entry_price:today.close_price
      ~entry_date:today.date ~quantity:100.0 ()
  in
  let bar_reader =
    bar_reader_of [ (benchmark, spy_stage4_bars); ("XLK", xlk) ]
  in
  let strat =
    Sector.make ~config:(config_gate ~k:1 ~symbols:[ "XLK" ]) ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:[ ("XLK", today) ]
      ~portfolio:(make_portfolio ~cash:0.0 ~positions:[ pos ] ())
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (o : Strategy_interface.output) -> o.transitions)
          (elements_are
             [
               field
                 (fun (t : Position.transition) -> (t.position_id, t.kind))
                 (matching
                    ~msg:"Expected macro force-flat (rotation_out) on XLK"
                    (function
                      | id, Position.TriggerExit e -> (
                          match e.exit_reason with
                          | Position.StrategySignal s -> Some (id, s.label)
                          | _ -> None)
                      | _ -> None)
                    (equal_to ("XLK-sector-rotation-weinstein", "rotation_out")));
             ])))

let test_macro_gate_off_ignores_benchmark_stage _ =
  (* Gate OFF (default) with SPY in Stage 4: the benchmark's stage is irrelevant,
     so the Stage-2 XLK is entered exactly as it would be under a rising
     benchmark — proving the gate is a true no-op when off. *)
  let xlk = stage2_bars ~slope:2.0 in
  let bar_reader =
    bar_reader_of [ (benchmark, spy_stage4_bars); ("XLK", xlk) ]
  in
  let strat =
    Sector.make ~config:(config_k ~k:1 ~symbols:[ "XLK" ]) ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:[ ("XLK", friday_bar xlk) ]
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that (entered_symbols result) (equal_to [ "XLK" ])

let test_macro_gate_dormant_when_benchmark_not_stage4 _ =
  (* Gate ON but SPY in Stage 2 (rising): the gate is dormant (it fires only on a
     Stage-4 benchmark), so normal selection proceeds and XLK is entered. *)
  let xlk = stage2_bars ~slope:2.0 in
  let bar_reader = bar_reader_of [ (benchmark, spy_bars); ("XLK", xlk) ] in
  let strat =
    Sector.make ~config:(config_gate ~k:1 ~symbols:[ "XLK" ]) ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:[ ("XLK", friday_bar xlk) ]
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that (entered_symbols result) (equal_to [ "XLK" ])

let test_universe_override_screens_given_symbols _ =
  (* The strategy screens only the symbols its config names. AAPL (Stage 2, high
     RS) and JPM (Stage 4) are present in the bar reader, but the config lists
     ONLY AAPL, so JPM is never screened/entered even though MSFT (a stronger
     Stage-2 name) is also present in the reader. Only AAPL is entered — proving
     the configured universe, not the bar reader's full key set, drives
     selection. This mirrors what the panel builder does when
     [use_scenario_universe = true]: it points the strategy at the scenario's
     symbols. *)
  let aapl = stage2_bars ~slope:2.0 in
  let msft = stage2_bars ~slope:3.0 in
  (* strictly stronger than AAPL *)
  let jpm = stage4_bars in
  let bar_reader =
    bar_reader_of
      [ (benchmark, spy_bars); ("AAPL", aapl); ("MSFT", msft); ("JPM", jpm) ]
  in
  let strat =
    Sector.make ~config:(config_k ~k:2 ~symbols:[ "AAPL" ]) ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:
        [
          ("AAPL", friday_bar aapl);
          ("MSFT", friday_bar msft);
          ("JPM", friday_bar jpm);
        ]
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that (entered_symbols result) (equal_to [ "AAPL" ])

let test_sector_cap_one_per_sector _ =
  (* Three Stage-2 candidates: AAPL + MSFT both Information Technology, JPM
     Financials. MSFT has the highest RS, then AAPL, then JPM. At k=3 the
     uncapped selection would hold all three. With [sector_cap = Some 1], only
     one Information-Technology name (MSFT, the higher RS of the two) is admitted
     and the second IT name (AAPL) is skipped in favour of JPM (a different
     sector) — so the held set is {MSFT, JPM}. *)
  let msft = stage2_bars ~slope:3.0 in
  let aapl = stage2_bars ~slope:2.0 in
  let jpm = stage2_bars ~slope:1.0 in
  let symbols = [ "AAPL"; "MSFT"; "JPM" ] in
  let bar_reader =
    bar_reader_of
      [ (benchmark, spy_bars); ("AAPL", aapl); ("MSFT", msft); ("JPM", jpm) ]
  in
  let strat =
    Sector.make
      ~config:
        (config_cap ~k:3 ~symbols ~sector_cap:(Some 1)
           ~sector_of:fixture_sector_of)
      ~bar_reader ()
  in
  let result =
    run_once strat
      ~today_bars:
        [
          ("AAPL", friday_bar aapl);
          ("MSFT", friday_bar msft);
          ("JPM", friday_bar jpm);
        ]
      ~portfolio:(make_portfolio ~cash:150_000.0 ())
  in
  assert_that (entered_symbols result) (equal_to [ "JPM"; "MSFT" ])

let suite =
  "sector_rotation_weinstein_strategy"
  >::: [
         "k=1 picks higher-RS sector" >:: test_k1_picks_higher_rs;
         "k=1 all-cash sizing" >:: test_k1_all_cash_sizing;
         "rotation out exits weaker holding" >:: test_rotation_out_exits_weaker;
         "Stage4 holding exits" >:: test_stage4_holding_exits;
         "k=3 holds top three by RS" >:: test_k3_holds_top_three;
         "stop hit exits holding" >:: test_stop_hit_exits_holding;
         "no Stage2 means no entry" >:: test_no_stage2_no_entry;
         "mid-week does not rotate" >:: test_mid_week_no_rotation;
         "macro gate blocks entry" >:: test_macro_gate_blocks_entry;
         "macro gate force-exits holding"
         >:: test_macro_gate_force_exits_holding;
         "macro gate off ignores benchmark stage"
         >:: test_macro_gate_off_ignores_benchmark_stage;
         "macro gate dormant when benchmark not Stage4"
         >:: test_macro_gate_dormant_when_benchmark_not_stage4;
         "universe override screens only configured symbols"
         >:: test_universe_override_screens_given_symbols;
         "sector cap limits one holding per sector"
         >:: test_sector_cap_one_per_sector;
       ]

let () = run_test_tt_main suite
