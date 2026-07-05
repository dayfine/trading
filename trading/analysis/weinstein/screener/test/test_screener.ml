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
    active_through = None;
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
  assert_that result.buy_candidates
    (all_of
       [
         size_is 1;
         elements_are
           [
             all_of
               [
                 field (fun c -> c.suggested_entry) (gt (module Float_ord) 0.0);
                 field
                   (fun c -> c.suggested_entry -. c.suggested_stop)
                   (gt (module Float_ord) 0.0);
                 field (fun c -> c.risk_pct) (gt (module Float_ord) 0.0);
               ];
           ];
       ])

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
  assert_that result.buy_candidates
    (all_of
       [
         size_is 2;
         elements_are
           [
             field (fun c -> c.ticker) (equal_to "A");
             field (fun c -> c.ticker) (equal_to "B");
           ];
         field
           (fun cs ->
             let c1 = List.nth_exn cs 0 in
             let c2 = List.nth_exn cs 1 in
             c1.score - c2.score)
           (gt (module Int_ord) 0);
       ])

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

(** [max_score_override = Some n] excludes candidates with [score >= n]. With
    the cap set strictly between LOW and HIGH, only LOW survives — the inverse
    of the [min_score_override] test. *)
let test_max_score_override_excludes_at_or_above_threshold _ =
  let stocks = _two_breakouts () in
  let scores = _scores_by_ticker stocks in
  let low_score = Map.find_exn scores "LOW" in
  let high_score = Map.find_exn scores "HIGH" in
  assert_that high_score (gt (module Int_ord) low_score);
  let cap = low_score + 1 in
  let cfg_cap = { cfg with max_score_override = Some cap } in
  let result =
    screen ~config:cfg_cap ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates
    (elements_are
       [ field (fun (c : scored_candidate) -> c.ticker) (equal_to "LOW") ])

(** [max_score_override = Some n] equal to HIGH's exact score still excludes
    HIGH — the gate is strict [<], symmetric with {!min_score_override}'s
    inclusive [>=]. *)
let test_max_score_override_exclusive_at_boundary _ =
  let stocks = _two_breakouts () in
  let scores = _scores_by_ticker stocks in
  let high_score = Map.find_exn scores "HIGH" in
  let cfg_cap = { cfg with max_score_override = Some high_score } in
  let result =
    screen ~config:cfg_cap ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates
    (all_of
       [
         size_is 1;
         elements_are
           [ field (fun (c : scored_candidate) -> c.ticker) (equal_to "LOW") ];
       ])

(** [max_score_override = None] (default) admits both candidates — bit-equal to
    the legacy ceiling-free behaviour. *)
let test_max_score_override_default_admits_all _ =
  let stocks = _two_breakouts () in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  assert_that (List.length result.buy_candidates) (equal_to 2)

(** [max_score_override] strictly above HIGH's score admits both — confirms the
    ceiling is a strict [<] (no candidate at-or-above the cap passes). *)
let test_max_score_override_above_high_admits_all _ =
  let stocks = _two_breakouts () in
  let scores = _scores_by_ticker stocks in
  let high_score = Map.find_exn scores "HIGH" in
  let cfg_cap = { cfg with max_score_override = Some (high_score + 1) } in
  let result =
    screen ~config:cfg_cap ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that (List.length result.buy_candidates) (equal_to 2)

(** [min_score_override] + [max_score_override] compose: window
    [low <= score < high] admits only candidates inside the band. With LOW's
    score as the floor and HIGH's score as the ceiling, only LOW survives. *)
let test_min_and_max_score_override_compose _ =
  let stocks = _two_breakouts () in
  let scores = _scores_by_ticker stocks in
  let low_score = Map.find_exn scores "LOW" in
  let high_score = Map.find_exn scores "HIGH" in
  let cfg_window =
    {
      cfg with
      min_score_override = Some low_score;
      max_score_override = Some high_score;
    }
  in
  let result =
    screen ~config:cfg_window ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates
    (elements_are
       [ field (fun (c : scored_candidate) -> c.ticker) (equal_to "LOW") ])

(* ------------------------------------------------------------------ *)
(* volume_ratio_exclude_range: per-Friday volume-band exclusion         *)
(* ------------------------------------------------------------------ *)

(** Helper: read each candidate's volume_ratio so tests can choose exclusion
    bands relative to live values without hard-pinning them. *)
let _volume_ratios stocks =
  String.Map.of_alist_reduce
    (List.filter_map stocks ~f:(fun (a : Stock_analysis.t) ->
         Option.map a.volume ~f:(fun v -> (a.ticker, v.Volume.volume_ratio))))
    ~f:(fun a _ -> a)

(** Default ([None]) is bit-equal to legacy behaviour: both LOW (ratio 1.5) and
    HIGH (ratio 3.0) survive. *)
let test_volume_ratio_exclude_range_default_admits_all _ =
  let stocks = _two_breakouts () in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  assert_that (List.length result.buy_candidates) (equal_to 2)

(** A band that brackets LOW's volume_ratio drops LOW; HIGH (outside band)
    survives. Pins the [low <= r < high] half-open semantics. *)
let test_volume_ratio_exclude_range_drops_in_band _ =
  let stocks = _two_breakouts () in
  let ratios = _volume_ratios stocks in
  let low_ratio = Map.find_exn ratios "LOW" in
  let cfg_excl =
    {
      cfg with
      volume_ratio_exclude_range =
        Some { low = low_ratio -. 0.1; high = low_ratio +. 0.1 };
    }
  in
  let result =
    screen ~config:cfg_excl ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates
    (elements_are
       [ field (fun (c : scored_candidate) -> c.ticker) (equal_to "HIGH") ])

(** Upper boundary is exclusive: a band ending exactly at HIGH's volume_ratio
    does NOT drop HIGH. Pins the half-open shape: low inclusive, high exclusive.
*)
let test_volume_ratio_exclude_range_upper_bound_exclusive _ =
  let stocks = _two_breakouts () in
  let ratios = _volume_ratios stocks in
  let high_ratio = Map.find_exn ratios "HIGH" in
  let low_ratio = Map.find_exn ratios "LOW" in
  let cfg_excl =
    {
      cfg with
      volume_ratio_exclude_range =
        Some { low = low_ratio +. 0.01; high = high_ratio };
    }
  in
  let result =
    screen ~config:cfg_excl ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  let surviving_tickers =
    List.map result.buy_candidates ~f:(fun (c : scored_candidate) -> c.ticker)
    |> List.sort ~compare:String.compare
  in
  assert_that surviving_tickers
    (elements_are [ equal_to "HIGH"; equal_to "LOW" ])

(** Composes with [min_score_override]: a candidate must pass BOTH the volume
    band and the score gate. With a min_score_override set at HIGH's score (so
    only HIGH would survive on score alone) AND a volume band that brackets
    HIGH's ratio (so HIGH would be dropped on volume alone), the result is
    empty. *)
let test_volume_ratio_exclude_range_composes_with_score _ =
  let stocks = _two_breakouts () in
  let scores = _scores_by_ticker stocks in
  let ratios = _volume_ratios stocks in
  let high_score = Map.find_exn scores "HIGH" in
  let high_ratio = Map.find_exn ratios "HIGH" in
  let cfg_compose =
    {
      cfg with
      min_score_override = Some high_score;
      volume_ratio_exclude_range =
        Some { low = high_ratio -. 0.1; high = high_ratio +. 0.1 };
    }
  in
  let result =
    screen ~config:cfg_compose ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates is_empty

(** Diagnostics fold: a candidate excluded by the volume band is counted as NOT
    passing the breakout phase, even though [is_breakout_candidate] returns
    true. Pins the docstring claim "the cascade-diagnostics phase counters treat
    exclusion as part of the breakout phase". *)
let test_volume_ratio_exclude_range_counts_as_breakout_drop _ =
  let stocks = _two_breakouts () in
  let ratios = _volume_ratios stocks in
  let low_ratio = Map.find_exn ratios "LOW" in
  let cfg_excl =
    {
      cfg with
      volume_ratio_exclude_range =
        Some { low = low_ratio -. 0.1; high = low_ratio +. 0.1 };
    }
  in
  let baseline =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  let with_excl =
    screen ~config:cfg_excl ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[]
  in
  assert_that baseline.cascade_diagnostics.long_breakout_admitted (equal_to 2);
  assert_that with_excl.cascade_diagnostics.long_breakout_admitted (equal_to 1)

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

(* A Stage4 short candidate in a Weak sector — same setup as
   {!test_neutral_macro_produces_shorts}, reused by the faithful-short gate
   tests below. *)
let short_setup () =
  let bars = declining_bars_with_spike ~n:60 100.0 30.0 ~spike_idx:55 in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let stocks = [ make_analysis "SHORT" prior bars ] in
  let sector_map =
    sector_map_of [ ("SHORT", make_sector ~rating:Weak "Energy") ]
  in
  (stocks, sector_map)

let screen_short ?(decline_is_slow_grind = true) ~config ~macro_trend () =
  let stocks, sector_map = short_setup () in
  Screener.screen_with_cooldown ~decline_is_slow_grind ~config ~macro_trend
    ~sector_map ~stocks ~held_tickers:[] ~as_of ~last_stop_out_dates:[] ()

(* ------------------------------------------------------------------ *)
(* neutral_blocks_shorts: Neutral tape blocks shorts when set          *)
(* ------------------------------------------------------------------ *)

(* Default ([neutral_blocks_shorts=false]) admits shorts in a Neutral tape. *)
let test_neutral_blocks_shorts_default_admits _ =
  let result = screen_short ~config:cfg ~macro_trend:Neutral () in
  assert_that
    (List.count result.short_candidates ~f:(fun _ -> true))
    (equal_to 1)

(* With the flag set, a Neutral tape produces zero shorts — symmetric to the
   [neutral_blocks_longs] gate. *)
let test_neutral_blocks_shorts_neutral_zero _ =
  let gated_cfg = { cfg with neutral_blocks_shorts = true } in
  let result = screen_short ~config:gated_cfg ~macro_trend:Neutral () in
  assert_that
    (List.count result.short_candidates ~f:(fun _ -> true))
    (equal_to 0)

(* The flag does not affect the Bearish tape — shorts still admitted. *)
let test_neutral_blocks_shorts_bearish_unaffected _ =
  let gated_cfg = { cfg with neutral_blocks_shorts = true } in
  let result = screen_short ~config:gated_cfg ~macro_trend:Bearish () in
  assert_that
    (List.count result.short_candidates ~f:(fun _ -> true))
    (equal_to 1)

(* ------------------------------------------------------------------ *)
(* enable_slow_grind_short_gate: gate short admission on slow-grind     *)
(* ------------------------------------------------------------------ *)

(* Gate off (default): [decline_is_slow_grind] is ignored — shorts admitted in
   a Bearish tape even when the decline is not a slow grind. *)
let test_slow_grind_gate_off_ignores_flag _ =
  let result =
    screen_short ~decline_is_slow_grind:false ~config:cfg ~macro_trend:Bearish
      ()
  in
  assert_that
    (List.count result.short_candidates ~f:(fun _ -> true))
    (equal_to 1)

(* Gate on + not a slow grind: zero shorts even in a Bearish tape. *)
let test_slow_grind_gate_on_blocks_fast_v _ =
  let gated_cfg = { cfg with enable_slow_grind_short_gate = true } in
  let result =
    screen_short ~decline_is_slow_grind:false ~config:gated_cfg
      ~macro_trend:Bearish ()
  in
  assert_that
    (List.count result.short_candidates ~f:(fun _ -> true))
    (equal_to 0)

(* Gate on + slow grind: shorts present in a Bearish tape. *)
let test_slow_grind_gate_on_admits_slow_grind _ =
  let gated_cfg = { cfg with enable_slow_grind_short_gate = true } in
  let result =
    screen_short ~decline_is_slow_grind:true ~config:gated_cfg
      ~macro_trend:Bearish ()
  in
  assert_that
    (List.count result.short_candidates ~f:(fun _ -> true))
    (equal_to 1)

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
  assert_that result.short_candidates
    (all_of
       [
         size_is 1;
         elements_are
           [
             all_of
               [
                 field
                   (fun c -> c.suggested_stop -. c.suggested_entry)
                   (gt (module Float_ord) 0.0);
                 field (fun c -> c.risk_pct) (gt (module Float_ord) 0.0);
               ];
           ];
       ])

(* ------------------------------------------------------------------ *)
(* Candidate grade field matches score                                 *)
(* ------------------------------------------------------------------ *)

let test_candidate_grade_matches_score _ =
  let bars = rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let prior = Some (Stage1 { weeks_in_base = 10 }) in
  let stocks = [ make_analysis "G" prior bars ] in
  let grade_for_score score : grade =
    if score >= 85 then A_plus
    else if score >= 70 then A
    else if score >= 55 then B
    else if score >= 40 then C
    else if score >= 25 then D
    else F
  in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates
    (all_of
       [
         size_is 1;
         elements_are
           [
             matching ~msg:"grade matches score-derived grade"
               (fun c ->
                 if Poly.equal c.grade (grade_for_score c.score) then Some ()
                 else None)
               (equal_to ());
           ];
       ])

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
  assert_that result.buy_candidates
    (all_of
       [
         size_is 1;
         elements_are
           [ field (fun c -> c.side) (equal_to Trading_base.Types.Long) ];
       ])

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
  assert_that result.short_candidates
    (all_of
       [
         size_is 1;
         elements_are
           [ field (fun c -> c.side) (equal_to Trading_base.Types.Short) ];
       ])

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
  assert_that result.short_candidates
    (all_of
       [
         size_is 1;
         elements_are
           [
             all_of
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
                              String.is_substring r
                                ~substring:"breakdown volume")
                        then Some ()
                        else None)
                      (equal_to ()));
               ];
           ];
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
  assert_that result.short_candidates
    (all_of
       [
         size_is 1;
         elements_are
           [
             field
               (fun c -> c.rationale)
               (matching ~msg:"contains 'Adequate breakdown volume'"
                  (fun rs ->
                    List.find rs ~f:(fun r ->
                        String.equal r "Adequate breakdown volume"))
                  (equal_to "Adequate breakdown volume"));
           ];
       ])

(** Inject a [Support.result] directly onto an otherwise-identical candidate and
    assert the screener's [_support_signal] picks it up as a clean-space-below
    bonus. Pins the {b strict} short-side ordering Virgin > Clean > Moderate >
    Heavy: Virgin → [w_virgin_support] (default 20), Clean →
    [w_clean_resistance] (15), Moderate → halved (7), Heavy / None → 0. The
    candidate's other signals contribute a fixed baseline so the support delta
    is the only thing varying across cases. Mirrors
    {!test_negative_rs_scoring_order}'s injection-and- compare shape.

    This is the regression pin for the 2026-06-12 ranking-collapse defect: every
    Stage-4 / Strong-volume short candidate scored an identical 50 because
    Virgin and Clean support previously both weighted [w_clean_resistance], so
    the most explosive setups (Virgin support below) could not rank above merely
    clean ones. The fix differentiates them — Virgin now scores strictly above
    Clean. See [Support] module doc ("Virgin_territory … Most explosive downside
    potential"). *)
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
  assert_that virgin.score (gt (module Int_ord) clean.score);
  assert_that clean.score (gt (module Int_ord) mod_.score);
  assert_that mod_.score (gt (module Int_ord) heavy.score)

(** Reproduce the 2026-06-12 weekly-picks ranking collapse: with RS absent
    ([rs = None], the freshly-built weekly-picks universe lacked the 52 aligned
    weekly bars the RS MA needs), two Stage-4 short candidates that share the
    same stage signal (Early Stage4) and the same Strong breakdown volume but
    differ only on below-support cleanliness (Virgin vs Clean) previously both
    scored an identical 50. After differentiating the Virgin-support weight, the
    Virgin candidate ranks strictly above the Clean one — the ranking spreads
    using a signal that already exists. This is the end-to-end (screen) pin of
    the live defect, distinct from {!test_support_below_scoring_order} which
    holds RS fixed (negative) — here RS is [None] exactly as in production. *)
let test_short_ranking_spreads_with_rs_absent _ =
  let bars = declining_bars_with_spike ~n:60 100.0 30.0 ~spike_idx:55 in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let make ticker quality =
    let base = make_analysis ticker prior bars in
    let support : Support.result = { quality; breakdown_price = 50.0 } in
    (* RS deliberately None — mirrors the live weekly-picks universe. *)
    { base with rs = None; support = Some support }
  in
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map:(empty_sector_map ())
      ~stocks:[ make "VIRGIN" Virgin_territory; make "CLEAN" Clean ]
      ~held_tickers:[]
  in
  let by_ticker t =
    List.find_exn result.short_candidates ~f:(fun c -> String.(c.ticker = t))
  in
  let virgin = (by_ticker "VIRGIN").score in
  let clean = (by_ticker "CLEAN").score in
  (* Both previously collapsed to the same score; now strictly ordered. The
     screen sorts by score DESC, so the higher-scoring Virgin candidate must
     also be ranked first. *)
  assert_that
    (virgin > clean, (List.hd_exn result.short_candidates).ticker)
    (equal_to (true, "VIRGIN"))

(** Exact-composition pin: the short cascade sums its per-signal weights into
    the final score the same way the long cascade does (additive [_tally] over
    stage
    + volume + RS + support + sector signals). Inject a single candidate whose
      every short signal is known and assert the exact integer score equals the
      sum of the configured weights — Stage3→Stage4 breakdown
      ([w_stage2_breakout = 30], the [prior_stage = Stage3] + declining bars
      give the full transition, not the early-Stage4 half) + Strong breakdown
      volume ([w_strong_volume = 20])
    + RS negative & declining ([w_positive_rs = 20]) + Virgin support below
      ([w_virgin_support = 20]) = 90. Guards against a regression where the
      short path silently short-circuits to a default instead of composing the
      weights. Mirrors {!test_short_side_volume_confirmation_strong}'s
      composition pin (which fixed the same bars to score 85 with Clean
      support); the only delta here is Virgin support (20) vs Clean (15). *)
let test_short_score_composition_is_additive _ =
  let bars = declining_bars_with_spike ~n:60 100.0 30.0 ~spike_idx:55 in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let base = make_analysis "COMPOSE" prior bars in
  let neg_rs : Rs.result =
    {
      current_rs = 0.8;
      current_normalized = -10.0;
      trend = Negative_declining;
      history = [];
    }
  in
  let support : Support.result =
    { quality = Virgin_territory; breakdown_price = 50.0 }
  in
  let candidate = { base with rs = Some neg_rs; support = Some support } in
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map:(empty_sector_map ())
      ~stocks:[ candidate ] ~held_tickers:[]
  in
  let w = default_scoring_weights in
  let expected =
    w.w_stage2_breakout + w.w_strong_volume + w.w_positive_rs
    + Option.value_exn w.w_virgin_support
  in
  assert_that result.short_candidates
    (elements_are
       [ field (fun (c : scored_candidate) -> c.score) (equal_to expected) ])

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
      ()
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
      ()
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
      ()
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
      ()
  in
  assert_that result.buy_candidates
    (all_of
       [ size_is 1; elements_are [ field (fun c -> c.ticker) (equal_to "HD") ] ])

(* ------------------------------------------------------------------ *)
(* Point-in-time membership filter                                    *)
(* ------------------------------------------------------------------ *)

(** PI filter unsupplied (default): every symbol is admitted — pins bit-equality
    with the pre-feature [screen_with_cooldown]. *)
let test_pi_filter_default_admits_all _ =
  let stocks = _breakout_stocks [ "AAPL"; "HD" ] in
  let result =
    screen_with_cooldown ~config:cfg ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[] ~as_of
      ~last_stop_out_dates:[] ()
  in
  assert_that result.buy_candidates (size_is 2)

(** PI filter explicitly admits both symbols: same result as the default. *)
let test_pi_filter_admits_both _ =
  let stocks = _breakout_stocks [ "AAPL"; "HD" ] in
  let always_member _ _ = true in
  let result =
    screen_with_cooldown ~membership_at:always_member ~config:cfg
      ~macro_trend:Bullish ~sector_map:(empty_sector_map ()) ~stocks
      ~held_tickers:[] ~as_of ~last_stop_out_dates:[] ()
  in
  assert_that result.buy_candidates (size_is 2)

(** PI filter rejects AAPL (delisted) but keeps HD. Models a 16y backtest where
    a symbol was active for years before [as_of] but is no longer in the
    eligible universe. *)
let test_pi_filter_excludes_delisted _ =
  let stocks = _breakout_stocks [ "AAPL"; "HD" ] in
  let membership_at ticker _date = not (String.equal ticker "AAPL") in
  let result =
    screen_with_cooldown ~membership_at ~config:cfg ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[] ~as_of
      ~last_stop_out_dates:[] ()
  in
  assert_that result.buy_candidates
    (all_of
       [ size_is 1; elements_are [ field (fun c -> c.ticker) (equal_to "HD") ] ])

(** PI filter is consulted with [as_of]: a callback that depends on the date can
    admit or reject the same ticker on different days. *)
let test_pi_filter_consults_as_of _ =
  let stocks = _breakout_stocks [ "AAPL" ] in
  let cutoff = Date.add_days as_of (-1) in
  (* AAPL is a member only on or before [cutoff]; here as_of > cutoff. *)
  let membership_at _ticker date = Date.( <= ) date cutoff in
  let result =
    screen_with_cooldown ~membership_at ~config:cfg ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ()) ~stocks ~held_tickers:[] ~as_of
      ~last_stop_out_dates:[] ()
  in
  assert_that result.buy_candidates is_empty

(** PI filter composes with the cooldown gate: a symbol that would survive the
    cooldown gate but fail the PI filter is still rejected. *)
let test_pi_filter_composes_with_cooldown _ =
  let stocks = _breakout_stocks [ "AAPL"; "HD" ] in
  let cooldown_cfg = { cfg with cascade_post_stop_cooldown_weeks = 4 } in
  (* HD blocked by PI filter; AAPL blocked by cooldown (recent stop). *)
  let membership_at ticker _date = not (String.equal ticker "HD") in
  let result =
    screen_with_cooldown ~membership_at ~config:cooldown_cfg
      ~macro_trend:Bullish ~sector_map:(empty_sector_map ()) ~stocks
      ~held_tickers:[] ~as_of
      ~last_stop_out_dates:[ ("AAPL", Date.add_days as_of (-7)) ]
      ()
  in
  assert_that result.buy_candidates is_empty

(* ------------------------------------------------------------------ *)
(* min_price: liquidity floor                                          *)
(* ------------------------------------------------------------------ *)

let _tickers cs = List.map cs ~f:(fun (c : scored_candidate) -> c.ticker)

(** A low-priced (~$2.70 breakout) Stage1→Stage2 breakout candidate. *)
let _cheap_long ticker =
  let bars = rising_bars_with_spike ~n:35 1.5 3.0 ~spike_idx:31 in
  make_analysis ticker (Some (Stage1 { weeks_in_base = 10 })) bars

(** A higher-priced (~$9.00 breakout) Stage1→Stage2 breakout candidate. *)
let _rich_long ticker =
  let bars = rising_bars_with_spike ~n:35 5.0 10.0 ~spike_idx:31 in
  make_analysis ticker (Some (Stage1 { weeks_in_base = 10 })) bars

(** A low-priced (~$3.34 breakdown) Stage3→Stage4 short candidate. *)
let _cheap_short ticker =
  let bars = declining_bars_with_spike ~n:60 6.0 3.0 ~spike_idx:55 in
  make_analysis ticker (Some (Stage3 { weeks_topping = 8 })) bars

(** No-op proof: [min_price = 0.0] (the default) admits a low-priced (~$2.70)
    Stage-2 breakout exactly as today. *)
let test_min_price_zero_admits_low_priced _ =
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks:[ _cheap_long "CHEAP" ]
      ~held_tickers:[]
  in
  assert_that
    (_tickers result.buy_candidates)
    (elements_are [ equal_to "CHEAP" ])

(** Floor rejects: [min_price = 5.0] drops the ~$2.70 candidate but admits the
    ~$9.00 one. *)
let test_min_price_floor_rejects_below _ =
  let floor_cfg = { cfg with min_price = 5.0 } in
  let result =
    screen ~config:floor_cfg ~macro_trend:Bullish
      ~sector_map:(empty_sector_map ())
      ~stocks:[ _cheap_long "CHEAP"; _rich_long "RICH" ]
      ~held_tickers:[]
  in
  assert_that
    (_tickers result.buy_candidates)
    (elements_are [ equal_to "RICH" ])

(** Short side: the floor also gates short candidates — a ~$3.34 breakdown short
    is rejected at [min_price = 5.0]. *)
let test_min_price_floor_rejects_short _ =
  let floor_cfg = { cfg with min_price = 5.0 } in
  let sector_map =
    sector_map_of [ ("SHT", make_sector ~rating:Weak "Energy") ]
  in
  let result =
    screen ~config:floor_cfg ~macro_trend:Bearish ~sector_map
      ~stocks:[ _cheap_short "SHT" ]
      ~held_tickers:[]
  in
  assert_that result.short_candidates is_empty

(** The same ~$3.34 breakdown short is admitted when the floor is disabled
    ([min_price = 0.0]) — confirms the short-side gate is the floor, not an
    unrelated rejection. *)
let test_min_price_zero_admits_short _ =
  let sector_map =
    sector_map_of [ ("SHT", make_sector ~rating:Weak "Energy") ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map
      ~stocks:[ _cheap_short "SHT" ]
      ~held_tickers:[]
  in
  assert_that
    (_tickers result.short_candidates)
    (elements_are [ equal_to "SHT" ])

(** Missing price under a positive floor is rejected — liquidity can't be
    verified. *)
let test_passes_price_floor_missing_price_rejected _ =
  assert_that (passes_price_floor ~min_price:5.0 ~price:None) (equal_to false)

(** Missing price with the floor disabled ([min_price = 0.0]) is admitted — the
    no-op short-circuits before the price is examined. *)
let test_passes_price_floor_missing_price_noop _ =
  assert_that (passes_price_floor ~min_price:0.0 ~price:None) (equal_to true)

(* ------------------------------------------------------------------ *)
(* w_early_stage2 — decoupled early-Stage2 weight                       *)
(* ------------------------------------------------------------------ *)

(** Synthetic early-Stage2 analysis: in Stage2 with [weeks_advancing <= 4] and
    no observed Stage1 predecessor, so [score_long] takes the Early-Stage2 arm,
    not the Stage1→2 breakout arm. *)
let _early_stage2_analysis () =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let base = make_analysis "EARLY" None bars in
  {
    base with
    stage =
      { base.stage with stage = Stage2 { weeks_advancing = 2; late = false } };
    prior_stage = None;
  }

(** A confirmed Stage1→2 breakout analysis (prior_stage = Stage1) — the arm
    [w_early_stage2] must NOT touch. *)
let _breakout_analysis () =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let base =
    make_analysis "BREAKOUT" (Some (Stage1 { weeks_in_base = 12 })) bars
  in
  {
    base with
    stage =
      { base.stage with stage = Stage2 { weeks_advancing = 2; late = false } };
  }

(** [w_early_stage2 = None] (default) reproduces the historical
    [w_stage2_breakout / 2 = 15] coupling, and [Some v] decouples it: [Some 15]
    is bit-identical to the default, while [Some 30] adds exactly 15 to the
    early-Stage2 score (all other signals held constant). *)
let test_w_early_stage2_none_preserves_half _ =
  let a = _early_stage2_analysis () in
  let sector = make_sector "Tech" in
  let score weights = fst (score_long ~weights ~sector a) in
  let s_none = score default_scoring_weights in
  let s_some15 =
    score { default_scoring_weights with w_early_stage2 = Some 15 }
  in
  let s_some30 =
    score { default_scoring_weights with w_early_stage2 = Some 30 }
  in
  (* Some 15 reproduces the default (w_stage2_breakout/2 = 15); Some 30 adds 15. *)
  assert_that (s_some15, s_some30 - s_none) (equal_to (s_none, 15))

(** [w_early_stage2] only touches the Early-Stage2 arm: on a confirmed Stage1→2
    breakout, changing it from [None] to [Some 30] leaves the score unchanged.
*)
let test_w_early_stage2_no_effect_on_breakout _ =
  let a = _breakout_analysis () in
  let sector = make_sector "Tech" in
  let score weights = fst (score_long ~weights ~sector a) in
  assert_that
    (score { default_scoring_weights with w_early_stage2 = Some 30 })
    (equal_to (score default_scoring_weights))

(** Override-resolution contract: with [@sexp.default None] the field is PRESENT
    in the serialized [scoring_weights] sexp even when [None] — required so
    [Backtest.Overlay_validator] (which derives valid override key-paths from
    the serialized base config) can resolve a
    [screening_config.weights.w_early_stage2] override. A sexp {e missing} the
    field still parses to [None] (older configs round-trip); a sexp carrying
    [(w_early_stage2 (v))] round-trips to [Some v]. *)
let test_w_early_stage2_sexp_present_and_roundtrips _ =
  let default_str =
    Sexp.to_string (sexp_of_scoring_weights default_scoring_weights)
  in
  let parsed_missing =
    scoring_weights_of_sexp
      (Sexp.of_string
         "((w_stage2_breakout 30)(w_strong_volume 20)(w_adequate_volume \
          10)(w_positive_rs 20)(w_bullish_rs_crossover 10)(w_clean_resistance \
          15)(w_sector_strong 10)(w_late_stage2_penalty -15))")
  in
  let roundtrip =
    scoring_weights_of_sexp
      (sexp_of_scoring_weights
         { default_scoring_weights with w_early_stage2 = Some 22 })
  in
  assert_that
    ( String.is_substring default_str ~substring:"w_early_stage2",
      parsed_missing.w_early_stage2,
      roundtrip.w_early_stage2 )
    (equal_to (true, None, Some 22))

(* ------------------------------------------------------------------ *)
(* candidate_ranking: tiebreak among equal-score candidates            *)
(* ------------------------------------------------------------------ *)

(** Build a {!Stock_analysis.t} carrying only the fields the [Quality] tiebreak
    reads ([rs.current_normalized], [stage.stage]'s [weeks_advancing],
    [volume.volume_ratio]); everything else is a benign stub. *)
let ranking_analysis ~ticker ~rs_norm ~weeks_advancing ~volume_ratio :
    Stock_analysis.t =
  {
    ticker;
    stage =
      {
        stage = Stage2 { weeks_advancing; late = false };
        ma_value = 100.0;
        ma_direction = Rising;
        ma_slope_pct = 0.05;
        transition = None;
        above_ma_count = 5;
      };
    rs =
      Some
        {
          current_rs = 1.0;
          current_normalized = rs_norm;
          trend = Positive_rising;
          history = [];
        };
    volume =
      Some
        {
          confirmation = Strong volume_ratio;
          event_volume = 3000;
          avg_volume = 1000.0;
          volume_ratio;
        };
    resistance = None;
    support = None;
    breakout_price = Some 100.0;
    breakdown_price = None;
    prior_stage = Some (Stage1 { weeks_in_base = 10 });
    continuation = None;
    as_of_date = as_of;
  }

(** Build a long {!scored_candidate} with a fixed score and the controllable
    [Quality]-tiebreak keys. *)
let ranking_candidate ~ticker ?(score = 75) ?(rs_norm = 1.0)
    ?(weeks_advancing = 5) ?(volume_ratio = 2.5) () : scored_candidate =
  {
    ticker;
    analysis = ranking_analysis ~ticker ~rs_norm ~weeks_advancing ~volume_ratio;
    sector = make_sector "Tech";
    side = Long;
    grade = A;
    score;
    suggested_entry = 100.0;
    suggested_stop = 92.0;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [];
  }

(** [sort_tickers ranking candidates] = the ticker order [compare_for_ranking]
    produces. *)
let sort_tickers ranking candidates =
  List.sort candidates ~compare:(compare_for_ranking ranking)
  |> List.map ~f:(fun (c : scored_candidate) -> c.ticker)

(* Parity: with equal scores, [Alphabetical] reproduces the historical
   ticker-only tiebreak exactly — input order is irrelevant, output is
   alphabetical. This is the bit-identical back-compat guarantee. *)
let test_ranking_alphabetical_is_ticker_order _ =
  let candidates =
    [
      ranking_candidate ~ticker:"ZED" ~rs_norm:9.0 ();
      ranking_candidate ~ticker:"ABE" ~rs_norm:1.0 ();
      ranking_candidate ~ticker:"MID" ~rs_norm:5.0 ();
    ]
  in
  assert_that
    (sort_tickers Alphabetical candidates)
    (elements_are [ equal_to "ABE"; equal_to "MID"; equal_to "ZED" ])

(* Reorder: with equal scores, [Quality] orders by RS magnitude descending
   (then earliness), so the highest-RS ticker comes first — the opposite of the
   alphabetical order for this fixture. *)
let test_ranking_quality_orders_by_rs _ =
  let candidates =
    [
      ranking_candidate ~ticker:"ABE" ~rs_norm:1.0 ();
      ranking_candidate ~ticker:"ZED" ~rs_norm:9.0 ();
      ranking_candidate ~ticker:"MID" ~rs_norm:5.0 ();
    ]
  in
  assert_that
    (sort_tickers Quality candidates)
    (elements_are [ equal_to "ZED"; equal_to "MID"; equal_to "ABE" ])

(* Earliness is the second [Quality] key: among equal-score, equal-RS
   candidates, the smaller [weeks_advancing] (earlier Stage 2) ranks first. *)
let test_ranking_quality_breaks_rs_ties_by_earliness _ =
  let candidates =
    [
      ranking_candidate ~ticker:"LATE" ~rs_norm:3.0 ~weeks_advancing:12 ();
      ranking_candidate ~ticker:"EARLY" ~rs_norm:3.0 ~weeks_advancing:2 ();
    ]
  in
  assert_that
    (sort_tickers Quality candidates)
    (elements_are [ equal_to "EARLY"; equal_to "LATE" ])

(* Primary key is unchanged: a higher score outranks a stronger RS in either
   mode — [Quality] only reorders *equal* scores. *)
let test_ranking_quality_respects_score_primary _ =
  let candidates =
    [
      ranking_candidate ~ticker:"HISCORE" ~score:80 ~rs_norm:1.0 ();
      ranking_candidate ~ticker:"LOSCORE" ~score:70 ~rs_norm:9.0 ();
    ]
  in
  assert_that
    (sort_tickers Quality candidates)
    (elements_are [ equal_to "HISCORE"; equal_to "LOSCORE" ])

(* [Quality_earliness] leads with earliness: among equal scores, the freshest
   Stage 2 (smallest [weeks_advancing]) ranks first EVEN when its RS is lower —
   the distinguishing behaviour vs [Quality], where the same fixture orders by
   RS. FRESH has the lowest RS but the smallest [weeks_advancing]. *)
let test_ranking_earliness_leads_with_earliness _ =
  let candidates =
    [
      ranking_candidate ~ticker:"EXT" ~rs_norm:9.0 ~weeks_advancing:12 ();
      ranking_candidate ~ticker:"FRESH" ~rs_norm:1.0 ~weeks_advancing:2 ();
      ranking_candidate ~ticker:"MID" ~rs_norm:5.0 ~weeks_advancing:6 ();
    ]
  in
  assert_that
    (sort_tickers Quality_earliness candidates)
    (elements_are [ equal_to "FRESH"; equal_to "MID"; equal_to "EXT" ])

(* The same fixture under [Quality] (RS-primary) orders the OPPOSITE way — pins
   that the two modes are genuinely distinct, not aliases. *)
let test_ranking_earliness_inverts_quality_on_rs_extended_fixture _ =
  let candidates =
    [
      ranking_candidate ~ticker:"EXT" ~rs_norm:9.0 ~weeks_advancing:12 ();
      ranking_candidate ~ticker:"FRESH" ~rs_norm:1.0 ~weeks_advancing:2 ();
      ranking_candidate ~ticker:"MID" ~rs_norm:5.0 ~weeks_advancing:6 ();
    ]
  in
  assert_that
    (sort_tickers Quality candidates)
    (elements_are [ equal_to "EXT"; equal_to "MID"; equal_to "FRESH" ])

(* RS is the second [Quality_earliness] key: among equal-score, equal-earliness
   candidates, the higher RS magnitude ranks first. *)
let test_ranking_earliness_breaks_earliness_ties_by_rs _ =
  let candidates =
    [
      ranking_candidate ~ticker:"LORS" ~rs_norm:1.0 ~weeks_advancing:3 ();
      ranking_candidate ~ticker:"HIRS" ~rs_norm:9.0 ~weeks_advancing:3 ();
    ]
  in
  assert_that
    (sort_tickers Quality_earliness candidates)
    (elements_are [ equal_to "HIRS"; equal_to "LORS" ])

(* Primary key unchanged: a higher score outranks a fresher setup —
   [Quality_earliness] only reorders *equal* scores. *)
let test_ranking_earliness_respects_score_primary _ =
  let candidates =
    [
      ranking_candidate ~ticker:"HISCORE" ~score:80 ~weeks_advancing:20 ();
      ranking_candidate ~ticker:"LOSCORE" ~score:70 ~weeks_advancing:1 ();
    ]
  in
  assert_that
    (sort_tickers Quality_earliness candidates)
    (elements_are [ equal_to "HISCORE"; equal_to "LOSCORE" ])

(* [Quality_earliness] round-trips through the config sexp — so it is a real
   [Overlay_validator] axis value (experiment-flag-discipline R2). *)
let test_ranking_earliness_round_trips _ =
  let earliness_cfg =
    config_of_sexp
      (Sexp.of_string
         (String.substr_replace_first
            (Sexp.to_string (sexp_of_config default_config))
            ~pattern:"(candidate_ranking Alphabetical)"
            ~with_:"(candidate_ranking Quality_earliness)"))
  in
  assert_that earliness_cfg.candidate_ranking (equal_to Quality_earliness)

(* Control mode [Reverse_alphabetical]: ties order Z->A (mirror of Alphabetical). *)
let test_ranking_reverse_alphabetical _ =
  let candidates =
    [
      ranking_candidate ~ticker:"ABE" ();
      ranking_candidate ~ticker:"ZED" ();
      ranking_candidate ~ticker:"MID" ();
    ]
  in
  assert_that
    (sort_tickers Reverse_alphabetical candidates)
    (elements_are [ equal_to "ZED"; equal_to "MID"; equal_to "ABE" ])

(* Control mode [Symbol_length]: shorter ticker first, then alphabetical. *)
let test_ranking_symbol_length _ =
  let candidates =
    [
      ranking_candidate ~ticker:"AAAA" ();
      ranking_candidate ~ticker:"BB" ();
      ranking_candidate ~ticker:"C" ();
    ]
  in
  assert_that
    (sort_tickers Symbol_length candidates)
    (elements_are [ equal_to "C"; equal_to "BB"; equal_to "AAAA" ])

(* Control mode [Hash_order]: deterministic FNV-1a pseudo-random order. For these
   tickers the 32-bit FNV-1a hashes are ZZ=924325685 < AAA=3061902210 <
   M=3356228888, so the order is [ZZ; AAA; M] — distinct from BOTH alphabetical
   [AAA; M; ZZ] AND symbol-length [M; ZZ; AAA], confirming it is a genuine
   pseudo-random (but reproducible) permutation, not secretly length- or
   alpha-ordered. *)
let test_ranking_hash_order_is_deterministic_permutation _ =
  let candidates =
    [
      ranking_candidate ~ticker:"AAA" ();
      ranking_candidate ~ticker:"M" ();
      ranking_candidate ~ticker:"ZZ" ();
    ]
  in
  assert_that
    (sort_tickers Hash_order candidates)
    (elements_are [ equal_to "ZZ"; equal_to "AAA"; equal_to "M" ])

(* All control modes round-trip through the config sexp (real [Overlay_validator]
   axis values). *)
let test_ranking_control_modes_round_trip _ =
  let cfg_with mode =
    config_of_sexp
      (Sexp.of_string
         (String.substr_replace_first
            (Sexp.to_string (sexp_of_config default_config))
            ~pattern:"(candidate_ranking Alphabetical)"
            ~with_:("(candidate_ranking " ^ mode ^ ")")))
  in
  assert_that
    [
      (cfg_with "Reverse_alphabetical").candidate_ranking;
      (cfg_with "Symbol_length").candidate_ranking;
      (cfg_with "Hash_order").candidate_ranking;
    ]
    (elements_are
       [
         equal_to Reverse_alphabetical;
         equal_to Symbol_length;
         equal_to Hash_order;
       ])

(* Axis-ability (experiment-flag-discipline R2): the field is present in the
   serialized config (so [Overlay_validator] resolves the
   [screening_config.candidate_ranking] override path) and a [Quality] overlay
   round-trips. An omitted field deserialises to the [Alphabetical] default. *)
let test_ranking_field_serializes_and_round_trips _ =
  let default_str = Sexp.to_string (sexp_of_config default_config) in
  let quality_cfg =
    config_of_sexp
      (Sexp.of_string
         (String.substr_replace_first default_str
            ~pattern:"(candidate_ranking Alphabetical)"
            ~with_:"(candidate_ranking Quality)"))
  in
  assert_that
    ( String.is_substring default_str ~substring:"candidate_ranking",
      quality_cfg.candidate_ranking )
    (equal_to (true, Quality))

let test_ranking_omitted_field_defaults_alphabetical _ =
  let no_ranking =
    config_of_sexp
      (Sexp.of_string
         (String.substr_replace_first
            (Sexp.to_string (sexp_of_config default_config))
            ~pattern:"(candidate_ranking Alphabetical)" ~with_:""))
  in
  assert_that no_ranking.candidate_ranking (equal_to Alphabetical)

(* ------------------------------------------------------------------ *)
(* early_stage2_max_weeks: early-Stage2 window knob                     *)
(* ------------------------------------------------------------------ *)

(** A fresh Stage2 analysis with no observed Stage1→Stage2 predecessor, so the
    early-Stage2 scoring arm (not the Stage1→Stage2 breakout arm) is the one
    that fires, gated by [early_stage2_max_weeks]. *)
let early_stage2_analysis ~weeks_advancing : Stock_analysis.t =
  {
    (ranking_analysis ~ticker:"X" ~rs_norm:1.0 ~weeks_advancing
       ~volume_ratio:3.0)
    with
    prior_stage = None;
  }

(** Count of "Early Stage2" labels in a scoring rationale (0 or 1). *)
let early_stage2_labels rationale =
  List.count rationale ~f:(String.equal "Early Stage2")

(* Widened window earns the Early-Stage2 signal for a weeks_advancing = 5
   candidate that the default window (4) does not — one knob drives the scoring
   bonus, matching the admission gate window. *)
let test_score_long_window_controls_early_stage2_signal _ =
  let sector = make_sector "Tech" in
  let a = early_stage2_analysis ~weeks_advancing:5 in
  let default_rationale = snd (score_long ~weights:cfg.weights ~sector a) in
  let widened_rationale =
    snd (score_long ~early_stage2_max_weeks:8 ~weights:cfg.weights ~sector a)
  in
  assert_that
    ( early_stage2_labels default_rationale,
      early_stage2_labels widened_rationale )
    (equal_to (0, 1))

(* Axis-ability (experiment-flag-discipline R2): the field is present in the
   serialized config (so [Overlay_validator] resolves the
   [screening_config.early_stage2_max_weeks] override path) and an overlay value
   round-trips. *)
let test_early_stage2_max_weeks_serializes_and_round_trips _ =
  let default_str = Sexp.to_string (sexp_of_config default_config) in
  let widened_cfg =
    config_of_sexp
      (Sexp.of_string
         (String.substr_replace_first default_str
            ~pattern:"(early_stage2_max_weeks 4)"
            ~with_:"(early_stage2_max_weeks 8)"))
  in
  assert_that
    ( String.is_substring default_str ~substring:"early_stage2_max_weeks",
      widened_cfg.early_stage2_max_weeks )
    (equal_to (true, 8))

(* An omitted field deserialises to the default 4 — older config sexps that
   predate this knob round-trip to the historical hardcoded window. *)
let test_early_stage2_max_weeks_omitted_defaults_4 _ =
  let no_field =
    config_of_sexp
      (Sexp.of_string
         (String.substr_replace_first
            (Sexp.to_string (sexp_of_config default_config))
            ~pattern:"(early_stage2_max_weeks 4)" ~with_:""))
  in
  assert_that no_field.early_stage2_max_weeks (equal_to 4)

let suite =
  "screener_tests"
  >::: [
         "test_w_early_stage2_none_preserves_half"
         >:: test_w_early_stage2_none_preserves_half;
         "test_w_early_stage2_sexp_present_and_roundtrips"
         >:: test_w_early_stage2_sexp_present_and_roundtrips;
         "test_w_early_stage2_no_effect_on_breakout"
         >:: test_w_early_stage2_no_effect_on_breakout;
         "test_min_price_zero_admits_low_priced"
         >:: test_min_price_zero_admits_low_priced;
         "test_min_price_floor_rejects_below"
         >:: test_min_price_floor_rejects_below;
         "test_min_price_floor_rejects_short"
         >:: test_min_price_floor_rejects_short;
         "test_min_price_zero_admits_short" >:: test_min_price_zero_admits_short;
         "test_passes_price_floor_missing_price_rejected"
         >:: test_passes_price_floor_missing_price_rejected;
         "test_passes_price_floor_missing_price_noop"
         >:: test_passes_price_floor_missing_price_noop;
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
         "test_max_score_override_excludes_at_or_above_threshold"
         >:: test_max_score_override_excludes_at_or_above_threshold;
         "test_max_score_override_exclusive_at_boundary"
         >:: test_max_score_override_exclusive_at_boundary;
         "test_max_score_override_default_admits_all"
         >:: test_max_score_override_default_admits_all;
         "test_max_score_override_above_high_admits_all"
         >:: test_max_score_override_above_high_admits_all;
         "test_volume_ratio_exclude_range_default_admits_all"
         >:: test_volume_ratio_exclude_range_default_admits_all;
         "test_volume_ratio_exclude_range_drops_in_band"
         >:: test_volume_ratio_exclude_range_drops_in_band;
         "test_volume_ratio_exclude_range_upper_bound_exclusive"
         >:: test_volume_ratio_exclude_range_upper_bound_exclusive;
         "test_volume_ratio_exclude_range_composes_with_score"
         >:: test_volume_ratio_exclude_range_composes_with_score;
         "test_volume_ratio_exclude_range_counts_as_breakout_drop"
         >:: test_volume_ratio_exclude_range_counts_as_breakout_drop;
         "test_min_and_max_score_override_compose"
         >:: test_min_and_max_score_override_compose;
         "test_neutral_macro_produces_shorts"
         >:: test_neutral_macro_produces_shorts;
         "test_neutral_blocks_shorts_default_admits"
         >:: test_neutral_blocks_shorts_default_admits;
         "test_neutral_blocks_shorts_neutral_zero"
         >:: test_neutral_blocks_shorts_neutral_zero;
         "test_neutral_blocks_shorts_bearish_unaffected"
         >:: test_neutral_blocks_shorts_bearish_unaffected;
         "test_slow_grind_gate_off_ignores_flag"
         >:: test_slow_grind_gate_off_ignores_flag;
         "test_slow_grind_gate_on_blocks_fast_v"
         >:: test_slow_grind_gate_on_blocks_fast_v;
         "test_slow_grind_gate_on_admits_slow_grind"
         >:: test_slow_grind_gate_on_admits_slow_grind;
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
         "test_short_ranking_spreads_with_rs_absent"
         >:: test_short_ranking_spreads_with_rs_absent;
         "test_short_score_composition_is_additive"
         >:: test_short_score_composition_is_additive;
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
         "test_pi_filter_default_admits_all"
         >:: test_pi_filter_default_admits_all;
         "test_pi_filter_admits_both" >:: test_pi_filter_admits_both;
         "test_pi_filter_excludes_delisted" >:: test_pi_filter_excludes_delisted;
         "test_pi_filter_consults_as_of" >:: test_pi_filter_consults_as_of;
         "test_pi_filter_composes_with_cooldown"
         >:: test_pi_filter_composes_with_cooldown;
         "test_ranking_alphabetical_is_ticker_order"
         >:: test_ranking_alphabetical_is_ticker_order;
         "test_ranking_quality_orders_by_rs"
         >:: test_ranking_quality_orders_by_rs;
         "test_ranking_quality_breaks_rs_ties_by_earliness"
         >:: test_ranking_quality_breaks_rs_ties_by_earliness;
         "test_ranking_quality_respects_score_primary"
         >:: test_ranking_quality_respects_score_primary;
         "test_ranking_earliness_leads_with_earliness"
         >:: test_ranking_earliness_leads_with_earliness;
         "test_ranking_earliness_inverts_quality_on_rs_extended_fixture"
         >:: test_ranking_earliness_inverts_quality_on_rs_extended_fixture;
         "test_ranking_earliness_breaks_earliness_ties_by_rs"
         >:: test_ranking_earliness_breaks_earliness_ties_by_rs;
         "test_ranking_earliness_respects_score_primary"
         >:: test_ranking_earliness_respects_score_primary;
         "test_ranking_earliness_round_trips"
         >:: test_ranking_earliness_round_trips;
         "test_ranking_reverse_alphabetical"
         >:: test_ranking_reverse_alphabetical;
         "test_ranking_symbol_length" >:: test_ranking_symbol_length;
         "test_ranking_hash_order_is_deterministic_permutation"
         >:: test_ranking_hash_order_is_deterministic_permutation;
         "test_ranking_control_modes_round_trip"
         >:: test_ranking_control_modes_round_trip;
         "test_ranking_field_serializes_and_round_trips"
         >:: test_ranking_field_serializes_and_round_trips;
         "test_ranking_omitted_field_defaults_alphabetical"
         >:: test_ranking_omitted_field_defaults_alphabetical;
         "test_score_long_window_controls_early_stage2_signal"
         >:: test_score_long_window_controls_early_stage2_signal;
         "test_early_stage2_max_weeks_serializes_and_round_trips"
         >:: test_early_stage2_max_weeks_serializes_and_round_trips;
         "test_early_stage2_max_weeks_omitted_defaults_4"
         >:: test_early_stage2_max_weeks_omitted_defaults_4;
       ]

let () = run_test_tt_main suite
