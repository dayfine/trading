(** Split-corpus self-consistency (issue #2973).

    Every other suite in this directory trusts [meta.sexp]; this one earns that
    trust from the bars themselves:

    - the corpus holds exactly the pinned entries (a dropped or renamed window
      fails here rather than silently shrinking every consumer column);
    - the production split detector ({!Types.Split_detector.detect_split}), run
      over every consecutive bar pair, finds exactly the meta's splits — same
      ex-dates, same ratios — and nothing else (no dividend false positive
      inside any window);
    - each meta factor matches the bars' own [adjusted_close /. close] on either
      side of the ex-date, and the meta is internally consistent
      ([factor_after /. factor_before = ratio]);
    - the meta's [shape] and [symbol] agree with its splits and its name. *)

open OUnit2
open Core
open Matchers

let _expected_entries =
  [
    "AAPL-2014-06-09";
    "AAPL-2020-08-31";
    "C-1996-05-28";
    "GE-2021-08-02";
    "NVDA-2021-07-20";
    "NVDA-2024-06-10";
    "TSLA-2020-08-31";
  ]

(* Relative tolerance for a meta factor vs the bars: meta.sexp records six
   significant figures. *)
let _factor_rel_tol = 1e-4

(* The detector snaps to an exact rational; the meta writes 4/3 to ten
   decimal places. *)
let _ratio_tol = 1e-9

let _root () =
  match Split_corpus.find_root () with
  | Some root -> root
  | None -> assert_failure "trading/test_data/split_corpus not found above cwd"

let _load name = Split_corpus.load ~root:(_root ()) name

(** Every [(date, ratio)] the production detector finds over consecutive bars.
*)
let _detected_splits (bars : Types.Daily_price.t list) =
  List.zip_exn (List.drop_last_exn bars) (List.tl_exn bars)
  |> List.filter_map ~f:(fun ((prev : Types.Daily_price.t), curr) ->
      Option.map (Types.Split_detector.detect_split ~prev ~curr ())
        ~f:(fun ratio -> (curr.Types.Daily_price.date, ratio)))

let _bar_on bars date =
  List.find_exn bars ~f:(fun (b : Types.Daily_price.t) ->
      Date.equal b.date date)

let _bar_before bars date =
  List.last_exn
    (List.take_while bars ~f:(fun (b : Types.Daily_price.t) ->
         Date.( < ) b.date date))

(** [actual /. expected] for the two meta factors of [split] and for the meta's
    own [factor_after /. factor_before] against its [ratio] — each [1.0] when
    the meta is right. *)
let _factor_ratios bars (split : Split_corpus.split) =
  let factor d = Split_corpus.adjustment_factor d in
  ( factor (_bar_before bars split.ex_date) /. split.factor_before,
    factor (_bar_on bars split.ex_date) /. split.factor_after,
    split.factor_after /. split.factor_before /. split.ratio )

let _one = float_equal ~epsilon:_factor_rel_tol 1.0

let _shape_agrees (meta : Split_corpus.meta) =
  match (meta.shape, meta.splits) with
  | Split_corpus.Forward, [ s ] -> Float.( > ) s.Split_corpus.ratio 1.0
  | Split_corpus.Reverse, [ s ] -> Float.( < ) s.Split_corpus.ratio 1.0
  | Split_corpus.Two_in_window, [ _; _ ] -> true
  | (Split_corpus.Forward | Reverse | Two_in_window), _ -> false

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

let test_corpus_holds_the_pinned_entries _ =
  assert_that
    (Split_corpus.entry_names ~root:(_root ()))
    (equal_to _expected_entries)

let _test_detector_finds_exactly_the_meta_splits name _ =
  let entry : Split_corpus.entry = _load name in
  assert_that
    (_detected_splits entry.bars)
    (elements_are
       (List.map entry.meta.splits ~f:(fun (s : Split_corpus.split) ->
            all_of
              [
                field fst (equal_to s.ex_date);
                field snd (float_equal ~epsilon:_ratio_tol s.ratio);
              ])))

let _test_meta_factors_match_bars name _ =
  let entry : Split_corpus.entry = _load name in
  assert_that
    (List.map entry.meta.splits ~f:(_factor_ratios entry.bars))
    (each
       (all_of
          [
            field (fun (b, _, _) -> b) _one;
            field (fun (_, a, _) -> a) _one;
            field (fun (_, _, r) -> r) (float_equal ~epsilon:1e-3 1.0);
          ]))

let _test_meta_shape_and_symbol_agree name _ =
  let entry : Split_corpus.entry = _load name in
  assert_that entry.meta
    (all_of
       [
         field
           (fun (m : Split_corpus.meta) ->
             String.is_prefix name ~prefix:(m.symbol ^ "-"))
           (equal_to true);
         field _shape_agrees (equal_to true);
       ])

let _per_entry label test =
  List.map _expected_entries ~f:(fun name ->
      Printf.sprintf "%s/%s" label name >:: test name)

let suite =
  "split_corpus"
  >::: [
         "corpus_holds_the_pinned_entries"
         >:: test_corpus_holds_the_pinned_entries;
       ]
       @ _per_entry "detector_finds_exactly_the_meta_splits"
           _test_detector_finds_exactly_the_meta_splits
       @ _per_entry "meta_factors_match_bars" _test_meta_factors_match_bars
       @ _per_entry "meta_shape_and_symbol_agree"
           _test_meta_shape_and_symbol_agree

let () = run_test_tt_main suite
