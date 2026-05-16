(** Curl-shellout HTTP fetcher for the Shiller mirror CSV.

    Mirrors the pattern PR #1137 established for [iwv_curl_fetch.ml]: shell out
    to the system [curl] binary rather than hand-roll a [Cohttp_async] client.
    Even though GitHub's raw-content endpoint is not Akamai-fronted (so the
    [Cohttp_async] fingerprint issue from the iShares scrape does not apply),
    using [curl] keeps the ingest tooling consistent across data sources and
    avoids dragging a TLS / HTTP/2 client into the data-source layer.

    The module exposes:
    - {!fetch} — IO-shaped one-shot GET that writes the response body to a temp
      file, reads it, deletes it, and returns the body or an error.

    Retry / backoff is not needed here: the GitHub raw endpoint is highly
    available and the dataset updates monthly — if a fetch fails the operator
    can simply re-run the CLI. *)

open! Core
open Async

val curl_path : string
(** The curl executable path. Currently ["curl"] (lookup via PATH). *)

val curl_max_time_seconds : int
(** Per-request curl timeout. The Shiller CSV is ~125 KB; this gives generous
    headroom even on slow links. *)

val fetch : Uri.t -> string Or_error.t Deferred.t
(** [fetch uri] performs a one-shot HTTP GET via system [curl] and returns the
    response body on HTTP 200. Returns [Error _] on any of:
    - non-zero curl exit (network / DNS / TLS / timeout)
    - non-200 HTTP status
    - unparseable status code from [curl -w]
    - process exec failure (e.g. [curl] not on PATH)
    - [curl] killed by signal

    The response body is staged through a tempfile (curl's [-o] flag) so the
    body stays out of curl's stdout (which carries the HTTP status code via
    [-w "%{http_code}"]). The tempfile is removed on every code path. *)
