(** Shadow screener adapter — see [shadow_screener.mli]. *)

open Core

(** [_ma_direction_of_stage] is the conservative proxy for MA direction when the
    only stage signal we have is the Weinstein stage variant. A Stage2 stock has
    a rising MA by definition; a Stage4 stock has a falling MA; Stage1 and
    Stage3 are base-building or distribution respectively, both with a flat MA.
    The screener does not read [ma_direction] directly — it reads [stage] and
    [prior_stage] — so this value is largely cosmetic but we keep it consistent
    so debug output is not misleading. *)
let _ma_direction_of_stage (stage : Weinstein_types.stage) :
    Weinstein_types.ma_direction =
  match stage with
  | Stage2 _ -> Rising
  | Stage4 _ -> Declining
  | Stage1 _ | Stage3 _ -> Flat

(** [_synthesize_stage_result] builds a [Stage.result] from Summary data. The
    placeholder fields ([ma_slope_pct], [above_ma_count]) are documented in the
    .mli as unused by the screener. [transition] is populated when [prior_stage]
    differs from the current stage — matches [Stage.classify]'s contract. *)
let _synthesize_stage_result ~(summary : Summary_compute.summary_values)
    ~prior_stage : Stage.result =
  let transition =
    match prior_stage with
    | None -> None
    | Some prev when not (Weinstein_types.equal_stage prev summary.stage) ->
        Some (prev, summary.stage)
    | Some _ -> None
  in
  {
    stage = summary.stage;
    ma_value = summary.ma_30w;
    ma_direction = _ma_direction_of_stage summary.stage;
    ma_slope_pct = 0.0;
    transition;
    above_ma_count = 0;
  }

(** [_synthesize_rs_result] projects [rs_line] into an [Rs.result]. The
    classification is binary — values at or above the Mansfield zero line (1.0)
    are treated as [Positive_rising], values below as [Negative_declining]. The
    [Positive_flat] / [Negative_improving] / crossover variants are unreachable
    by design; see the .mli "Known divergence" section. [history] is [[]]
    because the screener does not read it. *)
let _synthesize_rs_result ~(summary : Summary_compute.summary_values) :
    Rs.result =
  let trend : Weinstein_types.rs_trend =
    if Float.(summary.rs_line >= 1.0) then Positive_rising
    else Negative_declining
  in
  {
    current_rs = summary.rs_line;
    current_normalized = summary.rs_line;
    trend;
    history = [];
  }

(** [_synthesize_volume_result] returns a placeholder [Adequate 1.5]
    confirmation for Stage2 / Stage4 stubs, and [None] for Stage1 / Stage3. The
    floor of the Adequate band is the minimum value
    [Stock_analysis.is_breakout_candidate] / [is_breakdown_candidate] accept —
    without it the shadow screener would never produce candidates because volume
    data isn't retained at the Summary tier. The synthesis deliberately
    collapses Strong/Adequate/Weak into a single value; see the .mli "Known
    divergence" section. *)
let _synthesize_volume_result ~(summary : Summary_compute.summary_values) :
    Volume.result option =
  let open Weinstein_types in
  match summary.stage with
  | Stage2 _ | Stage4 _ ->
      Some
        {
          confirmation = Adequate 1.5;
          event_volume = 0;
          avg_volume = 0.0;
          volume_ratio = 1.5;
        }
  | Stage1 _ | Stage3 _ -> None

let synthesize_analysis ~summary ~ticker ~prior_stage ~as_of : Stock_analysis.t
    =
  {
    ticker;
    stage = _synthesize_stage_result ~summary ~prior_stage;
    rs = Some (_synthesize_rs_result ~summary);
    volume = _synthesize_volume_result ~summary;
    resistance = None;
    breakout_price = None;
    prior_stage;
    as_of_date = as_of;
  }

(** [_collect_analyses] walks the requested universe of summaries and builds
    synthesized analyses, updating [prior_stages] in place so the next call sees
    the current stage as the prior — same contract as [_screen_universe] in the
    Legacy path. *)
let _collect_analyses ~summaries ~prior_stages ~as_of : Stock_analysis.t list =
  List.map summaries ~f:(fun (ticker, summary) ->
      let prior_stage = Hashtbl.find prior_stages ticker in
      let analysis = synthesize_analysis ~summary ~ticker ~prior_stage ~as_of in
      Hashtbl.set prior_stages ~key:ticker ~data:summary.Summary_compute.stage;
      analysis)

let screen ~summaries ~config ~macro_trend ~sector_map ~prior_stages
    ~held_tickers ~as_of =
  let stocks = _collect_analyses ~summaries ~prior_stages ~as_of in
  Screener.screen ~config ~macro_trend ~sector_map ~stocks ~held_tickers
