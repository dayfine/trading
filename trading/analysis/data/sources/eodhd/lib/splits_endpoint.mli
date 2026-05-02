(** EODHD splits endpoint client.

    Wraps the [/api/splits/{symbol}.{exchange}] endpoint. EODHD returns one row
    per recorded split for the symbol, with the ex-date and a [N/M] textual
    factor (e.g. ["4.000000/1.000000"] for a 4:1 forward split).

    {1 Why this exists}

    The {!Http_client} module wires the EOD bar endpoint, but corporate-action
    metadata lives at separate endpoints. M6.4 (split/dividend verification
    harness) needs deterministic ground-truth split factors and ex-dates to
    drive replay tests — independent of the [adjusted_close]-based split
    detector ({!Split_detector}) which we are also testing.

    {1 Stubbing}

    Following the {!Http_client} convention, {!get_splits} accepts an optional
    [?fetch] argument that takes a [Uri.t] and returns the response body. Tests
    inject a fixture-backed [fetch] to avoid live network calls; production
    callers omit it and get the default Cohttp client. *)

open Async
open Core

type split = {
  date : Date.t;  (** Ex-date of the split. *)
  factor : float;
      (** [new_shares /. old_shares]. For a 4:1 forward split, [4.0]. For a 1:5
          reverse split, [0.2]. Always positive, non-zero. *)
}
[@@deriving show, eq]
(** A single split event, parsed from one row of the EODHD response. *)

val get_splits :
  token:string ->
  symbol:string ->
  ?exchange:string ->
  ?fetch:Http_client.fetch_fn ->
  unit ->
  split list Status.status_or Deferred.t
(** [get_splits ~token ~symbol ?exchange ?fetch ()] fetches the recorded splits
    for [symbol].

    - [exchange] defaults to ["US"] (the EODHD US composite).
    - [fetch] defaults to a live Cohttp client; tests pass a stub.

    Returns the split list in the order EODHD returned it. If EODHD reports no
    splits, returns [Ok []].

    Errors are reported as [Status.t]:
    - [Internal] if the HTTP fetch fails.
    - [Invalid_argument] if the response body is not valid JSON or is missing
      expected fields. *)
