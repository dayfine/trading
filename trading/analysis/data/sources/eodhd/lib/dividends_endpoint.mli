(** EODHD dividends endpoint client.

    Wraps the [/api/div/{symbol}.{exchange}] endpoint. EODHD returns one row per
    recorded cash dividend, with the ex-date and amount per share.

    {1 Why this exists}

    The M6.4 verification harness asserts that, for a known dividend ex-date,
    cash injection equals [quantity * div_per_share] and quantity is unchanged.
    A deterministic ground-truth feed of dividend dates and amounts is required
    to drive the assertion.

    {1 Stubbing}

    Following the {!Http_client} convention, {!get_dividends} accepts an
    optional [?fetch] argument so tests can inject a fixture-backed fetcher
    instead of hitting the live network. *)

open Async
open Core

type dividend = {
  date : Date.t;  (** Ex-date of the dividend. *)
  amount : float;
      (** Cash amount per share, in the security's quote currency. Positive. *)
}
[@@deriving show, eq]
(** A single cash-dividend event. *)

val get_dividends :
  token:string ->
  symbol:string ->
  ?exchange:string ->
  ?fetch:Http_client.fetch_fn ->
  unit ->
  dividend list Status.status_or Deferred.t
(** [get_dividends ~token ~symbol ?exchange ?fetch ()] fetches recorded
    dividends for [symbol].

    - [exchange] defaults to ["US"].
    - [fetch] defaults to a live Cohttp client.

    Returns the list in the order EODHD returned it. If EODHD reports no
    dividends, returns [Ok []].

    Errors are reported as [Status.t]:
    - [Internal] if the HTTP fetch fails.
    - [Invalid_argument] if the response body is not valid JSON or is missing
      expected fields. *)
