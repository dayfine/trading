(** Curl-shellout HTTP fetcher for the IWV scraper.

    Replaces the [Cohttp_async]-based GET path that PR #1131 added browser
    headers to. Even with browser headers, the OCaml HTTP/1.1 client tripped
    Akamai's bot fingerprint and got back an HTML challenge page (see
    [dev/notes/iwv-scrape-akamai-block-2026-05-16.md] §"Cohttp_async still
    serves HTML"). Shelling out to system curl — which negotiates HTTP/2
    + a real TLS stack — sidesteps the fingerprint.

    The module exposes:

    - [curl_args] — pure argv-list construction (testable).
    - [classify_curl_output] — pure classification of a [Process.Output.t] into
      the lib's [fetch_attempt] retry vocabulary (testable).
    - [attempt_fetch] — IO-shaped single HTTP attempt, with the underlying curl
      runner injectable for tests.

    All retry / backoff logic stays in
    [Fetch_iwv_history_lib.retry_with_backoff] (contract-stable per PR #1131).
*)

open Async
module Lib = Fetch_iwv_history_lib

val curl_path : string
(** The curl executable path. Currently ["curl"] (lookup via PATH). *)

val curl_max_time_seconds : int
(** Per-request curl timeout. iShares responses are typically well under 5 s;
    this gives generous headroom for transient slowness. *)

val curl_retryable_exit_codes : int list
(** Curl exit codes that classify as transient network errors (suitable for
    retry). 6=resolve, 7=connect, 28=op timeout, 35=ssl-handshake,
    52=empty-reply, 56=recv. All other non-zero curl exits surface as fatal.
    From the [curl(1)] man page. *)

val curl_args : body_tempfile:string -> Uri.t -> string list
(** [curl_args ~body_tempfile uri] returns the argv list (excluding the leading
    ["curl"] program path) for a single GET. The output body is streamed to
    [body_tempfile] (curl's [-o]); the HTTP status code is written to curl's
    stdout (curl's [-w "%{http_code}"]).

    Browser-mimicking headers (UA / Accept / Accept-Language / Referer) are
    added unconditionally. *)

val classify_curl_output :
  uri:Uri.t -> body:string -> Process.Output.t -> Lib.fetch_attempt
(** [classify_curl_output ~uri ~body output] turns a completed curl invocation
    into the retry-decision vocabulary.

    - Exit 0 + stdout-parses-as-200 → [Ok_body body].
    - Exit 0 + stdout-parses-as one of [503] / [429] / [502] / [504] →
      [Retryable_error _].
    - Exit 0 + any other parseable HTTP code → [Fatal_error _].
    - Exit 0 + unparseable stdout → [Fatal_error _].
    - Exit non-zero with a curl code in [curl_retryable_exit_codes] →
      [Retryable_error _].
    - Exit non-zero otherwise → [Fatal_error _].
    - Killed by signal → [Fatal_error _]. *)

type curl_runner =
  prog:string -> args:string list -> Process.Output.t Deferred.Or_error.t
(** Curl-runner abstraction. The production runner shells out via
    [Process.create] + [collect_output_and_wait]; tests inject a stub that
    returns a scripted [Process.Output.t]. *)

val real_curl_runner : curl_runner
(** [real_curl_runner ~prog ~args] launches [prog] with [args] via
    [Async.Process.create] and waits for it to terminate, returning its output
    (stdout + stderr + exit status). *)

val attempt_fetch : curl:curl_runner -> Uri.t -> Lib.fetch_attempt Deferred.t
(** [attempt_fetch ~curl uri] performs a single HTTP attempt via the injected
    curl runner. Manages the response-body tempfile (creation
    + read + delete on every code path). Returns a [fetch_attempt] for
      [Fetch_iwv_history_lib.retry_with_backoff] to decide on retries. *)
