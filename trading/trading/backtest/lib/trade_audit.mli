(** Per-trade decision-trail logging for backtest diagnostics.

    Captures, for every position the strategy enters:
    - The macro / stage / RS / volume / resistance state at decision time.
    - The cascade score + grade + rationale that produced the entry.
    - The alternative candidates considered at the same screen call but not
      chosen (with a reason).
    - The state at exit time (macro/stage/RS at exit, MAE/MFE during the hold,
      counters for how long macro was bearish or stage left 2 during the hold).

    Mirrors the shape of {!Stop_log}: a mutable, in-strategy observer collector
    seeded by capture sites in the strategy + simulator path, then drained at
    end-of-run into [Runner.result.audit]. Persisted as [trade_audit.sexp]
    alongside [trades.csv] when non-empty.

    PR-1 of the trade-audit plan ships the module + persistence plumbing.
    Capture-site wiring lives in PR-2; until then the collector is always empty
    and no [trade_audit.sexp] file is written.

    See [dev/plans/trade-audit-2026-04-28.md]. *)

open Core

(** {1 Types} *)

(** Why a candidate the screener returned was not actually entered.

    Populated by the strategy at sizing time, when it walks the screener's
    ranked candidate list and skips entries for portfolio-level reasons (cash,
    sector caps) or quality-floor reasons (sized to zero, below min grade). *)
type skip_reason =
  | Insufficient_cash
      (** Skipped because the portfolio did not have cash to size a meaningful
          position. *)
  | Already_held
      (** Skipped because the symbol was already in the portfolio. *)
  | Below_min_grade
      (** Skipped because the candidate's grade fell below the configured min.
      *)
  | Sized_to_zero
      (** Skipped because position-sizing rounded the share count down to 0. *)
  | Sector_concentration
      (** Skipped because the sector was at or above its concentration cap. *)
  | Top_n_cutoff
      (** Skipped because the candidate fell outside the top-N cap. *)
[@@deriving sexp]

type alternative_candidate = {
  symbol : string;
  side : Trading_base.Types.position_side;
  score : int;
  grade : Weinstein_types.grade;
  reason_skipped : skip_reason;
}
[@@deriving sexp]
(** A screener candidate that was scored at decision time but not entered. *)

(** Whether the installed initial stop sat on a support floor or fell back to a
    fixed-buffer stop below the screener's suggested level. Routed from
    [Weinstein_stops.compute_initial_stop_with_floor]. *)
type stop_floor_kind = Support_floor | Buffer_fallback [@@deriving sexp]

type entry_decision = {
  symbol : string;
  entry_date : Date.t;
  position_id : string;  (** Matches [Stop_log.stop_info.position_id]. *)
  (* Macro state at decision time. *)
  macro_trend : Weinstein_types.market_trend;
  macro_confidence : float;
  macro_indicators : Macro.indicator_reading list;
  (* Symbol-level analysis at decision time. *)
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
  (* Cascade outcome. *)
  cascade_score : int;
  cascade_grade : Weinstein_types.grade;
  cascade_score_components : (string * int) list;
      (** Itemised score breakdown — e.g.
          [("stage2_breakout", 30); ("strong_volume", 20)]. Built at the
          screener boundary in PR-2. *)
  cascade_rationale : string list;
  side : Trading_base.Types.position_side;
  (* Sizing + stop. *)
  suggested_entry : float;
  suggested_stop : float;  (** From the screener. *)
  installed_stop : float;
      (** After [Weinstein_stops.compute_initial_stop_with_floor] applies the
          initial-stop buffer. *)
  stop_floor_kind : stop_floor_kind;
  risk_pct : float;
  initial_position_value : float;
  initial_risk_dollars : float;  (** [(entry - stop) * qty]. *)
  alternatives_considered : alternative_candidate list;
      (** Top-N candidates from the same screen call that were not entered.
          Empty when the screener returned no other candidates that round. *)
}
[@@deriving sexp]
(** Decision trail captured at entry. *)

type exit_decision = {
  symbol : string;
  exit_date : Date.t;
  position_id : string;
  exit_trigger : Stop_log.exit_trigger;
  (* Macro state at exit. *)
  macro_trend_at_exit : Weinstein_types.market_trend;
  macro_confidence_at_exit : float;
  (* Symbol-level state at exit. *)
  stage_at_exit : Weinstein_types.stage;
  rs_trend_at_exit : Weinstein_types.rs_trend option;
  distance_from_ma_pct : float;  (** [(close - ma) / ma]. *)
  (* Holding-period summary captured by the simulator step stream. *)
  max_favorable_excursion_pct : float;
      (** Peak unrealized gain during the hold, as a fraction of entry price. *)
  max_adverse_excursion_pct : float;
      (** Trough unrealized loss during the hold, as a fraction of entry price.
      *)
  weeks_macro_was_bearish : int;
      (** Friday count where macro flipped Bearish during the hold. *)
  weeks_stage_left_2 : int;
      (** Friday count where stage was not Stage 2 during the hold. *)
}
[@@deriving sexp]
(** State captured at exit. *)

type audit_record = { entry : entry_decision; exit_ : exit_decision option }
[@@deriving sexp]
(** A paired entry + exit record. [exit_] is [None] for positions that were
    still open at end-of-run.

    Field name [exit_] (rather than [exit]) avoids shadowing [Stdlib.exit]. *)

type cascade_summary = {
  date : Date.t;
      (** Friday on which the cascade ran — same date the strategy passed into
          {!Screener.screen}. *)
  total_stocks : int;
      (** Number of stocks input to the screener post strategy-side phase 1 +
          sector pre-filter. *)
  candidates_after_held : int;
      (** [total_stocks] minus already-held tickers. *)
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
      (** Of the screener's combined top-N candidates, how many actually got
          entered (count of {!Position.transition}s emitted). Sits below
          [long_top_n_admitted + short_top_n_admitted] because cash limits,
          sector concentration, and round-share sizing all drop further
          candidates between the screener output and actual entry. *)
}
[@@deriving sexp]
(** Per-Friday cascade-rejection counts — complements [audit_record]'s per-trade
    decision trail.

    Where [audit_record] captures only the candidates that were ENTERED (plus
    their immediate rivals via [alternatives_considered]), [cascade_summary]
    captures the full per-phase admission-count history: candidates the cascade
    EVALUATED but did NOT admit.

    Lets the audit answer "did the macro gate ever block a candidate", "was the
    sector filter trivially permissive", "did the RS hard gate ever filter
    shorts" — questions [audit_record] alone cannot answer because filtered
    candidates never reach the per-entry record's alternatives bucket. *)

type audit_blob = {
  audit_records : audit_record list;
  cascade_summaries : cascade_summary list;
}
[@@deriving sexp]
(** Combined persistence envelope for [trade_audit.sexp]. Holds both the
    per-trade decision trail and the per-Friday cascade-rejection counts in a
    single sexp file. *)

(** {1 Collector} *)

type t
(** Mutable collector of audit records. One per backtest run. Not safe to share
    across threads. *)

val create : unit -> t
(** Create an empty collector. *)

val record_entry : t -> entry_decision -> unit
(** Record an entry decision. Keyed by [decision.position_id]; recording the
    same id twice overwrites the prior entry. *)

val record_exit : t -> exit_decision -> unit
(** Record an exit decision. Looks up the matching [entry] by
    [decision.position_id]; if no entry was previously recorded for that id the
    exit is dropped (the strategy never entered the position via this audit
    surface). *)

val record_cascade_summary : t -> cascade_summary -> unit
(** Append a per-Friday cascade summary. Append-only — recording two summaries
    with the same [date] keeps both. *)

val get_audit_records : t -> audit_record list
(** Return all audit records, sorted by [position_id]. Records with no exit yet
    recorded (positions still open) carry [exit_ = None]. *)

val get_cascade_summaries : t -> cascade_summary list
(** Return all per-Friday cascade summaries, sorted by [date] ascending. *)

val get_audit_blob : t -> audit_blob
(** Return the combined audit-records + cascade-summaries snapshot. Equivalent
    to
    [{ audit_records = get_audit_records t; cascade_summaries =
     get_cascade_summaries t }]. *)

(** {1 Sexp persistence} *)

val sexp_of_audit_records : audit_record list -> Sexp.t
(** Serialize an audit-record list as a single sexp. Round-trips with
    [audit_records_of_sexp]. *)

val audit_records_of_sexp : Sexp.t -> audit_record list
(** Parse an audit-record list from a sexp. Inverse of [sexp_of_audit_records].
*)

val sexp_of_audit_blob : audit_blob -> Sexp.t
(** Serialize the combined audit-records + cascade-summaries snapshot as a
    single sexp. Inverse of {!audit_blob_of_sexp}. *)

val audit_blob_of_sexp : Sexp.t -> audit_blob
(** Parse a combined audit-records + cascade-summaries snapshot from sexp.
    Inverse of {!sexp_of_audit_blob}. *)
