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
(* min_score_override: numeric threshold gate                           *)
(* ------------------------------------------------------------------ *)

(** Build two breakout candidates with distinct scores by varying volume
    confirmation: [LOW] uses Adequate-volume bars (spike_volume 1500 → ratio
    1.5, [w_adequate_volume = 10]); [HIGH] uses Strong-volume bars (spike_volume
    3000 → ratio 3.0, [w_strong_volume = 20]). Both share the Stage1→Stage2 stem
    so the score delta isolates the volume signal. The exact integer scores
    depend on additional analyzer signals (RS, resistance) — tests below probe
    the [min_score_override] gate by comparing scores from the screener output
    rather than pinning specific integers. *)
let _two_breakouts () =
  let bars_low =
    rising_bars_with_custom_spike ~n:35 50.0 100.0 ~spike_idx:31
      ~spike_volume:1500
  in
  let bars_high = rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let prior = Some (Stage1 { weeks_in_base = 10 }) in
  [ make_analysis "LOW" prior bars_low; make_analysis "HIGH" prior bars_high ]

(** Probe scores by running the screener with [min_grade = F] and no override —
    every breakout that passes the per-stock filters lands in the output, and we
    can read [score] for each ticker. *)
let _scores_by_ticker stocks =
  let probe_cfg = { cfg with min_grade = F; min_score_override = None } in
  let result =
    screen ~config:probe_cfg ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  String.Map.of_alist_reduce
    (List.map result.buy_candidates ~f:(fun (c : scored_candidate) ->
         (c.ticker, c.score)))
    ~f:(fun a _ -> a)

(** [min_score_override = Some n] strictly above LOW's score and at-or-below
    HIGH's score admits only HIGH — pure numeric gate, not grade-dependent. *)
let test_min_score_override_filters_below_threshold _ =
  let stocks = _two_breakouts () in
  let scores = _scores_by_ticker stocks in
  let low_score = Map.find_exn scores "LOW" in
  let high_score = Map.find_exn scores "HIGH" in
  assert_that high_score (gt (module Int_ord) low_score);
  let threshold = low_score + 1 in
  let cfg_override = { cfg with min_score_override = Some threshold } in
  let result =
    screen ~config:cfg_override ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates
    (elements_are
       [ field (fun (c : scored_candidate) -> c.ticker) (equal_to "HIGH") ])

(** [min_score_override = Some n] equal to HIGH's exact score still admits HIGH
    — the gate is [>=], not [>]. *)
let test_min_score_override_inclusive_at_boundary _ =
  let stocks = _two_breakouts () in
  let scores = _scores_by_ticker stocks in
  let high_score = Map.find_exn scores "HIGH" in
  let cfg_override = { cfg with min_score_override = Some high_score } in
  let result =
    screen ~config:cfg_override ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates
    (elements_are
       [ field (fun (c : scored_candidate) -> c.ticker) (equal_to "HIGH") ])

(** [min_score_override] strictly above HIGH's score excludes both — pins the
    [>=] semantics from above (no candidate strictly less than the threshold
    passes). *)
let test_min_score_override_strict_above_score _ =
  let stocks = _two_breakouts () in
  let scores = _scores_by_ticker stocks in
  let high_score = Map.find_exn scores "HIGH" in
  let cfg_override = { cfg with min_score_override = Some (high_score + 1) } in
  let result =
    screen ~config:cfg_override ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates is_empty

(** [min_score_override = None] (default) is bit-equal to the legacy
    {!min_grade}-based filter — for each [min_grade] level, the override-off run
    admits exactly the same candidates as the override-off run did before this
    field existed. Probed by running both LOW (grade C) and HIGH (grade B+)
    under [min_grade = C] — both are admitted. *)
let test_min_score_override_default_preserves_min_grade _ =
  let stocks = _two_breakouts () in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  assert_that (List.length result.buy_candidates) (equal_to 2)

(** When [min_score_override] is set, {!min_grade} is ignored — a configuration
    that would block both candidates under [min_grade = A_plus] still admits the
    HIGH candidate when the numeric override is at-or-below HIGH's score. *)
let test_min_score_override_supersedes_min_grade _ =
  let stocks = _two_breakouts () in
  let scores = _scores_by_ticker stocks in
  let low_score = Map.find_exn scores "LOW" in
  let cfg_override =
    { cfg with min_grade = A_plus; min_score_override = Some (low_score + 1) }
  in
  let result =
    screen ~config:cfg_override ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates
    (elements_are
       [ field (fun (c : scored_candidate) -> c.ticker) (equal_to "HIGH") ])

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

(* ------------------------------------------------------------------ *)
(* Cascade diagnostics                                                 *)
(* ------------------------------------------------------------------ *)

(** Bullish-macro Stage-2 setup: rising bars across a 35-week window from $50 to
    $100 with a Strong volume spike late in the run. The same fixture used by
    several existing buy-side tests; reused here so the diagnostic-count
    expectations stay aligned with the rest of the suite. *)
let _stage2_breakout_setup ticker =
  let bars = rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:30 in
  make_analysis ticker (Some (Stage1 { weeks_in_base = 12 })) bars

let test_diagnostics_empty_universe _ =
  let result =
    screen ~config:cfg ~macro_trend:Neutral ~sector_map:(empty_sector_map ())
      ~stocks:[] ~held_tickers:[]
  in
  assert_that result.cascade_diagnostics
    (all_of
       [
         field (fun (d : cascade_diagnostics) -> d.total_stocks) (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.candidates_after_held)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.long_macro_admitted)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.short_macro_admitted)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.long_top_n_admitted)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.short_top_n_admitted)
           (equal_to 0);
       ])

let test_diagnostics_total_stocks_and_held _ =
  let stocks =
    [
      _stage2_breakout_setup "AAPL";
      _stage2_breakout_setup "MSFT";
      _stage2_breakout_setup "NVDA";
    ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[ "MSFT" ]
  in
  (* total_stocks counts the input list; candidates_after_held drops the held
     ticker. *)
  assert_that result.cascade_diagnostics
    (all_of
       [
         field (fun (d : cascade_diagnostics) -> d.total_stocks) (equal_to 3);
         field
           (fun (d : cascade_diagnostics) -> d.candidates_after_held)
           (equal_to 2);
         field
           (fun (d : cascade_diagnostics) -> d.macro_trend)
           (equal_to Bullish);
       ])

let test_diagnostics_bearish_macro_blocks_longs _ =
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map:(empty_sector_map ())
      ~stocks:[ _stage2_breakout_setup "AAPL" ]
      ~held_tickers:[]
  in
  (* Macro=Bearish closes the long side: every long-side phase must read 0. *)
  assert_that result.cascade_diagnostics
    (all_of
       [
         field
           (fun (d : cascade_diagnostics) -> d.long_macro_admitted)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.long_breakout_admitted)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.long_sector_admitted)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.long_grade_admitted)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.long_top_n_admitted)
           (equal_to 0);
       ])

let test_diagnostics_bullish_macro_blocks_shorts _ =
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks:[ _stage2_breakout_setup "AAPL" ]
      ~held_tickers:[]
  in
  assert_that result.cascade_diagnostics
    (all_of
       [
         field
           (fun (d : cascade_diagnostics) -> d.short_macro_admitted)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.short_breakdown_admitted)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.short_sector_admitted)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.short_rs_hard_gate_admitted)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.short_grade_admitted)
           (equal_to 0);
         field
           (fun (d : cascade_diagnostics) -> d.short_top_n_admitted)
           (equal_to 0);
       ])

let test_diagnostics_long_top_n_matches_buy_candidates _ =
  let stocks =
    List.init 5 ~f:(fun i -> _stage2_breakout_setup (sprintf "T%d" i))
  in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  (* long_top_n_admitted is by definition [List.length buy_candidates]. *)
  assert_that result.cascade_diagnostics.long_top_n_admitted
    (equal_to (List.length result.buy_candidates))

(* ------------------------------------------------------------------ *)
(* Cascade post-stop-out cooldown gate                                 *)
(* ------------------------------------------------------------------ *)

(** Stage1→Stage2 breakout fixture used across the cooldown tests so each test
    pins one independent variable (cooldown_weeks, recency, per-symbol scope).
*)
let _breakout_stocks tickers =
  let bars = rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let prior = Some (Stage1 { weeks_in_base = 10 }) in
  List.map tickers ~f:(fun t -> make_analysis t prior bars)

(** Cooldown disabled (default 0 weeks): even a stop-out from yesterday must not
    exclude the symbol — pins bit-equality with [screen]. *)
let test_cooldown_disabled_no_exclusion _ =
  let stocks = _breakout_stocks [ "AAPL" ] in
  let result =
    screen_with_cooldown ~config:cfg ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[] ~as_of
      ~last_stop_out_dates:[ ("AAPL", Date.add_days as_of (-1)) ]
  in
  assert_that result.buy_candidates
    (elements_are [ field (fun c -> c.ticker) (equal_to "AAPL") ])

(** Cooldown 4 weeks, stop-out 14 days ago (< 28d): symbol excluded. *)
let test_cooldown_recent_stop_excludes _ =
  let stocks = _breakout_stocks [ "AAPL" ] in
  let cooldown_cfg = { cfg with cascade_post_stop_cooldown_weeks = 4 } in
  let result =
    screen_with_cooldown ~config:cooldown_cfg ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[] ~as_of
      ~last_stop_out_dates:[ ("AAPL", Date.add_days as_of (-14)) ]
  in
  assert_that result.buy_candidates is_empty

(** Cooldown 4 weeks, stop-out 35 days ago (>= 28d): symbol eligible again. *)
let test_cooldown_elapsed_stop_eligible _ =
  let stocks = _breakout_stocks [ "AAPL" ] in
  let cooldown_cfg = { cfg with cascade_post_stop_cooldown_weeks = 4 } in
  let result =
    screen_with_cooldown ~config:cooldown_cfg ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[] ~as_of
      ~last_stop_out_dates:[ ("AAPL", Date.add_days as_of (-35)) ]
  in
  assert_that result.buy_candidates
    (elements_are [ field (fun c -> c.ticker) (equal_to "AAPL") ])

(** Cooldown applies per-symbol: a recent stop-out on AAPL must not block HD. *)
let test_cooldown_per_symbol_scope _ =
  let stocks = _breakout_stocks [ "AAPL"; "HD" ] in
  let cooldown_cfg = { cfg with cascade_post_stop_cooldown_weeks = 4 } in
  let result =
    screen_with_cooldown ~config:cooldown_cfg ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[] ~as_of
      ~last_stop_out_dates:[ ("AAPL", Date.add_days as_of (-7)) ]
  in
  assert_that result.buy_candidates
    (all_of
       [ size_is 1; elements_are [ field (fun c -> c.ticker) (equal_to "HD") ] ])

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
         "test_min_score_override_filters_below_threshold"
         >:: test_min_score_override_filters_below_threshold;
         "test_min_score_override_inclusive_at_boundary"
         >:: test_min_score_override_inclusive_at_boundary;
         "test_min_score_override_strict_above_score"
         >:: test_min_score_override_strict_above_score;
         "test_min_score_override_default_preserves_min_grade"
         >:: test_min_score_override_default_preserves_min_grade;
         "test_min_score_override_supersedes_min_grade"
         >:: test_min_score_override_supersedes_min_grade;
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
         "test_diagnostics_empty_universe" >:: test_diagnostics_empty_universe;
         "test_diagnostics_total_stocks_and_held"
         >:: test_diagnostics_total_stocks_and_held;
         "test_diagnostics_bearish_macro_blocks_longs"
         >:: test_diagnostics_bearish_macro_blocks_longs;
         "test_diagnostics_bullish_macro_blocks_shorts"
         >:: test_diagnostics_bullish_macro_blocks_shorts;
         "test_diagnostics_long_top_n_matches_buy_candidates"
         >:: test_diagnostics_long_top_n_matches_buy_candidates;
         "test_cooldown_disabled_no_exclusion"
         >:: test_cooldown_disabled_no_exclusion;
         "test_cooldown_recent_stop_excludes"
         >:: test_cooldown_recent_stop_excludes;
         "test_cooldown_elapsed_stop_eligible"
         >:: test_cooldown_elapsed_stop_eligible;
         "test_cooldown_per_symbol_scope" >:: test_cooldown_per_symbol_scope;
       ]

let () = run_test_tt_main suite
