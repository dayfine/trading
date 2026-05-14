(** Tests for the screener point-in-time (PI) filter wiring in the Weinstein
    strategy.

    Pins the [Bar_reader.daily_bars_for] → [Daily_price.active_through] →
    [membership_at] callback path that [Weinstein_strategy_macro] hands to
    [Screener.screen_with_cooldown] when [config.enable_pi_filter = true].

    Authority: [dev/notes/historical-universe-membership-2026-04-30.md] §P5
    "screener point-in-time filter";
    [dev/notes/historical-universe-status- 2026-05-13.md] §1 phase 3 action item
    #2.

    {b Caveat — snapshot pipeline currently strips [active_through]}. The
    in-memory bar reader ({!Bar_reader.of_in_memory_bars}) round-trips bars
    through the snapshot-pipeline write/read path. The snapshot-runtime
    reconstitution
    ([Snapshot_runtime.Snapshot_bar_views_helpers._make_daily_price]) hard-
    codes [active_through = None] on every reconstituted row, so any
    [active_through] set on the input bars is dropped before reaching
    {!Bar_reader.daily_bars_for}'s consumers (this PR).

    That is the foundational P3 follow-up — propagating [active_through] through
    the snapshot pipeline — and is intentionally out of scope here. The tests
    below cover what can be exercised today: (a) the [None] / no-bars branches
    of the predicate, (b) the flag-driven callback factory. The rejection branch
    ([active_through = Some d] with [as_of > d]) is pinned at the {!Screener}
    layer by [test_pi_filter_excludes_delisted] in [test_screener.ml], which
    feeds the cascade an in-memory predicate directly. *)

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

let _make_bar ~date ~price : Types.Daily_price.t =
  {
    date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1_000_000;
    active_through = None;
  }

let _bars ~n ~start_date ~start_price ~step =
  let dates = _weekdays_starting ~start:start_date ~n in
  List.mapi dates ~f:(fun i d ->
      _make_bar ~date:d ~price:(start_price +. (Float.of_int i *. step)))

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

(** Most-recent bar's [active_through] reconstitutes to [None] under the current
    snapshot pipeline (P3 propagation not yet wired): predicate returns [true].
    Pins the bit-equality contract that PI-filter ON today does not change which
    symbols are admitted purely on bar contents — only the
    {!Daily_price.active_through} P3 follow-up activates the rejection branch.
*)
let test_active_through_currently_admits_through_snapshot _ =
  let bars =
    _bars ~n:10 ~start_date:(_ymd 2024 1 2) ~start_price:100.0 ~step:0.5
  in
  let bar_reader = Bar_reader.of_in_memory_bars [ ("AAPL", bars) ] in
  assert_that
    (Macro.Internal_for_test.pi_membership_at ~bar_reader "AAPL"
       (_ymd 2024 6 14))
    (equal_to true)

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
         "test_active_through_currently_admits_through_snapshot"
         >:: test_active_through_currently_admits_through_snapshot;
         "test_callback_default_is_none" >:: test_callback_default_is_none;
         "test_callback_enabled_returns_some"
         >:: test_callback_enabled_returns_some;
       ]

let () = run_test_tt_main suite
