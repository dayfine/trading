open Core
open OUnit2
open Matchers
open Weinstein_trading_state
open Weinstein_types
open Trading_portfolio.Portfolio

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

(* ------------------------------------------------------------------ *)
(* empty                                                                *)
(* ------------------------------------------------------------------ *)

let test_empty_initial_cash _ctx =
  let state = empty ~initial_cash:10000.0 in
  assert_that state.portfolio.current_cash (float_equal 10000.0)

let test_empty_no_positions _ctx =
  let state = empty ~initial_cash:5000.0 in
  assert_that state.portfolio.positions (size_is 0)

let test_empty_no_stops _ctx =
  let state = empty ~initial_cash:1000.0 in
  assert_that state.stop_states (size_is 0)

let test_empty_no_prior_stages _ctx =
  let state = empty ~initial_cash:1000.0 in
  assert_that state.prior_stages (size_is 0)

let test_empty_no_trade_log _ctx =
  let state = empty ~initial_cash:1000.0 in
  assert_that state.trade_log (size_is 0)

let test_empty_no_scan_date _ctx =
  let state = empty ~initial_cash:1000.0 in
  assert_that state.last_scan_date is_none

(* ------------------------------------------------------------------ *)
(* add_log_entry                                                        *)
(* ------------------------------------------------------------------ *)

let test_add_log_entry_appends _ctx =
  let state = empty ~initial_cash:1000.0 in
  let entry =
    make_entry ~ticker:"AAPL" ~action:`Buy ~shares:10 ~price:150.0 ()
  in
  let state' = add_log_entry state entry in
  assert_that state'.trade_log (size_is 1)

let test_add_log_entry_preserves_order _ctx =
  let state = empty ~initial_cash:1000.0 in
  let e1 = make_entry ~ticker:"AAPL" ~action:`Buy ~shares:10 ~price:150.0 () in
  let e2 = make_entry ~ticker:"TSLA" ~action:`Sell ~shares:5 ~price:200.0 () in
  let state' = add_log_entry (add_log_entry state e1) e2 in
  assert_that state'.trade_log
    (elements_are
       [
         (fun e -> assert_that e.ticker (equal_to "AAPL"));
         (fun e -> assert_that e.ticker (equal_to "TSLA"));
       ])

let test_add_log_entry_does_not_mutate_original _ctx =
  let state = empty ~initial_cash:1000.0 in
  let entry =
    make_entry ~ticker:"AAPL" ~action:`Buy ~shares:10 ~price:150.0 ()
  in
  let _state' = add_log_entry state entry in
  assert_that state.trade_log (size_is 0)

(* ------------------------------------------------------------------ *)
(* set/get/remove_stop_state                                            *)
(* ------------------------------------------------------------------ *)

let test_set_and_get_stop_state _ctx =
  let state = empty ~initial_cash:1000.0 in
  let state' = set_stop_state state ~ticker:"AAPL" a_stop_state in
  let result = get_stop_state state' ~ticker:"AAPL" in
  assert_that result
    (is_some_and (fun ss ->
         match ss with
         | Weinstein_stops.Initial { stop_level; _ } ->
             assert_that stop_level (float_equal 46.0)
         | _ -> OUnit2.assert_failure "Expected Initial stop_state"))

let test_get_stop_state_missing _ctx =
  let state = empty ~initial_cash:1000.0 in
  assert_that (get_stop_state state ~ticker:"AAPL") is_none

let test_set_stop_state_overwrites _ctx =
  let state = empty ~initial_cash:1000.0 in
  let ss1 =
    Weinstein_stops.Initial { stop_level = 46.0; reference_level = 50.0 }
  in
  let ss2 =
    Weinstein_stops.Initial { stop_level = 55.0; reference_level = 60.0 }
  in
  let state' =
    set_stop_state (set_stop_state state ~ticker:"AAPL" ss1) ~ticker:"AAPL" ss2
  in
  assert_that
    (get_stop_state state' ~ticker:"AAPL")
    (is_some_and (fun ss ->
         match ss with
         | Weinstein_stops.Initial { stop_level; _ } ->
             assert_that stop_level (float_equal 55.0)
         | _ -> OUnit2.assert_failure "Expected Initial stop_state"))

let test_remove_stop_state _ctx =
  let state = empty ~initial_cash:1000.0 in
  let state' = set_stop_state state ~ticker:"AAPL" a_stop_state in
  let state'' = remove_stop_state state' ~ticker:"AAPL" in
  assert_that (get_stop_state state'' ~ticker:"AAPL") is_none

let test_remove_nonexistent_stop_state_is_noop _ctx =
  let state = empty ~initial_cash:1000.0 in
  let state' = remove_stop_state state ~ticker:"MISSING" in
  assert_that state'.stop_states (size_is 0)

let test_stop_states_independent _ctx =
  let state = empty ~initial_cash:1000.0 in
  let ss_aapl =
    Weinstein_stops.Initial { stop_level = 46.0; reference_level = 50.0 }
  in
  let ss_tsla =
    Weinstein_stops.Initial { stop_level = 184.0; reference_level = 200.0 }
  in
  let state' =
    set_stop_state
      (set_stop_state state ~ticker:"AAPL" ss_aapl)
      ~ticker:"TSLA" ss_tsla
  in
  assert_that state'.stop_states (size_is 2);
  let state'' = remove_stop_state state' ~ticker:"AAPL" in
  assert_that
    (get_stop_state state'' ~ticker:"TSLA")
    (is_some_and (fun _ -> ()))

(* ------------------------------------------------------------------ *)
(* set/get_prior_stage                                                  *)
(* ------------------------------------------------------------------ *)

let test_set_and_get_prior_stage _ctx =
  let state = empty ~initial_cash:1000.0 in
  let stage = Stage2 { weeks_advancing = 3; late = false } in
  let state' = set_prior_stage state ~ticker:"AAPL" stage in
  let result = get_prior_stage state' ~ticker:"AAPL" in
  assert_that result
    (is_some_and (fun s ->
         match s with
         | Stage2 { weeks_advancing = 3; late = false } -> ()
         | other ->
             OUnit2.assert_failure
               (Printf.sprintf "Unexpected stage: %s" (show_stage other))))

let test_get_prior_stage_missing _ctx =
  let state = empty ~initial_cash:1000.0 in
  assert_that (get_prior_stage state ~ticker:"NEW") is_none

let test_set_prior_stage_overwrites _ctx =
  let state = empty ~initial_cash:1000.0 in
  let s1 = Stage1 { weeks_in_base = 5 } in
  let s2 = Stage2 { weeks_advancing = 1; late = false } in
  let state' =
    set_prior_stage (set_prior_stage state ~ticker:"AAPL" s1) ~ticker:"AAPL" s2
  in
  assert_that
    (get_prior_stage state' ~ticker:"AAPL")
    (is_some_and (fun s ->
         match s with
         | Stage2 _ -> ()
         | other ->
             OUnit2.assert_failure
               (Printf.sprintf "Expected Stage2, got %s" (show_stage other))))

(* ------------------------------------------------------------------ *)
(* save / load round-trip                                               *)
(* ------------------------------------------------------------------ *)

let test_save_and_load_empty_state _ctx =
  let state = empty ~initial_cash:5000.0 in
  let path = Core_unix.mkstemp "trading_state_test" |> fst in
  (match save state ~path with
  | Ok () -> ()
  | Error e -> OUnit2.assert_failure ("save failed: " ^ Status.show e));
  (match load ~path with
  | Ok loaded ->
      assert_that loaded.portfolio.current_cash (float_equal 5000.0);
      assert_that loaded.stop_states (size_is 0);
      assert_that loaded.trade_log (size_is 0);
      assert_that loaded.last_scan_date is_none
  | Error e -> OUnit2.assert_failure ("load failed: " ^ Status.show e));
  Core_unix.unlink path

let test_save_and_load_with_prior_stages _ctx =
  let state = empty ~initial_cash:1000.0 in
  let state' =
    set_prior_stage state ~ticker:"AAPL"
      (Stage2 { weeks_advancing = 4; late = false })
  in
  let state'' =
    set_prior_stage state' ~ticker:"TSLA" (Stage1 { weeks_in_base = 8 })
  in
  let path = Core_unix.mkstemp "trading_state_test" |> fst in
  (match save state'' ~path with
  | Ok () -> ()
  | Error e -> OUnit2.assert_failure ("save failed: " ^ Status.show e));
  (match load ~path with
  | Ok loaded ->
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
                      (show_stage other))))
  | Error e -> OUnit2.assert_failure ("load failed: " ^ Status.show e));
  Core_unix.unlink path

let test_save_and_load_with_trade_log _ctx =
  let state = empty ~initial_cash:1000.0 in
  let entry =
    make_entry ~ticker:"AAPL" ~action:`Buy ~shares:10 ~price:155.0
      ~grade:(Some A) ~reason:"stage2 breakout" ()
  in
  let state' = add_log_entry state entry in
  let path = Core_unix.mkstemp "trading_state_test" |> fst in
  (match save state' ~path with
  | Ok () -> ()
  | Error e -> OUnit2.assert_failure ("save failed: " ^ Status.show e));
  (match load ~path with
  | Ok loaded ->
      assert_that loaded.trade_log
        (elements_are
           [
             (fun e ->
               assert_that e.ticker (equal_to "AAPL");
               assert_that e.shares (equal_to 10);
               assert_that e.price (float_equal 155.0));
           ])
  | Error e -> OUnit2.assert_failure ("load failed: " ^ Status.show e));
  Core_unix.unlink path

let test_save_and_load_with_last_scan_date _ctx =
  let state = empty ~initial_cash:1000.0 in
  let state' =
    { state with last_scan_date = Some (Date.of_string "2024-03-15") }
  in
  let path = Core_unix.mkstemp "trading_state_test" |> fst in
  (match save state' ~path with
  | Ok () -> ()
  | Error e -> OUnit2.assert_failure ("save failed: " ^ Status.show e));
  (match load ~path with
  | Ok loaded ->
      assert_that loaded.last_scan_date
        (is_some_and (fun d ->
             assert_that (Date.to_string d) (equal_to "2024-03-15")))
  | Error e -> OUnit2.assert_failure ("load failed: " ^ Status.show e));
  Core_unix.unlink path

let test_load_nonexistent_file_returns_error _ctx =
  let result = load ~path:"/tmp/no_such_file_trading_state.json" in
  assert_that result is_error

let test_save_to_invalid_path_returns_error _ctx =
  let state = empty ~initial_cash:1000.0 in
  let result = save state ~path:"/no_such_dir/state.json" in
  assert_that result is_error

(* ------------------------------------------------------------------ *)
(* stop_states not restored from JSON (by design)                       *)
(* ------------------------------------------------------------------ *)

let test_stop_states_not_restored_from_json _ctx =
  (* Stop states are intentionally not round-tripped through JSON.
     The serialised string is kept for human inspection, but on load
     stop states are rebuilt from bar history. *)
  let state = empty ~initial_cash:1000.0 in
  let state' = set_stop_state state ~ticker:"AAPL" a_stop_state in
  let path = Core_unix.mkstemp "trading_state_test" |> fst in
  (match save state' ~path with
  | Ok () -> ()
  | Error e -> OUnit2.assert_failure ("save failed: " ^ Status.show e));
  (match load ~path with
  | Ok loaded ->
      (* Stop states are NOT restored — this is by design *)
      assert_that (get_stop_state loaded ~ticker:"AAPL") is_none
  | Error e -> OUnit2.assert_failure ("load failed: " ^ Status.show e));
  Core_unix.unlink path

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "weinstein_trading_state"
  >::: [
         "empty_initial_cash" >:: test_empty_initial_cash;
         "empty_no_positions" >:: test_empty_no_positions;
         "empty_no_stops" >:: test_empty_no_stops;
         "empty_no_prior_stages" >:: test_empty_no_prior_stages;
         "empty_no_trade_log" >:: test_empty_no_trade_log;
         "empty_no_scan_date" >:: test_empty_no_scan_date;
         "add_log_entry_appends" >:: test_add_log_entry_appends;
         "add_log_entry_preserves_order" >:: test_add_log_entry_preserves_order;
         "add_log_entry_does_not_mutate_original"
         >:: test_add_log_entry_does_not_mutate_original;
         "set_and_get_stop_state" >:: test_set_and_get_stop_state;
         "get_stop_state_missing" >:: test_get_stop_state_missing;
         "set_stop_state_overwrites" >:: test_set_stop_state_overwrites;
         "remove_stop_state" >:: test_remove_stop_state;
         "remove_nonexistent_stop_state_is_noop"
         >:: test_remove_nonexistent_stop_state_is_noop;
         "stop_states_independent" >:: test_stop_states_independent;
         "set_and_get_prior_stage" >:: test_set_and_get_prior_stage;
         "get_prior_stage_missing" >:: test_get_prior_stage_missing;
         "set_prior_stage_overwrites" >:: test_set_prior_stage_overwrites;
         "save_and_load_empty_state" >:: test_save_and_load_empty_state;
         "save_and_load_with_prior_stages"
         >:: test_save_and_load_with_prior_stages;
         "save_and_load_with_trade_log" >:: test_save_and_load_with_trade_log;
         "save_and_load_with_last_scan_date"
         >:: test_save_and_load_with_last_scan_date;
         "load_nonexistent_file_returns_error"
         >:: test_load_nonexistent_file_returns_error;
         "save_to_invalid_path_returns_error"
         >:: test_save_to_invalid_path_returns_error;
         "stop_states_not_restored_from_json"
         >:: test_stop_states_not_restored_from_json;
       ]

let () = run_test_tt_main suite
