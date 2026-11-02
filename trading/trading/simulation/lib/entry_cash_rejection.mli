(** At-fill cash rejections of entry tickets, as data (issue #3138).

    {b The event.} A resting entry ticket triggers and the engine fills it, but
    the fill price is above the price it was sized at and the book cannot fund
    it, so the portfolio refuses the trade. Unless the G2a retry
    ({!Entry_fill_retry}) or the G2b resize ({!Entry_fill_resize}) rescues it,
    {!Cancel_handler} then cancels the ticket outright. Before this module the
    only trace of how close the ticket came was the stderr WARN (the 26y
    investor s1 run: ADMA needed $446,712.52 with $427,489.55 available, 96 %
    funded). This module turns each such cancellation into a record that the
    run's observer ({!Simulator.dependencies.on_entry_cash_rejection}) receives
    and [trade_audit.sexp] persists.

    {b The amounts.} [required] is the refused fill's cost,
    [quantity *. price +. commission]. [available] is the portfolio's gross
    [current_cash] at the moment the trade was refused: earlier fills of the
    same step are already booked, later ones are not. That is the [Required] /
    [Available] pair the cash-floor error reports. For a short entry, [required]
    is the same notional cost, while the portfolio refuses a short on its
    collateral rule, so read short rows as "the size of the ticket", not the
    size of the shortfall. The floor also charges the book's unrealized-loss
    drag, so a long can be refused with [available >= required]; [budgeted] is
    net of that drag, so {!funded_fraction} (which reads [budgeted]) shows such
    a long as under-funded. [budgeted] is the cash-account floor's figure: under
    [initial_long_margin_req < 1.0] a margin-funded shortfall is not reflected.

    {b What is recorded.} Only refusals that end in a [CancelEntry]. A refusal
    the retry re-offers or the resize refills is not a cancellation and is not
    recorded; an exit refusal is reverted for retry, not cancelled, and is not
    recorded either. *)

open Core
module Position = Trading_strategy.Position

type t = {
  position_id : string;  (** The cancelled ticket's position id. *)
  symbol : string;
  date : Date.t;  (** The step on which the fill was refused. *)
  required : float;  (** The refused fill's cost, commission included. *)
  available : float;
      (** {b Gross} cash at the moment of the refusal ([current_cash]). *)
  budgeted : float;
      (** What the portfolio's cash floor let this fill spend:
          [current_cash + negative_unrealized_pnl]
          ({!Entry_fill_resize.spendable_cash}), the ceiling on a fill's cost
          (shares plus commission) that the refusing check and the G2b clamp
          both apply. Below [available] whenever the book carries paper losses
          (#3420). *)
}
[@@deriving show, eq]

val funded_fraction : t -> float
(** [budgeted /. required], or [0.0] when [required <= 0.0]: how close the
    ticket came to being fundable once the cash floor's paper-loss drag is
    counted (ADMA with no drag: 0.957; ADNT-wein-122: gross 0.789 funded, under
    0.5 budgeted). Below 1 for a long the floor refused. It can exceed 1 only
    when something other than cash refused the fill, such as a short refused on
    its collateral rule. *)

type pending
(** One step's refusals noted so far, by symbol, plus where to send the records.
    Created per step and discarded with it. *)

val pending : date:Date.t -> emit:(t -> unit) option -> pending
(** A fresh step table. With [emit = None] every operation below is a no-op, so
    the default simulator does no extra work. *)

val note :
  pending ->
  Trading_base.Types.trade ->
  available_cash:float ->
  budgeted_cash:float ->
  unit
(** [note p trade ~available_cash ~budgeted_cash] records that [trade] was
    refused when the portfolio held [available_cash] gross and could spend
    [budgeted_cash]. The first refusal of a symbol in a step wins. Shaped to be
    {!Cancel_handler.apply_trades_best_effort}'s [on_reject] hook. *)

val emit :
  pending ->
  positions:Position.t String.Map.t ->
  cancels:Position.transition list ->
  unit
(** [emit p ~positions ~cancels] sends one record to [emit] for every
    [CancelEntry] in [cancels] whose position (looked up by id in [positions],
    the map {e before} the cancels are applied) has a noted refusal for its
    symbol. Other transition kinds, and cancels with no noted refusal, are
    skipped. *)
