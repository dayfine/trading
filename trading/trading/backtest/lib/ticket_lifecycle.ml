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

type triple_confirmation = {
  breakout_volume_multiple : float option;
  rs_zero_cross : bool;
  in_base_advance_pct : float option;
}
[@@deriving sexp]

type entry_freshness_basis = Ma_cross | Range_top_breakout [@@deriving sexp]

type t = {
  placement_date : Date.t;
  ticket_age_weeks_at_fill_or_cancel : int option; [@sexp.option]
  fill_volume : fill_volume_verdict option; [@sexp.option]
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

let resolve lifecycle ~fill_volume ~age_weeks =
  Option.map lifecycle ~f:(fun l ->
      { l with fill_volume; ticket_age_weeks_at_fill_or_cancel = age_weeks })

let with_age lifecycle ~resolved =
  resolve lifecycle
    ~fill_volume:(Option.bind lifecycle ~f:(fun l -> l.fill_volume))
    ~age_weeks:(age_weeks_from lifecycle ~resolved)
