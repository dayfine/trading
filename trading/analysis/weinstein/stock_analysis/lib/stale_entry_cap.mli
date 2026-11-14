(** Stale-entry cap ("H2′", #3594): lower a long's buy-stop trigger [E] to the
    top of the {i current} trading range when [E] sits above it, and leave it
    alone otherwise.

    {b Rule.} [E′ = min(E, T)]. [E] is the screener's ticket anchor as today
    (the 520-week graded breakout top, or the replace anchor when
    [entry_anchor_local_range_weeks] is armed). [T] is the split-safe maximum
    high over the most recent [entry_cap_local_range_weeks] weekly bars (offsets
    [0 .. weeks - 1], the current bar included). It is the same
    {!Stock_analysis_scans.scan_recent_max_high} walk the replace anchor uses,
    so it truncates at the most recent split the same way. The comparison is
    made on anchors {i before} the screener's breakout buffer. The screener then
    applies its usual buffer to whichever level anchors the ticket
    ([Screener.candidate_params.entry_buffer_pct], default 0.5%, rounded to the
    cent by [Screener_prices.suggested_entry]). So the capped ticket is
    [round(min(A, T) * (1 + entry_buffer_pct))]: the screen's "4-week high x
    1.005" without hard-coding the buffer.

    {b A cap, not a replace.} The replace anchor (the screen's H2) moves [E] to
    the range top unconditionally. In most trades the graded [E] already sits
    {i below} the recent high, so replacing it raises the price paid and drops
    the orders that never reach the new level, which costs the right tail (the
    2026-10-03 backtest and the 2026-11-12 screen, both negative at every
    window). The cap moves [E] only {i down}, so it never raises a price and
    never removes a name from the fill set.

    {b How it reaches the ticket.} The capped level is stored in
    [Stock_analysis.t.local_range_top], which the screener's existing
    [Local_range_top] arm already reads. So the entry, the derived stop and the
    risk percentage follow the cap through the replace anchor's own path. The
    audit records the arm as [local_range_top] exactly when the cap bound.

    {b Scope.}
    - Longs only: a short's sell-stop anchors at the breakdown floor and never
      reads [local_range_top].
    - Base-level arms only. The MA fallback (no breakout price) is a formula on
      the classifier's adjusted MA (issue #2973). Comparing it with the
      raw-space [T] would mix bases, so it is left alone.
    - The continuation arm outranks [local_range_top] in the screener, so a
      continuation ticket is never capped.
    - Admission, resistance grading, cascade scoring and stage classification
      are unchanged: they read [breakout_price] and the uncapped replace anchor,
      never this level.

    {b Faithfulness.} [docs/design/weinstein-book-reference.md] §4.7 ("Entry
    level within the range": the checklist anchors the buy-stop at the top of
    the {i current} trading range) and §4.1 (break out above resistance). This
    is an entry-level dial (W2) with the spine intact. *)

val ticket_anchor :
  range_top:float option ->
  cap_top:float option ->
  breakout_price:float option ->
  float option
(** [ticket_anchor ~range_top ~cap_top ~breakout_price] is the level stored in
    [Stock_analysis.t.local_range_top].

    - [cap_top = None] (cap off, the default): [range_top] unchanged, which is
      bit-identical to the code before the cap existed.
    - [range_top = Some r] (replace anchor armed): [Some (min r t)]. Both tops
      come from the same walk from offset 0, so this is the replace anchor over
      the shorter of the two windows.
    - [range_top = None]: [Some t] iff [breakout_price = Some b] with [b > t]
      (the graded [E] is stale, above the current range). Otherwise [None], and
      the screener keeps the graded top, or the MA fallback when there is no
      breakout price.

    [range_top] is the replace anchor over [entry_anchor_local_range_weeks] and
    [cap_top] the range top [T] over [entry_cap_local_range_weeks]. Pure. *)

val anchors :
  get_high:(week_offset:int -> float option) ->
  get_split_factor:(week_offset:int -> float option) ->
  replace_weeks:int ->
  cap_weeks:int ->
  breakout_price:float option ->
  float option * float option
(** [anchors ~get_high ~get_split_factor ~replace_weeks ~cap_weeks
     ~breakout_price] is [(range_top, ticket)].
    - [range_top] is the replace anchor over [replace_weeks] bars. The F1
      freshness clock reads it.
    - [ticket] is {!ticket_anchor} of [range_top] under the cap over [cap_weeks]
      bars. [Stock_analysis.t.local_range_top] stores it.

    Both windows are {!Stock_analysis_scans.scan_recent_max_high}, and a week
    count of [0] scans nothing. With [cap_weeks = 0], [ticket = range_top]
    (bit-identical). The clock never sees the cap, so arming it cannot move
    admission. *)
