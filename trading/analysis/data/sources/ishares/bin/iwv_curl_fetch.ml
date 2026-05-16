open Core
open Async
module Lib = Fetch_iwv_history_lib

(* Browser-like header values for the curl invocation. iShares' Akamai
   WAF rejects the bare [Cohttp_async] UA with HTTP 503 ("AkamaiGHost");
   even after PR #1131 added these headers via [Cohttp.Header.of_list],
   the response body was an HTML bot-check page (HTTP/1.1 + OCaml TLS
   fingerprint). System curl with the same headers negotiates HTTP/2 +
   a real TLS stack and returns the genuine CSV.

   See [dev/notes/iwv-scrape-akamai-block-2026-05-16.md] §Option (c). *)
let _user_agent =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, \
   like Gecko) Chrome/120.0.0.0 Safari/537.36"

let _accept_header = "text/csv,application/csv,*/*;q=0.8"
let _accept_language_header = "en-US,en;q=0.9"

let _referer_header =
  "https://www.ishares.com/us/products/239714/ishares-russell-3000-etf"

(* Browser-fingerprint hint headers Chrome emits on every request. The
   ajax CSV endpoint is a same-origin XHR from the iShares product page,
   so the Sec-Fetch trio mirrors what a real browser would send. The
   sec-ch-ua client hints announce the brand list (Chrome 120 on macOS,
   non-mobile). 2026-05-16: PR #1137 (curl shell-out) was insufficient
   on both local and GHA runner egress IPs; this is the cheapest
   remaining probe before paying for a scraper-API.
   See [dev/notes/iwv-scrape-akamai-block-2026-05-16.md] §"Next options" #1. *)
let _sec_fetch_dest_header = "empty"
let _sec_fetch_mode_header = "cors"
let _sec_fetch_site_header = "same-origin"

let _sec_ch_ua_header =
  "\"Not_A Brand\";v=\"8\", \"Chromium\";v=\"120\", \"Google Chrome\";v=\"120\""

let _sec_ch_ua_mobile_header = "?0"
let _sec_ch_ua_platform_header = "\"macOS\""
let curl_path = "curl"
let curl_max_time_seconds = 30
let curl_retryable_exit_codes = [ 6; 7; 28; 35; 52; 56 ]

(* HTTP status codes that warrant retry. Mirrors PR #1131's
   [_is_retryable_status] semantics on the [Cohttp.Code.status]
   variant; integer form matches what curl emits via [-w]. *)
let _is_retryable_http_status = function
  | 503 | 429 | 502 | 504 -> true
  | _ -> false

let curl_args ~body_tempfile uri : string list =
  [
    "-sS";
    "--http2";
    "--max-time";
    Int.to_string curl_max_time_seconds;
    "-H";
    "User-Agent: " ^ _user_agent;
    "-H";
    "Accept: " ^ _accept_header;
    "-H";
    "Accept-Language: " ^ _accept_language_header;
    "-H";
    "Referer: " ^ _referer_header;
    "-H";
    "Sec-Fetch-Dest: " ^ _sec_fetch_dest_header;
    "-H";
    "Sec-Fetch-Mode: " ^ _sec_fetch_mode_header;
    "-H";
    "Sec-Fetch-Site: " ^ _sec_fetch_site_header;
    "-H";
    "sec-ch-ua: " ^ _sec_ch_ua_header;
    "-H";
    "sec-ch-ua-mobile: " ^ _sec_ch_ua_mobile_header;
    "-H";
    "sec-ch-ua-platform: " ^ _sec_ch_ua_platform_header;
    "-o";
    body_tempfile;
    "-w";
    "%{http_code}";
    Uri.to_string uri;
  ]

(* Classify a [Process.Output.t] (curl exit + stdout HTTP code +
   response body read from the tempfile) into the [Lib.fetch_attempt]
   retry vocabulary. Pure. *)
let _classify_zero_exit_output ~uri ~body ~stdout : Lib.fetch_attempt =
  let code_str = String.strip stdout in
  match Int.of_string_opt code_str with
  | None ->
      Lib.Fatal_error
        (Printf.sprintf "curl produced unparseable http_code %S for %s" code_str
           (Uri.to_string uri))
  | Some 200 -> Lib.Ok_body body
  | Some code when _is_retryable_http_status code ->
      Lib.Retryable_error
        (Printf.sprintf "HTTP %d for %s\n%s" code (Uri.to_string uri) body)
  | Some code ->
      Lib.Fatal_error
        (Printf.sprintf "HTTP %d for %s\n%s" code (Uri.to_string uri) body)

let classify_curl_output ~uri ~body (output : Process.Output.t) :
    Lib.fetch_attempt =
  match output.exit_status with
  | Ok () -> _classify_zero_exit_output ~uri ~body ~stdout:output.stdout
  | Error (`Exit_non_zero code) ->
      let stderr = String.strip output.stderr in
      let msg =
        Printf.sprintf "curl exit %d for %s\nstderr: %s" code
          (Uri.to_string uri) stderr
      in
      if List.mem curl_retryable_exit_codes code ~equal:Int.equal then
        Lib.Retryable_error msg
      else Lib.Fatal_error msg
  | Error (`Signal s) ->
      Lib.Fatal_error
        (Printf.sprintf "curl killed by signal %s for %s" (Signal.to_string s)
           (Uri.to_string uri))

type curl_runner =
  prog:string -> args:string list -> Process.Output.t Deferred.Or_error.t

let real_curl_runner : curl_runner =
 fun ~prog ~args ->
  Process.create ~prog ~args () >>=? fun proc ->
  Process.collect_output_and_wait proc >>| Or_error.return

(* Read [path] (returns "" if missing) and remove it. Used for both
   success and failure paths so a failed attempt leaves no debris. *)
let _read_and_remove path : string =
  let body =
    if Sys_unix.file_exists_exn path then In_channel.read_all path else ""
  in
  (try Sys_unix.remove path with _ -> ());
  body

let attempt_fetch ~(curl : curl_runner) uri : Lib.fetch_attempt Deferred.t =
  let body_tempfile =
    Filename_unix.temp_file ~in_dir:Filename.temp_dir_name "iwv_body" ".csv"
  in
  let args = curl_args ~body_tempfile uri in
  curl ~prog:curl_path ~args >>| fun result ->
  let body = _read_and_remove body_tempfile in
  match result with
  | Ok output -> classify_curl_output ~uri ~body output
  | Error err ->
      (* [Process.create] itself failed (e.g. could not fork / exec).
         Treat as retryable since it's typically transient. *)
      Lib.Retryable_error
        (Printf.sprintf "process exec failed for %s: %s" (Uri.to_string uri)
           (Error.to_string_hum err))
