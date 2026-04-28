(** Per-trade decision-trail logging for backtest diagnostics.

    See [trade_audit.mli] for the API contract. *)

open Core

(* Types ------------------------------------------------------------------ *)

type skip_reason =
  | Insufficient_cash
  | Already_held
  | Below_min_grade
  | Sized_to_zero
  | Sector_concentration
  | Top_n_cutoff
[@@deriving sexp]

type alternative_candidate = {
  symbol : string;
  side : Trading_base.Types.position_side;
  score : int;
  grade : Weinstein_types.grade;
  reason_skipped : skip_reason;
}
[@@deriving sexp]

type stop_floor_kind = Support_floor | Buffer_fallback [@@deriving sexp]

type entry_decision = {
  symbol : string;
  entry_date : Date.t;
  position_id : string;
  macro_trend : Weinstein_types.market_trend;
  macro_confidence : float;
  macro_indicators : Macro.indicator_reading list;
  stage : Weinstein_types.stage;
  ma_direction : Weinstein_types.ma_direction;
  ma_slope_pct : float;
  rs_trend : Weinstein_types.rs_trend option;
  rs_value : float option;
  volume_quality : Weinstein_types.volume_confirmation option;
  resistance_quality : Weinstein_types.overhead_quality option;
  support_quality : Weinstein_types.overhead_quality option;
  sector_name : string;
  sector_rating : Screener.sector_rating;
  cascade_score : int;
  cascade_grade : Weinstein_types.grade;
  cascade_score_components : (string * int) list;
  cascade_rationale : string list;
  side : Trading_base.Types.position_side;
  suggested_entry : float;
  suggested_stop : float;
  installed_stop : float;
  stop_floor_kind : stop_floor_kind;
  risk_pct : float;
  initial_position_value : float;
  initial_risk_dollars : float;
  alternatives_considered : alternative_candidate list;
}
[@@deriving sexp]

type exit_decision = {
  symbol : string;
  exit_date : Date.t;
  position_id : string;
  exit_trigger : Stop_log.exit_trigger;
  macro_trend_at_exit : Weinstein_types.market_trend;
  macro_confidence_at_exit : float;
  stage_at_exit : Weinstein_types.stage;
  rs_trend_at_exit : Weinstein_types.rs_trend option;
  distance_from_ma_pct : float;
  max_favorable_excursion_pct : float;
  max_adverse_excursion_pct : float;
  weeks_macro_was_bearish : int;
  weeks_stage_left_2 : int;
}
[@@deriving sexp]

type audit_record = { entry : entry_decision; exit_ : exit_decision option }
[@@deriving sexp]

type cascade_summary = {
  date : Date.t;
  total_stocks : int;
  candidates_after_held : int;
  macro_trend : Weinstein_types.market_trend;
  long_macro_admitted : int;
  long_breakout_admitted : int;
  long_sector_admitted : int;
  long_grade_admitted : int;
  long_top_n_admitted : int;
  short_macro_admitted : int;
  short_breakdown_admitted : int;
  short_sector_admitted : int;
  short_rs_hard_gate_admitted : int;
  short_grade_admitted : int;
  short_top_n_admitted : int;
  entered : int;
}
[@@deriving sexp]

type audit_blob = {
  audit_records : audit_record list;
  cascade_summaries : cascade_summary list;
}
[@@deriving sexp]

(* Collector -------------------------------------------------------------- *)

type _bucket = {
  bucket_entry : entry_decision;
  mutable bucket_exit : exit_decision option;
}
(** Internal mutable bucket. [exit_] is added to a record when the matching
    entry has already been recorded; otherwise the exit is dropped. *)

type t = {
  records : (string, _bucket) Hashtbl.t;
  cascade_summaries : cascade_summary Queue.t;
      (** Per-Friday cascade summaries, recorded in insertion order. Sorted by
          [date] ascending on retrieval — the strategy emits one per Friday
          screen call, but ordering across multiple backtests / threads is not
          relied on. *)
}

let create () =
  {
    records = Hashtbl.create (module String);
    cascade_summaries = Queue.create ();
  }

let record_entry t (entry : entry_decision) =
  Hashtbl.set t.records ~key:entry.position_id
    ~data:{ bucket_entry = entry; bucket_exit = None }

let record_exit t (exit_ : exit_decision) =
  match Hashtbl.find t.records exit_.position_id with
  | None -> ()
  | Some bucket -> bucket.bucket_exit <- Some exit_

let record_cascade_summary t (summary : cascade_summary) =
  Queue.enqueue t.cascade_summaries summary

let _bucket_to_record (bucket : _bucket) : audit_record =
  { entry = bucket.bucket_entry; exit_ = bucket.bucket_exit }

let _compare_by_position_id (a : audit_record) (b : audit_record) =
  String.compare a.entry.position_id b.entry.position_id

let _compare_by_date (a : cascade_summary) (b : cascade_summary) =
  Date.compare a.date b.date

let get_audit_records t : audit_record list =
  Hashtbl.fold t.records ~init:[] ~f:(fun ~key:_ ~data:bucket acc ->
      _bucket_to_record bucket :: acc)
  |> List.sort ~compare:_compare_by_position_id

let get_cascade_summaries t : cascade_summary list =
  Queue.to_list t.cascade_summaries |> List.sort ~compare:_compare_by_date

let get_audit_blob t : audit_blob =
  {
    audit_records = get_audit_records t;
    cascade_summaries = get_cascade_summaries t;
  }

(* Sexp persistence ------------------------------------------------------- *)

let sexp_of_audit_records (records : audit_record list) : Sexp.t =
  [%sexp_of: audit_record list] records

let audit_records_of_sexp (sexp : Sexp.t) : audit_record list =
  [%of_sexp: audit_record list] sexp

let sexp_of_audit_blob (blob : audit_blob) : Sexp.t =
  [%sexp_of: audit_blob] blob

let audit_blob_of_sexp (sexp : Sexp.t) : audit_blob =
  [%of_sexp: audit_blob] sexp
