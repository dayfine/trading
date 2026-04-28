(** Pure markdown renderer for the optimal-strategy counterfactual report.

    See [optimal_strategy_report.mli] for the API contract. *)

open Core

type variant_pack = {
  round_trips : Optimal_types.optimal_round_trip list;
  summary : Optimal_types.optimal_summary;
}

type actual_run = {
  scenario_name : string;
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
  initial_cash : float;
  final_portfolio_value : float;
  round_trips : Trading_simulation.Metrics.trade_metrics list;
  win_rate_pct : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  profit_factor : float;
  cascade_rejections : (string * string) list;
}

type input = {
  actual : actual_run;
  constrained : variant_pack;
  relaxed_macro : variant_pack;
}

(* ---------------------------------------------------------------- *)
(* Number formatting helpers                                         *)
(* ---------------------------------------------------------------- *)

let _fmt_pct_signed v = sprintf "%+.2f%%" v
let _fmt_pct_unsigned v = sprintf "%.2f%%" v
let _fmt_float_2 v = sprintf "%.2f" v
let _fmt_int i = Int.to_string i
let _fmt_float_or_inf v = if Float.is_finite v then sprintf "%.2f" v else "∞"
let _fmt_pp v = sprintf "%+.2f pp" v

(** Convert a counterfactual fractional return (e.g. [0.30]) to percentage
    points (e.g. [30.0]). The actual run reports its return already in
    percentage units (e.g. [+18.5]) — keep them comparable. *)
let _frac_to_pct v = v *. 100.0

(** Convert a counterfactual fractional drawdown (e.g. [0.42]) to percentage. *)
let _dd_frac_to_pct v = v *. 100.0

(** Counterfactual win-rate is stored as a fraction; the actual run reports
    percentage. Normalise both to percentage for table rendering. *)
let _wr_frac_to_pct v = v *. 100.0

(** Total return percentage of the actual run, derived from
    [(final - initial) / initial * 100]. *)
let _actual_total_return_pct (a : actual_run) : float =
  if Float.(a.initial_cash <= 0.0) then 0.0
  else (a.final_portfolio_value -. a.initial_cash) /. a.initial_cash *. 100.0

(** Mean R-multiple over a list of [Metrics.trade_metrics]. The actual side does
    not record R-multiples directly, so we approximate by the per-trade
    [pnl_percent] (already a percentage of entry price) — this is a rough proxy,
    but the headline table is for human comparison; the exact stat is in the
    full backtest summary already. *)
let _actual_avg_r (a : actual_run) : float =
  match a.round_trips with
  | [] -> 0.0
  | rts ->
      let n = List.length rts in
      List.sum
        (module Float)
        rts
        ~f:(fun (rt : Trading_simulation.Metrics.trade_metrics) ->
          rt.pnl_percent)
      /. Float.of_int n /. 100.0

(* ---------------------------------------------------------------- *)
(* Section: run header                                                *)
(* ---------------------------------------------------------------- *)

let _section_header (input : input) : string list =
  let a = input.actual in
  [
    sprintf "# Optimal-strategy counterfactual — %s" a.scenario_name;
    "";
    sprintf "- Period: %s → %s"
      (Date.to_string a.start_date)
      (Date.to_string a.end_date);
    sprintf "- Universe: %d symbols" a.universe_size;
    sprintf "- Starting cash: $%s" (_fmt_float_2 a.initial_cash);
    "";
    "**Disclaimer.** The counterfactual uses look-ahead — it scores every \
     candidate's realized exit using future bars, then greedily packs the \
     ranking under the live sizing envelope. It is **unrealizable**: a \
     real-time strategy cannot peek at future R-multiples. Treat the \
     counterfactual as an **upper bound** on what the cascade ranking + sizing \
     envelope could deliver if it were perfectly informed.";
    "";
  ]

(* ---------------------------------------------------------------- *)
(* Section: headline comparison table                                 *)
(* ---------------------------------------------------------------- *)

let _comp_row label ~actual ~constrained_v ~relaxed ~delta =
  sprintf "| %s | %s | %s | %s | %s |" label actual constrained_v relaxed delta

let _delta_pp ~constrained_v ~actual = _fmt_pp (constrained_v -. actual)

let _headline_section (input : input) : string list =
  let a = input.actual in
  let c = input.constrained in
  let r = input.relaxed_macro in
  let actual_return = _actual_total_return_pct a in
  let constrained_return = _frac_to_pct c.summary.total_return_pct in
  let relaxed_return = _frac_to_pct r.summary.total_return_pct in
  let actual_avg_r = _actual_avg_r a in
  [
    "## Headline comparison";
    "";
    "| Metric | Actual | Optimal (constrained) | Optimal (relaxed macro) | Δ \
     to constrained |";
    "|---|---:|---:|---:|---:|";
    _comp_row "Total return"
      ~actual:(_fmt_pct_signed actual_return)
      ~constrained_v:(_fmt_pct_signed constrained_return)
      ~relaxed:(_fmt_pct_signed relaxed_return)
      ~delta:(_delta_pp ~constrained_v:constrained_return ~actual:actual_return);
    _comp_row "Win rate"
      ~actual:(_fmt_pct_unsigned a.win_rate_pct)
      ~constrained_v:
        (_fmt_pct_unsigned (_wr_frac_to_pct c.summary.win_rate_pct))
      ~relaxed:(_fmt_pct_unsigned (_wr_frac_to_pct r.summary.win_rate_pct))
      ~delta:
        (_delta_pp
           ~constrained_v:(_wr_frac_to_pct c.summary.win_rate_pct)
           ~actual:a.win_rate_pct);
    _comp_row "MaxDD"
      ~actual:(sprintf "-%.2f%%" a.max_drawdown_pct)
      ~constrained_v:
        (sprintf "-%.2f%%" (_dd_frac_to_pct c.summary.max_drawdown_pct))
      ~relaxed:(sprintf "-%.2f%%" (_dd_frac_to_pct r.summary.max_drawdown_pct))
      ~delta:
        (_delta_pp
           ~constrained_v:(-._dd_frac_to_pct c.summary.max_drawdown_pct)
           ~actual:(-.a.max_drawdown_pct));
    _comp_row "Sharpe"
      ~actual:(_fmt_float_2 a.sharpe_ratio)
      ~constrained_v:"n/a" ~relaxed:"n/a" ~delta:"n/a";
    _comp_row "Profit factor"
      ~actual:(_fmt_float_or_inf a.profit_factor)
      ~constrained_v:(_fmt_float_or_inf c.summary.profit_factor)
      ~relaxed:(_fmt_float_or_inf r.summary.profit_factor)
      ~delta:"—";
    _comp_row "Round-trips"
      ~actual:(_fmt_int (List.length a.round_trips))
      ~constrained_v:(_fmt_int c.summary.total_round_trips)
      ~relaxed:(_fmt_int r.summary.total_round_trips)
      ~delta:"—";
    _comp_row "Avg R-multiple"
      ~actual:(_fmt_float_2 actual_avg_r)
      ~constrained_v:(_fmt_float_2 c.summary.avg_r_multiple)
      ~relaxed:(_fmt_float_2 r.summary.avg_r_multiple)
      ~delta:"—";
    "";
  ]

(* ---------------------------------------------------------------- *)
(* Section: per-Friday divergence table                              *)
(* ---------------------------------------------------------------- *)

(** Group actual round-trips by their entry date (the equivalent of "Friday").
    The actual side records [entry_date] from [trades.csv]; we group there. *)
let _actual_picks_by_friday (a : actual_run) :
    (Date.t * Trading_simulation.Metrics.trade_metrics list) list =
  a.round_trips
  |> List.sort
       ~compare:(fun
           (x : Trading_simulation.Metrics.trade_metrics)
           (y : Trading_simulation.Metrics.trade_metrics)
         -> Date.compare x.entry_date y.entry_date)
  |> List.group
       ~break:(fun
           (a : Trading_simulation.Metrics.trade_metrics)
           (b : Trading_simulation.Metrics.trade_metrics)
         -> not (Date.equal a.entry_date b.entry_date))
  |> List.map ~f:(fun group ->
      match group with
      | [] -> failwith "_actual_picks_by_friday: empty group (impossible)"
      | (hd : Trading_simulation.Metrics.trade_metrics) :: _ ->
          (hd.entry_date, group))

let _optimal_picks_by_friday (rts : Optimal_types.optimal_round_trip list) :
    (Date.t * Optimal_types.optimal_round_trip list) list =
  rts
  |> List.sort
       ~compare:(fun
           (x : Optimal_types.optimal_round_trip)
           (y : Optimal_types.optimal_round_trip)
         -> Date.compare x.entry_week y.entry_week)
  |> List.group
       ~break:(fun
           (a : Optimal_types.optimal_round_trip)
           (b : Optimal_types.optimal_round_trip)
         -> not (Date.equal a.entry_week b.entry_week))
  |> List.map ~f:(fun group ->
      match group with
      | [] -> failwith "_optimal_picks_by_friday: empty group (impossible)"
      | (hd : Optimal_types.optimal_round_trip) :: _ -> (hd.entry_week, group))

(** True iff the actual and constrained sets of symbols on [date] differ. *)
let _picks_diverge ~(actual : Trading_simulation.Metrics.trade_metrics list)
    ~(optimal : Optimal_types.optimal_round_trip list) : bool =
  let actual_syms =
    actual
    |> List.map ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
        t.symbol)
    |> Set.of_list (module String)
  in
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

(** Top-3 candidates the actual could have picked but didn't. We approximate
    "could have" as: counterfactual-Friday picks the actual didn't take, ranked
    by R-multiple descending. *)
let _missed_top3 ~(actual : Trading_simulation.Metrics.trade_metrics list)
    ~(optimal : Optimal_types.optimal_round_trip list) :
    Optimal_types.optimal_round_trip list =
  let actual_syms =
    actual
    |> List.map ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
        t.symbol)
    |> Set.of_list (module String)
  in
  optimal
  |> List.filter ~f:(fun (t : Optimal_types.optimal_round_trip) ->
      not (Set.mem actual_syms t.symbol))
  |> List.sort
       ~compare:(fun
           (a : Optimal_types.optimal_round_trip)
           (b : Optimal_types.optimal_round_trip)
         -> Float.compare b.r_multiple a.r_multiple)
  |> fun lst -> List.take lst 3

let _divergence_row ~date
    ~(actual : Trading_simulation.Metrics.trade_metrics list)
    ~(optimal : Optimal_types.optimal_round_trip list) : string list =
  let actual_str =
    if List.is_empty actual then "_(none)_"
    else String.concat ~sep:", " (List.map actual ~f:_fmt_actual_pick)
  in
  let optimal_str =
    if List.is_empty optimal then "_(none)_"
    else String.concat ~sep:", " (List.map optimal ~f:_fmt_optimal_pick)
  in
  let missed = _missed_top3 ~actual ~optimal in
  let missed_str =
    if List.is_empty missed then "_(none)_"
    else String.concat ~sep:", " (List.map missed ~f:_fmt_optimal_pick)
  in
  [
    sprintf "### %s" (Date.to_string date);
    "";
    sprintf "- Actual: %s" actual_str;
    sprintf "- Optimal: %s" optimal_str;
    sprintf "- Top-3 missed: %s" missed_str;
    "";
  ]

let _divergence_section (input : input) : string list =
  let actual_by = _actual_picks_by_friday input.actual in
  let optimal_by = _optimal_picks_by_friday input.constrained.round_trips in
  let actual_map = Map.of_alist_exn (module Date) actual_by in
  let optimal_map = Map.of_alist_exn (module Date) optimal_by in
  let all_dates =
    Set.union
      (Set.of_list (module Date) (Map.keys actual_map))
      (Set.of_list (module Date) (Map.keys optimal_map))
    |> Set.to_list
  in
  let divergent =
    List.filter all_dates ~f:(fun d ->
        let actual = Option.value (Map.find actual_map d) ~default:[] in
        let optimal = Option.value (Map.find optimal_map d) ~default:[] in
        _picks_diverge ~actual ~optimal)
  in
  if List.is_empty divergent then
    [
      "## Per-Friday divergence";
      "";
      "_No Fridays where actual and constrained-counterfactual picks differed._";
      "";
    ]
  else
    let header =
      [
        "## Per-Friday divergence";
        "";
        "Fridays where the actual run's entries differ from the \
         constrained-counterfactual's. Sizes are share counts; R is the \
         counterfactual's realized R-multiple.";
        "";
      ]
    in
    let body =
      List.concat_map divergent ~f:(fun d ->
          let actual = Option.value (Map.find actual_map d) ~default:[] in
          let optimal = Option.value (Map.find optimal_map d) ~default:[] in
          _divergence_row ~date:d ~actual ~optimal)
    in
    header @ body

(* ---------------------------------------------------------------- *)
(* Section: trades the actual missed                                  *)
(* ---------------------------------------------------------------- *)

(** Counterfactual round-trips whose symbol does not appear in the actual run.
    Ranked by realized P&L descending. *)
let _missed_trades (input : input) : Optimal_types.optimal_round_trip list =
  let actual_syms =
    input.actual.round_trips
    |> List.map ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
        t.symbol)
    |> Set.of_list (module String)
  in
  input.constrained.round_trips
  |> List.filter ~f:(fun (t : Optimal_types.optimal_round_trip) ->
      not (Set.mem actual_syms t.symbol))
  |> List.sort
       ~compare:(fun
           (a : Optimal_types.optimal_round_trip)
           (b : Optimal_types.optimal_round_trip)
         -> Float.compare b.pnl_dollars a.pnl_dollars)

let _lookup_rejection (input : input) (sym : string) : string option =
  List.find_map input.actual.cascade_rejections ~f:(fun (s, reason) ->
      if String.equal s sym then Some reason else None)

let _missed_trade_row (input : input) (rt : Optimal_types.optimal_round_trip) :
    string =
  let reason_str =
    match _lookup_rejection input rt.symbol with
    | None -> ""
    | Some r -> sprintf " — _%s_" r
  in
  sprintf "| %s | %s | %s | %s | %s | %s%s |" rt.symbol
    (Date.to_string rt.entry_week)
    (Date.to_string rt.exit_week)
    (sprintf "%+.2f" rt.r_multiple)
    (sprintf "$%.2f" rt.pnl_dollars)
    (Sexp.to_string (Optimal_types.sexp_of_exit_trigger rt.exit_trigger))
    reason_str

let _missed_section (input : input) : string list =
  let missed = _missed_trades input in
  if List.is_empty missed then
    [
      "## Trades the actual missed";
      "";
      "_No counterfactual round-trips on symbols the actual run skipped._";
      "";
    ]
  else
    let header =
      [
        "## Trades the actual missed";
        "";
        "Counterfactual round-trips on symbols the actual run never entered, \
         ranked by realized P&L. Cascade-rejection reasons (when captured by \
         the audit) are quoted inline.";
        "";
        "| Symbol | Entry | Exit | R | P&L | Trigger |";
        "|---|---|---|---:|---:|---|";
      ]
    in
    let body = List.map missed ~f:(_missed_trade_row input) in
    header @ body @ [ "" ]

(* ---------------------------------------------------------------- *)
(* Section: implications                                              *)
(* ---------------------------------------------------------------- *)

(** [optimal_total_return / actual_total_return]. Returns [None] when the actual
    return is non-positive (ratio undefined / sign-degenerate). *)
let _ratio_constrained_to_actual (input : input) : float option =
  let actual = _actual_total_return_pct input.actual in
  let optimal = _frac_to_pct input.constrained.summary.total_return_pct in
  if Float.(actual <= 0.0) then None else Some (optimal /. actual)

let _implications_narrative (input : input) : string =
  match _ratio_constrained_to_actual input with
  | None ->
      "Actual return was non-positive; counterfactual ratio is degenerate. \
       Inspect the divergence table directly — the cascade may be admitting \
       too few candidates, or the macro gate may be over-restrictive."
  | Some r when Float.(r > 3.0) ->
      sprintf
        "Constrained-counterfactual return is %.1f× the actual run's. The \
         cascade is significantly mis-scoring opportunities — material gains \
         are reachable via re-weighting alone, without relaxing the macro gate \
         or sector caps."
        r
  | Some r when Float.(r < 1.5) ->
      sprintf
        "Constrained-counterfactual return is %.1f× the actual run's — the \
         cascade is near-optimal under the current envelope. Further upside \
         requires structural changes (envelope, gate thresholds, or additional \
         signals)."
        r
  | Some r ->
      sprintf
        "Constrained-counterfactual return is %.1f× the actual run's. Moderate \
         cascade-ranking improvement is reachable; structural changes \
         (envelope / gate / signals) are also needed for full upside."
        r

let _implications_section (input : input) : string list =
  [ "## Implications"; ""; _implications_narrative input; "" ]

(* ---------------------------------------------------------------- *)
(* Top-level                                                          *)
(* ---------------------------------------------------------------- *)

let render (input : input) : string =
  let lines =
    _section_header input @ _headline_section input @ _divergence_section input
    @ _missed_section input
    @ _implications_section input
  in
  String.concat ~sep:"\n" lines ^ "\n"
