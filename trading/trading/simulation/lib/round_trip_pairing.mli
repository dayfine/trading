(** Round-trip pairing: turn a simulation's per-step trade stream into closed
    round-trips, quantity- and split-faithfully.

    Extracted from {!Metrics} so the pairing rules (which carry the issue #2059
    residual-tracking contract) read as one unit. {!Metrics} re-exports both the
    type and {!extract_round_trips}, so consumers need not depend on this module
    directly. *)

open Core

type trade_metrics = {
  symbol : string;  (** The traded symbol *)
  side : Trading_base.Types.side;
      (** Direction of the round-trip's {b entry} leg. [Buy] means a long
          round-trip (Buy→Sell); [Sell] means a short round-trip (Sell→Buy where
          the closing buy covers the short). Callers that distinguish long vs
          short P&L (release-report, [trades.csv], regression metrics) must
          dispatch on this field. *)
  entry_date : Date.t;  (** Date of entry — the open leg *)
  exit_date : Date.t;  (** Date of exit — the close leg *)
  days_held : int;  (** Number of days position was held *)
  entry_price : float;
      (** Price at entry, restated onto the exit leg's split basis. With no
          split straddling the hold this is the raw open-leg fill price; when ≥1
          split occurs between entry and exit it is the open-leg fill divided by
          the cumulative split factor, so it is directly comparable to
          [exit_price]. *)
  exit_price : float;  (** Price at exit — i.e. the close-leg fill price *)
  quantity : float;
      (** Number of shares traded, restated onto the exit leg's split basis (the
          open-leg quantity multiplied by the cumulative straddling-split
          factor). Equals the raw open-leg quantity when no split straddles the
          hold. *)
  pnl_dollars : float;
      (** Profit/loss in dollars, on the split-consistent basis. Long:
          [(exit − entry) × qty]. Short: [(entry − exit) × qty] (positive when
          cover price < entry). *)
  pnl_percent : float;
      (** Profit/loss as percentage of (split-adjusted) entry price. Mirrored
          direction so a positive reading always means profit, regardless of
          long or short. *)
  position_id : string option;
      (** The strategy position this round-trip's {b entry} leg opened, resolved
          from the entry fill's [order_id] through the [order_links] passed to
          {!extract_round_trips}. This is the {b exact} join key back to
          {!Trade_audit} / {!Stop_log} records — both are keyed by position id —
          and it is stable no matter how many calendar days separate the
          screener's decision tick from the resting order's fill tick.

          [None] when the caller supplied no links (the default, e.g. unit tests
          building step streams by hand) or when the entry order was not one the
          order generator recorded a link for. Consumers must keep whatever
          weaker join they used before as a fallback for those rows. *)
}
[@@deriving show, eq]
(** Metrics for a completed round-trip trade.

    A round-trip trade consists of an entry followed by a close trade for the
    same symbol. Two directions are supported: long (Buy→Sell) and short
    (Sell→Buy, where the closing buy covers the short). [side] tags the
    direction of the entry leg so downstream consumers can dispatch P&L
    semantics. *)

val extract_round_trips :
  ?order_links:string String.Map.t ->
  Trading_simulation_types.Simulator_types.step_result list ->
  trade_metrics list
(** Extract round-trip trades from simulation step results.

    [order_links] maps [order_id -> position_id] for every order the run's order
    generator produced (available as
    [Simulator_types.run_result.order_position_links]). It is used only to stamp
    [position_id] on each emitted round-trip; pairing itself is unaffected, so
    omitting it yields bit-identical results save for [position_id = None].

    A round-trip is identified by pairing an entry trade with the next close
    trade for the same symbol. Two directions are paired:

    - {b Long} round-trip: Buy → Sell, with [side = Buy] in the result.
    - {b Short} round-trip: Sell → Buy (the buy covers the short), with
      [side = Sell] in the result.

    Trades are matched in chronological order. Same-side trades accumulate as
    open entries; each opposite-side (closing) trade pairs with the open entry
    whose split-adjusted quantity matches exactly, falling back to the oldest
    open entry (FIFO) when none matches. For the common alternating
    single-position stream this reduces to pairing each entry with the next
    opposite-side trade; the quantity match matters when sibling positions
    coexist on one symbol (e.g. a scale-in parent + add), whose legs interleave
    as Buy, Buy, Sell, Sell. A trailing entry trade with no matching close
    (e.g., an open position at the end of the simulation window) is dropped.

    {b Quantity faithfulness (issue #2059).} Pairing is quantity-faithful: a
    closing trade consumes only as many shares as it actually closes.

    - A {b partial} exit (a trim, a maintenance reduce, or a stop whose fill is
      split across days) emits a round-trip for the shares it closed and leaves
      the {b residual open}, so the residual pairs with the next closing trade.
      Each leg's [quantity] and [pnl_dollars] therefore describe that leg alone;
      one entry can produce several round-trips.
    - A closing trade larger than every open entry closes what it can and opens
      a position on its own side with the excess — the portfolio genuinely flips
      direction on an over-close.

    Without residual tracking the whole entry was consumed by any opposing
    trade, which (a) booked the {e full} entry quantity against a {e partial}
    exit price, over-stating that row's P&L, and (b) left the next closing Sell
    with no open entry, so it was re-read as a {b short open} — manufacturing a
    SHORT round-trip with inverted P&L in an [enable_short_side = false]
    backtest, held open until some unrelated later re-entry Buy "covered" it.
    That is the LH 2001→2024 phantom short of issue #2059; two orphaned sells
    produced two byte-identical rows, double-counting the loss.
    {!Runner.round_trips_in_window} documents the same failure class arising
    from warmup-window truncation.

    {b Split adjustment.} Entry and exit fills can sit on different price bases
    when a stock split occurs mid-hold — the exit fill is post-split while the
    raw entry fill is pre-split. To keep per-trade P&L meaningful, each
    round-trip's entry leg is restated onto the exit's (post-split) basis using
    the [splits_applied] carried on each step: [entry_price] is divided by, and
    [quantity] multiplied by, the product of all split factors with
    [entry_date < split_date <= exit_date]. Dollar exposure is preserved, so a
    split-straddling winner is no longer mis-booked as a ~−50% loss. Holds with
    no straddling split are unaffected. This corrects only the trade-level
    metrics; portfolio NAV is already split-adjusted upstream by
    [Split_handler].

    @param steps List of step results from simulator run
    @return List of trade metrics for completed round-trips *)
