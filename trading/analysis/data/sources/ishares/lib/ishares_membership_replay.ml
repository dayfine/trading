open Core

type tenure_record = {
  ticker : string;
  first_seen : Date.t;
  last_seen : Date.t;
  sector_at_first : string;
  index : string;
}
[@@deriving show, eq]

(* In-progress tenure carried in the working state. [absent_streak] counts the
   number of consecutive snapshots in which [ticker] has been missing since
   [last_seen]; when it reaches the configured threshold, the tenure is
   closed. *)
type _in_progress = {
  ticker : string;
  first_seen : Date.t;
  last_seen : Date.t;
  sector_at_first : string;
  absent_streak : int;
}

let _untickered = "-"

let _new_in_progress ~as_of ~(holding : Ishares_holdings_client.holding) =
  {
    ticker = holding.ticker;
    first_seen = as_of;
    last_seen = as_of;
    sector_at_first = holding.sector;
    absent_streak = 0;
  }

let _to_tenure ~index (ip : _in_progress) : tenure_record =
  {
    ticker = ip.ticker;
    first_seen = ip.first_seen;
    last_seen = ip.last_seen;
    sector_at_first = ip.sector_at_first;
    index;
  }

(* Index a snapshot's holdings by ticker, dropping the [_untickered] sentinel
   rows. Asset-class and location filters are NOT applied here — see [.mli]
   note on the deliberate split. If a ticker appears twice in one snapshot
   (vendor quirk; not observed in the Phase 1.4 probe but cheap to guard
   against), the first occurrence wins so [sector_at_first] stays stable. *)
let _seen_in_snapshot (snap : Ishares_holdings_client.snapshot) :
    (string, Ishares_holdings_client.holding) Hashtbl.t =
  let tbl = Hashtbl.create (module String) in
  List.iter snap.holdings ~f:(fun h ->
      if not (String.equal h.ticker _untickered) then
        match Hashtbl.add tbl ~key:h.ticker ~data:h with
        | `Ok | `Duplicate -> ());
  tbl

(* Process one snapshot: update [state] in-place and return the list of
   tenure_records closed by hitting the miss threshold during this step. *)
let _step_snapshot ~threshold ~index ~(state : (string, _in_progress) Hashtbl.t)
    ((as_of, snap) : Date.t * Ishares_holdings_client.snapshot) :
    tenure_record list =
  let seen = _seen_in_snapshot snap in
  (* Update entries for tickers present in this snapshot. *)
  Hashtbl.iteri seen ~f:(fun ~key:ticker ~data:holding ->
      match Hashtbl.find state ticker with
      | Some ip ->
          Hashtbl.set state ~key:ticker
            ~data:{ ip with last_seen = as_of; absent_streak = 0 }
      | None ->
          Hashtbl.set state ~key:ticker ~data:(_new_in_progress ~as_of ~holding));
  (* Increment miss counters for tickers in state but absent in this
     snapshot. Core's Hashtbl forbids mutation during fold/iter, so we
     materialize an explicit "absent" list first, then mutate, then
     filter out closures. *)
  let absent =
    Hashtbl.fold state ~init:[] ~f:(fun ~key:ticker ~data:ip acc ->
        if Hashtbl.mem seen ticker then acc else (ticker, ip) :: acc)
  in
  let to_close =
    List.filter_map absent ~f:(fun (ticker, ip) ->
        let bumped = ip.absent_streak + 1 in
        if bumped >= threshold then (
          Hashtbl.remove state ticker;
          Some ip)
        else (
          Hashtbl.set state ~key:ticker ~data:{ ip with absent_streak = bumped };
          None))
  in
  (* Determinism: emit closures sorted by (first_seen, ticker) so the output
     is independent of hashtable iteration order. *)
  to_close
  |> List.sort ~compare:(fun a b ->
      match Date.compare a.first_seen b.first_seen with
      | 0 -> String.compare a.ticker b.ticker
      | c -> c)
  |> List.map ~f:(_to_tenure ~index)

(* Drain any still-open tenures at end of stream, sorted by (first_seen,
   ticker) ascending. *)
let _flush_state ~index (state : (string, _in_progress) Hashtbl.t) :
    tenure_record list =
  Hashtbl.data state
  |> List.sort ~compare:(fun a b ->
      match Date.compare a.first_seen b.first_seen with
      | 0 -> String.compare a.ticker b.ticker
      | c -> c)
  |> List.map ~f:(_to_tenure ~index)

let replay ?(index = "IWV") ~threshold_consecutive_misses
    (snapshots : (Date.t * Ishares_holdings_client.snapshot) list) :
    tenure_record list =
  let state : (string, _in_progress) Hashtbl.t =
    Hashtbl.create (module String)
  in
  let closures =
    List.concat_map snapshots
      ~f:(_step_snapshot ~threshold:threshold_consecutive_misses ~index ~state)
  in
  closures @ _flush_state ~index state
