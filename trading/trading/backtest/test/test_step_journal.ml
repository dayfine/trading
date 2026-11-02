(** [Backtest.Step_journal]: append-only step log with torn-tail tolerance
    (#3477 PR 5). *)

open OUnit2
open Core
open Matchers
module SJ = Backtest.Step_journal

let _step n : SJ.step_result =
  {
    date = Date.add_days (Date.of_string "2024-01-01") n;
    portfolio = Trading_simulation_types.Portfolio_summary.empty;
    portfolio_value = Float.of_int n;
    trades = [];
    orders_submitted = [];
    splits_applied = [];
    benchmark_return = None;
    had_market_bars = true;
  }

let _values =
  Result.map
    ~f:
      (List.map ~f:(fun (s : SJ.step_result) -> Float.to_int s.portfolio_value))

let _fresh_path () =
  Filename_unix.temp_file
    ~in_dir:(Filename.dirname (Filename_unix.temp_file "sj" ""))
    "journal" ".sexpl"

let _with_journal steps f =
  let path = _fresh_path () in
  Sys_unix.remove path;
  if not (List.is_empty steps) then SJ.append ~path steps;
  f path

let test_append_read_in_order _ =
  _with_journal
    [ _step 1 ]
    (fun path ->
      SJ.append ~path [ _step 2 ];
      assert_that
        (_values (SJ.read ~path ~n_steps:2))
        (is_ok_and_holds (equal_to [ 1; 2 ])))

let test_torn_tail_ignored _ =
  _with_journal
    [ _step 1; _step 2 ]
    (fun path ->
      Out_channel.with_file path ~append:true ~f:(fun oc ->
          Out_channel.output_string oc "((date 2024-");
      assert_that
        (_values (SJ.read ~path ~n_steps:2))
        (is_ok_and_holds (equal_to [ 1; 2 ])))

let test_truncate_then_append _ =
  _with_journal
    [ _step 1; _step 2; _step 3 ]
    (fun path ->
      let truncated = SJ.truncate ~path ~n_steps:2 in
      SJ.append ~path [ _step 9 ];
      assert_that
        (truncated, _values (SJ.read ~path ~n_steps:3))
        (all_of
           [
             field fst is_ok; field snd (is_ok_and_holds (equal_to [ 1; 2; 9 ]));
           ]))

let test_errors _ =
  let missing = _fresh_path () in
  Sys_unix.remove missing;
  let short =
    _with_journal
      [ _step 1 ]
      (fun path -> (SJ.read ~path ~n_steps:2, SJ.truncate ~path ~n_steps:2))
  in
  let corrupt =
    _with_journal
      [ _step 1 ]
      (fun path ->
        Out_channel.with_file path ~append:true ~f:(fun oc ->
            Out_channel.output_string oc "not a step\n");
        SJ.read ~path ~n_steps:2)
  in
  assert_that
    (SJ.read ~path:missing ~n_steps:1, short, corrupt)
    (all_of
       [
         field (fun (m, _, _) -> m) is_error;
         field (fun (_, (r, _), _) -> r) is_error;
         field (fun (_, (_, t), _) -> t) is_error;
         field
           (fun (_, _, c) ->
             match c with
             | Error (e : Status.t) ->
                 String.is_substring e.message ~substring:"line 2"
             | Ok _ -> false)
           (equal_to true);
       ])

let suite =
  "step_journal"
  >::: [
         "append_read_in_order" >:: test_append_read_in_order;
         "torn_tail_ignored" >:: test_torn_tail_ignored;
         "truncate_then_append" >:: test_truncate_then_append;
         "errors" >:: test_errors;
       ]

let () = run_test_tt_main suite
