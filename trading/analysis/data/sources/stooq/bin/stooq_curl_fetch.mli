(** Curl-shellout HTTP fetcher for the Stooq daily-CSV endpoint.

    Mirrors [shiller_curl_fetch.ml]'s shape (PR #1137): tempfile-staged body via
    [curl -o] + status via [-w "%{http_code}"], no [Cohttp_async] dependency.
    Keeps the live-network surface separable from the pure-parsing lib so tests
    don't depend on curl. *)

open! Core
open Async

val curl_path : string
(** The curl executable path. Currently ["curl"] (lookup via PATH). *)

val curl_max_time_seconds : int
(** Per-request curl timeout. Stooq responses are typically a few hundred KB
    served well under 5 s; this gives headroom for transient slowness. *)

val fetch : Uri.t -> string Or_error.t Deferred.t
(** [fetch uri] performs a single GET against [uri] via system curl and returns
    the body on HTTP 200, or an [Error] describing the failure (curl exec
    failure, non-zero curl exit, non-200 status, unparseable status, signal
    termination).

    {b Apikey-error responses surface as [Ok body], not [Error].} Stooq returns
    HTTP 200 with a plaintext "Get your apikey:" body when no key is presented,
    so the response is structurally well-formed at the HTTP layer. Callers
    should branch on {!Stooq.Stooq_client.is_apikey_error_body} after a
    successful fetch to distinguish real CSV from the apikey sentinel. *)
