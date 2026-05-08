(** Per-section helpers for the optimal-strategy counterfactual report.

    Pure markdown renderers for the per-Friday divergence table, missed-trades
    table, and implications narrative. All functions are pure: same input ->
    same output; no I/O.

    Called exclusively by [Optimal_strategy_report.render]. *)

open Core

(* ---------------------------------------------------------------- *)
(* Section: per-Friday divergence table                              *)
(* ---------------------------------------------------------------- *)

(** Compare two actual trade_metrics by entry_date. *)
let _cmp_actual_by_date (x : Trading_simulation.Metrics.trade_metrics)
    (y : Trading_simulation.Metrics.trade_metrics) =
  Date.compare x.entry_date y.entry_date

(** True iff two actual trade_metrics have different entry_dates (group break).
*)
let _actual_date_break (a : Trading_simulation.Metrics.trade_metrics)
    (b : Trading_simulation.Metrics.trade_metrics) =
  not (Date.equal a.entry_date b.entry_date)

(** Label a group of actual round-trips with their common entry_date. *)
let _label_actual_group (group : Trading_simulation.Metrics.trade_metrics list)
    =
  match group with
  | [] -> failwith "_actual_picks_by_friday: empty group (impossible)"
  | (hd : Trading_simulation.Metrics.trade_metrics) :: _ ->
      (hd.entry_date, group)

(** Group actual round-trips by their entry date (the equivalent of "Friday").
*)
let _actual_picks_by_friday
    (rts : Trading_simulation.Metrics.trade_metrics list) :
    (Date.t * Trading_simulation.Metrics.trade_metrics list) list =
  rts
  |> List.sort ~compare:_cmp_actual_by_date
  |> List.group ~break:_actual_date_break
  |> List.map ~f:_label_actual_group

(** Compare two optimal round-trips by entry_week. *)
let _cmp_optimal_by_date (x : Optimal_types.optimal_round_trip)
    (y : Optimal_types.optimal_round_trip) =
  Date.compare x.entry_week y.entry_week

(** True iff two optimal round-trips have different entry_weeks (group break).
*)
let _optimal_date_break (a : Optimal_types.optimal_round_trip)
    (b : Optimal_types.optimal_round_trip) =
  not (Date.equal a.entry_week b.entry_week)

(** Label a group of optimal round-trips with their common entry_week. *)
let _label_optimal_group (group : Optimal_types.optimal_round_trip list) =
  match group with
  | [] -> failwith "_optimal_picks_by_friday: empty group (impossible)"
  | (hd : Optimal_types.optimal_round_trip) :: _ -> (hd.entry_week, group)

let _optimal_picks_by_friday (rts : Optimal_types.optimal_round_trip list) :
    (Date.t * Optimal_types.optimal_round_trip list) list =
  rts
  |> List.sort ~compare:_cmp_optimal_by_date
  |> List.group ~break:_optimal_date_break
  |> List.map ~f:_label_optimal_group

let _syms_of_actual (rts : Trading_simulation.Metrics.trade_metrics list) =
  rts
  |> List.map ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
      t.symbol)
  |> Set.of_list (module String)

(** True iff the actual and constrained sets of symbols on a given date differ.
*)
let _picks_diverge ~(actual : Trading_simulation.Metrics.trade_metrics list)
    ~(optimal : Optimal_types.optimal_round_trip list) : bool =
  let actual_syms = _syms_of_actual actual in
  let optimal_syms =
    optimal
    |> List.map ~f:(fun (t : Optimal_types.optimal_round_trip) -> t.symbol)
    |> Set.of_list (module String)
  in
  not (Set.equal actual_syms optimal_syms)

let _fmt_actual_pick (t : Trading_simulation.Metrics.trade_metrics) =
  sprintf "%s (%.0f sh)" t.symbol t.quantity

let _fmt_optimal_pick (t : Optimal_types.optimal_round_trip) =
  sprintf "%s (%.0f sh, R=%+.2f)" t.symbol t.shares t.r_multiple

(** Top-3 counterfactual picks the actual did not take, ranked by R-multiple. *)
let _missed_top3 ~(actual : Trading_simulation.Metrics.trade_metrics list)
    ~(optimal : Optimal_types.optimal_round_trip list) :
    Optimal_types.optimal_round_trip list =
  let actual_syms = _syms_of_actual actual in
  optimal
  |> List.filter ~f:(fun (t : Optimal_types.optimal_round_trip) ->
      not (Set.mem actual_syms t.symbol))
  |> List.sort
       ~compare:(fun
           (a : Optimal_types.optimal_round_trip)
           (b : Optimal_types.optimal_round_trip)
         -> Float.compare b.r_multiple a.r_multiple)
  |> fun lst -> List.take lst 3

let _fmt_list fmt lst empty =
  if List.is_empty lst then empty
  else String.concat ~sep:", " (List.map lst ~f:fmt)

let _divergence_row ~date
    ~(actual : Trading_simulation.Metrics.trade_metrics list)
    ~(optimal : Optimal_types.optimal_round_trip list) : string list =
  let missed = _missed_top3 ~actual ~optimal in
  [
    sprintf "### %s" (Date.to_string date);
    "";
    sprintf "- Actual: %s" (_fmt_list _fmt_actual_pick actual "_(none)_");
    sprintf "- Optimal: %s" (_fmt_list _fmt_optimal_pick optimal "_(none)_");
    sprintf "- Top-3 missed: %s" (_fmt_list _fmt_optimal_pick missed "_(none)_");
    "";
  ]

let divergence_section
    ~(actual_round_trips : Trading_simulation.Metrics.trade_metrics list)
    ~(constrained_round_trips : Optimal_types.optimal_round_trip list) :
    string list =
  let actual_map =
    Map.of_alist_exn (module Date) (_actual_picks_by_friday actual_round_trips)
  in
  let optimal_map =
    Map.of_alist_exn
      (module Date)
      (_optimal_picks_by_friday constrained_round_trips)
  in
  let all_dates =
    Set.union
      (Set.of_list (module Date) (Map.keys actual_map))
      (Set.of_list (module Date) (Map.keys optimal_map))
    |> Set.to_list
  in
  let get_actual d = Option.value (Map.find actual_map d) ~default:[] in
  let get_optimal d = Option.value (Map.find optimal_map d) ~default:[] in
  let divergent =
    List.filter all_dates ~f:(fun d ->
        _picks_diverge ~actual:(get_actual d) ~optimal:(get_optimal d))
  in
  if List.is_empty divergent then
    [
      "## Per-Friday divergence";
      "";
      "_No Fridays where actual and constrained-counterfactual picks differed._";
      "";
    ]
  else
    [
      "## Per-Friday divergence";
      "";
      "Fridays where the actual run's entries differ from the \
       constrained-counterfactual's. Sizes are share counts; R is the \
       counterfactual's realized R-multiple.";
      "";
    ]
    @ List.concat_map divergent ~f:(fun d ->
        _divergence_row ~date:d ~actual:(get_actual d) ~optimal:(get_optimal d))

(* ---------------------------------------------------------------- *)
(* Section: trades the actual missed                                  *)
(* ---------------------------------------------------------------- *)

(** Counterfactual round-trips whose symbol is absent from the actual run,
    ranked by realized P&L descending. *)
let _missed_trades
    ~(actual_round_trips : Trading_simulation.Metrics.trade_metrics list)
    ~(constrained_round_trips : Optimal_types.optimal_round_trip list) :
    Optimal_types.optimal_round_trip list =
  let actual_syms = _syms_of_actual actual_round_trips in
  constrained_round_trips
  |> List.filter ~f:(fun (t : Optimal_types.optimal_round_trip) ->
      not (Set.mem actual_syms t.symbol))
  |> List.sort
       ~compare:(fun
           (a : Optimal_types.optimal_round_trip)
           (b : Optimal_types.optimal_round_trip)
         -> Float.compare b.pnl_dollars a.pnl_dollars)

let _missed_trade_row ~(cascade_rejections : (string * string) list)
    (rt : Optimal_types.optimal_round_trip) : string =
  let reason_str =
    match
      List.find_map cascade_rejections ~f:(fun (s, r) ->
          if String.equal s rt.symbol then Some r else None)
    with
    | None -> ""
    | Some r -> sprintf " -- _%s_" r
  in
  sprintf "| %s | %s | %s | %s | %s | %s%s |" rt.symbol
    (Date.to_string rt.entry_week)
    (Date.to_string rt.exit_week)
    (sprintf "%+.2f" rt.r_multiple)
    (sprintf "$%.2f" rt.pnl_dollars)
    (Sexp.to_string (Optimal_types.sexp_of_exit_trigger rt.exit_trigger))
    reason_str

let missed_section
    ~(actual_round_trips : Trading_simulation.Metrics.trade_metrics list)
    ~(constrained_round_trips : Optimal_types.optimal_round_trip list)
    ~(cascade_rejections : (string * string) list) : string list =
  let missed = _missed_trades ~actual_round_trips ~constrained_round_trips in
  if List.is_empty missed then
    [
      "## Trades the actual missed";
      "";
      "_No counterfactual round-trips on symbols the actual run skipped._";
      "";
    ]
  else
    [
      "## Trades the actual missed";
      "";
      "Counterfactual round-trips on symbols the actual run never entered, \
       ranked by realized P&L. Cascade-rejection reasons (when captured by the \
       audit) are quoted inline.";
      "";
      "| Symbol | Entry | Exit | R | P&L | Trigger |";
      "|---|---|---|---:|---:|---|";
    ]
    @ List.map missed ~f:(_missed_trade_row ~cascade_rejections)
    @ [ "" ]

(* ---------------------------------------------------------------- *)
(* Section: implications                                              *)
(* ---------------------------------------------------------------- *)

let _frac_to_pct v = v *. 100.0

(** Counterfactual/actual return ratio above which the cascade is deemed
    significantly mis-scoring (strong outperformance band). *)
let _strong_outperform_threshold = 3.0

(** Counterfactual/actual return ratio below which the cascade is deemed
    near-optimal (moderate outperformance band lower bound). *)
let _moderate_outperform_threshold = 1.5

(** Format a narrative for a valid (positive-actual) ratio of counterfactual to
    actual return. *)
let _ratio_narrative ~(r : float) : string =
  if Float.(r > _strong_outperform_threshold) then
    sprintf
      "Constrained-counterfactual return is %.1f* the actual run's. The \
       cascade is significantly mis-scoring opportunities -- material gains \
       are reachable via re-weighting alone, without relaxing the macro gate \
       or sector caps."
      r
  else if Float.(r < _moderate_outperform_threshold) then
    sprintf
      "Constrained-counterfactual return is %.1f* the actual run's -- the \
       cascade is near-optimal under the current envelope. Further upside \
       requires structural changes (envelope, gate thresholds, or additional \
       signals)."
      r
  else
    sprintf
      "Constrained-counterfactual return is %.1f* the actual run's. Moderate \
       cascade-ranking improvement is reachable; structural changes (envelope \
       / gate / signals) are also needed for full upside."
      r

let _implications_narrative ~(actual_total_return_pct : float)
    ~(constrained_total_return_pct : float) : string =
  if Float.(actual_total_return_pct <= 0.0) then
    "Actual return was non-positive; counterfactual ratio is degenerate. \
     Inspect the divergence table directly -- the cascade may be admitting too \
     few candidates, or the macro gate may be over-restrictive."
  else
    let r = constrained_total_return_pct /. actual_total_return_pct in
    _ratio_narrative ~r

let implications_section ~(actual_initial_cash : float)
    ~(actual_final_portfolio_value : float)
    ~(constrained_summary : Optimal_types.optimal_summary) : string list =
  let actual_total_return_pct =
    if Float.(actual_initial_cash <= 0.0) then 0.0
    else
      (actual_final_portfolio_value -. actual_initial_cash)
      /. actual_initial_cash *. 100.0
  in
  let constrained_total_return_pct =
    _frac_to_pct constrained_summary.total_return_pct
  in
  [
    "## Implications";
    "";
    _implications_narrative ~actual_total_return_pct
      ~constrained_total_return_pct;
    "";
  ]
