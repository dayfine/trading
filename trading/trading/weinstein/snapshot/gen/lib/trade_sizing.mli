(** Size one weekly-pick candidate into an executable order (Phase B).

    Mirrors the backtest: the order size comes from the {b same}
    {!Portfolio_risk.compute_position_size} the live/simulation strategy uses —
    fixed-risk sizing (risk a fixed fraction of portfolio value per trade),
    capped by the per-position, side-exposure, and spendable-cash limits. Orders
    are therefore {b not} equal-sized: a tighter-stop name earns more shares for
    the same dollar risk.

    Pure function — no I/O. The generator calls it per long candidate and stamps
    the result onto the {!Weekly_snapshot.candidate}'s [sized_*] / [sizing_note]
    fields; the renderer formats the instruction cell from those fields. *)

open Weinstein_snapshot

val size_candidate :
  risk_config:Portfolio_risk.config ->
  portfolio_value:float ->
  sizing_cash:float ->
  side:[ `Long | `Short ] ->
  placeholder:bool ->
  Weekly_snapshot.candidate ->
  Weekly_snapshot.candidate
(** [size_candidate ~risk_config ~portfolio_value ~sizing_cash ~side
     ~placeholder c] returns [c] with its [sized_shares] /
    [sized_position_value] / [sized_position_pct] / [sized_risk_amount] /
    [sizing_note] fields populated.

    - [portfolio_value] drives the risk-pct and %-cap math; [sizing_cash] bounds
      the spendable-cash cap (pass the portfolio's cash).
    - Entry and stop are read from [c.entry] / [c.stop].
    - [placeholder = true] stamps [sizing_note] with the
      ["UNSIZED — set portfolio.sexp"] label (the generator had no live
      portfolio and sized against the template default); the numeric fields are
      still filled so the reader sees a placeholder size.
    - [placeholder = false] leaves [sizing_note = None] on a normal fill, or
      [Some reason] when the size is [0] shares (invalid stop direction, or cash
      / caps exhausted).

    Pure: same inputs → same output. *)
