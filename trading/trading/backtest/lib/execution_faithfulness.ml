open Core

type entry_order_kind = Market | Stop_limit_band of float
[@@deriving sexp, eq]

(* Percentage points -> fraction for the do-not-chase band. *)
let _pct_to_fraction = 100.0

(* Relative float tolerance on the trigger/limit bounds so a fill that lands
   exactly on a boundary (the common case — the simulator fills a StopLimit at
   its trigger) is not spuriously flagged unfaithful by sub-ULP noise. *)
let _rel_tolerance = 1e-6

let entry_order_kind_of_config (config : Weinstein_strategy.config) =
  if
    config.enable_sim_entry_stoplimit
    && Float.(config.entry_extension_max_pct > 0.0)
  then Stop_limit_band (config.entry_extension_max_pct /. _pct_to_fraction)
  else Market

(* The entry order's trigger = the [CreateEntering.entry_price] the strategy
   installed = the effective entry [E]. [entry_decision] does not carry the raw
   share count, but it carries the two dollar quantities the strategy derived
   from [E]:
     initial_position_value v = shares *. E
     initial_risk_dollars   r = shares *. |E -. installed_stop|
   so [r /. v = |E -. installed_stop| /. E], giving (long, [installed_stop < E])
   [E = installed_stop /. (1 -. r/v)] and (short, [installed_stop > E])
   [E = installed_stop /. (1 +. r/v)]. Exact for any real filled entry
   ([v > 0], [installed_stop > 0], [r/v] in [(0, 1)]); falls back to the
   screener's [suggested_entry] in the degenerate cases the guards catch (they
   do not arise for an entry that actually filled). *)
let _designed_trigger (entry : Trade_audit.entry_decision) =
  let v = entry.initial_position_value in
  (* [nan] when [v <= 0] so the guard below rejects it (any comparison with nan
     is false), falling back to [suggested_entry]. *)
  let ratio =
    if Float.(v > 0.0) then entry.initial_risk_dollars /. v else Float.nan
  in
  let denom =
    match entry.side with Long -> 1.0 -. ratio | Short -> 1.0 +. ratio
  in
  if
    Float.(v > 0.0) && Float.(entry.installed_stop > 0.0) && Float.(denom > 0.0)
  then entry.installed_stop /. denom
  else entry.suggested_entry

let _limit_of ~(side : Trading_base.Types.position_side) ~trigger ~band =
  match side with
  | Long -> trigger *. (1.0 +. band)
  | Short -> trigger *. (1.0 -. band)

(* A faithful StopLimit fill is at/beyond the trigger in the breakout direction
   and within the do-not-chase limit: for a long buy-stop [trigger <= fill <=
   limit]; mirrored for a short sell-stop [limit <= fill <= trigger]. Each bound
   carries [_rel_tolerance] for float noise. *)
let _within_band ~(side : Trading_base.Types.position_side) ~trigger ~limit
    ~fill =
  match side with
  | Long ->
      Float.(fill >= trigger *. (1.0 -. _rel_tolerance))
      && Float.(fill <= limit *. (1.0 +. _rel_tolerance))
  | Short ->
      Float.(fill <= trigger *. (1.0 +. _rel_tolerance))
      && Float.(fill >= limit *. (1.0 -. _rel_tolerance))

let _execution_of ~entry_order_kind ~(entry : Trade_audit.entry_decision)
    ~fill_price : Trade_audit.execution_faithfulness =
  let trigger = _designed_trigger entry in
  let fill_vs_trigger_pct =
    if Float.(trigger <> 0.0) then (fill_price -. trigger) /. trigger else 0.0
  in
  match entry_order_kind with
  | Market ->
      {
        designed_order_type = Trade_audit.Market;
        designed_trigger = trigger;
        fill_price;
        fill_vs_trigger_pct;
        fill_within_band = true;
        faithful = true;
      }
  | Stop_limit_band band ->
      let limit = _limit_of ~side:entry.side ~trigger ~band in
      let within =
        _within_band ~side:entry.side ~trigger ~limit ~fill:fill_price
      in
      {
        designed_order_type = Trade_audit.Stop_limit { trigger; limit };
        designed_trigger = trigger;
        fill_price;
        fill_vs_trigger_pct;
        fill_within_band = within;
        faithful = within;
      }

(* Add one round-trip's entry leg to the [position_id -> (fill price, fill date)]
   map, keyed by the position [Trade_context] resolves for it (first match
   wins). The fill date is carried alongside the price for the PR-5 ticket-age
   stamp below; it costs nothing extra — this join is the only place the
   placement tick and the fill tick are both in hand. *)
let _add_fill ~pre acc (trade : Trading_simulation.Metrics.trade_metrics) =
  match (Trade_context.of_precomputed pre ~trade).position_id with
  | Some pid when not (Map.mem acc pid) ->
      Map.set acc ~key:pid ~data:(trade.entry_price, trade.entry_date)
  | _ -> acc

(* position_id -> (entry fill price, entry fill date). Reuses [Trade_context]'s
   join to resolve each round-trip's position: the id the round-trip carries,
   else the legacy (symbol, entry_date) date-proximity fallback. *)
let _fill_by_position_id ~audit ~round_trips =
  let pre = Trade_context.precompute ~audit ~stop_infos:[] in
  List.fold round_trips ~init:String.Map.empty ~f:(_add_fill ~pre)

(* PR-5: stamp the ticket's resting age at fill, anchored on the entry row's own
   [placement_date]. Writes ONLY [ticket_age_weeks_at_fill]: a row with no
   [ticket_lifecycle] (written before PR-5) is left untouched, and any
   already-merged [ticket_age_weeks_at_cancel] is preserved — a cancelled ticket
   has no round-trip to join. *)
let _with_ticket_age (entry : Trade_audit.entry_decision) ~fill_date =
  {
    entry with
    ticket_lifecycle =
      Ticket_lifecycle.with_fill_age entry.ticket_lifecycle ~resolved:fill_date;
  }

let _enriched_record ~fill_by_pid ~entry_order_kind
    (r : Trade_audit.audit_record) =
  match Map.find fill_by_pid r.entry.position_id with
  | None -> r
  | Some (fill_price, fill_date) ->
      let execution =
        _execution_of ~entry_order_kind ~entry:r.entry ~fill_price
      in
      {
        r with
        entry = _with_ticket_age r.entry ~fill_date;
        execution = Some execution;
      }

let enrich ~audit ~round_trips ~entry_order_kind =
  let fill_by_pid = _fill_by_position_id ~audit ~round_trips in
  List.map audit ~f:(_enriched_record ~fill_by_pid ~entry_order_kind)

let enrich_for_config ~audit ~round_trips ~config =
  enrich ~audit ~round_trips
    ~entry_order_kind:(entry_order_kind_of_config config)
