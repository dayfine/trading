(** Unit tests for the #2672 stub-print tail guard,
    {!Snapshot_runtime.Stub_tail}.

    Pins the pure truncation rule against the four shapes the #2672 warehouse
    scan named, plus the memoized warehouse-backed resolver and the
    {!Snapshot_callbacks} wrapper the strategy reads through.

    The load-bearing contract is a pair of opposites: the {b STMP} shape (real
    bars to $329.61, then $0.045 / $0.04 / $0.03 to the end) is truncated, while
    a genuine crash that keeps printing is untouched — the guard removes bars
    nothing could have traded against, and no others. *)

open OUnit2
open Core
open Matchers
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Stub_tail = Snapshot_runtime.Stub_tail
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

(* The suggested paired-run ratio from the config docstring. *)
let _ratio = 0.05
let _start = Date.create_exn ~y:2021 ~m:Month.Sep ~d:1
let _day i = Date.add_days _start i

let _closes (xs : float list) : (Date.t * float) list =
  List.mapi xs ~f:(fun i c -> (_day i, c))

let _cutoff ?(ratio = _ratio) xs = Stub_tail.cutoff_date ~ratio (_closes xs)

(* --- Pure truncation: the four #2672 shapes -------------------------- *)

(** STMP: real bars, then a terminal run of penny prints. Truncated immediately
    after the last real close. *)
let test_stmp_tail_is_truncated _ =
  assert_that
    (_cutoff [ 320.0; 325.0; 329.61; 0.045; 0.04; 0.03 ])
    (is_some_and (equal_to (_day 2)))

(** CLE: months of interleaved ~$0.70 / ~$0.03 prints ending in a single [0.025]
    stub after a [0.68]. Only the final bar is dropped — the run cannot extend
    backwards, because [0.68] is not a stub against the ~$0.70 before it. *)
let test_cle_interleaved_drops_only_the_final_bar _ =
  assert_that
    (_cutoff [ 0.70; 0.03; 0.71; 0.03; 0.69; 0.03; 0.68; 0.025 ])
    (is_some_and (equal_to (_day 6)))

(** A real -60% one-day crash followed by more bars near the new level is left
    entirely alone: the terminal run's own maximum is nowhere near [ratio] of
    the pre-crash close. Truncating this would be a lookahead edge; not
    truncating it is the whole reason the rule keys on the run's maximum. *)
let test_real_crash_is_untouched _ =
  assert_that (_cutoff [ 100.0; 98.0; 40.0; 41.0; 39.5; 42.0 ]) is_none

(** A monotone decline that never reaches the ratio is not a stub tail. *)
let test_ordinary_decline_is_untouched _ =
  assert_that (_cutoff [ 100.0; 90.0; 80.0; 70.0; 60.0 ]) is_none

(* --- Pure truncation: the off switch + edges -------------------------- *)

(** Ratio [0.0] (the default) is the identity — the R1 contract. *)
let test_zero_ratio_is_identity _ =
  assert_that (_cutoff ~ratio:0.0 [ 329.61; 0.045; 0.04; 0.03 ]) is_none

(** A negative ratio is treated as off, not as an inverted test. *)
let test_negative_ratio_is_identity _ =
  assert_that (_cutoff ~ratio:(-1.0) [ 329.61; 0.045; 0.04; 0.03 ]) is_none

(** A series too short to have a reference bar cannot have a stub run. *)
let test_single_bar_series_is_untouched _ =
  assert_that (_cutoff [ 0.03 ]) is_none

(** [Float.nan] is the schema's "value unknown" sentinel; such rows are ignored
    when locating the run, so a NaN row does not break the reference lookup. *)
let test_nan_rows_are_ignored _ =
  assert_that
    (Stub_tail.cutoff_date ~ratio:_ratio
       [
         (_day 0, 320.0); (_day 1, Float.nan); (_day 2, 329.61); (_day 3, 0.03);
       ])
    (is_some_and (equal_to (_day 2)))

(* --- Pure truncation over bars --------------------------------------- *)

let _bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = 1_000;
    active_through = None;
  }

let _bars (xs : float list) =
  List.mapi xs ~f:(fun i close -> _bar ~date:(_day i) ~close)

(** [truncate] drops the STMP tail and keeps everything before it. *)
let test_truncate_drops_the_stmp_tail _ =
  assert_that
    (Stub_tail.truncate ~ratio:_ratio (_bars [ 320.0; 329.61; 0.045; 0.03 ]))
    (elements_are
       [
         field
           (fun (b : Types.Daily_price.t) -> b.close_price)
           (float_equal 320.0);
         field
           (fun (b : Types.Daily_price.t) -> b.close_price)
           (float_equal 329.61);
       ])

(** [truncate] at ratio [0.0] returns every bar. *)
let test_truncate_at_zero_ratio_keeps_every_bar _ =
  assert_that
    (Stub_tail.truncate ~ratio:0.0 (_bars [ 320.0; 329.61; 0.045; 0.03 ]))
    (size_is 4)

(* --- Warehouse-backed resolver + callbacks wrapper -------------------- *)

let _schema = Snapshot_schema.default

let _row ~symbol ~date ~close =
  let values =
    Array.map (Array.of_list _schema.fields) ~f:(fun field ->
        match field with
        | Snapshot_schema.Open | Snapshot_schema.High | Snapshot_schema.Low
        | Snapshot_schema.Close | Snapshot_schema.Adjusted_close ->
            close
        | Snapshot_schema.Volume -> 1_000.0
        | _ -> Float.nan)
  in
  match Snapshot.create ~schema:_schema ~symbol ~date ~values with
  | Ok r -> r
  | Error err -> assert_failure ("Snapshot.create: " ^ Status.show err)

(* One-symbol warehouse whose closes are [closes], dated from [_start]. *)
let _callbacks_over ~symbol ~closes =
  let dir = Filename_unix.temp_dir ~in_dir:"/tmp" "stub_tail_" "" in
  let rows =
    List.mapi closes ~f:(fun i c -> _row ~symbol ~date:(_day i) ~close:c)
  in
  let path = Filename.concat dir (symbol ^ ".snap") in
  (match Snapshot_format.write ~path rows with
  | Ok () -> ()
  | Error err -> assert_failure ("Snapshot_format.write: " ^ Status.show err));
  let entries =
    [
      ({
         symbol;
         path;
         byte_size = 0;
         payload_md5 = "ignored";
         csv_mtime = 0.0;
         active_through = None;
       }
        : Snapshot_manifest.file_metadata);
    ]
  in
  let manifest = Snapshot_manifest.create ~schema:_schema ~entries in
  match Daily_panels.create ~snapshot_dir:dir ~manifest ~max_cache_mb:1 with
  | Ok panels -> Snapshot_callbacks.of_daily_panels panels
  | Error err -> assert_failure ("Daily_panels.create: " ^ Status.show err)

let _stmp_closes = [ 320.0; 325.0; 329.61; 0.045; 0.04; 0.03 ]

(** The resolver reads the symbol's own close series out of the warehouse and
    lands on the same cutoff the pure function does. *)
let test_resolver_finds_the_cutoff _ =
  let cb = _callbacks_over ~symbol:"STMP" ~closes:_stmp_closes in
  assert_that
    (Stub_tail.cutoff_for
       (Stub_tail.of_callbacks ~ratio:_ratio cb)
       ~symbol:"STMP")
    (is_some_and (equal_to (_day 2)))

(** An unarmed resolver never reads and never truncates. *)
let test_unarmed_resolver_has_no_cutoff _ =
  let cb = _callbacks_over ~symbol:"STMP" ~closes:_stmp_closes in
  let t = Stub_tail.of_callbacks ~ratio:0.0 cb in
  assert_that (Stub_tail.is_armed t) (equal_to false);
  assert_that (Stub_tail.cutoff_for t ~symbol:"STMP") is_none

(** A symbol absent from the manifest resolves to "keep everything" rather than
    raising — the same fail-soft contract every other snapshot read has. *)
let test_unknown_symbol_has_no_cutoff _ =
  let cb = _callbacks_over ~symbol:"STMP" ~closes:_stmp_closes in
  assert_that
    (Stub_tail.cutoff_for
       (Stub_tail.of_callbacks ~ratio:_ratio cb)
       ~symbol:"NOPE")
    is_none

(** [wrap_callbacks] makes the strategy's history read stop at the last real
    bar: the three penny prints are gone, the three real closes remain. *)
let test_wrapped_history_stops_at_the_last_real_bar _ =
  let cb = _callbacks_over ~symbol:"STMP" ~closes:_stmp_closes in
  let wrapped =
    Stub_tail.wrap_callbacks (Stub_tail.of_callbacks ~ratio:_ratio cb) cb
  in
  assert_that
    (wrapped.read_field_history ~symbol:"STMP" ~from:(_day 0) ~until:(_day 5)
       ~field:Snapshot_schema.Close)
    (is_ok_and_holds
       (elements_are
          [
            field snd (float_equal 320.0);
            field snd (float_equal 325.0);
            field snd (float_equal 329.61);
          ]))

(** A point read inside the stub tail answers [Error NotFound] — the same answer
    an absent row gives, which {!Snapshot_bar_views} folds to "no bar". *)
let test_wrapped_point_read_in_the_tail_is_not_found _ =
  let cb = _callbacks_over ~symbol:"STMP" ~closes:_stmp_closes in
  let wrapped =
    Stub_tail.wrap_callbacks (Stub_tail.of_callbacks ~ratio:_ratio cb) cb
  in
  assert_that
    (wrapped.read_field ~symbol:"STMP" ~date:(_day 4)
       ~field:Snapshot_schema.Close)
    is_error

(** The same read before the cutoff is untouched. *)
let test_wrapped_point_read_before_the_tail_is_unchanged _ =
  let cb = _callbacks_over ~symbol:"STMP" ~closes:_stmp_closes in
  let wrapped =
    Stub_tail.wrap_callbacks (Stub_tail.of_callbacks ~ratio:_ratio cb) cb
  in
  assert_that
    (wrapped.read_field ~symbol:"STMP" ~date:(_day 2)
       ~field:Snapshot_schema.Close)
    (is_ok_and_holds (float_equal 329.61))

(** Unarmed, the wrapper hands back a reader that still sees every bar — the R1
    bit-identical default path. *)
let test_unarmed_wrapper_sees_every_bar _ =
  let cb = _callbacks_over ~symbol:"STMP" ~closes:_stmp_closes in
  let wrapped =
    Stub_tail.wrap_callbacks (Stub_tail.of_callbacks ~ratio:0.0 cb) cb
  in
  assert_that
    (wrapped.read_field_history ~symbol:"STMP" ~from:(_day 0) ~until:(_day 5)
       ~field:Snapshot_schema.Close)
    (is_ok_and_holds (size_is 6))

let () =
  run_test_tt_main
    ("Stub_tail"
    >::: [
           "STMP tail is truncated" >:: test_stmp_tail_is_truncated;
           "CLE interleaved drops only the final bar"
           >:: test_cle_interleaved_drops_only_the_final_bar;
           "a real crash is untouched" >:: test_real_crash_is_untouched;
           "an ordinary decline is untouched"
           >:: test_ordinary_decline_is_untouched;
           "ratio 0.0 is the identity" >:: test_zero_ratio_is_identity;
           "a negative ratio is the identity"
           >:: test_negative_ratio_is_identity;
           "a single-bar series is untouched"
           >:: test_single_bar_series_is_untouched;
           "NaN rows are ignored" >:: test_nan_rows_are_ignored;
           "truncate drops the STMP tail" >:: test_truncate_drops_the_stmp_tail;
           "truncate at ratio 0.0 keeps every bar"
           >:: test_truncate_at_zero_ratio_keeps_every_bar;
           "resolver finds the cutoff" >:: test_resolver_finds_the_cutoff;
           "unarmed resolver has no cutoff"
           >:: test_unarmed_resolver_has_no_cutoff;
           "unknown symbol has no cutoff" >:: test_unknown_symbol_has_no_cutoff;
           "wrapped history stops at the last real bar"
           >:: test_wrapped_history_stops_at_the_last_real_bar;
           "wrapped point read in the tail is NotFound"
           >:: test_wrapped_point_read_in_the_tail_is_not_found;
           "wrapped point read before the tail is unchanged"
           >:: test_wrapped_point_read_before_the_tail_is_unchanged;
           "unarmed wrapper sees every bar"
           >:: test_unarmed_wrapper_sees_every_bar;
         ])
