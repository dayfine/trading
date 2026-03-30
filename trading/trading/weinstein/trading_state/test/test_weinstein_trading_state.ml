open Core
open OUnit2
open Matchers
open Weinstein_trading_state
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Test helpers                                                         *)
(* ------------------------------------------------------------------ *)

let make_entry ?(grade = None) ?(reason = "test") ~ticker ~action ~shares ~price
    () =
  {
    date = Date.of_string "2024-01-15";
    ticker;
    action;
    shares;
    price;
    grade;
    reason;
  }

let a_stop_state : Weinstein_stops.stop_state =
  Weinstein_stops.Initial { stop_level = 46.0; reference_level = 50.0 }

let with_tmp_path f =
  let path_str = Core_unix.mkstemp "trading_state_test" |> fst in
  let path = Fpath.v path_str in
  Fun.protect ~finally:(fun () -> Core_unix.unlink path_str) (fun () -> f path)

let save_exn state ~path =
  match save state ~path with
  | Ok () -> ()
  | Error e -> OUnit2.assert_failure ("save failed: " ^ Status.show e)

let load_exn ~path =
  match load ~path with
  | Ok state -> state
  | Error e -> OUnit2.assert_failure ("load failed: " ^ Status.show e)

(* ------------------------------------------------------------------ *)
(* empty                                                                *)
(* ------------------------------------------------------------------ *)

let test_empty _ctx =
  let state = empty ~initial_cash:10000.0 in
  assert_that state.portfolio.current_cash (float_equal 10000.0);
  assert_that state.portfolio.positions (size_is 0);
  assert_that state.stop_states (size_is 0);
  assert_that state.prior_stages (size_is 0);
  assert_that state.trade_log (size_is 0);
  assert_that state.last_scan_date is_none

(* ------------------------------------------------------------------ *)
(* save / load round-trips                                              *)
(* ------------------------------------------------------------------ *)

let test_save_and_load_empty_state _ctx =
  with_tmp_path (fun path ->
      save_exn (empty ~initial_cash:5000.0) ~path;
      let loaded = load_exn ~path in
      assert_that loaded.portfolio.current_cash (float_equal 5000.0);
      assert_that loaded.stop_states (size_is 0);
      assert_that loaded.trade_log (size_is 0);
      assert_that loaded.last_scan_date is_none)

let test_save_and_load_with_stop_states _ctx =
  with_tmp_path (fun path ->
      let state =
        set_stop_state (empty ~initial_cash:1000.0) ~ticker:"AAPL" a_stop_state
      in
      save_exn state ~path;
      let loaded = load_exn ~path in
      assert_that
        (get_stop_state loaded ~ticker:"AAPL")
        (is_some_and (fun ss ->
             match ss with
             | Weinstein_stops.Initial { stop_level; _ } ->
                 assert_that stop_level (float_equal 46.0)
             | _ -> OUnit2.assert_failure "Expected Initial stop_state")))

let test_save_and_load_with_prior_stages _ctx =
  with_tmp_path (fun path ->
      let state = empty ~initial_cash:1000.0 in
      let state =
        set_prior_stage state ~ticker:"AAPL"
          (Stage2 { weeks_advancing = 4; late = false })
      in
      let state =
        set_prior_stage state ~ticker:"TSLA" (Stage1 { weeks_in_base = 8 })
      in
      save_exn state ~path;
      let loaded = load_exn ~path in
      assert_that loaded.prior_stages (size_is 2);
      assert_that
        (get_prior_stage loaded ~ticker:"AAPL")
        (is_some_and (fun s ->
             match s with
             | Stage2 { weeks_advancing = 4; _ } -> ()
             | other ->
                 OUnit2.assert_failure
                   (Printf.sprintf "Expected Stage2(4), got %s"
                      (show_stage other))));
      assert_that
        (get_prior_stage loaded ~ticker:"TSLA")
        (is_some_and (fun s ->
             match s with
             | Stage1 { weeks_in_base = 8 } -> ()
             | other ->
                 OUnit2.assert_failure
                   (Printf.sprintf "Expected Stage1(8), got %s"
                      (show_stage other)))))

let test_save_and_load_with_trade_log _ctx =
  with_tmp_path (fun path ->
      let state =
        add_log_entry
          (empty ~initial_cash:1000.0)
          (make_entry ~ticker:"AAPL" ~action:`Buy ~shares:10 ~price:155.0
             ~grade:(Some A) ~reason:"stage2 breakout" ())
      in
      save_exn state ~path;
      let loaded = load_exn ~path in
      assert_that loaded.trade_log
        (elements_are
           [
             (fun e ->
               assert_that e.ticker (equal_to "AAPL");
               assert_that e.shares (equal_to 10);
               assert_that e.price (float_equal 155.0));
           ]))

let test_save_and_load_with_last_scan_date _ctx =
  with_tmp_path (fun path ->
      let state =
        {
          (empty ~initial_cash:1000.0) with
          last_scan_date = Some (Date.of_string "2024-03-15");
        }
      in
      save_exn state ~path;
      let loaded = load_exn ~path in
      assert_that loaded.last_scan_date
        (is_some_and (fun d ->
             assert_that (Date.to_string d) (equal_to "2024-03-15"))))

let test_load_nonexistent_file_returns_not_found _ctx =
  assert_that
    (load ~path:(Fpath.v "/tmp/no_such_file_trading_state.sexp"))
    (is_error_with Status.NotFound)

let test_save_to_invalid_path_returns_internal_error _ctx =
  assert_that
    (save
       (empty ~initial_cash:1000.0)
       ~path:(Fpath.v "/no_such_dir/state.sexp"))
    (is_error_with Status.Internal)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "weinstein_trading_state"
  >::: [
         "empty" >:: test_empty;
         "save_and_load_empty_state" >:: test_save_and_load_empty_state;
         "save_and_load_with_stop_states"
         >:: test_save_and_load_with_stop_states;
         "save_and_load_with_prior_stages"
         >:: test_save_and_load_with_prior_stages;
         "save_and_load_with_trade_log" >:: test_save_and_load_with_trade_log;
         "save_and_load_with_last_scan_date"
         >:: test_save_and_load_with_last_scan_date;
         "load_nonexistent_file_returns_not_found"
         >:: test_load_nonexistent_file_returns_not_found;
         "save_to_invalid_path_returns_internal_error"
         >:: test_save_to_invalid_path_returns_internal_error;
       ]

let () = run_test_tt_main suite
