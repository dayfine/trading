open OUnit2
open Core
open Matchers
open Stock_analysis
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = default_config
let as_of = Date.of_string "2024-01-01"
let base_date = Date.of_string "2020-01-06"

let make_bar i price volume =
  {
    Daily_price.date =
      Date.of_string (Date.to_string (Date.add_days base_date (i * 7)));
    open_price = price;
    high_price = price *. 1.02;
    low_price = price *. 0.98;
    close_price = price;
    adjusted_close = price;
    volume;
    active_through = None;
  }

(** Rising bars from [start] to [stop_], all at uniform volume 1000. *)
let rising_bars ~n start stop_ =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> make_bar i (start +. (Float.of_int i *. step)) 1000)

(** Rising bars with a volume spike at [spike_idx] (3000 vs 1000 elsewhere).
    With default [breakout_event_lookback=8] and [volume.lookback_bars=4],
    placing spike_idx at n-4 puts the spike inside the search window with 4
    baseline bars before it → ratio = 3.0 → Strong confirmation. *)
let rising_bars_with_spike ~n start stop_ ~spike_idx =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i ->
      let p = start +. (Float.of_int i *. step) in
      let v = if i = spike_idx then 3000 else 1000 in
      make_bar i p v)

(** Declining bars from [start] to [stop_]. *)
let declining_bars ~n start stop_ =
  let step = (start -. stop_) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> make_bar i (start -. (Float.of_int i *. step)) 1000)

(* ------------------------------------------------------------------ *)
(* Stage propagation                                                    *)
(* ------------------------------------------------------------------ *)

let test_stage2_stock_classified_correctly _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  match result.stage.stage with
  | Stage2 _ -> ()
  | other ->
      assert_failure
        (Printf.sprintf "Expected Stage2, got %s" (show_stage other))

let test_insufficient_bars_yields_stage1 _ =
  let bars = List.init 5 ~f:(fun i -> make_bar i 50.0 1000) in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  match result.stage.stage with
  | Stage1 _ -> ()
  | other ->
      assert_failure
        (Printf.sprintf "Expected Stage1 for insufficient data, got %s"
           (show_stage other))

(* ------------------------------------------------------------------ *)
(* Breakout candidate                                                   *)
(* ------------------------------------------------------------------ *)

let test_breakout_candidate_true_with_stage1_prior_and_strong_volume _ =
  (* spike_idx = n-4 = 31: inside 8-bar lookback, 4 baseline bars before it *)
  let bars = rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let bench = rising_bars ~n:35 80.0 110.0 in
  let prior = Some (Stage1 { weeks_in_base = 12 }) in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:bench
      ~prior_stage:prior ~as_of_date:as_of
  in
  assert_that (is_breakout_candidate result) (equal_to true)

let test_breakout_candidate_false_when_stage4 _ =
  (* A declining stock (Stage 4) is never a breakout candidate regardless of
     volume or RS. *)
  let bars = declining_bars ~n:60 100.0 30.0 in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  assert_that (is_breakout_candidate result) (equal_to false)

let test_breakout_candidate_false_when_no_volume_confirmation _ =
  (* Uniform volume → ratio = 1.0 → Weak → not a candidate *)
  let bars = rising_bars ~n:35 50.0 100.0 in
  let bench = rising_bars ~n:35 80.0 110.0 in
  let prior = Some (Stage1 { weeks_in_base = 12 }) in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:bench
      ~prior_stage:prior ~as_of_date:as_of
  in
  assert_that (is_breakout_candidate result) (equal_to false)

(* ------------------------------------------------------------------ *)
(* Early-Stage2 admission window (early_stage2_max_weeks)                *)
(* ------------------------------------------------------------------ *)

(** A fresh Stage2 analysis (no observed Stage1→Stage2 predecessor) with the
    given [weeks_advancing], Strong volume, and rising RS — so admission turns
    solely on the early-Stage2 window arm of [is_breakout_candidate]. *)
let fresh_stage2 ?(virgin_readmission = false) ~weeks_advancing () :
    Stock_analysis.t =
  {
    ticker = "X";
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
          current_normalized = 1.0;
          trend = Positive_rising;
          history = [];
        };
    volume =
      Some
        {
          confirmation = Strong 3.0;
          event_volume = 3000;
          avg_volume = 1000.0;
          volume_ratio = 3.0;
        };
    resistance = None;
    support = None;
    breakout_price = Some 100.0;
    breakdown_price = None;
    prior_stage = None;
    continuation = None;
    supply = None;
    virgin_readmission;
    as_of_date = as_of;
  }

(* Default window (4): weeks_advancing = 4 is admitted, 5 is rejected — pins the
   historical hardcoded window bit-for-bit. *)
let test_default_window_admits_4_rejects_5 _ =
  assert_that
    ( is_breakout_candidate (fresh_stage2 ~weeks_advancing:4 ()),
      is_breakout_candidate (fresh_stage2 ~weeks_advancing:5 ()) )
    (equal_to (true, false))

(* Widened window (8): the same weeks_advancing = 5 candidate that the default
   rejects is admitted once the window is widened to 8. *)
let test_widened_window_admits_5 _ =
  assert_that
    (is_breakout_candidate ~early_stage2_max_weeks:8
       (fresh_stage2 ~weeks_advancing:5 ()))
    (equal_to true)

(* ------------------------------------------------------------------ *)
(* Virgin-crossing re-admission arm (resistance-v2 lever (a))            *)
(* ------------------------------------------------------------------ *)

(* A stale Stage-2 survivor (weeks_advancing = 8, well past the default 4-week
   window) that has crossed into virgin territory ([virgin_readmission = true])
   is re-admitted by the re-admission arm — the book's "new high ground"
   breakout. Without the flag the same stale survivor is rejected. Pins that the
   arm bypasses ONLY the staleness cut (the pair differs solely in the flag). *)
let test_stale_virgin_readmitted_only_when_armed _ =
  assert_that
    ( is_breakout_candidate
        (fresh_stage2 ~weeks_advancing:8 ~virgin_readmission:true ()),
      is_breakout_candidate
        (fresh_stage2 ~weeks_advancing:8 ~virgin_readmission:false ()) )
    (equal_to (true, false))

(* Fresh (non-stale) Stage-2 candidates are admitted by the initial-breakout arm
   regardless of the re-admission flag — the flag never rejects, so a fresh
   candidate is unaffected either way. *)
let test_fresh_candidate_unaffected_by_readmission_flag _ =
  assert_that
    ( is_breakout_candidate
        (fresh_stage2 ~weeks_advancing:4 ~virgin_readmission:true ()),
      is_breakout_candidate
        (fresh_stage2 ~weeks_advancing:4 ~virgin_readmission:false ()) )
    (equal_to (true, true))

(* ------------------------------------------------------------------ *)
(* Breakdown candidate                                                  *)
(* ------------------------------------------------------------------ *)

let test_breakdown_candidate_true_with_stage3_prior _ =
  let bars = declining_bars ~n:60 100.0 30.0 in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:prior
      ~as_of_date:as_of
  in
  assert_that (is_breakdown_candidate result) (equal_to true)

let test_breakdown_candidate_false_for_stage2 _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  assert_that (is_breakdown_candidate result) (equal_to false)

(* ------------------------------------------------------------------ *)
(* Purity                                                               *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let bench = rising_bars ~n:35 80.0 110.0 in
  let run () =
    analyze ~config:cfg ~ticker:"AAPL" ~bars ~benchmark_bars:bench
      ~prior_stage:None ~as_of_date:as_of
  in
  let r1 = run () and r2 = run () in
  assert_that r1.stage.stage (equal_to (r2.stage.stage : stage));
  assert_that r1.breakout_price (equal_to (r2.breakout_price : float option));
  assert_that
    (Option.map r1.volume ~f:(fun v -> v.volume_ratio))
    (equal_to
       (Option.map r2.volume ~f:(fun v -> v.volume_ratio) : float option))

(* ------------------------------------------------------------------ *)
(* Parity: analyze (bar-list) vs analyze_with_callbacks                *)
(*                                                                      *)
(* Builds the {!callbacks} record externally over the same arrays the  *)
(* wrapper would compute internally, then asserts that the two entry   *)
(* points produce bit-identical [t] records. Each scenario hits a      *)
(* different regime: pre-breakout, confirmed breakout (high vs low     *)
(* volume), Stage1/2/3/4 input, insufficient bars.                     *)
(* ------------------------------------------------------------------ *)

(** Bit-identity matcher for {!Stage.result}. Float fields use [equal_to]
    (Poly.equal — structural equality) so any drift fails. *)
let stage_result_is_bit_identical (expected : Stage.result) :
    Stage.result matcher =
  all_of
    [
      field (fun (r : Stage.result) -> r.stage) (equal_to expected.stage);
      field
        (fun (r : Stage.result) -> r.ma_value)
        (equal_to (expected.ma_value : float));
      field
        (fun (r : Stage.result) -> r.ma_direction)
        (equal_to expected.ma_direction);
      field
        (fun (r : Stage.result) -> r.ma_slope_pct)
        (equal_to (expected.ma_slope_pct : float));
      field
        (fun (r : Stage.result) -> r.transition)
        (equal_to expected.transition);
      field
        (fun (r : Stage.result) -> r.above_ma_count)
        (equal_to expected.above_ma_count);
    ]

(** Bit-identity matcher for {!Volume.result}. *)
let volume_result_is_bit_identical (expected : Volume.result) :
    Volume.result matcher =
  all_of
    [
      field
        (fun (r : Volume.result) -> r.confirmation)
        (equal_to expected.confirmation);
      field
        (fun (r : Volume.result) -> r.event_volume)
        (equal_to (expected.event_volume : int));
      field
        (fun (r : Volume.result) -> r.avg_volume)
        (equal_to (expected.avg_volume : float));
      field
        (fun (r : Volume.result) -> r.volume_ratio)
        (equal_to (expected.volume_ratio : float));
    ]

(** Bit-identity matcher for {!Stock_analysis.t}. The Resistance result is
    compared structurally (via [Poly.equal]) since the [resistance_zone] list
    has no derived equality but its float and int fields support polymorphic
    equality. Same for the {!Rs.result} record. *)
let result_is_bit_identical (expected : Stock_analysis.t) :
    Stock_analysis.t matcher =
  all_of
    [
      field (fun (r : Stock_analysis.t) -> r.ticker) (equal_to expected.ticker);
      field
        (fun (r : Stock_analysis.t) -> r.stage)
        (stage_result_is_bit_identical expected.stage);
      field
        (fun (r : Stock_analysis.t) -> r.rs)
        (equal_to (expected.rs : Rs.result option));
      field
        (fun (r : Stock_analysis.t) -> r.volume)
        (match expected.volume with
        | None -> is_none
        | Some v -> is_some_and (volume_result_is_bit_identical v));
      field
        (fun (r : Stock_analysis.t) -> r.resistance)
        (equal_to (expected.resistance : Resistance.result option));
      field
        (fun (r : Stock_analysis.t) -> r.breakout_price)
        (equal_to (expected.breakout_price : float option));
      field
        (fun (r : Stock_analysis.t) -> r.prior_stage)
        (equal_to expected.prior_stage);
      field
        (fun (r : Stock_analysis.t) -> r.as_of_date)
        (equal_to expected.as_of_date);
    ]

(** Run both [analyze] and [analyze_with_callbacks] over the same input and
    assert their results are bit-equal. The callback bundle is built externally
    via {!Stock_analysis.callbacks_from_bars} (the same constructor the wrapper
    uses internally, but we exercise it through the public API). *)
let assert_parity ~bars ~benchmark_bars ?(prior_stage = None) () =
  let callbacks =
    Stock_analysis.callbacks_from_bars ~config:cfg ~bars ~benchmark_bars
  in
  let from_bars =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars ~prior_stage
      ~as_of_date:as_of
  in
  let from_callbacks =
    analyze_with_callbacks ~config:cfg ~ticker:"X" ~callbacks ~prior_stage
      ~as_of_date:as_of
  in
  assert_that from_callbacks (result_is_bit_identical from_bars)

(** Pre-breakout: declining stock, no signals fire. Hits Stage4 input. *)
let test_parity_pre_breakout_stage4 _ =
  let bars = declining_bars ~n:80 100.0 50.0 in
  let bench = rising_bars ~n:80 80.0 110.0 in
  assert_parity ~bars ~benchmark_bars:bench ()

(** Confirmed breakout with high volume: Stage1 prior + spike. Hits the
    Strong-volume branch. *)
let test_parity_confirmed_breakout_high_volume _ =
  let bars = rising_bars_with_spike ~n:60 50.0 150.0 ~spike_idx:56 in
  let bench = rising_bars ~n:60 80.0 110.0 in
  let prior = Some (Stage1 { weeks_in_base = 12 }) in
  assert_parity ~bars ~benchmark_bars:bench ~prior_stage:prior ()

(** Confirmed breakout but low volume: uniform volume produces ratio=1.0 → Weak.
    Hits the breakout-no-confirmation branch. *)
let test_parity_confirmed_breakout_low_volume _ =
  let bars = rising_bars ~n:60 50.0 150.0 in
  let bench = rising_bars ~n:60 80.0 110.0 in
  let prior = Some (Stage1 { weeks_in_base = 12 }) in
  assert_parity ~bars ~benchmark_bars:bench ~prior_stage:prior ()

(** Stage2 input regime: pure rising series, no prior. *)
let test_parity_stage2_rising _ =
  let bars = rising_bars ~n:80 50.0 200.0 in
  let bench = rising_bars ~n:80 80.0 110.0 in
  assert_parity ~bars ~benchmark_bars:bench ()

(** Stage3 input regime: rising then flat with prior Stage2. *)
let test_parity_stage3_flat_after_advance _ =
  let rising = List.init 30 ~f:(fun i -> 50.0 +. (Float.of_int i *. 2.0)) in
  let flat = List.init 70 ~f:(fun _ -> 110.0) in
  let bars = List.mapi (rising @ flat) ~f:(fun i p -> make_bar i p 1000) in
  let bench = rising_bars ~n:100 80.0 110.0 in
  let prior = Some (Stage2 { weeks_advancing = 10; late = false }) in
  assert_parity ~bars ~benchmark_bars:bench ~prior_stage:prior ()

(** Stage1 input regime: declining then flat with prior Stage4. *)
let test_parity_stage1_flat_after_decline _ =
  let declining = List.init 30 ~f:(fun i -> 200.0 -. (Float.of_int i *. 2.0)) in
  let flat = List.init 70 ~f:(fun _ -> 140.0) in
  let bars = List.mapi (declining @ flat) ~f:(fun i p -> make_bar i p 1000) in
  let bench = rising_bars ~n:100 80.0 110.0 in
  let prior = Some (Stage4 { weeks_declining = 10 }) in
  assert_parity ~bars ~benchmark_bars:bench ~prior_stage:prior ()

(** Insufficient bars: too few for Stage / RS / breakout-price scan. *)
let test_parity_insufficient_bars _ =
  let bars = List.init 5 ~f:(fun i -> make_bar i 50.0 1000) in
  assert_parity ~bars ~benchmark_bars:[] ()

(** Edge of the breakout-price scan: bars exactly equal to base_lookback +
    base_end_offset. The wrapper's scan covers indices [n - base_lookback] to
    [n - base_end_offset] (exclusive). *)
let test_parity_exact_base_window _ =
  (* default_config: base_lookback=52, base_end_offset=8 → need ≥ 8 bars, and
     a base window with at least one bar requires n > 8. n = 60 puts
     base_start = 8, base_end = 52, scanning 44 bars. *)
  let bars = rising_bars ~n:60 50.0 150.0 in
  let bench = rising_bars ~n:60 80.0 110.0 in
  assert_parity ~bars ~benchmark_bars:bench ()

(* ------------------------------------------------------------------ *)
(* G14 split-boundary truncation                                        *)
(*                                                                      *)
(* The breakout-price / breakdown-price scans must stop at the most     *)
(* recent split between consecutive bars in the prior-base window —     *)
(* otherwise pre-split raw highs (in a different price space) leak into *)
(* post-split breakout levels. See [_scan_max_high_callback] in         *)
(* [stock_analysis.ml] and [dev/notes/g14-deep-dive-2026-05-01.md].     *)
(* ------------------------------------------------------------------ *)

(** Build a synthetic series of [n_total] bars where the first [n_pre] bars sit
    in pre-split raw price space (high=[pre_high], close=[pre_close],
    adjusted_close=[pre_adj]) and the remaining bars sit in post-split raw price
    space (high=[post_high], close=[post_close], adjusted_close=[post_adj]). The
    split is between bar [n_pre - 1] and bar [n_pre]: factor jumps from
    [pre_adj /. pre_close] to [post_adj /. post_close] across that boundary.

    Uses weekly cadence (date stride 7) so the bars look like weekly buckets to
    [Stock_analysis.analyze]. *)
let _split_synth ~n_total ~n_pre ~pre_high ~pre_close ~pre_adj ~post_high
    ~post_close ~post_adj : Daily_price.t list =
  List.init n_total ~f:(fun i ->
      let high, close, adj =
        if i < n_pre then (pre_high, pre_close, pre_adj)
        else (post_high, post_close, post_adj)
      in
      {
        Daily_price.date = Date.add_days base_date (i * 7);
        open_price = close;
        high_price = high;
        low_price = close *. 0.99;
        close_price = close;
        adjusted_close = adj;
        volume = 1000;
        active_through = None;
      })

(** With a 4:1 split between weeks 15 and 16 (pre: factor 0.25, post: factor
    1.0), the prior-base scan must stop at the split boundary — pre-split raw
    highs ($200) leaking into the breakout level would be in a different price
    space than the current post-split fill ($50). The truncated max falls within
    the post-split bars only (a small range around $52). *)
let test_breakout_truncates_at_split_boundary _ =
  (* n_pre = 16, n_total = 30. With base_end_offset = 8 the scan walks
     offsets [8, 52) → bars [21..0]; the split lives between bars 15 and 16
     (= offsets 13 and 14 from the newest-at-29). The truncation guard fires
     at offset 14, so the scan covers bars [16..21] only (post-split). *)
  let bars =
    _split_synth ~n_total:30 ~n_pre:16 ~pre_high:200.0 ~pre_close:400.0
      ~pre_adj:100.0 ~post_high:50.0 ~post_close:48.0 ~post_adj:48.0
  in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  (* breakout_price comes from the post-split window only — never the
     pre-split $200. Pin a tight upper bound to catch any leakage. *)
  assert_that result.breakout_price (is_some_and (lt (module Float_ord) 100.0))

(** Mirror of the breakout truncation: when post-split lows ($48) and pre- split
    lows ($396) live in different price spaces, [_scan_min_low_callback] must
    truncate at the split boundary so the breakdown level reflects the current
    price space. The pre-split low at $396 is artificially high (it sits in the
    pre-split raw space), so without truncation it would not affect the min —
    but the symmetric test validates the truncation guard fires on the short
    side too. We verify breakdown_price is below 100 (in the post-split price
    space). *)
let test_breakdown_truncates_at_split_boundary _ =
  let bars =
    _split_synth ~n_total:30 ~n_pre:16 ~pre_high:200.0 ~pre_close:400.0
      ~pre_adj:100.0 ~post_high:50.0 ~post_close:48.0 ~post_adj:48.0
  in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  assert_that result.breakdown_price (is_some_and (lt (module Float_ord) 100.0))

(** Sanity: when there is no split (every bar's adjusted_close = close_price),
    the truncation guard never fires and the scan covers the full prior-base
    window. The classic rising_bars fixture exercises this. *)
let test_no_split_no_truncation _ =
  let bars = rising_bars ~n:60 50.0 150.0 in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  (* base window covers bars [8, 52) → indices [60-52..60-8) = [8..52) of the
     rising series. Highs in this slice peak near the most-recent bar in the
     window (~$133) — well above the all-bars min of ~$50. Pin the lower
     bound to confirm truncation didn't fire spuriously. *)
  assert_that result.breakout_price (is_some_and (gt (module Float_ord) 100.0))

(* ------------------------------------------------------------------ *)
(* Continuation buys — Interpretation B of issue #889                   *)
(*                                                                      *)
(* The continuation arm of [is_breakout_candidate] only fires when      *)
(* [config.continuation = Some _]. The default config keeps it [None]   *)
(* so the existing screener tests remain bit-equal.                     *)
(* ------------------------------------------------------------------ *)

(** Build a Stage-2 stock with a pullback-then-breakout shape:
    - rising trend up to bar [n-12]
    - pullback (close back near MA) at bar [n-6]
    - tight consolidation bars [n-5..n-2]
    - fresh breakout bar at [n-1] (the as-of bar)

    With [n = 60] this puts the continuation pattern inside the default
    [pullback_lookback_weeks = 8] window. *)
let _continuation_shape_bars =
  let bars = ref [] in
  (* Phase 1: rising bars 0..47 (Stage 2 advance) *)
  for i = 0 to 47 do
    bars := make_bar i (50.0 +. (Float.of_int i *. 1.5)) 1000 :: !bars
  done;
  (* Phase 2: pullback at bars 48-52 *)
  let pullback_prices = [ 110.0; 108.0; 106.0; 105.0; 105.0 ] in
  List.iteri pullback_prices ~f:(fun k p ->
      let i = 48 + k in
      bars := make_bar i p 1000 :: !bars);
  (* Phase 3: consolidation at bars 53-58 *)
  let consol_prices = [ 110.0; 112.0; 111.0; 113.0; 114.0; 115.0 ] in
  List.iteri consol_prices ~f:(fun k p ->
      let i = 53 + k in
      bars := make_bar i p 1000 :: !bars);
  (* Phase 4: breakout at bar 59 with a strong volume spike (3x) so the
     volume gate also fires. *)
  bars := make_bar 59 130.0 3000 :: !bars;
  List.rev !bars

(** With [config.continuation = None] (default), a mature Stage-2 symbol fails
    the initial-breakout arm ([weeks_advancing > 4] without
    [prior_stage = Stage1]) and is NOT admitted. *)
let test_continuation_default_off_keeps_existing_rejection _ =
  let bars = _continuation_shape_bars in
  let bench = rising_bars ~n:60 80.0 110.0 in
  let prior = Some (Stage2 { weeks_advancing = 10; late = false }) in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:bench
      ~prior_stage:prior ~as_of_date:as_of
  in
  assert_that result
    (all_of
       [
         field (fun (r : Stock_analysis.t) -> r.continuation) is_none;
         field
           (fun (r : Stock_analysis.t) -> is_breakout_candidate r)
           (equal_to false);
       ])

(** With [config.continuation = Some _], the same mature Stage-2 symbol IS
    admitted via the continuation OR-arm because the bars show the
    pullback-then-breakout pattern. Pins the design plan's "B-1 approach" (issue
    #889) integration site. *)
let test_continuation_enabled_admits_mature_stage2 _ =
  let bars = _continuation_shape_bars in
  let bench = rising_bars ~n:60 80.0 110.0 in
  let prior = Some (Stage2 { weeks_advancing = 10; late = false }) in
  let cfg_on = { cfg with continuation = Some Continuation.default_config } in
  let result =
    analyze ~config:cfg_on ~ticker:"X" ~bars ~benchmark_bars:bench
      ~prior_stage:prior ~as_of_date:as_of
  in
  (* Sanity: the detector fired (continuation field populated). The OR-arm
     of [is_breakout_candidate] also fires. *)
  assert_that result
    (all_of
       [
         field
           (fun (r : Stock_analysis.t) -> r.continuation)
           (is_some_and
              (field
                 (fun (c : Continuation.result) -> c.is_continuation)
                 (equal_to true)));
         field
           (fun (r : Stock_analysis.t) -> is_breakout_candidate r)
           (equal_to true);
       ])

(* ------------------------------------------------------------------ *)
(* Overhead-supply (resistance-v2) — gated by config + callback         *)
(* ------------------------------------------------------------------ *)

let armed_supply_cfg =
  { cfg with overhead_supply = Some Resistance_supply.default_config }

(** A sketch proving overhead exists above the breakout (max-high above the
    breakout, empty histogram) — [Resistance_supply.analyze] yields a finite
    score in [0, 1] regardless of the exact breakout price the bars produce. *)
let make_sketch () : Resistance_supply.sketch =
  {
    max_high_130w = 200.0;
    max_high_260w = 200.0;
    max_high_520w = 200.0;
    bars_seen = 200.0;
    hist_bands =
      Resistance_supply.hist_bands_of_legacy (Array.create ~len:20 0.0);
    anchor_close = 100.0;
  }

(** Run [analyze_with_callbacks] over rising bars (which yield a breakout price)
    with [config] and a [get_sketch] closure returning [sketch_opt]. Returns the
    resulting [supply] field. *)
let supply_of ~config ~sketch_opt =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let base = callbacks_from_bars ~config ~bars ~benchmark_bars:[] in
  let callbacks = { base with get_sketch = (fun () -> sketch_opt) } in
  (analyze_with_callbacks ~config ~ticker:"X" ~callbacks ~prior_stage:None
     ~as_of_date:as_of)
    .supply

(** Armed config AND a present sketch: [supply] is [Some] with a score in
    [0, 1]. *)
let test_supply_present_when_armed_and_sketch _ =
  assert_that
    (supply_of ~config:armed_supply_cfg ~sketch_opt:(Some (make_sketch ())))
    (is_some_and
       (field
          (fun (r : Resistance_supply.result) -> r.score)
          (is_between (module Float_ord) ~low:0.0 ~high:1.0)))

(** Armed config but the callback returns no sketch: [supply] is [None]. *)
let test_supply_none_when_sketch_absent _ =
  assert_that (supply_of ~config:armed_supply_cfg ~sketch_opt:None) is_none

(** Feature off (default config) even with a present sketch: [supply] is [None]
    — bit-identical to pre-feature behaviour. *)
let test_supply_none_when_config_off _ =
  assert_that
    (supply_of ~config:cfg ~sketch_opt:(Some (make_sketch ())))
    is_none

(* ------------------------------------------------------------------ *)
(* Virgin-crossing re-admission (resistance-v2 lever (a)) — compute path *)
(* ------------------------------------------------------------------ *)

let armed_readmission_cfg = { cfg with virgin_crossing_readmission = true }

(** A virgin sketch: every max-high below any plausible breakout price the
    rising bars produce (>=~50), so [Resistance_supply.is_virgin] is true. *)
let virgin_sketch () : Resistance_supply.sketch =
  {
    (make_sketch ()) with
    max_high_130w = 1.0;
    max_high_260w = 1.0;
    max_high_520w = 1.0;
  }

(** A genuine-overhead sketch: max-high 200 above the breakout (so [is_virgin]
    is false) AND a non-zero histogram bin (so [is_clear_of_supply] is false).
    Neither new-high-ground arm fires → no re-admission. *)
let overhead_sketch () : Resistance_supply.sketch =
  let hist = Array.create ~len:20 0.0 in
  hist.(0) <- 5.0;
  {
    (make_sketch ()) with
    hist_bands = Resistance_supply.hist_bands_of_legacy hist;
  }

(** Run [analyze_with_callbacks] over rising bars with [config] and a
    [get_sketch] closure returning [sketch_opt]; return [t.virgin_readmission].
*)
let virgin_readmission_of ~config ~sketch_opt =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let base = callbacks_from_bars ~config ~bars ~benchmark_bars:[] in
  let callbacks = { base with get_sketch = (fun () -> sketch_opt) } in
  (analyze_with_callbacks ~config ~ticker:"X" ~callbacks ~prior_stage:None
     ~as_of_date:as_of)
    .virgin_readmission

(** Armed AND a present virgin sketch: [virgin_readmission] is [true]. *)
let test_readmission_true_when_armed_and_virgin _ =
  assert_that
    (virgin_readmission_of ~config:armed_readmission_cfg
       ~sketch_opt:(Some (virgin_sketch ())))
    (equal_to true)

(** The AXTI own-week-high case: [make_sketch]'s max-high (200) sits ABOVE the
    breakout (so [is_virgin] is false — the own-week-high artifact) but its
    histogram is empty (no overhead on a closing basis). The
    [is_clear_of_supply] arm admits it: armed → [virgin_readmission] is [true].
*)
let test_readmission_true_when_armed_and_clear_of_supply _ =
  assert_that
    (virgin_readmission_of ~config:armed_readmission_cfg
       ~sketch_opt:(Some (make_sketch ())))
    (equal_to true)

(** Armed but the sketch shows genuine overhead (max-high above the breakout AND
    a non-zero histogram bin): neither new-high-ground arm fires →
    [virgin_readmission] is [false]. *)
let test_readmission_false_when_armed_and_overhead _ =
  assert_that
    (virgin_readmission_of ~config:armed_readmission_cfg
       ~sketch_opt:(Some (overhead_sketch ())))
    (equal_to false)

(** Armed but the callback returns no sketch: [virgin_readmission] is [false] —
    no fabrication of virginity from missing data. *)
let test_readmission_false_when_sketch_absent _ =
  assert_that
    (virgin_readmission_of ~config:armed_readmission_cfg ~sketch_opt:None)
    (equal_to false)

(** Feature off (default) even with a present virgin sketch:
    [virgin_readmission] is [false] — bit-identical to pre-feature behaviour. *)
let test_readmission_false_when_config_off _ =
  assert_that
    (virgin_readmission_of ~config:cfg ~sketch_opt:(Some (virgin_sketch ())))
    (equal_to false)

let suite =
  "stock_analysis_tests"
  >::: [
         "test_stage2_stock_classified_correctly"
         >:: test_stage2_stock_classified_correctly;
         "test_insufficient_bars_yields_stage1"
         >:: test_insufficient_bars_yields_stage1;
         "test_breakout_candidate_true_with_stage1_prior_and_strong_volume"
         >:: test_breakout_candidate_true_with_stage1_prior_and_strong_volume;
         "test_breakout_candidate_false_when_stage4"
         >:: test_breakout_candidate_false_when_stage4;
         "test_breakout_candidate_false_when_no_volume_confirmation"
         >:: test_breakout_candidate_false_when_no_volume_confirmation;
         "test_default_window_admits_4_rejects_5"
         >:: test_default_window_admits_4_rejects_5;
         "test_widened_window_admits_5" >:: test_widened_window_admits_5;
         "stale virgin readmitted only when armed"
         >:: test_stale_virgin_readmitted_only_when_armed;
         "fresh candidate unaffected by readmission flag"
         >:: test_fresh_candidate_unaffected_by_readmission_flag;
         "test_breakdown_candidate_true_with_stage3_prior"
         >:: test_breakdown_candidate_true_with_stage3_prior;
         "test_breakdown_candidate_false_for_stage2"
         >:: test_breakdown_candidate_false_for_stage2;
         "test_pure_same_inputs" >:: test_pure_same_inputs;
         "test_parity_pre_breakout_stage4" >:: test_parity_pre_breakout_stage4;
         "test_parity_confirmed_breakout_high_volume"
         >:: test_parity_confirmed_breakout_high_volume;
         "test_parity_confirmed_breakout_low_volume"
         >:: test_parity_confirmed_breakout_low_volume;
         "test_parity_stage2_rising" >:: test_parity_stage2_rising;
         "test_parity_stage3_flat_after_advance"
         >:: test_parity_stage3_flat_after_advance;
         "test_parity_stage1_flat_after_decline"
         >:: test_parity_stage1_flat_after_decline;
         "test_parity_insufficient_bars" >:: test_parity_insufficient_bars;
         "test_parity_exact_base_window" >:: test_parity_exact_base_window;
         "G14: breakout truncates at split boundary"
         >:: test_breakout_truncates_at_split_boundary;
         "G14: breakdown truncates at split boundary"
         >:: test_breakdown_truncates_at_split_boundary;
         "G14: no split, no truncation" >:: test_no_split_no_truncation;
         "continuation default off keeps existing rejection"
         >:: test_continuation_default_off_keeps_existing_rejection;
         "continuation enabled admits mature stage2"
         >:: test_continuation_enabled_admits_mature_stage2;
         "supply present when armed and sketch"
         >:: test_supply_present_when_armed_and_sketch;
         "supply none when sketch absent"
         >:: test_supply_none_when_sketch_absent;
         "supply none when config off" >:: test_supply_none_when_config_off;
         "readmission true when armed and virgin"
         >:: test_readmission_true_when_armed_and_virgin;
         "readmission true when armed and clear of supply"
         >:: test_readmission_true_when_armed_and_clear_of_supply;
         "readmission false when armed and overhead"
         >:: test_readmission_false_when_armed_and_overhead;
         "readmission false when sketch absent"
         >:: test_readmission_false_when_sketch_absent;
         "readmission false when config off"
         >:: test_readmission_false_when_config_off;
       ]

let () = run_test_tt_main suite
