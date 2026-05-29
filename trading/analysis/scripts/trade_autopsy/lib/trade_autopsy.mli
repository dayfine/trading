(** Trade-autopsy classifier.

    Consumes the round-trip trade list produced by
    {!Per_symbol_stage_strategy_lib.Single_symbol_backtest} for a single symbol,
    together with the weekly bar series the strategy walked, and classifies each
    long trade against the four gain-capture failure modes enumerated in
    [dev/notes/next-session-priorities-2026-05-29.md] §P3:

    1. [Stage3_false_positive] — exit was a Stage 3 transition, but the symbol
    recovered into Stage-2 territory within [stage3_recovery_weeks] (gained at
    least [stage3_recovery_pct] above the exit price). 2. [Late_reentry] — after
    exit, the next re-entry took longer than [late_reentry_weeks] AND the symbol
    price ran more than [late_reentry_pct] between exit and re-entry. 3.
    [Late_stage2_admission] — entry occurred more than [late_stage2_weeks] after
    the prior cyclical low (in the [late_stage2_lookback_weeks]-week lookback
    ending at entry). 4. [Stop_out_whipsaw] — exit was a stop-out, and price
    recovered above the exit price by [stop_whipsaw_pct] within
    [stop_whipsaw_weeks]. INERT under the per-symbol stage strategy input (which
    has no stops) but exposed for strategies that do.

    All classification thresholds come from {!Trade_autopsy_config.t}.

    Pure functions. *)

open Core
module Walk_step = Per_symbol_stage_strategy_lib.Walk_step

(** Trade side. Mirrors {!Walk_step.trade.variant_side} but as a plain ADT so
    the autopsy record can derive sexp without pulling in the strategy module's
    serializers. *)
type trade_side = Long_side | Short_side [@@deriving show, eq, sexp]

(** Exit-reason classification for a closed trade. Re-exported from
    {!Exit_reason.t} so consumers can pattern-match using
    [Trade_autopsy.<Variant>] without depending directly on the [Exit_reason]
    module. See {!Exit_reason.t} for per-variant documentation. *)
type exit_reason = Exit_reason.t =
  | Stage3_exit
  | Stage1_cover_short
  | End_of_period
  | Stop_out
  | Stage4_decline
  | Laggard_rotation
[@@deriving show, eq, sexp]

type failure_modes = {
  stage3_false_positive : bool;
  late_reentry : bool;
  late_stage2_admission : bool;
  stop_out_whipsaw : bool;
}
[@@deriving show, eq, sexp]
(** Failure-mode flags. A single trade can match more than one mode — they are
    independent classifications, not a partition. *)

type trade_autopsy = {
  symbol : string;
  side : trade_side;
  entry_date : Date.t;
  exit_date : Date.t;
  entry_price : float;
  exit_price : float;
  return_pct : float;
      (** Round-trip return on the trade itself, mirrored from
          {!Walk_step.trade.return_pct}. *)
  exit_reason : exit_reason;
  weeks_held : int;
  missed_gain_pct : float;
      (** Price-change fraction between [exit_price] and either (a) the next
          same-side re-entry price, if one exists in the window, or (b) the
          close at the end of the test window. Positive means price ran up after
          the strategy exited (missed gain); negative means price kept declining
          (the strategy successfully avoided a loss).

          For short trades: the sign is inverted (a downside move after covering
          is what the short would have captured had we stayed in). *)
  next_entry_date : Date.t option;
      (** Date of the same-side re-entry used to compute [missed_gain_pct].
          [None] if no re-entry happens and [missed_gain_pct] was computed
          against the end-of-window close. *)
  weeks_to_reentry : int option;
      (** Number of weekly bars between exit and the same-side next entry.
          [None] when [next_entry_date] is [None]. *)
  weeks_since_cyclical_low : int option;
      (** Number of weekly bars between the prior cyclical low (in the
          [late_stage2_lookback_weeks] window before entry) and the entry date.
          [None] if the bar series doesn't contain a complete lookback window
          before entry, or for short trades (where the concept does not apply).
      *)
  modes : failure_modes;
}
[@@deriving show, sexp]
(** Per-trade autopsy record. Sexp-serializable so the runner can write
    structured output to disk for downstream analysis. *)

val classify_trades :
  config:Trade_autopsy_config.t ->
  symbol:string ->
  weekly_bars:Types.Daily_price.t list ->
  trades:Walk_step.trade list ->
  trade_autopsy list
(** [classify_trades ~config ~symbol ~weekly_bars ~trades] produces one autopsy
    record per trade in [trades], in entry-date order. The same [weekly_bars]
    series is used for all price lookups. *)

type mode_summary = {
  mode_name : string;
  trade_count : int;  (** How many trades matched this mode. *)
  total_missed_gain_pct : float;
      (** Sum of [missed_gain_pct] over matching trades, expressed as a fraction
          (e.g. 1.50 = 150%). *)
  avg_missed_gain_pct : float;
      (** Mean [missed_gain_pct] over matching trades. 0.0 if [trade_count = 0].
      *)
}
[@@deriving show, sexp]
(** Aggregate across one or more autopsies. *)

val summarize : trade_autopsy list -> mode_summary list
(** [summarize autopsies] returns one [mode_summary] per failure mode, in a
    fixed order ([Stage3_false_positive], [Late_reentry],
    [Late_stage2_admission], [Stop_out_whipsaw]). *)

type per_symbol_breakdown = {
  symbol : string;
  num_trades : int;
  stage3_false_positive_missed_gain : float;
  late_reentry_missed_gain : float;
  late_stage2_admission_missed_gain : float;
  stop_out_whipsaw_missed_gain : float;
}
[@@deriving show, sexp]
(** Per-symbol breakdown: total missed-gain by failure mode for one symbol's
    autopsies. *)

val breakdown_for_symbol :
  symbol:string -> trade_autopsy list -> per_symbol_breakdown
(** [breakdown_for_symbol ~symbol autopsies] aggregates [autopsies] (assumed to
    all be for [symbol]) into a single row. *)
