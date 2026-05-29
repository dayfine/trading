(** Configuration for the trade autopsy classifier.

    All thresholds are exposed as fields so callers can override defaults in a
    sweep / tuning context. The runner uses [default] unmodified. *)

type t = {
  stage3_recovery_pct : float;
      (** Minimum price recovery above the exit price within
          [stage3_recovery_weeks] required to call a Stage-3 exit a
          "false-positive". Default: 0.05 (5%). A Stage-3 exit that resolves
          back to Stage-2 territory by gaining at least this much within the
          look-ahead window is counted as a premature exit. *)
  stage3_recovery_weeks : int;
      (** Look-ahead window (in weekly bars) for detecting Stage-3 false
          positives. Default: 12. *)
  late_reentry_weeks : int;
      (** Time-to-re-entry threshold (weekly bars) above which a re-entry is
          considered "late". Combined with [late_reentry_pct]. Default: 8. *)
  late_reentry_pct : float;
      (** Missed-gain threshold for a "late re-entry": the symbol's price ran
          this much (in % of exit price) between the exit and the next re-entry.
          Default: 0.10 (10%). *)
  late_stage2_weeks : int;
      (** Time-from-prior-cyclical-low threshold (weekly bars). An entry whose
          [entry_date] is more than this many weeks after the prior cyclical low
          is classified as "late Stage 2 admission". Default: 8. *)
  late_stage2_lookback_weeks : int;
      (** Lookback window (weekly bars) used to find the prior cyclical low for
          a Stage-2 entry. The low is the minimum close price in the window
          ending at the entry bar. Default: 12. *)
  stop_whipsaw_weeks : int;
      (** Look-ahead window (weekly bars) for detecting stop-out whipsaws.
          Default: 4. (Currently inert — the per-symbol stage strategy has no
          stop-loss mechanism — but exposed so the same tool can be retargeted
          at strategies that do have stops.) *)
  stop_whipsaw_pct : float;
      (** Price-recovery threshold for stop-out whipsaws. Default: 0.05 (5%).
          (Inert under the current input strategy; see above.) *)
}
[@@deriving show, sexp]

val default : t
(** Default thresholds (per the dispatch brief 2026-05-29):
    - [stage3_recovery_pct = 0.05]
    - [stage3_recovery_weeks = 12]
    - [late_reentry_weeks = 8]
    - [late_reentry_pct = 0.10]
    - [late_stage2_weeks = 8]
    - [late_stage2_lookback_weeks = 12]
    - [stop_whipsaw_weeks = 4]
    - [stop_whipsaw_pct = 0.05] *)
