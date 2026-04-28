open OUnit2
open Core
open Matchers
open Screener
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = default_config
let as_of = Date.of_string "2024-01-01"

let make_bar ?(volume = 1000) date adjusted_close =
  {
    Daily_price.date = Date.of_string date;
    open_price = adjusted_close;
    high_price = adjusted_close *. 1.02;
    low_price = adjusted_close *. 0.98;
    close_price = adjusted_close;
    adjusted_close;
    volume;
  }

let weekly_bars_with_volumes prices_and_volumes =
  let base = Date.of_string "2020-01-06" in
  List.mapi prices_and_volumes ~f:(fun i (p, v) ->
      make_bar ~volume:v (Date.to_string (Date.add_days base (i * 7))) p)

let weekly_bars prices =
  weekly_bars_with_volumes (List.map prices ~f:(fun p -> (p, 1000)))

let rising_bars ~n start stop_ =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> start +. (Float.of_int i *. step)) |> weekly_bars

(** Rising bars with a configurable volume spike at [spike_idx]. *)
let rising_bars_with_custom_spike ~n start stop_ ~spike_idx ~spike_volume =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i ->
      let p = start +. (Float.of_int i *. step) in
      let v = if i = spike_idx then spike_volume else 1000 in
      (p, v))
  |> weekly_bars_with_volumes

(** Rising bars with a Strong-volume spike (3000) at [spike_idx]. *)
let rising_bars_with_spike ~n start stop_ ~spike_idx =
  rising_bars_with_custom_spike ~n start stop_ ~spike_idx ~spike_volume:3000

(** Declining bars with a Strong-volume spike (3000) at [spike_idx]. *)
let declining_bars_with_spike ~n start stop_ ~spike_idx =
  let step = (start -. stop_) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i ->
      let p = start -. (Float.of_int i *. step) in
      let v = if i = spike_idx then 3000 else 1000 in
      (p, v))
  |> weekly_bars_with_volumes

(** Make a Stock_analysis.t for a given ticker with controlled stage. *)
let make_analysis ticker prior bars =
  Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker ~bars
    ~benchmark_bars:[] ~prior_stage:prior ~as_of_date:as_of

(** Build a sector context. *)
let make_sector ?(rating = (Neutral : sector_rating)) name =
  {
    sector_name = name;
    rating;
    stage = Stage2 { weeks_advancing = 5; late = false };
  }

(** Build an empty sector map. *)
let empty_sector_map () = Hashtbl.create (module String)

(** Build a sector map with entries. *)
let sector_map_of entries =
  let m = Hashtbl.create (module String) in
  List.iter entries ~f:(fun (ticker, sector) ->
      Hashtbl.set m ~key:ticker ~data:sector);
  m

(* ------------------------------------------------------------------ *)
(* Macro gate: Bearish → no buys                                       *)
(* ------------------------------------------------------------------ *)

let test_bearish_macro_no_buys _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let stocks =
    [ make_analysis "AAPL" (Some (Stage1 { weeks_in_base = 12 })) bars ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates is_empty

let test_bullish_macro_no_shorts _ =
  let declining = List.init 15 ~f:(fun i -> 100.0 -. Float.of_int i) in
  let flat = List.init 50 ~f:(fun _ -> 85.0) in
  let decline2 = List.init 20 ~f:(fun i -> 85.0 -. (Float.of_int i *. 1.5)) in
  let bars = declining @ flat @ decline2 |> weekly_bars in
  let stocks =
    [ make_analysis "XYZ" (Some (Stage3 { weeks_topping = 8 })) bars ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  assert_that result.short_candidates is_empty

(* ------------------------------------------------------------------ *)
(* Sector gate: weak sector excluded from buys                         *)
(* ------------------------------------------------------------------ *)

let test_weak_sector_excluded_from_buys _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let stocks =
    [ make_analysis "AAPL" (Some (Stage1 { weeks_in_base = 12 })) bars ]
  in
  let sector_map =
    sector_map_of [ ("AAPL", make_sector ~rating:Weak "Tech") ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Neutral ~sector_map ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates is_empty

let test_strong_sector_excluded_from_shorts _ =
  let declining = List.init 15 ~f:(fun i -> 100.0 -. Float.of_int i) in
  let flat = List.init 50 ~f:(fun _ -> 85.0) in
  let decline2 = List.init 20 ~f:(fun i -> 85.0 -. (Float.of_int i *. 1.5)) in
  let bars = declining @ flat @ decline2 |> weekly_bars in
  let stocks =
    [ make_analysis "XYZ" (Some (Stage3 { weeks_topping = 8 })) bars ]
  in
  let sector_map =
    sector_map_of [ ("XYZ", make_sector ~rating:Strong "Energy") ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Neutral ~sector_map ~stocks ~held_tickers:[]
  in
  assert_that result.short_candidates is_empty

(* ------------------------------------------------------------------ *)
(* Held tickers excluded                                               *)
(* ------------------------------------------------------------------ *)

let test_held_tickers_excluded _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let stocks =
    [ make_analysis "AAPL" (Some (Stage1 { weeks_in_base = 12 })) bars ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[ "AAPL" ]
  in
  assert_that result.buy_candidates is_empty

(* ------------------------------------------------------------------ *)
(* Macro trend propagated                                              *)
(* ------------------------------------------------------------------ *)

let test_macro_trend_propagated _ =
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map:(empty_sector_map ())
      ~stocks:[] ~held_tickers:[]
  in
  assert_that result.macro_trend (equal_to Bearish)

let test_macro_trend_neutral _ =
  let result =
    screen ~config:cfg ~macro_trend:Neutral ~sector_map:(empty_sector_map ())
      ~stocks:[] ~held_tickers:[]
  in
  assert_that result.macro_trend (equal_to Neutral)

(* ------------------------------------------------------------------ *)
(* Candidate fields                                                     *)
(* ------------------------------------------------------------------ *)

let test_candidate_has_suggested_entry _ =
  (* spike_idx = n-4 = 31: inside default 8-bar lookback, 4 baseline bars
     before it → ratio = 3.0 → Strong volume → is_breakout_candidate = true *)
  let bars = rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let stocks =
    [ make_analysis "MSFT" (Some (Stage1 { weeks_in_base = 10 })) bars ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  match result.buy_candidates with
  | [] -> assert_failure "Expected at least one buy candidate"
  | c :: _ ->
      assert_that c.suggested_entry (gt (module Float_ord) 0.0);
      assert_that c.suggested_stop (lt (module Float_ord) c.suggested_entry);
      assert_that c.risk_pct (gt (module Float_ord) 0.0)

(* ------------------------------------------------------------------ *)
(* Purity                                                               *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let stocks =
    [ make_analysis "AAPL" (Some (Stage1 { weeks_in_base = 12 })) bars ]
  in
  let r1 =
    screen ~config:cfg ~macro_trend:Neutral ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  let r2 =
    screen ~config:cfg ~macro_trend:Neutral ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  assert_that
    (List.length r1.buy_candidates)
    (equal_to (List.length r2.buy_candidates));
  assert_that
    (List.length r1.short_candidates)
    (equal_to (List.length r2.short_candidates))

(* ------------------------------------------------------------------ *)
(* Sort order: higher score appears first                              *)
(* ------------------------------------------------------------------ *)

let test_scores_drive_sort_order _ =
  (* Both stocks: Stage1→Stage2 breakout + Strong volume.
     A is in a Strong sector (+10 pts), B is Neutral → A scores higher. *)
  let bars = rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let prior = Some (Stage1 { weeks_in_base = 10 }) in
  let stocks = [ make_analysis "A" prior bars; make_analysis "B" prior bars ] in
  let sector_map =
    sector_map_of
      [
        ("A", make_sector ~rating:Strong "Tech");
        ("B", make_sector ~rating:Neutral "Tech");
      ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map ~stocks ~held_tickers:[]
  in
  match result.buy_candidates with
  | c1 :: c2 :: _ ->
      assert_that c1.ticker (equal_to "A");
      assert_that c2.ticker (equal_to "B");
      assert_that c1.score (gt (module Int_ord) c2.score)
  | _ -> assert_failure "Expected at least two buy candidates"

(* ------------------------------------------------------------------ *)
(* Max cap: only top-N returned                                        *)
(* ------------------------------------------------------------------ *)

let test_max_buy_candidates_cap _ =
  let bars = rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let prior = Some (Stage1 { weeks_in_base = 10 }) in
  let stocks =
    List.init 4 ~f:(fun i -> make_analysis (Printf.sprintf "T%d" i) prior bars)
  in
  let capped_cfg = { cfg with max_buy_candidates = 2 } in
  let result =
    screen ~config:capped_cfg ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that (List.length result.buy_candidates) (equal_to 2)

(* ------------------------------------------------------------------ *)
(* Grade filter and watchlist                                          *)
(* ------------------------------------------------------------------ *)

(** A stock with Stage1→Stage2 + Adequate volume scores grade C (40 pts). With
    [min_grade=B] it is excluded from buy_candidates but grade C ≥ D, so it ends
    up on the watchlist. *)
let test_watchlist_captures_low_grade _ =
  (* Adequate volume: spike=1500 → ratio 1.5 → Adequate (+10).
     Score: Stage1→Stage2 (30) + Adequate (10) = 40 → grade C.
     With min_grade=B that excludes this stock from buy_candidates,
     but grade C lands on the watchlist. *)
  let bars =
    rising_bars_with_custom_spike ~n:35 50.0 100.0 ~spike_idx:31
      ~spike_volume:1500
  in
  let prior = Some (Stage1 { weeks_in_base = 10 }) in
  let stocks = [ make_analysis "LOW" prior bars ] in
  let b_cfg = { cfg with min_grade = B } in
  let result =
    screen ~config:b_cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates is_empty;
  assert_bool "LOW on watchlist"
    (List.exists result.watchlist ~f:(fun (t, _) -> String.(t = "LOW")))

(* ------------------------------------------------------------------ *)
(* Short candidates in Neutral market                                  *)
(* ------------------------------------------------------------------ *)

let test_neutral_macro_produces_shorts _ =
  (* Stage4 stock in a Weak sector: stage score (30) + weak-sector bonus (10)
     = 40 → grade C, which meets the default min_grade=C threshold. *)
  let bars = declining_bars_with_spike ~n:60 100.0 30.0 ~spike_idx:55 in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let stocks = [ make_analysis "SHORT" prior bars ] in
  let sector_map =
    sector_map_of [ ("SHORT", make_sector ~rating:Weak "Energy") ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Neutral ~sector_map ~stocks ~held_tickers:[]
  in
  assert_bool "expected short candidate"
    (not (List.is_empty result.short_candidates))

(* ------------------------------------------------------------------ *)
(* Short candidate fields: stop above entry                            *)
(* ------------------------------------------------------------------ *)

let test_short_candidate_stop_above_entry _ =
  let bars = declining_bars_with_spike ~n:60 100.0 30.0 ~spike_idx:55 in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let stocks = [ make_analysis "SHT" prior bars ] in
  let sector_map =
    sector_map_of [ ("SHT", make_sector ~rating:Weak "Energy") ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map ~stocks ~held_tickers:[]
  in
  match result.short_candidates with
  | [] -> assert_failure "Expected a short candidate"
  | c :: _ ->
      assert_that c.suggested_stop (gt (module Float_ord) c.suggested_entry);
      assert_that c.risk_pct (gt (module Float_ord) 0.0)

(* ------------------------------------------------------------------ *)
(* Candidate grade field matches score                                 *)
(* ------------------------------------------------------------------ *)

let test_candidate_grade_matches_score _ =
  let bars = rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let prior = Some (Stage1 { weeks_in_base = 10 }) in
  let stocks = [ make_analysis "G" prior bars ] in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  match result.buy_candidates with
  | [] -> assert_failure "Expected a buy candidate"
  | c :: _ ->
      let expected_grade =
        if c.score >= 85 then A_plus
        else if c.score >= 70 then A
        else if c.score >= 55 then B
        else if c.score >= 40 then C
        else if c.score >= 25 then D
        else F
      in
      assert_that c.grade (equal_to (expected_grade : grade))

(* ------------------------------------------------------------------ *)
(* Candidate side: buy_candidates are Long, short_candidates are Short *)
(* ------------------------------------------------------------------ *)

let test_buy_candidates_are_long _ =
  let bars = rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let prior = Some (Stage1 { weeks_in_base = 10 }) in
  let stocks = [ make_analysis "G" prior bars ] in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  match result.buy_candidates with
  | [] -> assert_failure "Expected a buy candidate"
  | c :: _ -> assert_that c.side (equal_to Trading_base.Types.Long)

let test_short_candidates_are_short _ =
  let bars = declining_bars_with_spike ~n:60 100.0 30.0 ~spike_idx:55 in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let stocks = [ make_analysis "SHT" prior bars ] in
  let sector_map =
    sector_map_of [ ("SHT", make_sector ~rating:Weak "Energy") ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map ~stocks ~held_tickers:[]
  in
  match result.short_candidates with
  | [] -> assert_failure "Expected a short candidate"
  | c :: _ -> assert_that c.side (equal_to Trading_base.Types.Short)

(* ------------------------------------------------------------------ *)
(* Short-side volume confirmation (mirror of long-side)                *)
(* ------------------------------------------------------------------ *)

(** Short-side cascade weights breakdown volume the same way the long-side
    cascade weights breakout volume: Strong adds [w_strong_volume], Adequate
    adds [w_adequate_volume], Weak adds 0. Mirrors the test patterns in
    {!test_candidate_grade_matches_score} but on the short path. The
    declining-bars-with-spike helper places a 3000-volume bar at offset 55,
    surrounded by 1000-volume bars; the peak-volume scanner picks it up and
    {!Volume.analyze_breakout} classifies the spike vs the prior 4-bar average
    (1000) as Strong (ratio = 3.0).

    The synthetic Support analysis on the same declining bars yields Clean
    support below (the bars between [breakdown_price] and the most recent bar
    are spread across multiple congestion bands, so no single band hits the
    moderate-resistance threshold of 3). Clean adds [w_clean_resistance = 15].
    The score tallies stage (30) + Strong breakdown volume (20) + bearish RS
    [Negative_declining] (20) + Clean support below (15) = 85 → A+. The test
    pins both the score and the presence of the breakdown-volume rationale
    label. *)
let test_short_side_volume_confirmation_strong _ =
  let bars = declining_bars_with_spike ~n:60 100.0 30.0 ~spike_idx:55 in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let base = make_analysis "VOL_STRONG" prior bars in
  let neg_rs : Rs.result =
    {
      current_rs = 0.8;
      current_normalized = -10.0;
      trend = Negative_declining;
      history = [];
    }
  in
  let with_neg_rs = { base with rs = Some neg_rs } in
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map:(empty_sector_map ())
      ~stocks:[ with_neg_rs ] ~held_tickers:[]
  in
  match result.short_candidates with
  | [] -> assert_failure "Expected a short candidate"
  | c :: _ ->
      assert_that c
        (all_of
           [
             field (fun c -> c.ticker) (equal_to "VOL_STRONG");
             field (fun c -> c.score) (equal_to 85);
             field (fun c -> c.grade) (equal_to (A_plus : grade));
             field
               (fun c -> c.rationale)
               (matching ~msg:"rationale contains breakdown-volume label"
                  (fun rs ->
                    if
                      List.exists rs ~f:(fun r ->
                          String.is_substring r ~substring:"breakdown volume")
                    then Some ()
                    else None)
                  (equal_to ()));
           ])

(** Adequate breakdown volume (1.5x average) adds [w_adequate_volume = 10]
    points, lifting a Stage-4 candidate that would otherwise score 30 + 0 + 0
    (Negative_improving = half of w_positive_rs = 10) = 40 to 50, but the
    important assertion is that the rationale labels reflect the short-side
    breakdown context, not generic "volume". *)
let test_short_side_volume_adequate_label _ =
  let bars =
    let step = (100.0 -. 30.0) /. Float.of_int (60 - 1) in
    List.init 60 ~f:(fun i ->
        let p = 100.0 -. (Float.of_int i *. step) in
        let v = if i = 55 then 1500 else 1000 in
        (p, v))
    |> weekly_bars_with_volumes
  in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let base = make_analysis "VOL_ADQ" prior bars in
  let neg_rs : Rs.result =
    {
      current_rs = 0.8;
      current_normalized = -10.0;
      trend = Negative_declining;
      history = [];
    }
  in
  let with_neg_rs = { base with rs = Some neg_rs } in
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map:(empty_sector_map ())
      ~stocks:[ with_neg_rs ] ~held_tickers:[]
  in
  match result.short_candidates with
  | [] -> assert_failure "Expected a short candidate"
  | c :: _ ->
      assert_that c.rationale
        (matching ~msg:"contains 'Adequate breakdown volume'"
           (fun rs ->
             List.find rs ~f:(fun r ->
                 String.equal r "Adequate breakdown volume"))
           (equal_to "Adequate breakdown volume"))

(** Inject a [Support.result] directly onto an otherwise-identical candidate and
    assert the screener's [_support_signal] picks it up as a clean-space- below
    bonus. Pins the contract that mirrors [_resistance_signal] for the short
    side: Virgin / Clean → [w_clean_resistance], Moderate → halved, Heavy / None
    → 0. The candidate's other signals contribute a fixed baseline so the
    support delta is the only thing varying across cases. Mirrors
    {!test_negative_rs_scoring_order}'s injection-and-compare shape. *)
let test_support_below_scoring_order _ =
  let bars = declining_bars_with_spike ~n:60 100.0 30.0 ~spike_idx:55 in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let neg_rs : Rs.result =
    {
      current_rs = 0.8;
      current_normalized = -10.0;
      trend = Negative_declining;
      history = [];
    }
  in
  let make_with_support ticker quality =
    let base = make_analysis ticker prior bars in
    let support : Support.result = { quality; breakdown_price = 50.0 } in
    { base with rs = Some neg_rs; support = Some support }
  in
  let stocks =
    [
      make_with_support "VIRGIN" Virgin_territory;
      make_with_support "CLEAN" Clean;
      make_with_support "MOD" Moderate_resistance;
      make_with_support "HEAVY" Heavy_resistance;
    ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  let by_ticker t =
    List.find_exn result.short_candidates ~f:(fun c -> String.(c.ticker = t))
  in
  let virgin = by_ticker "VIRGIN" in
  let clean = by_ticker "CLEAN" in
  let mod_ = by_ticker "MOD" in
  let heavy = by_ticker "HEAVY" in
  assert_that virgin.score (equal_to clean.score);
  assert_that clean.score (gt (module Int_ord) mod_.score);
  assert_that mod_.score (gt (module Int_ord) heavy.score)

(** Negative-RS scoring (already wired prior to this PR) is a positive signal
    for shorts: [Bearish_crossover] adds
    [w_positive_rs + w_bullish_rs_crossover = 30], [Negative_declining] adds
    [w_positive_rs = 20], and [Negative_improving] adds
    [w_positive_rs / 2 = 10]. This regression test pins the relative ordering by
    injecting three otherwise-identical Stage-4 candidates differing only on RS
    trend and asserting the bearish-crossover score > negative-declining score >
    negative-improving score. *)
let test_negative_rs_scoring_order _ =
  let bars = declining_bars_with_spike ~n:60 100.0 30.0 ~spike_idx:55 in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let make_with_rs ticker trend =
    let base = make_analysis ticker prior bars in
    let rs : Rs.result =
      { current_rs = 0.8; current_normalized = -10.0; trend; history = [] }
    in
    { base with rs = Some rs }
  in
  let stocks =
    [
      make_with_rs "BX" Bearish_crossover;
      make_with_rs "ND" Negative_declining;
      make_with_rs "NI" Negative_improving;
    ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  let by_ticker t =
    List.find_exn result.short_candidates ~f:(fun c -> String.(c.ticker = t))
  in
  let bx = by_ticker "BX" in
  let nd = by_ticker "ND" in
  let ni = by_ticker "NI" in
  assert_that bx.score (gt (module Int_ord) nd.score);
  assert_that nd.score (gt (module Int_ord) ni.score)

(* ------------------------------------------------------------------ *)
(* Ch. 11 rule: positive RS blocks short candidates                   *)
(* ------------------------------------------------------------------ *)

let test_positive_rs_blocks_short _ =
  (* Weinstein Ch. 11: "NEVER short a stock with strong RS, even if it breaks
     down." The existing short-candidate test sees a None RS result (empty
     benchmark_bars). Here we manually inject a positive RS onto an otherwise
     eligible Stage-4 breakdown candidate and assert the screener now rejects
     it entirely. *)
  let bars = declining_bars_with_spike ~n:60 100.0 30.0 ~spike_idx:55 in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let base = make_analysis "STRONG" prior bars in
  let positive_rs : Rs.result =
    {
      current_rs = 1.2;
      current_normalized = 10.0;
      trend = Positive_rising;
      history = [];
    }
  in
  let with_positive_rs = { base with rs = Some positive_rs } in
  let sector_map =
    sector_map_of [ ("STRONG", make_sector ~rating:Weak "Energy") ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map
      ~stocks:[ with_positive_rs ] ~held_tickers:[]
  in
  assert_that result.short_candidates is_empty

let suite =
  "screener_tests"
  >::: [
         "test_bearish_macro_no_buys" >:: test_bearish_macro_no_buys;
         "test_bullish_macro_no_shorts" >:: test_bullish_macro_no_shorts;
         "test_weak_sector_excluded_from_buys"
         >:: test_weak_sector_excluded_from_buys;
         "test_strong_sector_excluded_from_shorts"
         >:: test_strong_sector_excluded_from_shorts;
         "test_held_tickers_excluded" >:: test_held_tickers_excluded;
         "test_macro_trend_propagated" >:: test_macro_trend_propagated;
         "test_macro_trend_neutral" >:: test_macro_trend_neutral;
         "test_candidate_has_suggested_entry"
         >:: test_candidate_has_suggested_entry;
         "test_pure_same_inputs" >:: test_pure_same_inputs;
         "test_scores_drive_sort_order" >:: test_scores_drive_sort_order;
         "test_max_buy_candidates_cap" >:: test_max_buy_candidates_cap;
         "test_watchlist_captures_low_grade"
         >:: test_watchlist_captures_low_grade;
         "test_neutral_macro_produces_shorts"
         >:: test_neutral_macro_produces_shorts;
         "test_short_candidate_stop_above_entry"
         >:: test_short_candidate_stop_above_entry;
         "test_candidate_grade_matches_score"
         >:: test_candidate_grade_matches_score;
         "test_buy_candidates_are_long" >:: test_buy_candidates_are_long;
         "test_short_candidates_are_short" >:: test_short_candidates_are_short;
         "test_positive_rs_blocks_short" >:: test_positive_rs_blocks_short;
         "test_short_side_volume_confirmation_strong"
         >:: test_short_side_volume_confirmation_strong;
         "test_short_side_volume_adequate_label"
         >:: test_short_side_volume_adequate_label;
         "test_negative_rs_scoring_order" >:: test_negative_rs_scoring_order;
         "test_support_below_scoring_order" >:: test_support_below_scoring_order;
       ]

let () = run_test_tt_main suite
