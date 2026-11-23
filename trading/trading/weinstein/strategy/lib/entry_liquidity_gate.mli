(** Strategy-side adapter for the entry arm of the liquidity-realism overlay.

    Wraps the pure {!Liquidity_gate.filter} with the bar-plumbing it needs: it
    builds the [dollar_adv_for] lookup from the screening cycle's {!Bar_reader}
    via {!Liquidity_metric.dollar_adv}, then applies the gate. Kept out of
    {!Weinstein_strategy_screening} so that coordinator stays under the
    file-length cap.

    No-op at [min_entry_dollar_adv = 0.0]: returns the candidate list
    bit-identical. (The default is [1_000_000.0] since the 2026-07-10
    realism-defaults flip, so the gate is armed by default; setting the
    threshold to [0.0] reproduces the pre-flip behaviour.) Pure with respect to
    the supplied bar reader. *)

open Core

val apply :
  config:Liquidity_config.t ->
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** [apply ~config ~bar_reader ~current_date candidates] drops entry candidates
    (long AND short) whose trailing dollar-ADV — computed from bars available at
    [current_date] (no lookahead), over [config.adv_lookback_days] and reduced
    by [config.adv_aggregation] / [config.adv_trim_pct] — is below
    [config.min_entry_dollar_adv].

    Delegates the keep/drop decision to {!Liquidity_gate.filter}; this function
    only supplies the [dollar_adv_for] lookup. *)

val dollar_adv_for :
  config:Liquidity_config.t ->
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  string ->
  float option
(** [dollar_adv_for ~config ~bar_reader ~current_date ticker] is the trailing
    dollar-ADV every liquidity threshold is compared against: bars available at
    [current_date], [config.adv_lookback_days] long, reduced by
    [config.adv_aggregation] / [config.adv_trim_pct], on true dollars when the
    reader carries a split divisor. [None] when there is no reading. *)

(** {1 Participation cap (issue #3681)}

    Scales the entry gate with position size: an entry is allowed only when its
    planned position dollars are at most [p] times the dollar-ADV. It blocks; it
    never resizes (see {!Liquidity_config.t.max_entry_adv_participation}). The
    fixed [min_entry_dollar_adv] floor in {!apply} still applies first. *)

val participation_allows :
  max_participation:float option ->
  position_dollars:float ->
  dollar_adv:float option ->
  bool
(** [true] when [max_participation = None] (no cap), when [dollar_adv = None] (a
    missing reading never blocks), or when [position_dollars <= p *. adv]. Pure.
*)

val within_participation :
  config:Liquidity_config.t ->
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  ticker:string ->
  position_dollars:float ->
  bool
(** {!participation_allows} with [config.max_entry_adv_participation] and the
    {!dollar_adv_for} reading of [ticker]. When the cap is [None] it returns
    [true] without reading any bars, so the default path is byte-identical. *)

val cap_entry_attempt :
  config:Liquidity_config.t ->
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  Screener.scored_candidate ->
  Entry_audit_capture.entry_attempt_result ->
  Entry_audit_capture.entry_attempt_result
(** The entry walk's use of {!within_participation}: turns a sized [Entry_ok]
    whose position dollars ([shares *. effective_entry_price], sized from the
    current portfolio value) exceed the cap into [Over_adv_participation]. It
    blocks rather than resizes. Every other result, and every result when the
    cap is [None], passes through unchanged (R1). *)
