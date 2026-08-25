(** Size one weekly-pick candidate into an executable order (Phase B).

    Mirrors the backtest: the order size comes from the {b same}
    {!Portfolio_risk.compute_position_size} the live/simulation strategy uses —
    fixed-risk sizing (risk a fixed fraction of portfolio value per trade),
    capped by the per-position, side-exposure, and spendable-cash limits. Orders
    are therefore {b not} equal-sized: a tighter-stop name earns more shares for
    the same dollar risk.

    Pure function — no I/O. The generator calls it per long candidate and stamps
    the result onto the {!Weekly_snapshot.candidate}'s [sized_*] / [sizing_note]
    fields; the renderer formats the instruction cell from those fields.

    {1 Sizing is on the WORST admissible fill — the cap (issues #2103, #2158)}

    The entry price fed to {!Portfolio_risk.compute_position_size} is
    {!Weekly_snapshot.sizing_basis_price}, {b never} [c.entry] directly.
    [c.entry] is the breakout level from the transition week; a candidate whose
    price has already run through it fills at the market, not at the level. The
    2026-07-24 MBX pick was sized 651 shares against a $46.08 entry with the
    stock at $62 — a 34% larger notional than intended and, against the $44.88
    stop, {b 14x the displayed dollar risk}.

    Issue #2158 tightens this from the {e expected} fill to the do-not-chase
    {b cap} — the worst fill the live [StopLimit] order can accept. Sizing on
    the cap makes the displayed risk the worst case ([cap - stop]) rather than
    optimistic ("size on the cap", user 2026-07-29). When the candidate carries
    no cap (disarmed default), {!Weekly_snapshot.sizing_basis_price} falls back
    to the expected fill, so the default path is unchanged.

    Run {!Entry_reconcile} before this pass so the class is available. *)

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
    - The stop is read from [c.stop]; the entry price is
      {!Weekly_snapshot.sizing_basis_price} [c] — the do-not-chase cap for a
      reconciled candidate (issue #2158), and [c.entry] for an unreconciled one
      (the disarmed default) or a pre-#2158 snapshot with no cap.
    - {b Every} reconciliation class is sized the same way, including
      {!Entry_reconciliation.Extended} (issue #2404). An extended candidate's
      order is the same capped [StopLimit]; it merely will not fill at the
      current price, and would fill at the cap if price returned into the band —
      so the cap is its honest sizing basis too. Before #2404 it was returned
      explicitly unsized because its ticket was suppressed.
    - [placeholder = true] stamps [sizing_note] with the
      ["UNSIZED — set portfolio.sexp"] label (the generator had no live
      portfolio and sized against the template default); the numeric fields are
      still filled so the reader sees a placeholder size.
    - [placeholder = false] leaves [sizing_note = None] on a normal fill, or
      [Some reason] when the size is [0] shares (invalid stop direction, or cash
      / caps exhausted).

    Pure: same inputs → same output. *)
