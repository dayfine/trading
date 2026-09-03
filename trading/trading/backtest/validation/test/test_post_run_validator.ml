open Core
open OUnit2
open Matchers
module Vt = Post_run_validator.Validator_types
module Vc = Post_run_validator.Validator_checks
module Va = Post_run_validator.Validator_artifacts

(* ---- builders ---------------------------------------------------------- *)

let trade ?(side = "LONG") ?(exit_trigger = "") ?(stop_trigger_kind = "")
    ?(entry_price = 100.0) ?(exit_price = 100.0) ?(exit_date = "2020-06-01")
    ?(stop_initial_distance_pct = None) ?(position_id = None)
    ?(stop_fill_distance_pct = None) ~symbol ~entry_date () : Vt.trade_row =
  {
    symbol;
    side;
    entry_date = Date.of_string entry_date;
    exit_date = Date.of_string exit_date;
    entry_price;
    exit_price;
    quantity = 100.0;
    exit_trigger;
    stop_trigger_kind;
    stop_initial_distance_pct;
    position_id;
    stop_fill_distance_pct;
  }

let ctx ?(stage = Weinstein_types.Stage2 { weeks_advancing = 3; late = false })
    ?(macro_trend = Weinstein_types.Bullish)
    ?(ma_direction = Weinstein_types.Rising) ?(resistance_quality = None)
    ?(installed_stop = 90.0) ?(suggested_entry = 100.0) () : Vt.entry_context =
  {
    stage;
    macro_trend;
    ma_direction;
    resistance_quality;
    installed_stop;
    suggested_entry;
  }

let audit_of assoc (row : Vt.trade_row) =
  List.Assoc.find assoc row.symbol ~equal:String.equal

let weekly pairs : Vt.bars =
  {
    weekly_dates = Array.of_list_map pairs ~f:(fun (d, _) -> Date.of_string d);
    weekly_closes = Array.of_list_map pairs ~f:(fun (_, c) -> c);
    daily = [||];
  }

let bars_of assoc sym = List.Assoc.find assoc sym ~equal:String.equal
let result ~id inputs = Vc.run_check ~id (inputs : Vt.inputs)

let violations_and_pass n_viol passed =
  all_of
    [
      field (fun (r : Vt.check_result) -> r.n_violations) (equal_to n_viol);
      field (fun (r : Vt.check_result) -> r.passed) (equal_to passed);
    ]

(* ---- V1: LONG entry must be Stage2 ------------------------------------- *)

let test_v1 _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"BAD" ~entry_date:"2020-01-03" ();
          trade ~symbol:"OK" ~entry_date:"2020-02-07" ();
        ];
      audit =
        audit_of
          [
            ("BAD", ctx ~stage:(Weinstein_types.Stage3 { weeks_topping = 2 }) ());
            ("OK", ctx ());
          ];
    }
  in
  assert_that (result ~id:"V1" inputs) (violations_and_pass 1 false)

(* ---- V2: no Bearish-macro LONG entry ----------------------------------- *)

let test_v2 _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"BEAR" ~entry_date:"2020-01-03" () ];
      audit = audit_of [ ("BEAR", ctx ~macro_trend:Weinstein_types.Bearish ()) ];
    }
  in
  assert_that (result ~id:"V2" inputs) (violations_and_pass 1 false)

(* ---- V5: exit_trigger vs stop_trigger_kind consistency ----------------- *)

let test_v5 _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          (* Strategy_signal label must be non_stop_exit, not intraday. *)
          trade ~symbol:"MISMATCH" ~entry_date:"2020-01-03"
            ~exit_trigger:"stage3_force_exit" ~stop_trigger_kind:"intraday" ();
          (* Stop-loss with gap_down is consistent. *)
          trade ~symbol:"OK" ~entry_date:"2020-02-07" ~exit_trigger:"stop_loss"
            ~stop_trigger_kind:"gap_down" ();
        ];
    }
  in
  assert_that (result ~id:"V5" inputs) (violations_and_pass 1 false)

(* A re-traded symbol whose two round-trips each carry consistent per-position
   triggers passes V5. This is the post-fix shape of the WSM specimen the
   trades.csv export-join defect produced (laggard_rotation paired with
   gap_down; stop_loss paired with non_stop_exit) — both joins now key by
   position_id so each row is internally consistent. *)
let test_v5_retraded_symbol_consistent _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"WSM" ~entry_date:"2017-08-01" ~exit_date:"2017-10-14"
            ~exit_trigger:"laggard_rotation" ~stop_trigger_kind:"non_stop_exit"
            ();
          trade ~symbol:"WSM" ~entry_date:"2023-05-01" ~exit_date:"2023-07-01"
            ~exit_trigger:"stop_loss" ~stop_trigger_kind:"intraday" ();
        ];
    }
  in
  assert_that (result ~id:"V5" inputs) (violations_and_pass 0 true)

(* ---- V6: rename-twin duplicate positions ------------------------------- *)

let test_v6 _ =
  let twin symbol =
    trade ~symbol ~entry_date:"2020-01-03" ~exit_date:"2020-05-01"
      ~entry_price:42.0 ~exit_price:37.0 ()
  in
  let inputs =
    { (Vt.empty_inputs ()) with trades = [ twin "NLS"; twin "BFX" ] }
  in
  assert_that (result ~id:"V6" inputs) (violations_and_pass 1 false)

let test_v6_no_twin _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"A" ~entry_date:"2020-01-03" ~entry_price:10.0 ();
          trade ~symbol:"B" ~entry_date:"2020-01-03" ~entry_price:20.0 ();
        ];
    }
  in
  assert_that (result ~id:"V6" inputs) (violations_and_pass 0 true)

(* V6 regression: rename twins differ by feed-adjustment price noise (the
   real NLS/BFX rows: 4.72 vs 4.75 entries, same dates/qty/exit). *)
let test_v6_price_noise_twin _ =
  let t symbol entry_price =
    trade ~symbol ~entry_date:"2020-04-18" ~exit_date:"2021-01-16" ~entry_price
      ~exit_price:21.0 ()
  in
  let inputs =
    { (Vt.empty_inputs ()) with trades = [ t "NLS" 4.72; t "BFX" 4.75 ] }
  in
  assert_that (result ~id:"V6" inputs) (violations_and_pass 1 false)

(* ---- V3/V4: armed-only realism checks ----------------------------------- *)

(* A flat bar: OHLC all equal and unadjusted, so it carries a close + volume
   and nothing else. V13/V14 build their own OHLC bars via [ohlc] below; V15
   builds adjusted ones via [adj_bar]. *)
let flat_bar (d, c, v) : Vt.daily_bar =
  {
    date = Date.of_string d;
    open_price = c;
    high = c;
    low = c;
    close = c;
    adjusted_close = c;
    volume = v;
  }

let with_daily pairs : Vt.bars =
  {
    weekly_dates = [||];
    weekly_closes = [||];
    daily = Array.of_list_map pairs ~f:flat_bar;
  }

let test_v3_armed_flags_thin_adv _ =
  let config =
    { Vt.default_config with min_entry_dollar_adv = Some 1_000_000.0 }
  in
  let inputs =
    {
      (Vt.empty_inputs ~config ()) with
      trades = [ trade ~symbol:"THIN" ~entry_date:"2020-01-10" () ];
      bars = bars_of [ ("THIN", with_daily [ ("2020-01-09", 5.0, 1000) ]) ];
    }
  in
  assert_that (result ~id:"V3" inputs) (violations_and_pass 1 false)

let test_v3_unarmed_noop _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"THIN" ~entry_date:"2020-01-10" () ];
      bars = bars_of [ ("THIN", with_daily [ ("2020-01-09", 5.0, 1000) ]) ];
    }
  in
  assert_that (result ~id:"V3" inputs) (violations_and_pass 0 true)

let test_v4_armed_flags_stale_open _ =
  let config = { Vt.default_config with stale_exit_after_days = Some 5 } in
  let op : Vt.open_row =
    {
      symbol = "GHOST";
      side = "LONG";
      entry_date = Date.of_string "2020-01-10";
      entry_price = 10.0;
      quantity = 100.0;
    }
  in
  let inputs =
    {
      (Vt.empty_inputs ~config ()) with
      open_positions = [ op ];
      bars = bars_of [ ("GHOST", with_daily [ ("2020-02-01", 10.0, 1000) ]) ];
      run_end = Date.of_string "2020-03-01";
    }
  in
  assert_that (result ~id:"V4" inputs) (violations_and_pass 1 false)

(* ---- V7: Virgin_territory needs enough visible history ------------------ *)

let test_v7_starved_virgin _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"COO" ~entry_date:"2020-05-29" () ];
      audit =
        audit_of
          [
            ( "COO",
              ctx ~resistance_quality:(Some Weinstein_types.Virgin_territory) ()
            );
          ];
      bars =
        bars_of
          [ ("COO", weekly [ ("2020-05-22", 90.0); ("2020-05-29", 100.0) ]) ];
    }
  in
  assert_that (result ~id:"V7" inputs) (violations_and_pass 1 false)

(* ---- V8: Declining-MA entry -------------------------------------------- *)

let test_v8_declining_ma _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"AIR" ~entry_date:"2020-03-14" () ];
      audit =
        audit_of [ ("AIR", ctx ~ma_direction:Weinstein_types.Declining ()) ];
    }
  in
  assert_that (result ~id:"V8" inputs) (violations_and_pass 1 false)

(* ---- V9: entry beneath overhead supply --------------------------------- *)

let test_v9 _ =
  (* Prior top 115 sits +15% above the 100 entry (inside the 25% band). *)
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"OVH" ~entry_date:"2020-05-29" () ];
      bars =
        bars_of
          [ ("OVH", weekly [ ("2019-01-04", 115.0); ("2020-05-29", 100.0) ]) ];
    }
  in
  assert_that (result ~id:"V9" inputs) (violations_and_pass 1 false)

let test_v9_clean _ =
  (* All prior closes below entry: a clean breakout, no overhead. *)
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"CLR" ~entry_date:"2020-05-29" () ];
      bars =
        bars_of
          [ ("CLR", weekly [ ("2019-01-04", 80.0); ("2020-05-29", 100.0) ]) ];
    }
  in
  assert_that (result ~id:"V9" inputs) (violations_and_pass 0 true)

(* ---- V10: entry-week vertical spike ------------------------------------ *)

let spike_bars closes =
  weekly
    (List.zip_exn
       [ "2020-05-01"; "2020-05-08"; "2020-05-15"; "2020-05-22"; "2020-05-29" ]
       closes)

let test_v10 _ =
  (* Entry week 100 is +100% above the 4-weeks-ago 50 (> 60% spike). *)
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"SPK" ~entry_date:"2020-05-29" () ];
      bars = bars_of [ ("SPK", spike_bars [ 50.0; 50.0; 50.0; 50.0; 100.0 ]) ];
    }
  in
  assert_that (result ~id:"V10" inputs) (violations_and_pass 1 false)

let test_v10_calm _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"CLM" ~entry_date:"2020-05-29" () ];
      bars = bars_of [ ("CLM", spike_bars [ 90.0; 90.0; 90.0; 90.0; 100.0 ]) ];
    }
  in
  assert_that (result ~id:"V10" inputs) (violations_and_pass 0 true)

(* ---- V11: stop distance bounds ----------------------------------------- *)

let test_v11 _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"WIDE" ~entry_date:"2020-01-03"
            ~stop_initial_distance_pct:(Some 0.55) ();
          trade ~symbol:"OK" ~entry_date:"2020-02-07"
            ~stop_initial_distance_pct:(Some 0.08) ();
        ];
    }
  in
  assert_that (result ~id:"V11" inputs) (violations_and_pass 1 false)

(* ---- V12: stop-distance gate consistency ------------------------------- *)

(* A fill at 100 with an installed stop at 50 is 50% away — wider than the 15%
   gate, so the [Stop_too_wide] gate should have rejected it. A stop at 90 (10%)
   is within the gate and passes. The distance is measured against the FILL
   (entry_price), exactly as the gate measures it. *)
let test_v12 _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"WIDE" ~entry_date:"2020-01-03" ~entry_price:100.0 ();
          trade ~symbol:"OK" ~entry_date:"2020-02-07" ~entry_price:100.0 ();
        ];
      audit =
        audit_of
          [
            ("WIDE", ctx ~installed_stop:50.0 ());
            ("OK", ctx ~installed_stop:90.0 ());
          ];
    }
  in
  assert_that (result ~id:"V12" inputs) (violations_and_pass 1 false)

(* Rows with no audit join or a legacy [installed_stop = 0.0] are un-evaluable
   and must be skipped (not flagged), so V12 stays PASS on inputs it cannot
   judge rather than false-firing. *)
let test_v12_skips_unevaluable _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"NOAUDIT" ~entry_date:"2020-01-03" ~entry_price:100.0 ();
          trade ~symbol:"LEGACY" ~entry_date:"2020-02-07" ~entry_price:100.0 ();
        ];
      audit = audit_of [ ("LEGACY", ctx ~installed_stop:0.0 ()) ];
    }
  in
  assert_that (result ~id:"V12" inputs) (violations_and_pass 0 true)

(* The gate threshold is configurable: a run whose strategy loosened the gate to
   60% must not flag a 50% stop. *)
let test_v12_respects_config_gate _ =
  let inputs =
    {
      (Vt.empty_inputs
         ~config:{ Vt.default_config with gate_max_stop_distance_pct = 0.60 }
         ())
      with
      trades =
        [ trade ~symbol:"WIDE" ~entry_date:"2020-01-03" ~entry_price:100.0 () ];
      audit = audit_of [ ("WIDE", ctx ~installed_stop:50.0 ()) ];
    }
  in
  assert_that (result ~id:"V12" inputs) (violations_and_pass 0 true)

(* ---- V13: fill dates and prices must lie on a real bar ----------------- *)

let ohlc ~date ~o ~h ~l ~c : Vt.daily_bar =
  {
    date = Date.of_string date;
    open_price = o;
    high = h;
    low = l;
    close = c;
    adjusted_close = c;
    volume = 1000;
  }

let ohlc_bars lst : Vt.bars =
  { weekly_dates = [||]; weekly_closes = [||]; daily = Array.of_list lst }

let skipped_and_pass n_skipped passed =
  all_of
    [
      field (fun (r : Vt.check_result) -> r.n_skipped) (equal_to n_skipped);
      field (fun (r : Vt.check_result) -> r.passed) (equal_to passed);
    ]

(* Full outcome: violations, un-evaluable rows, and the pass verdict together.
   Discriminates a genuine Pass from a Skip that also leaves the violation
   count at zero. *)
let violations_skipped_pass n_viol n_skipped passed =
  all_of
    [
      violations_and_pass n_viol passed;
      field (fun (r : Vt.check_result) -> r.n_skipped) (equal_to n_skipped);
    ]

(* Mon 2020-06-01 entry at 100 (inside [98,102]), Fri 2020-06-05 exit at 110
   (inside [108,112]) — both fills sit on a real bar, inside its range. *)
let test_v13_clean _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"OK" ~entry_date:"2020-06-01" ~entry_price:100.0
            ~exit_date:"2020-06-05" ~exit_price:110.0 ();
        ];
      bars =
        bars_of
          [
            ( "OK",
              ohlc_bars
                [
                  ohlc ~date:"2020-06-01" ~o:99.0 ~h:102.0 ~l:98.0 ~c:100.0;
                  ohlc ~date:"2020-06-05" ~o:109.0 ~h:112.0 ~l:108.0 ~c:110.0;
                ] );
          ];
    }
  in
  assert_that (result ~id:"V13" inputs) (violations_and_pass 0 true)

(* The §D1 defect: the exit is dated Saturday 2020-06-06, a day on which no bar
   exists, at the preceding Friday's price. *)
let test_v13_flags_saturday_exit _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"SAT" ~entry_date:"2020-06-01" ~entry_price:100.0
            ~exit_date:"2020-06-06" ~exit_price:105.0 ();
        ];
      bars =
        bars_of
          [
            ( "SAT",
              ohlc_bars
                [
                  ohlc ~date:"2020-06-01" ~o:99.0 ~h:102.0 ~l:98.0 ~c:100.0;
                  ohlc ~date:"2020-06-05" ~o:104.0 ~h:107.0 ~l:103.0 ~c:105.0;
                ] );
          ];
    }
  in
  assert_that (result ~id:"V13" inputs) (violations_and_pass 1 false)

(* The exit day HAS a bar, but the fill at 130 sits above its high of 112. *)
let test_v13_flags_price_outside_bar _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"OOR" ~entry_date:"2020-06-01" ~entry_price:100.0
            ~exit_date:"2020-06-05" ~exit_price:130.0 ();
        ];
      bars =
        bars_of
          [
            ( "OOR",
              ohlc_bars
                [
                  ohlc ~date:"2020-06-01" ~o:99.0 ~h:102.0 ~l:98.0 ~c:100.0;
                  ohlc ~date:"2020-06-05" ~o:109.0 ~h:112.0 ~l:108.0 ~c:110.0;
                ] );
          ];
    }
  in
  assert_that (result ~id:"V13" inputs) (violations_and_pass 1 false)

(* A symbol the bar store does not carry is un-evaluable, not a violation: it
   is skipped and surfaces in the finding's skip count. *)
let test_v13_skips_absent_symbol _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"GONE" ~entry_date:"2020-06-01" () ];
    }
  in
  assert_that (result ~id:"V13" inputs) (skipped_and_pass 1 true)

(* A store entry the loader produced with no daily bars at all is un-evaluable
   for the same reason an absent symbol is. *)
let test_v13_skips_store_with_no_daily_bars _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"EMPTY" ~entry_date:"2020-06-01" () ];
      bars = bars_of [ ("EMPTY", ohlc_bars []) ];
    }
  in
  assert_that (result ~id:"V13" inputs) (skipped_and_pass 1 true)

(* Bars re-based 4:1 after the run: the stored close of 25 against a fill of 100
   is a ratio of 0.25, far outside the basis band, so comparing the two would
   flag every fill for the symbol. Both legs land on a real bar, so the row is
   un-evaluable (skipped + counted), not a violation and not a silent pass. *)
let rebased_bars =
  ohlc_bars
    [
      ohlc ~date:"2020-06-01" ~o:24.75 ~h:25.5 ~l:24.5 ~c:25.0;
      ohlc ~date:"2020-06-05" ~o:27.25 ~h:28.0 ~l:27.0 ~c:27.5;
    ]

let rebased_trade ~exit_date =
  trade ~symbol:"SPLIT" ~entry_date:"2020-06-01" ~entry_price:100.0 ~exit_date
    ~exit_price:110.0 ()

let test_v13_rebased_store_waives_price_leg _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ rebased_trade ~exit_date:"2020-06-05" ];
      bars = bars_of [ ("SPLIT", rebased_bars) ];
    }
  in
  assert_that (result ~id:"V13" inputs) (violations_skipped_pass 0 1 true)

(* Same re-based store, but the exit is dated on a Saturday. The date leg is
   basis-free, so it still fires: waiving the price leg must not disable §D1
   detection for a re-based symbol. *)
let test_v13_rebased_store_still_flags_saturday_exit _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ rebased_trade ~exit_date:"2020-06-06" ];
      bars = bars_of [ ("SPLIT", rebased_bars) ];
    }
  in
  assert_that (result ~id:"V13" inputs) (violations_skipped_pass 1 0 false)

(* ---- V14: stop-out judged against the entry bar ------------------------ *)

(* The §D2 artifact shape: fill 100 with a 5% stop at 95; the entry bar dipped
   to 94 (below the stop) but CLOSED at 99, above it — the position never
   closed through its stop, yet it was sold the next day at 98, also above the
   stop. The stop was judged against the entry bar's pre-fill low. *)
(* The entry bar carries the caller's low/high/close; every [later] date gets an
   ordinary bar so [bars_in_window] has real trading days to count. *)
let ebs_bars ~entry_date ~entry_low ~entry_high ~entry_close ~later =
  ohlc_bars
    (ohlc ~date:entry_date ~o:100.0 ~h:entry_high ~l:entry_low ~c:entry_close
    :: List.map later ~f:(fun d -> ohlc ~date:d ~o:98.0 ~h:99.0 ~l:97.0 ~c:98.0)
    )

let stopout_inputs ?(config = Vt.default_config) ?(side = "LONG")
    ?(stop_fill_distance_pct = Some 0.05) ?(stop_initial_distance_pct = None)
    ?(entry_date = "2020-06-01") ?(exit_date = "2020-06-02")
    ?(later = [ "2020-06-02" ]) ?(entry_high = 101.0) ~entry_low ~entry_close ()
    =
  {
    (Vt.empty_inputs ~config ()) with
    trades =
      [
        trade ~symbol:"EBS" ~side ~entry_date ~entry_price:100.0 ~exit_date
          ~exit_price:98.0 ~exit_trigger:"stop_loss" ~stop_fill_distance_pct
          ~stop_initial_distance_pct ();
      ];
    bars =
      bars_of
        [
          ( "EBS",
            ebs_bars ~entry_date ~entry_low ~entry_high ~entry_close ~later );
        ];
  }

let entry_bar_stopout_inputs ~entry_low ~entry_close =
  stopout_inputs ~entry_low ~entry_close ()

let config_max_bars n =
  { Vt.default_config with entry_bar_stopout_max_bars = n }

let test_v14_flags_entry_bar_stopout _ =
  assert_that
    (result ~id:"V14"
       (entry_bar_stopout_inputs ~entry_low:94.0 ~entry_close:99.0))
    (violations_and_pass 1 false)

(* A genuine gap-down entry day closes PAST the stop (90 < 95): the stop-out is
   legitimate and must not flag. *)
let test_v14_allows_genuine_gap_down _ =
  assert_that
    (result ~id:"V14"
       (entry_bar_stopout_inputs ~entry_low:88.0 ~entry_close:90.0))
    (violations_and_pass 0 true)

(* Same bar shape, but the exit was a rotation rather than a stop — V14 has no
   stop to reason about and passes the row untouched. *)
let test_v14_ignores_non_stop_exit _ =
  let inputs =
    {
      (entry_bar_stopout_inputs ~entry_low:94.0 ~entry_close:99.0) with
      trades =
        [
          trade ~symbol:"EBS" ~entry_date:"2020-06-01" ~entry_price:100.0
            ~exit_date:"2020-06-02" ~exit_price:98.0
            ~exit_trigger:"laggard_rotation" ~stop_fill_distance_pct:(Some 0.05)
            ();
        ];
    }
  in
  assert_that (result ~id:"V14" inputs) (violations_and_pass 0 true)

(* An ordinary stop-loss several bars after entry. Its entry bar closed above
   the stop, exactly like the §D2 shape — only the bar window keeps V14 from
   flagging it, so this is the test that fails if the window guard is dropped. *)
let late_stop_exit_inputs config =
  stopout_inputs ~config ~entry_low:94.0 ~entry_close:99.0
    ~exit_date:"2020-06-05"
    ~later:[ "2020-06-02"; "2020-06-03"; "2020-06-04"; "2020-06-05" ]
    ()

let test_v14_ignores_late_stop_exit _ =
  assert_that
    (result ~id:"V14" (late_stop_exit_inputs Vt.default_config))
    (violations_skipped_pass 0 0 true)

(* Same trade, window widened past the four intervening bars: now in scope and
   flagged. Together with the previous test this pins the knob itself. *)
let test_v14_widened_window_flags_late_exit _ =
  assert_that
    (result ~id:"V14" (late_stop_exit_inputs (config_max_bars 4)))
    (violations_skipped_pass 1 0 false)

(* [bars_in_window] counts BARS, not calendar days. With the window at zero, a
   Friday entry and a Monday exit are one bar apart and out of scope... *)
let friday_entry_inputs ~config ~exit_date ~later =
  stopout_inputs ~config ~entry_low:94.0 ~entry_close:99.0
    ~entry_date:"2020-06-05" ~exit_date ~later ()

let test_v14_friday_to_monday_counts_one_bar _ =
  assert_that
    (result ~id:"V14"
       (friday_entry_inputs ~config:(config_max_bars 0) ~exit_date:"2020-06-08"
          ~later:[ "2020-06-08" ]))
    (violations_skipped_pass 0 0 true)

(* ...while a Saturday-dated exit counts ZERO bars (no bar exists that day), so
   it stays in scope even at a zero-bar window. *)
let test_v14_saturday_exit_counts_zero_bars _ =
  assert_that
    (result ~id:"V14"
       (friday_entry_inputs ~config:(config_max_bars 0) ~exit_date:"2020-06-06"
          ~later:[ "2020-06-08" ]))
    (violations_skipped_pass 1 0 false)

(* A legacy trades.csv row predating the stop_fill_distance_pct column: the
   E-basis stop_initial_distance_pct reconstructs the same 95 stop. *)
let test_v14_falls_back_to_initial_distance _ =
  assert_that
    (result ~id:"V14"
       (stopout_inputs ~stop_fill_distance_pct:None
          ~stop_initial_distance_pct:(Some 0.05) ~entry_low:94.0
          ~entry_close:99.0 ()))
    (violations_skipped_pass 1 0 false)

(* Both columns present, with stops on opposite sides of the entry close: the
   fill-basis 0.5% gives a stop of 99.5 (close 99 is BELOW it — a real
   stop-out), the E-basis 5% would give 95 and flag. Preferring fill-basis is
   what makes this row clean. *)
let test_v14_prefers_fill_distance_over_initial _ =
  assert_that
    (result ~id:"V14"
       (stopout_inputs ~stop_fill_distance_pct:(Some 0.005)
          ~stop_initial_distance_pct:(Some 0.05) ~entry_low:94.0
          ~entry_close:99.0 ()))
    (violations_skipped_pass 0 0 true)

(* Neither stop-distance column: the stop cannot be reconstructed, so the row is
   un-evaluable rather than clean. *)
let test_v14_skips_row_with_no_stop_distance _ =
  assert_that
    (result ~id:"V14"
       (stopout_inputs ~stop_fill_distance_pct:None
          ~stop_initial_distance_pct:None ~entry_low:94.0 ~entry_close:99.0 ()))
    (violations_skipped_pass 0 1 true)

(* SHORT mirror of the §D2 shape: the stop sits ABOVE the fill at 105, the entry
   bar spiked through it to 106 but closed at 99 — below the stop, the protected
   side for a short — so the same-bar stop-out had nothing to fire on. *)
let test_v14_short_flags_entry_bar_stopout _ =
  assert_that
    (result ~id:"V14"
       (stopout_inputs ~side:"SHORT" ~entry_low:98.0 ~entry_high:106.0
          ~entry_close:99.0 ()))
    (violations_skipped_pass 1 0 false)

(* SHORT mirror of the genuine gap: the entry day closed at 110, PAST the 105
   stop, so the stop-out is legitimate. *)
let test_v14_short_allows_genuine_gap_up _ =
  assert_that
    (result ~id:"V14"
       (stopout_inputs ~side:"SHORT" ~entry_low:100.0 ~entry_high:112.0
          ~entry_close:110.0 ()))
    (violations_skipped_pass 0 0 true)

(* A stop-loss row whose symbol the bar store does not carry: there is no entry
   bar to judge the reconstructed stop against, so the row is un-evaluable
   rather than clean, and the skip is counted. *)
let test_v14_skips_absent_symbol _ =
  let inputs =
    {
      (entry_bar_stopout_inputs ~entry_low:94.0 ~entry_close:99.0) with
      bars = (fun _ -> None);
    }
  in
  assert_that (result ~id:"V14" inputs) (violations_skipped_pass 0 1 true)

(* The same row against a store entry the loader produced with no daily bars at
   all — un-evaluable for the same reason an absent symbol is. *)
let test_v14_skips_store_with_no_daily_bars _ =
  let inputs =
    {
      (entry_bar_stopout_inputs ~entry_low:94.0 ~entry_close:99.0) with
      bars = bars_of [ ("EBS", ohlc_bars []) ];
    }
  in
  assert_that (result ~id:"V14" inputs) (violations_skipped_pass 0 1 true)

(* Bars re-based after the run: the entry bar's close of 24.75 against a fill of
   100 is a ratio of 0.2475, far outside the basis band, so the bar and the
   reconstructed stop are not on the same scale. The row is the §D2 shape in
   miniature — the 80% stop distance puts the stop at 20 and the entry bar
   closed above it, so WITHOUT the basis guard this row would flag. The guard is
   what keeps a re-based symbol from flagging every one of its stop-losses. *)
let test_v14_rebased_store_skips_stop_comparison _ =
  assert_that
    (result ~id:"V14"
       (stopout_inputs ~stop_fill_distance_pct:(Some 0.80) ~entry_low:19.0
          ~entry_high:25.5 ~entry_close:24.75 ()))
    (violations_skipped_pass 0 1 true)

(* ---- V15: huge, brief round trip whose fill bar sits on a data splice --- *)

(* A bar carrying an explicit raw close and adjusted close (mirroring
   [Test_splice_detector.bar]). The two are equal by default — no corporate
   action in the window — so a fixture spells out [raw] only when it is testing
   the split path, where the whole point is that the two bases disagree. *)
let adj_bar ~date ~adj ?raw () : Vt.daily_bar =
  let close = Option.value raw ~default:adj in
  {
    date = Date.of_string date;
    open_price = close;
    high = close;
    low = close;
    close;
    adjusted_close = adj;
    volume = 1000;
  }

let adj_bars lst : Vt.bars =
  { weekly_dates = [||]; weekly_closes = [||]; daily = Array.of_list lst }

(* The issue-#2646 specimen. CHS's adjusted close steps 4.0693 -> 15.8803
   (x3.902) on 2004-12-20 with no split behind it: from that bar the series is
   a different security under a recycled ticker. Bought Friday at 11.2875,
   "sold" Monday at 45.16 — +300% on a three-day hold. *)
let chs_bars =
  adj_bars
    [
      adj_bar ~date:"2004-12-15" ~adj:4.05 ();
      adj_bar ~date:"2004-12-16" ~adj:4.06 ();
      adj_bar ~date:"2004-12-17" ~adj:4.0693 ();
      adj_bar ~date:"2004-12-20" ~adj:15.8803 ();
    ]

let chs_inputs ?(config = Vt.default_config) ?(side = "LONG")
    ?(exit_date = "2004-12-20") ?(exit_price = 45.16) ?(bars = chs_bars) () =
  {
    (Vt.empty_inputs ~config ()) with
    trades =
      [
        trade ~side ~symbol:"CHS" ~entry_date:"2004-12-17" ~entry_price:11.2875
          ~exit_date ~exit_price ();
      ];
    bars = bars_of [ ("CHS", bars) ];
  }

let test_v15_flags_chs_exit_splice _ =
  assert_that
    (result ~id:"V15" (chs_inputs ()))
    (violations_skipped_pass 1 0 false)

(* The same artifact on the short side: the SHORT loses 300% instead of gaining
   it, and the unsigned P&L test flags it identically. *)
let test_v15_flags_short_side_of_same_splice _ =
  assert_that
    (result ~id:"V15" (chs_inputs ~side:"SHORT" ()))
    (violations_skipped_pass 1 0 false)

(* A real +120% four-day trade on a continuous series. It clears BOTH halves of
   the candidate predicate, so only the bar-continuity test keeps it clean —
   this is what separates V15 from "flag every implausible-looking trade". *)
let test_v15_clean_fast_double _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"REAL" ~entry_date:"2020-06-01" ~entry_price:10.0
            ~exit_date:"2020-06-05" ~exit_price:22.0 ();
        ];
      bars =
        bars_of
          [
            ( "REAL",
              adj_bars
                [
                  adj_bar ~date:"2020-05-29" ~adj:9.8 ();
                  adj_bar ~date:"2020-06-01" ~adj:10.0 ();
                  adj_bar ~date:"2020-06-02" ~adj:13.0 ();
                  adj_bar ~date:"2020-06-03" ~adj:16.5 ();
                  adj_bar ~date:"2020-06-04" ~adj:20.0 ();
                  adj_bar ~date:"2020-06-05" ~adj:22.0 ();
                ] );
          ];
    }
  in
  assert_that (result ~id:"V15" inputs) (violations_skipped_pass 0 0 true)

(* A correctly adjusted 4:1 split on the ENTRY bar: the raw close steps
   400 -> 100 (x0.25, far below [splice_adj_ratio_min]) while the adjusted close
   holds at 100 (x1.0), because the back-roll has already absorbed the split.
   The row is a genuine candidate — a +120% four-day round trip on the
   post-split basis the simulator fills at — so only the choice of series keeps
   it clean. Reading [close] here instead of [adjusted_close] would flag every
   split in the store; this is the one V15 fixture where the two bases
   disagree, and it is what makes the "ordinary corporate actions do not flag"
   claim testable. *)
let test_v15_clean_across_adjusted_split _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"SPLIT4" ~entry_date:"2020-08-31" ~entry_price:100.0
            ~exit_date:"2020-09-04" ~exit_price:220.0 ();
        ];
      bars =
        bars_of
          [
            ( "SPLIT4",
              adj_bars
                [
                  adj_bar ~date:"2020-08-28" ~adj:100.0 ~raw:400.0 ();
                  adj_bar ~date:"2020-08-31" ~adj:100.0 ~raw:100.0 ();
                  adj_bar ~date:"2020-09-04" ~adj:220.0 ();
                ] );
          ];
    }
  in
  assert_that (result ~id:"V15" inputs) (violations_skipped_pass 0 0 true)

(* The entry bar is the FIRST of the series, so it has no predecessor to
   measure against. Un-evaluable, not clean: the row is Skipped and counted,
   even though the exit leg on its own is continuous. *)
let test_v15_skips_fill_bar_without_prior _ =
  let bars =
    adj_bars
      [
        adj_bar ~date:"2004-12-17" ~adj:4.0693 ();
        adj_bar ~date:"2004-12-20" ~adj:4.1 ();
      ]
  in
  assert_that
    (result ~id:"V15" (chs_inputs ~bars ~exit_price:34.0 ()))
    (violations_skipped_pass 0 1 true)

(* Boundary: a ratio of exactly [splice_adj_ratio_max] (10.0 / 4.0 = 2.5) is
   inside the band and passes; a hair past it flags. *)
let bounded_inputs ~exit_adj =
  {
    (Vt.empty_inputs ()) with
    trades =
      [
        trade ~symbol:"EDGE" ~entry_date:"2020-06-02" ~entry_price:10.0
          ~exit_date:"2020-06-03" ~exit_price:25.0 ();
      ];
    bars =
      bars_of
        [
          ( "EDGE",
            adj_bars
              [
                adj_bar ~date:"2020-06-01" ~adj:3.9 ();
                adj_bar ~date:"2020-06-02" ~adj:4.0 ();
                adj_bar ~date:"2020-06-03" ~adj:exit_adj ();
              ] );
        ];
  }

let test_v15_ratio_at_upper_bound_passes _ =
  assert_that
    (result ~id:"V15" (bounded_inputs ~exit_adj:10.0))
    (violations_skipped_pass 0 0 true)

let test_v15_ratio_just_past_upper_bound_flags _ =
  assert_that
    (result ~id:"V15" (bounded_inputs ~exit_adj:10.1))
    (violations_skipped_pass 1 0 false)

(* The other bound, on the entry leg: the entry bar's adjusted close collapses
   to a quarter of the prior bar's (a cheaper security taking over the ticker),
   after which the "price" quadruples back. Ratio 0.25 < 0.4 flags. *)
let test_v15_flags_entry_bar_collapse _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"REUSE" ~entry_date:"2020-06-02" ~entry_price:10.0
            ~exit_date:"2020-06-03" ~exit_price:41.0 ();
        ];
      bars =
        bars_of
          [
            ( "REUSE",
              adj_bars
                [
                  adj_bar ~date:"2020-06-01" ~adj:40.0 ();
                  adj_bar ~date:"2020-06-02" ~adj:10.0 ();
                  adj_bar ~date:"2020-06-03" ~adj:11.0 ();
                ] );
          ];
    }
  in
  assert_that (result ~id:"V15" inputs) (violations_skipped_pass 1 0 false)

(* Candidate predicate, hold-length half: the same spliced exit bar held past
   [splice_max_days_held] is not a candidate at all — passed, not skipped. *)
let test_v15_ignores_long_hold _ =
  let bars =
    adj_bars
      [
        adj_bar ~date:"2004-12-16" ~adj:4.06 ();
        adj_bar ~date:"2004-12-17" ~adj:4.0693 ();
        adj_bar ~date:"2004-12-27" ~adj:15.8803 ();
      ]
  in
  assert_that
    (result ~id:"V15" (chs_inputs ~bars ~exit_date:"2004-12-27" ()))
    (violations_skipped_pass 0 0 true)

(* Candidate predicate, P&L half: a modest move over the same spliced bar is
   not a candidate. *)
let test_v15_ignores_modest_move _ =
  assert_that
    (result ~id:"V15" (chs_inputs ~exit_price:12.0 ()))
    (violations_skipped_pass 0 0 true)

let test_v15_skips_absent_symbol _ =
  assert_that
    (result ~id:"V15" { (chs_inputs ()) with bars = (fun _ -> None) })
    (violations_skipped_pass 0 1 true)

let test_v15_skips_store_with_no_daily_bars _ =
  assert_that
    (result ~id:"V15" (chs_inputs ~bars:(adj_bars []) ()))
    (violations_skipped_pass 0 1 true)

(* The entry bar's predecessor carries a zero [adjusted_close] — a vendor row
   with no adjustment recorded. The ratio is undefined there, so the row is
   un-evaluable and Skipped. Without the non-positive guard the division would
   yield [infinity], which is outside every band and would report this
   data-quality hole as a splice VIOLATION rather than an un-evaluable
   candidate. The exit leg (10.0 -> 22.0, x2.2) is inside the band, so the Skip
   can only come from the entry leg. *)
let test_v15_skips_non_positive_prior_close _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"ZEROADJ" ~entry_date:"2020-06-02" ~entry_price:10.0
            ~exit_date:"2020-06-03" ~exit_price:22.0 ();
        ];
      bars =
        bars_of
          [
            ( "ZEROADJ",
              adj_bars
                [
                  adj_bar ~date:"2020-06-01" ~adj:0.0 ();
                  adj_bar ~date:"2020-06-02" ~adj:10.0 ();
                  adj_bar ~date:"2020-06-03" ~adj:22.0 ();
                ] );
          ];
    }
  in
  assert_that (result ~id:"V15" inputs) (violations_skipped_pass 0 1 true)

(* The band is config-routed, not a literal: widening the ceiling past the
   3.902 CHS ratio makes the same row pass. *)
let test_v15_respects_configured_bounds _ =
  let config = { Vt.default_config with splice_adj_ratio_max = 5.0 } in
  assert_that
    (result ~id:"V15" (chs_inputs ~config ()))
    (violations_skipped_pass 0 0 true)

(* ---- bar loading: the raw-vs-adjusted price basis ---------------------- *)

(* A stored bar with a live adjustment: [raw] is what the tape printed, [adj]
   is the back-rolled close. *)
let stored_bar ~date ~raw ~adj =
  Types.Daily_price.make ~date:(Date.of_string date) ~open_price:raw
    ~high_price:raw ~low_price:raw ~close_price:raw ~volume:1000
    ~adjusted_close:adj ()

(* The construction site every bar-dependent check inherits its basis from.
   A 4:1 split: Thursday's raw close is 400 against an adjusted 100, Friday's
   raw close is 100 with the adjusted close unchanged. [close] must carry the
   RAW series (V13 compares [trades.csv] fills to it) and [adjusted_close] the
   ADJUSTED one (V15's day-over-day ratio has to be blind to splits).
   Populating [adjusted_close] from [close_price] would collapse both onto one
   basis, and every V15 fixture — which sets the two equal — would still
   pass. *)
let test_bars_of_daily_keeps_raw_and_adjusted_apart _ =
  let bars =
    Va.bars_of_daily
      [
        stored_bar ~date:"2020-08-27" ~raw:400.0 ~adj:100.0;
        stored_bar ~date:"2020-08-28" ~raw:100.0 ~adj:100.0;
      ]
  in
  assert_that (Array.to_list bars.daily)
    (elements_are
       [
         all_of
           [
             field (fun (b : Vt.daily_bar) -> b.close) (float_equal 400.0);
             field
               (fun (b : Vt.daily_bar) -> b.adjusted_close)
               (float_equal 100.0);
           ];
         all_of
           [
             field (fun (b : Vt.daily_bar) -> b.close) (float_equal 100.0);
             field
               (fun (b : Vt.daily_bar) -> b.adjusted_close)
               (float_equal 100.0);
           ];
       ])

(* ---- audit join: position_id vs symbol|date ---------------------------- *)

let join_row ?(context = ctx ()) ~position_id ~symbol ~entry_date () :
    Va.audit_join_row =
  { position_id; symbol; entry_date = Date.of_string entry_date; context }

(* The audit entry_date is the SIGNAL Friday (2014-11-28); the trades.csv row
   carries the FILL date (next trading day, 2014-11-29). The old symbol|date join
   missed 100% of rows on this skew — position_id joins through it. *)
let test_join_by_position_id_survives_date_skew _ =
  let lookup =
    Va.build_audit_lookup
      [
        join_row ~position_id:"A-wein-5618" ~symbol:"A" ~entry_date:"2014-11-28"
          ~context:(ctx ~macro_trend:Weinstein_types.Bearish ())
          ();
      ]
  in
  let row =
    trade ~symbol:"A" ~entry_date:"2014-11-29" ~position_id:(Some "A-wein-5618")
      ()
  in
  assert_that (lookup row)
    (is_some_and
       (field
          (fun (c : Vt.entry_context) -> c.macro_trend)
          (equal_to Weinstein_types.Bearish)))

(* A legacy 19-column row (no position_id) falls back to the symbol|date key,
   which for legacy runs is the only key available. *)
let test_join_legacy_falls_back_to_symbol_date _ =
  let lookup =
    Va.build_audit_lookup
      [
        join_row ~position_id:"B-wein-1" ~symbol:"B" ~entry_date:"2020-02-07" ();
      ]
  in
  let row = trade ~symbol:"B" ~entry_date:"2020-02-07" ~position_id:None () in
  assert_that (lookup row)
    (is_some_and
       (field
          (fun (c : Vt.entry_context) -> c.macro_trend)
          (equal_to Weinstein_types.Bullish)))

(* Coverage counts: 2 of 3 trades resolve to an audit record (P9 has none). *)
let test_audit_join_coverage_counts _ =
  let lookup =
    Va.build_audit_lookup
      [
        join_row ~position_id:"P1" ~symbol:"A" ~entry_date:"2020-01-03" ();
        join_row ~position_id:"P2" ~symbol:"B" ~entry_date:"2020-02-07" ();
      ]
  in
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~symbol:"A" ~entry_date:"2020-01-06" ~position_id:(Some "P1") ();
          trade ~symbol:"B" ~entry_date:"2020-02-10" ~position_id:(Some "P2") ();
          trade ~symbol:"C" ~entry_date:"2020-03-02" ~position_id:(Some "P9") ();
        ];
      audit = lookup;
    }
  in
  assert_that (Vc.validate inputs).audit_join
    (equal_to ({ matched = 2; total = 3 } : Vt.audit_join))

(* ---- severity + validate wiring ---------------------------------------- *)

let test_severity_default _ =
  assert_that
    (result ~id:"V1" (Vt.empty_inputs ()))
    (field (fun (r : Vt.check_result) -> r.severity) (equal_to Vt.Invariant))

let test_validate_runs_all _ =
  let report = Vc.validate (Vt.empty_inputs ()) in
  assert_that report.checks (size_is (List.length Vc.all_check_ids))

let suite =
  "post_run_validator"
  >::: [
         "v1_stage" >:: test_v1;
         "v2_macro" >:: test_v2;
         "v5_trigger_consistency" >:: test_v5;
         "v5_retraded_symbol_consistent" >:: test_v5_retraded_symbol_consistent;
         "v6_twin" >:: test_v6;
         "v6_no_twin" >:: test_v6_no_twin;
         "v6_price_noise_twin" >:: test_v6_price_noise_twin;
         "v3_armed_flags_thin_adv" >:: test_v3_armed_flags_thin_adv;
         "v3_unarmed_noop" >:: test_v3_unarmed_noop;
         "v4_armed_flags_stale_open" >:: test_v4_armed_flags_stale_open;
         "v7_starved_virgin" >:: test_v7_starved_virgin;
         "v8_declining_ma" >:: test_v8_declining_ma;
         "v9_overhead" >:: test_v9;
         "v9_clean" >:: test_v9_clean;
         "v10_spike" >:: test_v10;
         "v10_calm" >:: test_v10_calm;
         "v11_stop_bounds" >:: test_v11;
         "v12_gate_consistency" >:: test_v12;
         "v12_skips_unevaluable" >:: test_v12_skips_unevaluable;
         "v12_respects_config_gate" >:: test_v12_respects_config_gate;
         "v13_clean" >:: test_v13_clean;
         "v13_flags_saturday_exit" >:: test_v13_flags_saturday_exit;
         "v13_flags_price_outside_bar" >:: test_v13_flags_price_outside_bar;
         "v13_skips_absent_symbol" >:: test_v13_skips_absent_symbol;
         "v13_skips_store_with_no_daily_bars"
         >:: test_v13_skips_store_with_no_daily_bars;
         "v13_rebased_store_waives_price_leg"
         >:: test_v13_rebased_store_waives_price_leg;
         "v13_rebased_store_still_flags_saturday_exit"
         >:: test_v13_rebased_store_still_flags_saturday_exit;
         "v14_flags_entry_bar_stopout" >:: test_v14_flags_entry_bar_stopout;
         "v14_allows_genuine_gap_down" >:: test_v14_allows_genuine_gap_down;
         "v14_ignores_non_stop_exit" >:: test_v14_ignores_non_stop_exit;
         "v14_ignores_late_stop_exit" >:: test_v14_ignores_late_stop_exit;
         "v14_widened_window_flags_late_exit"
         >:: test_v14_widened_window_flags_late_exit;
         "v14_friday_to_monday_counts_one_bar"
         >:: test_v14_friday_to_monday_counts_one_bar;
         "v14_saturday_exit_counts_zero_bars"
         >:: test_v14_saturday_exit_counts_zero_bars;
         "v14_falls_back_to_initial_distance"
         >:: test_v14_falls_back_to_initial_distance;
         "v14_prefers_fill_distance_over_initial"
         >:: test_v14_prefers_fill_distance_over_initial;
         "v14_skips_row_with_no_stop_distance"
         >:: test_v14_skips_row_with_no_stop_distance;
         "v14_short_flags_entry_bar_stopout"
         >:: test_v14_short_flags_entry_bar_stopout;
         "v14_short_allows_genuine_gap_up"
         >:: test_v14_short_allows_genuine_gap_up;
         "v14_skips_absent_symbol" >:: test_v14_skips_absent_symbol;
         "v14_skips_store_with_no_daily_bars"
         >:: test_v14_skips_store_with_no_daily_bars;
         "v14_rebased_store_skips_stop_comparison"
         >:: test_v14_rebased_store_skips_stop_comparison;
         "v15_flags_chs_exit_splice" >:: test_v15_flags_chs_exit_splice;
         "v15_flags_short_side_of_same_splice"
         >:: test_v15_flags_short_side_of_same_splice;
         "v15_clean_fast_double" >:: test_v15_clean_fast_double;
         "v15_clean_across_adjusted_split"
         >:: test_v15_clean_across_adjusted_split;
         "v15_skips_fill_bar_without_prior"
         >:: test_v15_skips_fill_bar_without_prior;
         "v15_ratio_at_upper_bound_passes"
         >:: test_v15_ratio_at_upper_bound_passes;
         "v15_ratio_just_past_upper_bound_flags"
         >:: test_v15_ratio_just_past_upper_bound_flags;
         "v15_flags_entry_bar_collapse" >:: test_v15_flags_entry_bar_collapse;
         "v15_ignores_long_hold" >:: test_v15_ignores_long_hold;
         "v15_ignores_modest_move" >:: test_v15_ignores_modest_move;
         "v15_skips_absent_symbol" >:: test_v15_skips_absent_symbol;
         "v15_skips_store_with_no_daily_bars"
         >:: test_v15_skips_store_with_no_daily_bars;
         "v15_skips_non_positive_prior_close"
         >:: test_v15_skips_non_positive_prior_close;
         "v15_respects_configured_bounds"
         >:: test_v15_respects_configured_bounds;
         "bars_of_daily_keeps_raw_and_adjusted_apart"
         >:: test_bars_of_daily_keeps_raw_and_adjusted_apart;
         "join_by_position_id_survives_date_skew"
         >:: test_join_by_position_id_survives_date_skew;
         "join_legacy_falls_back_to_symbol_date"
         >:: test_join_legacy_falls_back_to_symbol_date;
         "audit_join_coverage_counts" >:: test_audit_join_coverage_counts;
         "severity_default" >:: test_severity_default;
         "validate_runs_all" >:: test_validate_runs_all;
       ]

let () = run_test_tt_main suite
