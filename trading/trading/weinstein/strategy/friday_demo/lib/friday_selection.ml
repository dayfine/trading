open Core
open Friday_trace
module WS = Weinstein_strategy
module Audit_recorder = WS.Audit_recorder

let _entry_for ~(entries : Audit_recorder.entry_event list)
    (d : Audit_recorder.walk_decision) =
  match d.outcome with
  | Skipped _ -> None
  | Placed ->
      List.find entries ~f:(fun e ->
          String.equal e.candidate.ticker d.ranked.ticker)

(* The walk draws each placed ticket's cost from cash, in walk order. *)
let _cost (entry : Audit_recorder.entry_event option) =
  Option.value_map entry ~default:0.0 ~f:(fun e -> e.initial_position_value)

let _walk_row ~gate_stop ~entries cash_before (d : Audit_recorder.walk_decision)
    =
  let entry = _entry_for ~entries d in
  let cash_after = cash_before -. _cost entry in
  let row =
    {
      candidate = d.ranked;
      outcome = d.outcome;
      gate = gate_stop d.ranked;
      entry;
      cash_before;
      cash_after;
    }
  in
  (cash_after, row)

let initial_stop_buffer (config : WS.Weinstein_strategy_config.config)
    ~(macro : Macro.result) =
  WS.Stop_buffer_by_state.buffer_for config.initial_stop_buffer_by_macro_state
    ~fallback:config.initial_stop_buffer ~state:macro.breadth_state

let walk_rows (config : WS.Weinstein_strategy_config.config) ~bar_reader ~date
    ~macro ~cash ~entries decisions =
  let initial_stop_buffer = initial_stop_buffer config ~macro in
  let gate_stop =
    WS.Entry_stop_width_order.gate_stop ~initial_stop_buffer ~config ~bar_reader
      ~current_date:date
  in
  List.folding_map decisions ~init:cash ~f:(_walk_row ~gate_stop ~entries)

let _is_ranked (d : Audit_recorder.cascade_drop) =
  match d.outcome.phase with
  | Admitted | Dropped_at_top_n -> true
  | Dropped_at_macro | Dropped_at_breakout _ | Dropped_at_sector | Dropped_at_rs
  | Dropped_at_grade ->
      false

(* [price] is read only by [Price_band_seeded]. A walk candidate carries its
   ticket price; a name cut at top-N does not, so it falls back to its close. *)
let _rankable ~walk (d : Audit_recorder.cascade_drop) : Screener.rankable =
  let ticket_price =
    List.find_map walk ~f:(fun (w : walk_row) ->
        Option.some_if
          (String.equal w.candidate.ticker d.outcome.ticker)
          w.candidate.suggested_entry)
  in
  {
    score = d.outcome.score;
    ticker = d.outcome.ticker;
    price =
      Option.value ticket_price
        ~default:(Option.value d.analysis.current_close ~default:0.0);
    analysis = d.analysis;
  }

let _tiebreak_key (sc : Screener.config) ~date ticker =
  match sc.candidate_ranking with
  | Seeded | Price_band_seeded ->
      Some
        (Screener.seeded_tiebreak_key ~tiebreak_seed:sc.tiebreak_seed
           ~as_of:date ticker)
  | Alphabetical | Quality | Quality_earliness | Reverse_alphabetical
  | Symbol_length | Hash_order ->
      None

let _ranked_row sc ~date (d : Audit_recorder.cascade_drop) : ranked_row =
  {
    ticker = d.outcome.ticker;
    side = d.side;
    score = d.outcome.score;
    grade = d.outcome.grade;
    tiebreak_key = _tiebreak_key sc ~date d.outcome.ticker;
    above_cut = Screener.equal_cascade_phase d.outcome.phase Admitted;
  }

let ranking (config : WS.Weinstein_strategy_config.config) ~date ~walk drops =
  let sc = config.screening_config in
  let compare a b =
    Screener.compare_rankable ~tiebreak_seed:sc.tiebreak_seed ~as_of:date
      ~price_band_edges:sc.ranking_price_band_edges sc.candidate_ranking
      (_rankable ~walk a) (_rankable ~walk b)
  in
  let on_side side =
    List.filter drops ~f:(fun (d : Audit_recorder.cascade_drop) ->
        _is_ranked d && Trading_base.Types.equal_position_side d.side side)
    |> List.sort ~compare
  in
  List.map (on_side Long @ on_side Short) ~f:(_ranked_row sc ~date)
