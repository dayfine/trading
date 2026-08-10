(** Renders a weekly OHLCV table (blinded or plain) as aligned plain text for
    judge consumption -- see [.claude/skills/blind-judge/SKILL.md]. *)

val render :
  symbol_label:string ->
  bars:Types.Daily_price.t list ->
  week_labels:string list ->
  ma_30w:float option ->
  string
(** [render ~symbol_label ~bars ~week_labels ~ma_30w] renders [bars]
    (chronologically ascending, oldest first) as an aligned
    [week open high low close volume] text table, one row per bar, labeled by
    the corresponding entry of [week_labels]. Raises [Invalid_argument] if
    [week_labels] and [bars] differ in length.

    The header states [symbol_label], the bar count, and that the series ends AT
    the decision week (the last row) with no bars beyond it -- the textual
    restatement of {!Bar_window.select}'s lookahead invariant, so a judge
    transcript is self-documenting even read in isolation.

    Prices are raw (unadjusted) and never rescaled -- round-number levels stay
    meaningful (book reference SS5.1, the >15%-above-base "prefer other
    candidates" rule and the round-number stop discussion both depend on real
    price levels, not a normalized series).

    A trailing ["# 30w MA at decision week: <value>"] line is appended iff
    [ma_30w] is [Some _]; omitted entirely (not even a placeholder line) when
    [None], so a judge cannot infer "insufficient history" from a blank vs.
    present line -- the CLI only ever passes [Some _] when [--with-ma] was
    requested by the operator. *)
