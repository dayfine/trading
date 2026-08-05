open Core

type entry_order_kind =
  | Market
  | Stop_limit_band of float
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
  let r = entry.initial_risk_dollars in
  if Float.(v <= 0.0) || Float.(entry.installed_stop <= 0.0) then
    entry.suggested_entry
  else
    let ratio = r /. v in
    let denom =
      match entry.side with Long -> 1.0 -. ratio | Short -> 1.0 +. ratio
    in
    if Float.(denom <= 0.0) then entry.suggested_entry
    else entry.installed_stop /. denom

let _limit_of ~(side : Trading_base.Types.position_side) ~trigger ~band =
  match side with
  | Long -> trigger *. (1.0 +. band)
  | Short -> trigger *. (1.0 -. band)

(* A faithful StopLimit fill is at/beyond the trigger in the breakout direction
   and within the do-not-chase limit: for a long buy-stop [trigger <= fill <=
   limit]; mirrored for a short sell-stop [limit <= fill <= trigger]. Each bound
   carries [_rel_tolerance] for float noise. *)
let _within_band ~(side : Trading_base.Types.position_side) ~trigger ~limit ~fill
    =
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

(* position_id -> entry fill price. Reuses [Trade_context]'s (symbol,
   entry_date) + 7-day window join to resolve each round-trip's position; the
   first round-trip matched to a position supplies its entry fill. *)
let _fill_by_position_id ~audit ~round_trips =
  let pre = Trade_context.precompute ~audit ~stop_infos:[] in
  List.fold round_trips ~init:String.Map.empty
    ~f:(fun acc (trade : Trading_simulation.Metrics.trade_metrics) ->
      match (Trade_context.of_precomputed pre ~trade).position_id with
      | Some pid when not (Map.mem acc pid) ->
          Map.set acc ~key:pid ~data:trade.entry_price
      | _ -> acc)

let enrich ~audit ~round_trips ~entry_order_kind =
  let fill_by_pid = _fill_by_position_id ~audit ~round_trips in
  List.map audit ~f:(fun (r : Trade_audit.audit_record) ->
      match Map.find fill_by_pid r.entry.position_id with
      | None -> r
      | Some fill_price ->
          {
            r with
            execution =
              Some (_execution_of ~entry_order_kind ~entry:r.entry ~fill_price);
          })
