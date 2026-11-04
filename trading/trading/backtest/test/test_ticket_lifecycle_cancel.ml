(** The cancel pair travels as one value (R1 of the #2357 qc-behavioral review).

    [Ticket_lifecycle.t] carries a ticket's cancellation as a single
    [cancellation option] — the resting age and the reason token together — so a
    row cannot hold one without the other. On disk the value is still written as
    the two flat fields it replaced, [(ticket_age_weeks_at_cancel N)] and
    [(cancel_reason TOKEN)], at the same position: the awk / shell readers of
    [trade_audit.sexp] grep for exactly that shape. These tests pin the on-disk
    bytes, the round-trip, and the parser's refusal of a half-pair. *)

open OUnit2
open Core
open Matchers
module TL = Backtest.Ticket_lifecycle

let _lifecycle ~cancel : TL.t =
  {
    placement_date = Date.of_string "2024-03-01";
    cancel;
    ticket_age_weeks_at_fill = None;
    fill_volume = None;
    freshness_basis = TL.Ma_cross;
    entry_anchor = None;
    sized_down_wide_stop = false;
    triple_confirmation =
      {
        breakout_volume_multiple = None;
        rs_zero_cross = false;
        in_base_advance_pct = None;
      };
    reissued_from = None;
    cash_rejection = None;
  }

let _ttl_cancel : TL.cancellation =
  { age_weeks = 3; reason = "entry_ticket_ttl_expired" }

let _tail =
  "(freshness_basis Ma_cross)(sized_down_wide_stop \
   false)(triple_confirmation((breakout_volume_multiple())(rs_zero_cross \
   false)(in_base_advance_pct()))))"

(** The serialized bytes are those of the pre-R1 two-field record: the pair at
    the position the old [ticket_age_weeks_at_cancel] / [cancel_reason] fields
    held, no nested [cancel] field anywhere. *)
let test_cancelled_row_writes_the_flat_pair _ =
  assert_that
    (Sexp.to_string (TL.sexp_of_t (_lifecycle ~cancel:(Some _ttl_cancel))))
    (equal_to
       ("((placement_date 2024-03-01)(ticket_age_weeks_at_cancel \
         3)(cancel_reason entry_ticket_ttl_expired)" ^ _tail))

(** An uncancelled row writes neither field, as before. *)
let test_uncancelled_row_writes_neither_field _ =
  assert_that
    (Sexp.to_string (TL.sexp_of_t (_lifecycle ~cancel:None)))
    (equal_to ("((placement_date 2024-03-01)" ^ _tail))

(** Both shapes read back to the value that wrote them; the views return the
    pair's halves. *)
let test_round_trip_preserves_the_cancellation _ =
  let read l = TL.t_of_sexp (TL.sexp_of_t l) in
  assert_that
    [
      read (_lifecycle ~cancel:(Some _ttl_cancel));
      read (_lifecycle ~cancel:None);
    ]
    (elements_are
       [
         all_of
           [
             field TL.ticket_age_weeks_at_cancel (is_some_and (equal_to 3));
             field TL.cancel_reason
               (is_some_and (equal_to "entry_ticket_ttl_expired"));
           ];
         all_of
           [
             field TL.ticket_age_weeks_at_cancel is_none;
             field TL.cancel_reason is_none;
           ];
       ])

(** A row carrying only one half of the pair is malformed and is refused, in
    either direction — the type has no way to hold it. *)
let test_half_pair_is_refused _ =
  let parse prefix =
    Result.is_error
      (Or_error.try_with (fun () ->
           TL.t_of_sexp
             (Sexp.of_string ("((placement_date 2024-03-01)" ^ prefix ^ _tail))))
  in
  assert_that
    [
      parse "(ticket_age_weeks_at_cancel 3)";
      parse "(cancel_reason entry_ticket_ttl_expired)";
    ]
    (equal_to [ true; true ])

let suite =
  "Ticket_lifecycle cancel pair"
  >::: [
         "cancelled row writes the flat pair"
         >:: test_cancelled_row_writes_the_flat_pair;
         "uncancelled row writes neither field"
         >:: test_uncancelled_row_writes_neither_field;
         "round trip preserves the cancellation"
         >:: test_round_trip_preserves_the_cancellation;
         "half pair is refused" >:: test_half_pair_is_refused;
       ]

let () = run_test_tt_main suite
