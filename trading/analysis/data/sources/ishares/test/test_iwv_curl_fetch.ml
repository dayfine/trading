open Core
open Async
open OUnit2
open Matchers
module Curl_fetch = Iwv_curl_fetch
module Lib = Fetch_iwv_history_lib

let _dummy_uri = Uri.of_string "https://example.invalid/iwv.csv"

(* ------------------------------------------------------------------------- *)
(* curl_args — pure argv construction                                        *)
(* ------------------------------------------------------------------------- *)

(* Pin the full curl argv in order. This catches accidental flag
   re-ordering, dropped flags, or a misplaced URI. The browser-header
   values are matched via [contains_substring] so a future tweak of
   the UA / Referer string doesn't force a brittle rebase. *)
let test_curl_args_full_argv_shape _ =
  let args =
    Curl_fetch.curl_args ~body_tempfile:"/tmp/iwv_body_abc.csv" _dummy_uri
  in
  assert_that args
    (elements_are
       [
         equal_to "-sS";
         equal_to "--http2";
         equal_to "--max-time";
         equal_to (Int.to_string Curl_fetch.curl_max_time_seconds);
         equal_to "-H";
         all_of
           [
             contains_substring "User-Agent: Mozilla/5.0";
             contains_substring "Chrome/120.0.0.0";
           ];
         equal_to "-H";
         contains_substring "Accept: text/csv";
         equal_to "-H";
         contains_substring "Accept-Language: en-US";
         equal_to "-H";
         contains_substring "Referer: https://www.ishares.com/";
         equal_to "-H";
         contains_substring "Sec-Fetch-Dest: empty";
         equal_to "-H";
         contains_substring "Sec-Fetch-Mode: cors";
         equal_to "-H";
         contains_substring "Sec-Fetch-Site: same-origin";
         equal_to "-H";
         all_of
           [
             contains_substring "sec-ch-ua:";
             contains_substring "Google Chrome";
             contains_substring "v=\"120\"";
           ];
         equal_to "-H";
         contains_substring "sec-ch-ua-mobile: ?0";
         equal_to "-H";
         contains_substring "sec-ch-ua-platform: \"macOS\"";
         equal_to "-o";
         equal_to "/tmp/iwv_body_abc.csv";
         equal_to "-w";
         equal_to "%{http_code}";
         equal_to "https://example.invalid/iwv.csv";
       ])

(* ------------------------------------------------------------------------- *)
(* classify_curl_output — pure classification                                *)
(* ------------------------------------------------------------------------- *)

let _output ~exit_status ~stdout ~stderr : Process.Output.t =
  { stdout; stderr; exit_status }

let test_classify_200_returns_ok_body _ =
  let output = _output ~exit_status:(Ok ()) ~stdout:"200" ~stderr:"" in
  let result =
    Curl_fetch.classify_curl_output ~uri:_dummy_uri ~body:"the-csv-body" output
  in
  assert_that result
    (matching ~msg:"Expected Ok_body"
       (function Lib.Ok_body s -> Some s | _ -> None)
       (equal_to "the-csv-body"))

(* Trailing newline on the http_code is normal curl output when
   stdout writers add it; the classifier must strip it before parsing. *)
let test_classify_200_strips_whitespace _ =
  let output = _output ~exit_status:(Ok ()) ~stdout:"200\n" ~stderr:"" in
  let result =
    Curl_fetch.classify_curl_output ~uri:_dummy_uri ~body:"payload" output
  in
  assert_that result
    (matching ~msg:"Expected Ok_body"
       (function Lib.Ok_body s -> Some s | _ -> None)
       (equal_to "payload"))

let test_classify_503_is_retryable _ =
  let output = _output ~exit_status:(Ok ()) ~stdout:"503" ~stderr:"" in
  let result =
    Curl_fetch.classify_curl_output ~uri:_dummy_uri ~body:"akamai html" output
  in
  assert_that result
    (matching ~msg:"Expected Retryable_error"
       (function Lib.Retryable_error m -> Some m | _ -> None)
       (all_of
          [ contains_substring "HTTP 503"; contains_substring "akamai html" ]))

let test_classify_429_is_retryable _ =
  let output = _output ~exit_status:(Ok ()) ~stdout:"429" ~stderr:"" in
  let result =
    Curl_fetch.classify_curl_output ~uri:_dummy_uri ~body:"rate-limit" output
  in
  assert_that result
    (matching ~msg:"Expected Retryable_error"
       (function Lib.Retryable_error m -> Some m | _ -> None)
       (contains_substring "HTTP 429"))

let test_classify_404_is_fatal _ =
  let output = _output ~exit_status:(Ok ()) ~stdout:"404" ~stderr:"" in
  let result =
    Curl_fetch.classify_curl_output ~uri:_dummy_uri ~body:"not found" output
  in
  assert_that result
    (matching ~msg:"Expected Fatal_error"
       (function Lib.Fatal_error m -> Some m | _ -> None)
       (contains_substring "HTTP 404"))

let test_classify_unparseable_http_code_is_fatal _ =
  let output = _output ~exit_status:(Ok ()) ~stdout:"???" ~stderr:"" in
  let result =
    Curl_fetch.classify_curl_output ~uri:_dummy_uri ~body:"" output
  in
  assert_that result
    (matching ~msg:"Expected Fatal_error"
       (function Lib.Fatal_error m -> Some m | _ -> None)
       (contains_substring "unparseable http_code"))

(* Curl exit codes the iShares scraper treats as transient (timeout,
   connect refused, DNS fail). 28 = operation timeout — the most
   common one on a slow Akamai response. *)
let test_classify_curl_exit_28_is_retryable _ =
  let output =
    _output
      ~exit_status:(Error (`Exit_non_zero 28))
      ~stdout:"" ~stderr:"operation timed out"
  in
  let result =
    Curl_fetch.classify_curl_output ~uri:_dummy_uri ~body:"" output
  in
  assert_that result
    (matching ~msg:"Expected Retryable_error"
       (function Lib.Retryable_error m -> Some m | _ -> None)
       (all_of
          [ contains_substring "curl exit 28"; contains_substring "timed out" ]))

let test_classify_curl_exit_7_is_retryable _ =
  let output =
    _output
      ~exit_status:(Error (`Exit_non_zero 7))
      ~stdout:"" ~stderr:"failed to connect"
  in
  let result =
    Curl_fetch.classify_curl_output ~uri:_dummy_uri ~body:"" output
  in
  assert_that result
    (matching ~msg:"Expected Retryable_error"
       (function Lib.Retryable_error m -> Some m | _ -> None)
       (contains_substring "curl exit 7"))

(* Exit codes outside the retryable allowlist are fatal — e.g. 22
   (server returned 4xx via [-f], not in use here) or 99 (a value
   curl will never emit; pinned here to lock the default-fatal
   branch). *)
let test_classify_curl_exit_99_is_fatal _ =
  let output =
    _output
      ~exit_status:(Error (`Exit_non_zero 99))
      ~stdout:"" ~stderr:"made-up failure"
  in
  let result =
    Curl_fetch.classify_curl_output ~uri:_dummy_uri ~body:"" output
  in
  assert_that result
    (matching ~msg:"Expected Fatal_error"
       (function Lib.Fatal_error m -> Some m | _ -> None)
       (contains_substring "curl exit 99"))

let test_classify_signal_is_fatal _ =
  let output =
    _output ~exit_status:(Error (`Signal Signal.term)) ~stdout:"" ~stderr:""
  in
  let result =
    Curl_fetch.classify_curl_output ~uri:_dummy_uri ~body:"" output
  in
  assert_that result
    (matching ~msg:"Expected Fatal_error"
       (function Lib.Fatal_error m -> Some m | _ -> None)
       (contains_substring "killed by signal"))

(* ------------------------------------------------------------------------- *)
(* attempt_fetch — DI'd curl runner, tempfile-lifecycle assertions           *)
(* ------------------------------------------------------------------------- *)

(* Stub curl runner that records the args it was passed and writes a
   scripted body to the [-o <path>] tempfile before returning a
   scripted [Process.Output.t]. This is the seam that lets us pin
   end-to-end behaviour (body read, classification, tempfile cleanup)
   without ever forking [curl]. *)
let _extract_o_path args =
  let rec loop = function
    | [] -> None
    | "-o" :: path :: _ -> Some path
    | _ :: rest -> loop rest
  in
  loop args

let _stub_runner_writing ~body_to_write ~output_to_return :
    Curl_fetch.curl_runner * string list ref * string list ref =
  let calls = ref [] in
  let observed_args = ref [] in
  let runner ~prog ~args =
    calls := prog :: !calls;
    observed_args := args;
    (match _extract_o_path args with
    | Some path ->
        Out_channel.with_file path ~f:(fun oc ->
            Out_channel.output_string oc body_to_write)
    | None -> ());
    Deferred.Or_error.return output_to_return
  in
  (runner, calls, observed_args)

let _block_on f = Async.Thread_safe.block_on_async_exn f

let test_attempt_fetch_returns_body_on_200 _ =
  let curl, calls, _args =
    _stub_runner_writing ~body_to_write:"col1,col2\na,b\n"
      ~output_to_return:(_output ~exit_status:(Ok ()) ~stdout:"200" ~stderr:"")
  in
  let result =
    _block_on (fun () -> Curl_fetch.attempt_fetch ~curl _dummy_uri)
  in
  assert_that result
    (matching ~msg:"Expected Ok_body"
       (function Lib.Ok_body s -> Some s | _ -> None)
       (equal_to "col1,col2\na,b\n"));
  (* Exactly one curl invocation; production prog name. *)
  assert_that !calls (elements_are [ equal_to Curl_fetch.curl_path ])

(* Tempfile lifecycle: after [attempt_fetch] returns, the [-o] path
   must no longer exist on disk. This guards against the leak that
   would silently accumulate /tmp/iwv_body_*.csv files over a
   ~3700-date backfill. *)
let test_attempt_fetch_cleans_up_tempfile _ =
  let curl, _calls, args_ref =
    _stub_runner_writing ~body_to_write:"body-x"
      ~output_to_return:(_output ~exit_status:(Ok ()) ~stdout:"200" ~stderr:"")
  in
  let (_ : Lib.fetch_attempt) =
    _block_on (fun () -> Curl_fetch.attempt_fetch ~curl _dummy_uri)
  in
  let tempfile_path = _extract_o_path !args_ref in
  let path =
    match tempfile_path with
    | Some p -> p
    | None -> assert_failure "stub runner did not see a -o argument"
  in
  assert_that (Sys_unix.file_exists_exn path) (equal_to false)

(* 503 path: curl exits 0 but emits "503" on stdout. Classifier maps
   to Retryable_error. *)
let test_attempt_fetch_503_is_retryable _ =
  let curl, _calls, _args =
    _stub_runner_writing ~body_to_write:"<html>akamai bot check</html>"
      ~output_to_return:(_output ~exit_status:(Ok ()) ~stdout:"503" ~stderr:"")
  in
  let result =
    _block_on (fun () -> Curl_fetch.attempt_fetch ~curl _dummy_uri)
  in
  assert_that result
    (matching ~msg:"Expected Retryable_error"
       (function Lib.Retryable_error m -> Some m | _ -> None)
       (contains_substring "HTTP 503"))

(* Process.create failure path: [Or_error.error] from the curl runner
   gets translated to [Retryable_error] (transient system condition,
   not a permanent endpoint failure). *)
let test_attempt_fetch_runner_error_is_retryable _ =
  let curl ~prog:_ ~args:_ =
    Deferred.return (Or_error.error_string "could not fork")
  in
  let result =
    _block_on (fun () -> Curl_fetch.attempt_fetch ~curl _dummy_uri)
  in
  assert_that result
    (matching ~msg:"Expected Retryable_error"
       (function Lib.Retryable_error m -> Some m | _ -> None)
       (contains_substring "process exec failed"))

let suite =
  "iwv_curl_fetch_test"
  >::: [
         "curl_args_full_argv_shape" >:: test_curl_args_full_argv_shape;
         "classify_200_returns_ok_body" >:: test_classify_200_returns_ok_body;
         "classify_200_strips_whitespace"
         >:: test_classify_200_strips_whitespace;
         "classify_503_is_retryable" >:: test_classify_503_is_retryable;
         "classify_429_is_retryable" >:: test_classify_429_is_retryable;
         "classify_404_is_fatal" >:: test_classify_404_is_fatal;
         "classify_unparseable_http_code_is_fatal"
         >:: test_classify_unparseable_http_code_is_fatal;
         "classify_curl_exit_28_is_retryable"
         >:: test_classify_curl_exit_28_is_retryable;
         "classify_curl_exit_7_is_retryable"
         >:: test_classify_curl_exit_7_is_retryable;
         "classify_curl_exit_99_is_fatal"
         >:: test_classify_curl_exit_99_is_fatal;
         "classify_signal_is_fatal" >:: test_classify_signal_is_fatal;
         "attempt_fetch_returns_body_on_200"
         >:: test_attempt_fetch_returns_body_on_200;
         "attempt_fetch_cleans_up_tempfile"
         >:: test_attempt_fetch_cleans_up_tempfile;
         "attempt_fetch_503_is_retryable"
         >:: test_attempt_fetch_503_is_retryable;
         "attempt_fetch_runner_error_is_retryable"
         >:: test_attempt_fetch_runner_error_is_retryable;
       ]

let () = run_test_tt_main suite
