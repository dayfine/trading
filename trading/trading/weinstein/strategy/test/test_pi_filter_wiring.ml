(** Tests for the screener point-in-time (PI) filter wiring in the Weinstein
    strategy.

    Pins the [Bar_reader.daily_bars_for] → [Daily_price.active_through] →
    [membership_at] callback path that [Weinstein_strategy_macro] hands to
    [Screener.screen_with_cooldown] when [config.enable_pi_filter = true].

    Authority: [dev/notes/historical-universe-membership-2026-04-30.md] §P5
    "screener point-in-time filter";
    [dev/notes/historical-universe-status- 2026-05-13.md] §1 phase 3 action item
    #2.

    Coverage spans:
    - the [None] / no-bars branches of [_pi_membership_at] (predicate-only),
    - the flag-driven callback factory,
    - end-to-end propagation of [active_through] through the
      [Bar_reader.of_in_memory_bars] → snapshot writer → manifest →
      [Snapshot_callbacks.active_through_for] →
      [Snapshot_bar_views.daily_bars_for] → [Bar_reader.daily_bars_for] path,
      including the rejection branch ([active_through = Some d] with
      [as_of > d]). The end-to-end coverage is what makes
      [enable_pi_filter = true] behaviourally distinct from
      [enable_pi_filter = false] on real backtests.

    Cross-reference: the screener-layer rejection branch is also pinned in
    [test_screener.ml]'s [test_pi_filter_excludes_delisted], which feeds the
    cascade an in-memory predicate directly without exercising the snapshot
    pipeline. *)

open OUnit2
open Core
open Matchers
module Bar_reader = Weinstein_strategy.Bar_reader
module Macro = Weinstein_strategy.Weinstein_strategy_macro
module Config = Weinstein_strategy.Weinstein_strategy_config

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

let _is_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat | Day_of_week.Sun -> false
  | _ -> true

let _weekdays_starting ~start ~n =
  let rec loop acc d remaining =
    if remaining = 0 then List.rev acc
    else if _is_weekday d then
      loop (d :: acc) (Date.add_days d 1) (remaining - 1)
    else loop acc (Date.add_days d 1) remaining
  in
  loop [] start n

let _make_bar ?(active_through = None) ~date ~price () : Types.Daily_price.t =
  {
    date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1_000_000;
    active_through;
  }

let _bars ?active_through ~n ~start_date ~start_price ~step () =
  let dates = _weekdays_starting ~start:start_date ~n in
  List.mapi dates ~f:(fun i d ->
      _make_bar ?active_through ~date:d
        ~price:(start_price +. (Float.of_int i *. step))
        ())

let _default_config () =
  Config.default_config ~universe:[ "AAPL"; "MSFT" ] ~index_symbol:"SPY"

(* ------------------------------------------------------------------ *)
(* pi_membership_at: branches reachable through the current pipeline   *)
(* ------------------------------------------------------------------ *)

(** No resident bars: predicate returns [true] — default to membership so the
    cascade's downstream phases (which themselves drop the symbol when its
    weekly view is empty) make the rejection decision uniformly. *)
let test_no_bars_admits _ =
  let bar_reader = Bar_reader.empty () in
  assert_that
    (Macro.Internal_for_test.pi_membership_at ~bar_reader "AAPL"
       (_ymd 2024 6 14))
    (equal_to true)

(** Bars with [active_through = None] (still trading): predicate returns [true]
    after the snapshot round-trip. Pins the bit-equality contract that PI-filter
    ON does not change which symbols are admitted purely on bar contents when no
    delisting marker is set. *)
let test_active_through_none_admits_through_snapshot _ =
  let bars =
    _bars ~n:10 ~start_date:(_ymd 2024 1 2) ~start_price:100.0 ~step:0.5 ()
  in
  let bar_reader = Bar_reader.of_in_memory_bars [ ("AAPL", bars) ] in
  assert_that
    (Macro.Internal_for_test.pi_membership_at ~bar_reader "AAPL"
       (_ymd 2024 6 14))
    (equal_to true)

(** End-to-end propagation: bars with [active_through = Some d] where
    [as_of <= d] still admit. Pins that the manifest's per-symbol
    [active_through] reaches the predicate through the snapshot pipeline. *)
let test_active_through_set_admits_within_window _ =
  let delisted_on = _ymd 2024 12 31 in
  let bars =
    _bars ~active_through:(Some delisted_on) ~n:10 ~start_date:(_ymd 2024 1 2)
      ~start_price:100.0 ~step:0.5 ()
  in
  let bar_reader = Bar_reader.of_in_memory_bars [ ("AAPL", bars) ] in
  assert_that
    (Macro.Internal_for_test.pi_membership_at ~bar_reader "AAPL"
       (_ymd 2024 6 14))
    (equal_to true)

(** End-to-end propagation, rejection branch: bars with
    [active_through = Some d] where [as_of > d] reject. This is the behavioural
    contract the P5 PI filter relies on; with [active_through] propagation in
    place a delisted symbol that loses index membership is excluded from
    screening even after its last bar. *)
let test_active_through_set_rejects_after_delisting _ =
  let delisted_on = _ymd 2024 3 31 in
  let bars =
    _bars ~active_through:(Some delisted_on) ~n:10 ~start_date:(_ymd 2024 1 2)
      ~start_price:100.0 ~step:0.5 ()
  in
  let bar_reader = Bar_reader.of_in_memory_bars [ ("AAPL", bars) ] in
  assert_that
    (Macro.Internal_for_test.pi_membership_at ~bar_reader "AAPL"
       (_ymd 2024 6 14))
    (equal_to false)

(* ------------------------------------------------------------------ *)
(* membership_at_callback_of: flag-driven wiring                       *)
(* ------------------------------------------------------------------ *)

(** Default config ([enable_pi_filter = false]): callback factory returns [None]
    — the screener's PI gate is a no-op and all baselines are preserved. *)
let test_callback_default_is_none _ =
  let config = _default_config () in
  let bar_reader = Bar_reader.empty () in
  assert_that
    (Macro.Internal_for_test.membership_at_callback_of ~config ~bar_reader)
    is_none

(** [enable_pi_filter = true] with no bars: callback factory returns [Some _],
    and the wrapped callback returns [true] on every symbol (the no-bars branch
    defaults to membership). This pins the "flag flip → seam open" half of the
    wiring; the as_of-vs-active_through semantics are covered by the
    screener-layer test. *)
let test_callback_enabled_returns_some _ =
  let config = { (_default_config ()) with enable_pi_filter = true } in
  let bar_reader = Bar_reader.empty () in
  assert_that
    (Macro.Internal_for_test.membership_at_callback_of ~config ~bar_reader)
    (is_some_and (field (fun c -> c "AAPL" (_ymd 2024 6 14)) (equal_to true)))

let suite =
  "pi_filter_wiring_tests"
  >::: [
         "test_no_bars_admits" >:: test_no_bars_admits;
         "test_active_through_none_admits_through_snapshot"
         >:: test_active_through_none_admits_through_snapshot;
         "test_active_through_set_admits_within_window"
         >:: test_active_through_set_admits_within_window;
         "test_active_through_set_rejects_after_delisting"
         >:: test_active_through_set_rejects_after_delisting;
         "test_callback_default_is_none" >:: test_callback_default_is_none;
         "test_callback_enabled_returns_some"
         >:: test_callback_enabled_returns_some;
       ]

let () = run_test_tt_main suite
