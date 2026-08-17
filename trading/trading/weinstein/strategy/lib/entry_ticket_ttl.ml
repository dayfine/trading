open Core
module Position = Trading_strategy.Position

let _days_per_week = 7

(* Diagnostic-only reason strings carried on the [CancelEntry]; they name which
   of the two paths fired so a trade audit can tell a re-screen cancel (the
   book's §7 weekend-homework decision) from the clock backstop. *)
let _requalification_reason = "entry_ticket_requalification_failed"
let _ttl_reason = "entry_ticket_ttl_expired"

let _cancel_transition ~current_date ~reason (pos : Position.t) :
    Position.transition =
  {
    position_id = pos.id;
    date = current_date;
    kind = Position.CancelEntry { reason };
  }

(* Whole weeks a ticket placed on [created_date] has rested as of
   [current_date]. Weekly reviews are 7 days apart, so a ticket placed on
   review week 0 reads [n] on review week [n]. *)
let _weeks_resting ~current_date ~created_date =
  Date.diff current_date created_date / _days_per_week

(* [true] when the clock is armed and this ticket has outlived it. Split from
   the re-screen half in 2026-08-16 (defect C): [max_rest_weeks <= 0] is now
   "unbounded", not "the whole mechanism is off". *)
let _clock_expired ~max_rest_weeks ~current_date ~created_date =
  max_rest_weeks > 0
  && _weeks_resting ~current_date ~created_date > max_rest_weeks

(* [Some reason] when this position is a resting (unfilled) entry ticket that
   should be cancelled; [None] otherwise. The re-screen is checked first so its
   reason wins when both would fire — the book-supported cause is the more
   informative one to record. Partially-filled entries are skipped:
   [CancelEntry] closes the position, which would strand the booked shares. *)
let _cancel_reason_for ~rescreen ~max_rest_weeks ~still_qualifies ~current_date
    (pos : Position.t) =
  match Position.get_state pos with
  | Position.Entering { filled_quantity; created_date; _ }
    when Float.equal filled_quantity 0.0 ->
      if rescreen && not (still_qualifies ~symbol:pos.symbol ~side:pos.side)
      then Some _requalification_reason
      else if _clock_expired ~max_rest_weeks ~current_date ~created_date then
        Some _ttl_reason
      else None
  | Position.Entering _ | Position.Holding _ | Position.Exiting _
  | Position.Closed _ ->
      None

let _cancel_of ~rescreen ~max_rest_weeks ~still_qualifies ~current_date pos =
  _cancel_reason_for ~rescreen ~max_rest_weeks ~still_qualifies ~current_date
    pos
  |> Option.map ~f:(fun reason -> _cancel_transition ~current_date ~reason pos)

let cancellations ~rescreen ~max_rest_weeks ~positions ~still_qualifies
    ~current_date =
  if (not rescreen) && max_rest_weeks <= 0 then []
  else
    Map.data positions
    |> List.filter_map
         ~f:
           (_cancel_of ~rescreen ~max_rest_weeks ~still_qualifies ~current_date)

let run ~rescreen ~max_rest_weeks ~pending_entry_e ~positions ~still_qualifies
    ~current_date =
  let transitions =
    cancellations ~rescreen ~max_rest_weeks ~positions ~still_qualifies
      ~current_date
  in
  List.iter transitions ~f:(fun (t : Position.transition) ->
      match Map.find positions t.position_id with
      | Some (pos : Position.t) ->
          Entry_freeze.release pending_entry_e ~symbol:pos.symbol
      | None -> ());
  transitions
