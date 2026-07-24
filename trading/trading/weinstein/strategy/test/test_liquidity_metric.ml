open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* Build a daily bar with explicit close + volume; OHLC default around close. *)
let make_bar date ~close ~volume =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close = close;
    volume;
    active_through = None;
  }

let make_bar_on date_string = make_bar (Date.of_string date_string)

(* close 10, vol 1000 => 10_000 dollar-volume per bar. *)
let bars_uniform =
  [
    make_bar_on "2024-01-02" ~close:10.0 ~volume:1000;
    make_bar_on "2024-01-03" ~close:10.0 ~volume:1000;
    make_bar_on "2024-01-04" ~close:10.0 ~volume:1000;
  ]

(* Dollar volumes 5_000; 10_000; 20_000 — deliberately NOT in sorted order of
   magnitude relative to the calendar, so an aggregation that assumed
   chronological == sorted would be caught. *)
let bars_ascending =
  [
    make_bar_on "2024-01-02" ~close:5.0 ~volume:1000;
    make_bar_on "2024-01-03" ~close:20.0 ~volume:1000;
    make_bar_on "2024-01-04" ~close:10.0 ~volume:1000;
  ]

let all_aggregations =
  [
    Liquidity_metric.Mean;
    Liquidity_metric.Median;
    Liquidity_metric.Trimmed_mean;
  ]

(* Read the metric under every aggregation, in [all_aggregations] order. *)
let readings_for_each_aggregation ?trim_pct ~lookback_days bars =
  List.map all_aggregations ~f:(fun aggregation ->
      Liquidity_metric.dollar_adv ~aggregation ?trim_pct ~lookback_days bars)

(* --- Legacy (pre-#2060) contract: the default reading is the plain mean ----- *)

let test_uniform_mean _ =
  assert_that
    (Liquidity_metric.dollar_adv ~lookback_days:3 bars_uniform)
    (is_some_and (float_equal 10_000.0))

let test_window_takes_trailing _ =
  (* Trailing 2 of [5000; 20000; 10000] dollar-volume = mean(20000, 10000). *)
  assert_that
    (Liquidity_metric.dollar_adv ~lookback_days:2 bars_ascending)
    (is_some_and (float_equal 15_000.0))

let test_window_longer_than_bars_uses_all _ =
  (* lookback 10 but only 3 bars: averages over the 3 present (no padding). *)
  assert_that
    (Liquidity_metric.dollar_adv ~lookback_days:10 bars_uniform)
    (is_some_and (float_equal 10_000.0))

let test_empty_bars_none _ =
  assert_that (Liquidity_metric.dollar_adv ~lookback_days:20 []) is_none

let test_nonpositive_lookback_none _ =
  assert_that
    (Liquidity_metric.dollar_adv ~lookback_days:0 bars_uniform)
    is_none

(* --- The LINK spoof scenario (issue #2060) --------------------------------- *)

(* LINK genuinely traded ~$250k/day; on 2026-05-11 it printed 4,608,300 shares
   ($15.4M) with zero price impact — a block cross or bad print. That one day
   lifted its 20-day trailing MEAN dollar-ADV to ~$1.0M, just clearing the armed
   $1M entry gate, and the strategy opened an $8.9M position that stopped out
   five days later at -17.7%. The fixture below reproduces that shape with round
   numbers: 60 bars of honest $250k/day plus one $15.4M print inside the
   trailing 20-bar window. *)
let honest_dollar_volume = 250_000.0
let spoof_dollar_volume = 15_400_000.0
let entry_floor = 1_000_000.0
let spoof_lookback = 20

(* mean = (19 * 250_000 + 15_400_000) / 20 = 1_007_500 — clears $1M by 0.75%. *)
let spoof_mean = 1_007_500.0

(* 60 bars at a flat $5 close; the block print sits at index 50, i.e. inside the
   trailing 20-bar window the entry gate reads. *)
let spoof_bars =
  let start = Date.of_string "2026-03-16" in
  let close = 5.0 in
  let volume_for dollar_volume = Float.to_int (dollar_volume /. close) in
  List.init 60 ~f:(fun i ->
      let dollar_volume =
        if i = 50 then spoof_dollar_volume else honest_dollar_volume
      in
      make_bar (Date.add_days start i) ~close ~volume:(volume_for dollar_volume))

let spoof_reading ?trim_pct ~aggregation () =
  Liquidity_metric.dollar_adv ~aggregation ?trim_pct
    ~lookback_days:spoof_lookback spoof_bars

(* Pins TODAY'S DEFECT: the mean is spoofed past the armed entry floor. *)
let test_spoof_mean_clears_entry_floor _ =
  assert_that
    (spoof_reading ~aggregation:Liquidity_metric.Mean ())
    (is_some_and
       (all_of [ float_equal spoof_mean; ge (module Float_ord) entry_floor ]))

(* The fix: neither robust aggregation is moved by the single block print, so
   both read the honest ~$250k/day baseline and fail the $1M floor. *)
let test_spoof_robust_aggregations_stay_below_floor _ =
  assert_that
    [
      spoof_reading ~aggregation:Liquidity_metric.Median ();
      spoof_reading ~aggregation:Liquidity_metric.Trimmed_mean ();
    ]
    (elements_are
       [
         is_some_and
           (all_of
              [
                float_equal honest_dollar_volume;
                lt (module Float_ord) entry_floor;
              ]);
         is_some_and
           (all_of
              [
                float_equal honest_dollar_volume;
                lt (module Float_ord) entry_floor;
              ]);
       ])

(* --- R1 (experiment-flag-discipline): the default is bit-identical to Mean -- *)

(* (bars, lookback_days) spanning the spoof fixture, the legacy fixtures and
   both degenerate cases. *)
let backward_compat_inputs =
  [
    (spoof_bars, spoof_lookback);
    (bars_uniform, 3);
    (bars_ascending, 2);
    (bars_uniform, 10);
    ([], 20);
    (bars_uniform, 0);
  ]

let test_default_aggregation_is_bit_identical_to_mean _ =
  assert_that
    (List.map backward_compat_inputs ~f:(fun (bars, lookback_days) ->
         Liquidity_metric.dollar_adv ~lookback_days bars))
    (elements_are
       (List.map backward_compat_inputs ~f:(fun (bars, lookback_days) ->
            (* [equal_to] on [float option] is exact structural equality — not
               an epsilon compare — so this pins bit-identity, not closeness. *)
            equal_to
              (Liquidity_metric.dollar_adv ~aggregation:Liquidity_metric.Mean
                 ~lookback_days bars))))

let test_config_default_aggregation_is_mean _ =
  assert_that Liquidity_config.default_config.adv_aggregation
    (equal_to Liquidity_metric.Mean)

(* --- Median -------------------------------------------------------------- *)

let test_median_odd_window _ =
  (* [5000; 20000; 10000] sorted = [5000; 10000; 20000]; middle = 10000. *)
  assert_that
    (Liquidity_metric.dollar_adv ~aggregation:Liquidity_metric.Median
       ~lookback_days:3 bars_ascending)
    (is_some_and (float_equal 10_000.0))

let test_median_even_window _ =
  (* [5000; 20000; 10000; 40000] sorted = [5000; 10000; 20000; 40000];
     mean of the two central observations = (10000 + 20000) / 2 = 15000. *)
  let bars =
    bars_ascending @ [ make_bar_on "2024-01-05" ~close:40.0 ~volume:1000 ]
  in
  assert_that
    (Liquidity_metric.dollar_adv ~aggregation:Liquidity_metric.Median
       ~lookback_days:4 bars)
    (is_some_and (float_equal 15_000.0))

let test_median_respects_lookback_truncation _ =
  (* Trailing 3 of the 60-bar spoof fixture: all honest, so median = $250k —
     and dropping the spike out of the window must not change that. *)
  assert_that
    (Liquidity_metric.dollar_adv ~aggregation:Liquidity_metric.Median
       ~lookback_days:3 spoof_bars)
    (is_some_and (float_equal honest_dollar_volume))

(* --- Trimmed mean -------------------------------------------------------- *)

let test_trim_pct_zero_degenerates_to_mean _ =
  assert_that
    (spoof_reading ~aggregation:Liquidity_metric.Trimmed_mean ~trim_pct:0.0 ())
    (is_some_and (float_equal spoof_mean))

let test_trim_pct_nonfinite_trims_nothing _ =
  assert_that
    [
      spoof_reading ~aggregation:Liquidity_metric.Trimmed_mean
        ~trim_pct:Float.nan ();
      spoof_reading ~aggregation:Liquidity_metric.Trimmed_mean
        ~trim_pct:Float.infinity ();
      spoof_reading ~aggregation:Liquidity_metric.Trimmed_mean ~trim_pct:(-0.25)
        ();
    ]
    (elements_are
       [
         is_some_and (float_equal spoof_mean);
         is_some_and (float_equal spoof_mean);
         is_some_and (float_equal spoof_mean);
       ])

let test_trim_pct_at_half_degenerates_to_median _ =
  (* trim_pct >= 0.5 trims maximally: on the odd-length [5000; 10000; 20000]
     window that leaves the single central observation. *)
  assert_that
    (Liquidity_metric.dollar_adv ~aggregation:Liquidity_metric.Trimmed_mean
       ~trim_pct:0.6 ~lookback_days:3 bars_ascending)
    (is_some_and (float_equal 10_000.0))

let test_trim_always_leaves_one_observation _ =
  (* Two bars, aggressive trim: (n-1)/2 = 0, so nothing is trimmed and the
     reading is the mean of both rather than a division by zero. *)
  let bars =
    [
      make_bar_on "2024-01-02" ~close:5.0 ~volume:1000;
      make_bar_on "2024-01-03" ~close:20.0 ~volume:1000;
    ]
  in
  assert_that
    (Liquidity_metric.dollar_adv ~aggregation:Liquidity_metric.Trimmed_mean
       ~trim_pct:0.49 ~lookback_days:2 bars)
    (is_some_and (float_equal 12_500.0))

(* --- Degenerate inputs, for EVERY aggregation ----------------------------- *)

(* The contract [None] means "no liquidity reading", which every caller treats
   as "passes". A robust aggregation must not turn a missing reading into a
   spurious exit / drop, so [None] must survive unchanged. *)
let test_empty_bars_none_for_every_aggregation _ =
  assert_that
    (readings_for_each_aggregation ~lookback_days:20 [])
    (elements_are [ is_none; is_none; is_none ])

let test_nonpositive_lookback_none_for_every_aggregation _ =
  assert_that
    (readings_for_each_aggregation ~lookback_days:0 bars_uniform)
    (elements_are [ is_none; is_none; is_none ])

let test_single_bar_same_for_every_aggregation _ =
  assert_that
    (readings_for_each_aggregation ~lookback_days:20
       [ make_bar_on "2024-01-02" ~close:10.0 ~volume:1000 ])
    (elements_are
       [
         is_some_and (float_equal 10_000.0);
         is_some_and (float_equal 10_000.0);
         is_some_and (float_equal 10_000.0);
       ])

let test_zero_volume_reads_zero_for_every_aggregation _ =
  let bars =
    [
      make_bar_on "2024-01-02" ~close:10.0 ~volume:0;
      make_bar_on "2024-01-03" ~close:10.0 ~volume:0;
    ]
  in
  assert_that
    (readings_for_each_aggregation ~lookback_days:20 bars)
    (elements_are
       [
         is_some_and (float_equal 0.0);
         is_some_and (float_equal 0.0);
         is_some_and (float_equal 0.0);
       ])

let suite =
  "liquidity_metric"
  >::: [
         "uniform mean" >:: test_uniform_mean;
         "window takes trailing" >:: test_window_takes_trailing;
         "window longer than bars uses all"
         >:: test_window_longer_than_bars_uses_all;
         "empty bars -> none" >:: test_empty_bars_none;
         "nonpositive lookback -> none" >:: test_nonpositive_lookback_none;
         "spoof: mean clears entry floor" >:: test_spoof_mean_clears_entry_floor;
         "spoof: robust aggregations stay below floor"
         >:: test_spoof_robust_aggregations_stay_below_floor;
         "default aggregation is bit-identical to mean"
         >:: test_default_aggregation_is_bit_identical_to_mean;
         "config default aggregation is mean"
         >:: test_config_default_aggregation_is_mean;
         "median odd window" >:: test_median_odd_window;
         "median even window" >:: test_median_even_window;
         "median respects lookback truncation"
         >:: test_median_respects_lookback_truncation;
         "trim_pct 0 degenerates to mean"
         >:: test_trim_pct_zero_degenerates_to_mean;
         "trim_pct non-finite trims nothing"
         >:: test_trim_pct_nonfinite_trims_nothing;
         "trim_pct at half degenerates to median"
         >:: test_trim_pct_at_half_degenerates_to_median;
         "trim always leaves one observation"
         >:: test_trim_always_leaves_one_observation;
         "empty bars -> none for every aggregation"
         >:: test_empty_bars_none_for_every_aggregation;
         "nonpositive lookback -> none for every aggregation"
         >:: test_nonpositive_lookback_none_for_every_aggregation;
         "single bar same for every aggregation"
         >:: test_single_bar_same_for_every_aggregation;
         "zero volume reads zero for every aggregation"
         >:: test_zero_volume_reads_zero_for_every_aggregation;
       ]

let () = run_test_tt_main suite
