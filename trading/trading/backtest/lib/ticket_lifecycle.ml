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

type entry_anchor =
  | Continuation
  | Local_range_top
  | Breakout
  | Breakdown
  | Ma_fallback
[@@deriving sexp]

type reissue = { original_position_id : string; reissue_date : Date.t }
[@@deriving sexp]

type cash_rejection = {
  required : float;
  available : float;
  budgeted : float; [@sexp.default 0.0]
}
[@@deriving sexp]

type cancellation = { age_weeks : int; reason : string } [@@deriving sexp]

type t = {
  placement_date : Date.t;
  cancel : cancellation option; [@sexp.option]
  ticket_age_weeks_at_fill : int option; [@sexp.option]
  fill_volume : fill_volume_check option; [@sexp.option]
  freshness_basis : entry_freshness_basis;
  entry_anchor : entry_anchor option; [@sexp.option]
  sized_down_wide_stop : bool;
  triple_confirmation : triple_confirmation;
  reissued_from : reissue option; [@sexp.option]
  cash_rejection : cash_rejection option; [@sexp.option]
}
[@@deriving sexp]

(* On-disk shape: [cancel] is written as the two flat fields it replaced, at the
   same position, so [trade_audit.sexp] stays byte-identical for its awk / shell
   readers. The derived converters above see the nested field; these wrap them. *)
let _age_field = "ticket_age_weeks_at_cancel"
let _reason_field = "cancel_reason"
let _cancel_field = "cancel"
let _nested_sexp_of_t = sexp_of_t
let _nested_t_of_sexp = t_of_sexp

let _flat_cancel_fields { age_weeks; reason } =
  [
    Sexp.List [ Atom _age_field; sexp_of_int age_weeks ];
    Sexp.List [ Atom _reason_field; sexp_of_string reason ];
  ]

(* The nested [(cancel ...)] field becomes the flat pair; every other field is
   kept as is. *)
let _flatten_field cancel = function
  | Sexp.List [ Atom name; _ ] when String.equal name _cancel_field ->
      Option.value_map cancel ~default:[] ~f:_flat_cancel_fields
  | field -> [ field ]

let sexp_of_t t =
  match _nested_sexp_of_t t with
  | Sexp.List fields ->
      Sexp.List (List.concat_map fields ~f:(_flatten_field t.cancel))
  | atom -> atom

let _named name = function
  | Sexp.List [ Atom n; v ] when String.equal n name -> Some v
  | _ -> None

let _nested_cancel_field sexp ~age ~reason =
  match (age, reason) with
  | None, None -> []
  | Some a, Some r ->
      let cancel = { age_weeks = int_of_sexp a; reason = string_of_sexp r } in
      [ Sexp.List [ Atom _cancel_field; sexp_of_cancellation cancel ] ]
  | _ ->
      of_sexp_error
        "Ticket_lifecycle.t_of_sexp: ticket_age_weeks_at_cancel and \
         cancel_reason must appear together"
        sexp

let t_of_sexp sexp =
  match sexp with
  | Sexp.List fields ->
      let pick name = List.find_map fields ~f:(_named name) in
      let is_flat f =
        Option.is_some (_named _age_field f)
        || Option.is_some (_named _reason_field f)
      in
      let cancel =
        _nested_cancel_field sexp ~age:(pick _age_field)
          ~reason:(pick _reason_field)
      in
      _nested_t_of_sexp
        (Sexp.List (List.filter fields ~f:(Fn.non is_flat) @ cancel))
  | Sexp.Atom _ -> _nested_t_of_sexp sexp

let ticket_age_weeks_at_cancel t = Option.map t.cancel ~f:(fun c -> c.age_weeks)
let cancel_reason t = Option.map t.cancel ~f:(fun c -> c.reason)
let _days_per_week = 7

let age_weeks ~placed ~resolved =
  Int.max 0 (Date.diff resolved placed / _days_per_week)

let age_weeks_from lifecycle ~resolved =
  Option.map lifecycle ~f:(fun l ->
      age_weeks ~placed:l.placement_date ~resolved)

(* Extracted for the same reason [_stamp_fill_age] is: a record update this wide
   inside the [Option.map] closure trips the nesting linter. *)
let cash_rejection_of (r : Trading_simulation.Entry_cash_rejection.t) =
  { required = r.required; available = r.available; budgeted = r.budgeted }

let _merge_resolutions ~fill_volume ~cancel ~cash_rejection l =
  { l with fill_volume; cancel; cash_rejection }

let resolve lifecycle ~fill_volume ~cancel ~cash_rejection =
  Option.map lifecycle
    ~f:(_merge_resolutions ~fill_volume ~cancel ~cash_rejection)

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

(* Extracted for the nesting linter, like [_stamp_fill_age]. *)
let _stamp_reissue link l = { l with reissued_from = Some link }
let with_reissue lifecycle link = Option.map lifecycle ~f:(_stamp_reissue link)
