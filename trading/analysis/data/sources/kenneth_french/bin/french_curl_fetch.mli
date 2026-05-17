(** Curl-shellout HTTP fetcher for the Kenneth French Data Library ZIPs.

    Mirrors the pattern PR #1137 / PR #1141 established for the Shiller +
    iShares fetchers: shell out to the system [curl] binary rather than
    hand-roll a [Cohttp_async] client. The Dartmouth/Tuck server is
    Microsoft-IIS/10.0 (per the 2026-05-16 probe) and serves binary ZIP bodies;
    shelling to curl keeps the ingest tooling consistent across data sources and
    avoids dragging an HTTP/2 client into the data-source layer.

    The module exposes:
    - {!fetch} — IO-shaped one-shot GET that writes the response body
      (binary-safe) to a temp file and returns the file path. The caller is
      responsible for unpacking the ZIP and removing the file.

    Retry / backoff is not needed here: Dartmouth's FTP-style endpoint is highly
    available and the datasets update monthly — if a fetch fails the operator
    can simply re-run the CLI.

    Differs from [shiller_curl_fetch.fetch] in returning the staged tempfile
    path instead of the body string, because the Kenneth French response is a
    binary ZIP and reading it back as an OCaml string serves no purpose — the
    next step is [unzip], which wants a path. *)

open! Core
open Async

val curl_path : string
(** The curl executable path. Currently ["curl"] (lookup via PATH). *)

val curl_max_time_seconds : int
(** Per-request curl timeout. The 5-Industry daily ZIP is ~520 KB; this gives
    generous headroom even on slow links. *)

val user_agent : string
(** Browser-style User-Agent used in the [-A] header. The Dartmouth/Tuck server
    returned 200 with [Mozilla/5.0] during the 2026-05-16 probe; we pin a
    similar value defensively against future IIS WAF changes. *)

val fetch : Uri.t -> dest_path:string -> unit Or_error.t Deferred.t
(** [fetch uri ~dest_path] performs a one-shot HTTP GET via system [curl] and
    writes the (binary-safe) response body to [dest_path] on HTTP 200. Returns
    [Error _] on any of:
    - non-zero curl exit (network / DNS / TLS / timeout)
    - non-200 HTTP status
    - unparseable status code from [curl -w]
    - process exec failure (e.g. [curl] not on PATH)
    - [curl] killed by signal

    On error, the destination file is removed (best-effort) so the caller does
    not need to clean up a partially-written body. *)
