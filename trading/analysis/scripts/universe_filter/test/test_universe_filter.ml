open Core
open OUnit2
open Matchers
module U = Universe_filter_lib

(* --- Helpers ------------------------------------------------------------- *)

let row symbol sector : U.row = { symbol; sector }
let cfg_of_string s = s |> Sexp.of_string |> U.config_of_sexp

(* --- filter tests -------------------------------------------------------- *)

let test_empty_config_is_noop _ctx =
  let cfg : U.config = { rules = [] } in
  let rows = [ row "AAPL" "Information Technology"; row "JPM" "Financials" ] in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field (fun r -> r.U.kept) (elements_are (List.map rows ~f:equal_to));
         field (fun r -> r.U.dropped) (elements_are []);
         field (fun r -> r.U.rule_stats) (elements_are []);
         field (fun r -> r.U.rescued_by_allowlist) (equal_to 0);
       ])

let test_symbol_pattern_drops_matches _ctx =
  let cfg : U.config =
    { rules = [ U.Symbol_pattern { name = "units"; pattern = "\\.U$" } ] }
  in
  let rows =
    [ row "AAPL" "IT"; row "FOO.U" "Financials"; row "BAR.U" "Financials" ]
  in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field (fun r -> r.U.kept) (elements_are [ equal_to (row "AAPL" "IT") ]);
         field
           (fun r -> r.U.dropped)
           (elements_are
              [
                equal_to (row "FOO.U" "Financials");
                equal_to (row "BAR.U" "Financials");
              ]);
         field
           (fun r -> r.U.rule_stats)
           (elements_are
              [
                equal_to ({ rule_name = "units"; drop_count = 2 } : U.rule_stat);
              ]);
         field (fun r -> r.U.rescued_by_allowlist) (equal_to 0);
       ])

let test_allowlist_rescues_match _ctx =
  (* The regex matches 'SPY', but the allow-list should preserve it.
     A different symbol 'ZZPY' that matches the same regex should still
     be dropped. *)
  let cfg : U.config =
    {
      rules =
        [
          U.Symbol_pattern { name = "ends_py"; pattern = "PY$" };
          U.Keep_allowlist { name = "broad"; symbols = [ "SPY" ] };
        ];
    }
  in
  let rows = [ row "SPY" "Financials"; row "ZZPY" "Financials" ] in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field
           (fun r -> r.U.kept)
           (elements_are [ equal_to (row "SPY" "Financials") ]);
         field
           (fun r -> r.U.dropped)
           (elements_are [ equal_to (row "ZZPY" "Financials") ]);
         field
           (fun r -> r.U.rule_stats)
           (elements_are
              [
                equal_to
                  ({ rule_name = "ends_py"; drop_count = 2 } : U.rule_stat);
              ]);
         field (fun r -> r.U.rescued_by_allowlist) (equal_to 1);
       ])

let test_multiple_rules_independent_counts _ctx =
  (* A row matching two patterns counts once in each rule's stat; the row
     is still dropped once (appears in `dropped` exactly once). *)
  let cfg : U.config =
    {
      rules =
        [
          U.Symbol_pattern { name = "ends_W"; pattern = "W$" };
          U.Symbol_pattern { name = "starts_A"; pattern = "^A" };
        ];
    }
  in
  (* AW matches both; AB matches starts_A; BW matches ends_W; ZZ matches neither. *)
  let rows = [ row "AW" ""; row "AB" ""; row "BW" ""; row "ZZ" "" ] in
  let result = U.filter cfg rows in
  assert_that result
    (all_of
       [
         field (fun r -> r.U.kept) (elements_are [ equal_to (row "ZZ" "") ]);
         field
           (fun r -> r.U.dropped)
           (elements_are
              [
                equal_to (row "AW" "");
                equal_to (row "AB" "");
                equal_to (row "BW" "");
              ]);
         field
           (fun r -> r.U.rule_stats)
           (elements_are
              [
                equal_to
                  ({ rule_name = "ends_W"; drop_count = 2 } : U.rule_stat);
                equal_to
                  ({ rule_name = "starts_A"; drop_count = 2 } : U.rule_stat);
              ]);
       ])

let test_stats_zero_for_nonmatching_rule _ctx =
  (* A rule that matches nothing still shows up with count 0, so the
     operator sees that the rule is present but inert. *)
  let cfg : U.config =
    { rules = [ U.Symbol_pattern { name = "inert"; pattern = "ZZZZ$" } ] }
  in
  let rows = [ row "AAPL" ""; row "MSFT" "" ] in
  let result = U.filter cfg rows in
  assert_that result
    (field
       (fun r -> r.U.rule_stats)
       (elements_are
          [ equal_to ({ rule_name = "inert"; drop_count = 0 } : U.rule_stat) ]))

(* --- load_config tests --------------------------------------------------- *)

let _write_tmp contents =
  let tmp = Stdlib.Filename.temp_file "universe_filter_test" ".sexp" in
  Stdlib.Out_channel.with_open_text tmp (fun oc ->
      Stdlib.Out_channel.output_string oc contents);
  tmp

(* load_config returns (config, string) Result.t — not Status.status_or — so
   we pattern-match instead of using is_ok_and_holds / is_error matchers. *)
let test_load_config_ok _ctx =
  let tmp =
    _write_tmp
      {|((rules (
  (Symbol_pattern (name "u") (pattern "\\.U$"))
  (Keep_allowlist (name "broad") (symbols (SPY QQQ))))))|}
  in
  let result = U.load_config tmp in
  Stdlib.Sys.remove tmp;
  match result with
  | Error e -> assert_failure ("expected Ok, got Error: " ^ e)
  | Ok cfg ->
      assert_that cfg (field (fun c -> List.length c.U.rules) (equal_to 2))

let test_load_config_missing_file _ctx =
  let result = U.load_config "/nonexistent/does-not-exist.sexp" in
  match result with
  | Ok _ -> assert_failure "expected Error for missing file, got Ok"
  | Error _ -> ()

let test_load_config_malformed _ctx =
  let tmp = _write_tmp "(this is (not a valid config))" in
  let result = U.load_config tmp in
  Stdlib.Sys.remove tmp;
  match result with
  | Ok _ -> assert_failure "expected Error for malformed sexp, got Ok"
  | Error _ -> ()

(* --- default.sexp smoke test --------------------------------------------- *)

(* The default sexp that ships under dev/config/universe_filter is not
   directly addressable from the test cwd, so we exercise its content by
   inlining the same shape. This guards against syntax drift in the
   shipped default. *)
let test_default_shape_parses _ctx =
  let sample =
    {|((rules (
        (Symbol_pattern (name "suffix_units_.U") (pattern "\\.U$"))
        (Keep_allowlist (name "broad") (symbols (SPY QQQ))))))|}
  in
  let cfg = cfg_of_string sample in
  assert_that cfg (field (fun c -> List.length c.U.rules) (equal_to 2))

(* --- CSV roundtrip ------------------------------------------------------- *)

let test_csv_roundtrip _ctx =
  let tmp_dir = Stdlib.Filename.temp_dir "universe_filter_csv" "" in
  let path = tmp_dir ^ "/test.csv" in
  let rows = [ row "AAPL" "IT"; row "JPM" "Financials" ] in
  (match U.write_csv path rows with
  | Ok () -> ()
  | Error e -> assert_failure ("write failed: " ^ e));
  let loaded =
    match U.read_csv path with
    | Ok r -> r
    | Error e -> assert_failure ("read failed: " ^ e)
  in
  Stdlib.Sys.remove path;
  Stdlib.Sys.rmdir tmp_dir;
  assert_that loaded (elements_are (List.map rows ~f:equal_to))

(* --- Test runner --------------------------------------------------------- *)

let () =
  run_test_tt_main
    ("universe_filter"
    >::: [
           "filter"
           >::: [
                  "empty config is no-op" >:: test_empty_config_is_noop;
                  "symbol pattern drops matches"
                  >:: test_symbol_pattern_drops_matches;
                  "allowlist rescues match" >:: test_allowlist_rescues_match;
                  "multiple rules independent counts"
                  >:: test_multiple_rules_independent_counts;
                  "stats show zero for nonmatching rule"
                  >:: test_stats_zero_for_nonmatching_rule;
                ];
           "load_config"
           >::: [
                  "parses valid file" >:: test_load_config_ok;
                  "missing file is error" >:: test_load_config_missing_file;
                  "malformed sexp is error" >:: test_load_config_malformed;
                  "default-sexp shape parses" >:: test_default_shape_parses;
                ];
           "csv_io" >::: [ "roundtrip" >:: test_csv_roundtrip ];
         ])
