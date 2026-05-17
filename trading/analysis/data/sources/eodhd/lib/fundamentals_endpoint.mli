(** EODHD fundamentals endpoint client.

    Wraps the [/api/fundamentals/{symbol}] endpoint, requesting only the
    [General] and [SharesStats] sections (the two we currently need for sector /
    industry / market-cap metadata and the shares-outstanding enrichment pass).
    Following the {!Splits_endpoint} / {!Dividends_endpoint} pattern, this
    module sits alongside {!Http_client} rather than inside it, keeping each
    endpoint module small and independently testable.

    {1 Stubbing}

    {!get_fundamentals} accepts an optional [?fetch] argument; tests inject a
    fixture-backed [fetch] to avoid live network calls. Production callers omit
    it and get the default Cohttp client via {!Http_client.default_fetch}. *)

open Async

type fundamentals = {
  symbol : string;
  name : string;
  sector : string;
  industry : string;
  market_cap : float;
  exchange : string;
  shares_outstanding : float;
      (** Total shares outstanding as reported by EODHD. Sourced from the
          [SharesStats.SharesOutstanding] field of the fundamentals response
          (NOT [General]). [0.0] when the field is missing or null — caller
          should treat zero as "no fundamentals data available for ranking". *)
}
[@@deriving show, eq]
(** Fundamental data for a security, including sector and industry metadata. *)

val get_fundamentals :
  token:string ->
  symbol:string ->
  ?fetch:Http_client.fetch_fn ->
  unit ->
  fundamentals Status.status_or Deferred.t
(** Fetch fundamental data (sector, industry, market cap, shares-outstanding)
    for a symbol. Requests the [General] and [SharesStats] sections of the
    [/api/fundamentals/{symbol}] response.

    Note on token tier: the fundamentals endpoint requires an EODHD plan with
    the "Fundamentals API" add-on. Tokens without this add-on return HTTP 403
    even though [/api/eod] continues to work — callers should handle the 403
    distinctly from other errors when wiring bulk enrichment runs. *)
