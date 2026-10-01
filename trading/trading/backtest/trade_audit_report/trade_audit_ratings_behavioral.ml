(** Behavioural-metric computation (over-trading, exit winners/losers, cascade
    quartiles, entering losers) and the audit/trade join helpers they share.
    Re-exported by [Trade_audit_ratings]; see its .mli for the contract. *)

open Core
open Trade_audit_ratings_types

(** Max calendar-day gap tolerated when joining a [trades.csv] round-trip to its
    audit record (and back). The audit [entry_date] is the Friday decision date;
    the round-trip [entry_date] is the actual fill (next trading day), so the
    two differ by 1-3 days across a weekend. A week bridges that without
    cross-matching a distinct re-entry of the same symbol. Kept in sync with
    [Trade_audit_report]'s join tolerance. *)
let join_tolerance_days = 7

(* From [candidates] sharing a symbol, return the one whose [date_of] is closest
   to [entry_date], within [join_tolerance_days]. *)
let nearest_within ~entry_date ~date_of candidates =
  List.filter_map candidates ~f:(fun c ->
      let gap = Int.abs (Date.diff (date_of c) entry_date) in
      if gap <= join_tolerance_days then Some (gap, c) else None)
  |> List.min_elt ~compare:(fun (g1, _) (g2, _) -> Int.compare g1 g2)
  |> Option.map ~f:snd

let audit_index audit =
  List.fold audit
    ~init:(Map.empty (module String))
    ~f:(fun acc (record : Backtest.Trade_audit.audit_record) ->
      Map.add_multi acc ~key:record.entry.symbol ~data:record)

(* Behavioural metric (a) — over-trading ---------------------------------- *)

let _years_observed_of trades =
  let starts =
    List.map trades ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
        t.entry_date)
  in
  let ends =
    List.map trades ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
        t.exit_date)
  in
  match
    ( List.min_elt starts ~compare:Date.compare,
      List.max_elt ends ~compare:Date.compare )
  with
  | Some s, Some e ->
      let days = Date.diff e s in
      if days <= 0 then Float.nan else Float.of_int days /. 365.25
  | _ -> Float.nan

let _burst_outliers_of ~window_days trades =
  let by_symbol =
    List.fold trades
      ~init:(Map.empty (module String))
      ~f:(fun acc (t : Trading_simulation.Metrics.trade_metrics) ->
        Map.update acc t.symbol ~f:(function
          | None -> [ t ]
          | Some xs -> t :: xs))
  in
  Map.fold by_symbol ~init:[] ~f:(fun ~key:_ ~data:ts acc ->
      let sorted =
        List.sort ts ~compare:(fun a b ->
            Date.compare a.Trading_simulation.Metrics.entry_date b.entry_date)
      in
      let in_burst =
        List.filter sorted
          ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
            List.exists sorted
              ~f:(fun (other : Trading_simulation.Metrics.trade_metrics) ->
                (not (Date.equal other.entry_date t.entry_date))
                && Int.abs (Date.diff t.entry_date other.entry_date)
                   <= window_days))
      in
      List.map in_burst ~f:(fun t ->
          {
            symbol = t.Trading_simulation.Metrics.symbol;
            entry_date = t.entry_date;
            metric =
              sprintf "within %dd of another %s entry" window_days t.symbol;
          })
      @ acc)

let _over_trading ~config ~trades : over_trading =
  let total_trades = List.length trades in
  let years = _years_observed_of trades in
  let trades_per_year =
    if Float.is_nan years || Float.( <= ) years 0.0 then Float.nan
    else Float.of_int total_trades /. years
  in
  let exceeds =
    (not (Float.is_nan trades_per_year))
    && Float.( > ) trades_per_year (Float.of_int config.trades_per_year_warn)
  in
  let outliers =
    _burst_outliers_of ~window_days:config.concentrated_burst_window_days trades
  in
  let burst_pct =
    if total_trades = 0 then 0.0
    else
      Float.of_int (List.length outliers) /. Float.of_int total_trades *. 100.0
  in
  {
    total_trades;
    trades_per_year;
    exceeds_threshold = exceeds;
    concentrated_burst_pct = burst_pct;
    outliers;
  }

(* Behavioural metric (b) — exit winners too early ------------------------ *)

let _exit_winners ~config ~ratings ~trades : exit_winners_too_early =
  let trade_idx =
    List.fold trades
      ~init:(Map.empty (module String))
      ~f:(fun acc (t : Trading_simulation.Metrics.trade_metrics) ->
        Map.add_multi acc ~key:t.symbol ~data:t)
  in
  let winners = List.filter ratings ~f:(fun r -> equal_outcome r.outcome Win) in
  let realized_pct (r : rating) =
    match Map.find trade_idx r.symbol with
    | None -> 0.0
    | Some trades -> (
        match
          nearest_within ~entry_date:r.entry_date
            ~date_of:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
              t.entry_date)
            trades
        with
        | Some (t : Trading_simulation.Metrics.trade_metrics) ->
            t.pnl_percent /. 100.0
        | None -> 0.0)
  in
  let gaps = List.map winners ~f:(fun r -> (r, r.mfe_pct -. realized_pct r)) in
  let flagged =
    List.filter gaps ~f:(fun (r, _) ->
        let realized_frac = realized_pct r in
        Float.( > ) r.mfe_pct 0.0
        && Float.( < ) realized_frac
             (config.exit_early_mfe_fraction *. r.mfe_pct))
  in
  let avg_gap =
    match gaps with
    | [] -> 0.0
    | _ ->
        let total = List.fold gaps ~init:0.0 ~f:(fun acc (_, g) -> acc +. g) in
        total /. Float.of_int (List.length gaps) *. 100.0
  in
  let outliers =
    List.map flagged ~f:(fun (r, gap) ->
        {
          symbol = r.symbol;
          entry_date = r.entry_date;
          metric = sprintf "left %.2fpp on the table" (gap *. 100.0);
        })
  in
  {
    winners_evaluated = List.length winners;
    flagged_count = List.length flagged;
    avg_left_on_table_pct = avg_gap;
    outliers;
  }

(* Behavioural metric (c) — exit losers too late -------------------------- *)

let _exit_losers ~config ~ratings : exit_losers_too_late =
  let losers = List.filter ratings ~f:(fun r -> equal_outcome r.outcome Loss) in
  let stop_disciplined =
    List.count losers ~f:(fun r ->
        (not (Float.is_nan r.r_multiple))
        && Float.( <= ) (Float.abs r.r_multiple) 1.0)
  in
  let flagged =
    List.filter losers ~f:(fun r ->
        Float.is_nan r.r_multiple
        || Float.( > ) (Float.abs r.r_multiple)
             config.loser_r_multiple_threshold
        ||
        let mae_r = Float.abs r.mae_pct in
        let realized_r = Float.abs r.r_multiple in
        Float.( > ) realized_r 0.0
        && Float.( >= ) mae_r (config.loser_mae_to_realized_ratio *. realized_r))
  in
  let outliers =
    List.map flagged ~f:(fun r ->
        {
          symbol = r.symbol;
          entry_date = r.entry_date;
          metric =
            sprintf "realized R=%.2f, MAE=%.2f%%" r.r_multiple
              (r.mae_pct *. 100.0);
        })
  in
  let stop_pct =
    if List.is_empty losers then 0.0
    else
      Float.of_int stop_disciplined
      /. Float.of_int (List.length losers)
      *. 100.0
  in
  {
    losers_evaluated = List.length losers;
    flagged_count = List.length flagged;
    stop_discipline_pct = stop_pct;
    outliers;
  }

(* Cascade quartile bucketing --------------------------------------------- *)

(** Rank-based quartile: sort scores ascending, split by index into 4 equal
    chunks. Q1_top = top quartile (highest scores), Q4_bottom = lowest. Ties
    handled by sort stability (input order preserved). *)
let _quartile_of_index ~total i =
  if total <= 0 then Q4_bottom
  else
    let q1_cutoff = total / 4 in
    let q2_cutoff = total / 2 in
    let q3_cutoff = 3 * total / 4 in
    if i < q1_cutoff then Q1_top
    else if i < q2_cutoff then Q2
    else if i < q3_cutoff then Q3
    else Q4_bottom

let quartile_assignments_by_score ~audit (ratings : rating list) :
    (rating * cascade_quartile) list =
  let idx = audit_index audit in
  let with_score =
    List.filter_map ratings ~f:(fun (r : rating) ->
        match Map.find idx r.symbol with
        | None -> None
        | Some records ->
            nearest_within ~entry_date:r.entry_date
              ~date_of:(fun (a : Backtest.Trade_audit.audit_record) ->
                a.entry.entry_date)
              records
            |> Option.map ~f:(fun (a : Backtest.Trade_audit.audit_record) ->
                (r, a.entry.cascade_score)))
  in
  let sorted_desc =
    List.sort with_score ~compare:(fun (_, sa) (_, sb) -> Int.compare sb sa)
  in
  let total = List.length sorted_desc in
  List.mapi sorted_desc ~f:(fun i (r, _) -> (r, _quartile_of_index ~total i))

let quartile_stats (assignments : (rating * cascade_quartile) list) =
  let bucket_of q (rs : rating list) =
    let n = List.length rs in
    let wins = List.count rs ~f:(fun r -> equal_outcome r.outcome Win) in
    let pct =
      if n = 0 then 0.0 else Float.of_int wins /. Float.of_int n *. 100.0
    in
    { quartile = q; trade_count = n; win_count = wins; win_rate_pct = pct }
  in
  let pick q =
    List.filter_map assignments ~f:(fun (r, q') ->
        if equal_cascade_quartile q q' then Some r else None)
  in
  List.map [ Q1_top; Q2; Q3; Q4_bottom ] ~f:(fun q -> bucket_of q (pick q))

(* Behavioural metric (d) — entering losers too often --------------------- *)

let _entering_losers ~audit ~ratings : entering_losers_often =
  let assignments = quartile_assignments_by_score ~audit ratings in
  let per_quartile = quartile_stats assignments in
  let bottom_losers =
    List.filter assignments ~f:(fun (r, q) ->
        equal_cascade_quartile q Q4_bottom && equal_outcome r.outcome Loss)
  in
  let top_losers =
    List.filter assignments ~f:(fun (r, q) ->
        equal_cascade_quartile q Q1_top && equal_outcome r.outcome Loss)
  in
  let outliers =
    List.map bottom_losers ~f:(fun (r, _) ->
        {
          symbol = r.symbol;
          entry_date = r.entry_date;
          metric = "bottom-quartile entry became loser (cascade mis-scoring)";
        })
    @ List.map top_losers ~f:(fun (r, _) ->
        {
          symbol = r.symbol;
          entry_date = r.entry_date;
          metric = "top-quartile entry became loser (blind spot)";
        })
  in
  { per_quartile; flagged_count = List.length outliers; outliers }

let behavioral_metrics_of ~config ~ratings ~audit ~trades : behavioral_metrics =
  {
    over_trading = _over_trading ~config ~trades;
    exit_winners_too_early = _exit_winners ~config ~ratings ~trades;
    exit_losers_too_late = _exit_losers ~config ~ratings;
    entering_losers_often = _entering_losers ~audit ~ratings;
  }
