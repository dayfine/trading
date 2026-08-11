(** Resting-entry-ticket lifecycle audit record. See [ticket_lifecycle.mli]. *)

open Core

type fill_volume_verdict =
  | Confirmed_spike of float
  | Confirmed_buildup of float
  | Unconfirmed of {
      spike_ratio : float option;
      buildup_multiple : float option;
    }
  | No_verdict
[@@deriving sexp]

type fill_volume_outcome = Ejected | Skipped_other_exit | Held
[@@deriving sexp]

type fill_volume_check = {
  verdict : fill_volume_verdict;
  outcome : fill_volume_outcome;
}
[@@deriving sexp]

type triple_confirmation = {
  breakout_volume_multiple : float option;
  rs_zero_cross : bool;
  in_base_advance_pct : float option;
}
[@@deriving sexp]

type entry_freshness_basis = Ma_cross | Range_top_breakout [@@deriving sexp]

type t = {
  placement_date : Date.t;
  ticket_age_weeks_at_cancel : int option; [@sexp.option]
  ticket_age_weeks_at_fill : int option; [@sexp.option]
  fill_volume : fill_volume_check option; [@sexp.option]
  freshness_basis : entry_freshness_basis;
  sized_down_wide_stop : bool;
  triple_confirmation : triple_confirmation;
}
[@@deriving sexp]

let _days_per_week = 7

let age_weeks ~placed ~resolved =
  Int.max 0 (Date.diff resolved placed / _days_per_week)

let age_weeks_from lifecycle ~resolved =
  Option.map lifecycle ~f:(fun l ->
      age_weeks ~placed:l.placement_date ~resolved)

let resolve lifecycle ~fill_volume ~cancel_age_weeks =
  Option.map lifecycle ~f:(fun l ->
      { l with fill_volume; ticket_age_weeks_at_cancel = cancel_age_weeks })

(* Extracted so [with_fill_age] stays a one-liner: inlining this record update
   inside the [Option.map] closure trips the nesting linter. *)
let _stamp_fill_age ~resolved l =
  {
    l with
    ticket_age_weeks_at_fill =
      Some (age_weeks ~placed:l.placement_date ~resolved);
  }

let with_fill_age lifecycle ~resolved =
  Option.map lifecycle ~f:(_stamp_fill_age ~resolved)
