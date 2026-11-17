(** Resistance-v2 sketch-consuming results for {!Stock_analysis}: the continuous
    overhead-supply score and the virgin-crossing re-admission predicate.

    Split out of [stock_analysis.ml] for file-length hygiene. Consumes only
    {!Resistance_supply} plus primitives (a [get_sketch] closure, the breakout
    price and the as-of raw close), carrying no dependency on the
    [Stock_analysis.t] / [callbacks] records — so this stays a leaf module and
    the extraction introduces no cycle. *)

(** Which price basis the virgin test and the supply grade compare on (#3664).

    [breakout_price] is a raw (as-traded) weekly high. The sketch is on its
    warehouse's basis: since #2145 that is the back-adjusted one, which on
    history already carries every split and dividend the name pays {i later}.

    - [Legacy_mixed] {b (default)} — today's comparison, verbatim: the raw
      breakout against the sketch as stored. On an adjusted-basis sketch that
      mixes bases, so a name below its 10-year high passes as virgin when it
      later splits (the record's path; #3664). Kept as the default so every
      golden, the record and every default config stay byte-identical
      ([dev/rules/experiment-flag-discipline.md] R1).
    - [One_basis] — the breakout is put on the sketch's basis first
      ({!breakout_on_sketch_basis}); the ticket price stays raw. *)
type basis = Legacy_mixed | One_basis [@@deriving show, eq, sexp]

val breakout_on_sketch_basis :
  basis:basis ->
  sketch:Resistance_supply.sketch ->
  breakout_price:float option ->
  current_raw_close:float option ->
  float option
(** [breakout_on_sketch_basis ~basis ~sketch ~breakout_price ~current_raw_close]
    is the breakout level the virgin test and the supply grade read.

    [Legacy_mixed]: [breakout_price] unchanged.

    [One_basis]: [breakout_price * sketch.anchor_close / current_raw_close]. The
    sketch's [anchor_close] is the as-of close on the sketch's own basis and
    [current_raw_close] ({!Stock_analysis.t.current_raw_close}) is the same
    close on the raw basis of [breakout_price], so the ratio carries a raw as-of
    price onto the sketch's basis: the as-of split factor
    ([adjusted_close / close_price]) on an adjusted-basis sketch (every
    warehouse since #2145, and the live sketch), and 1 on a raw-basis one, where
    the comparison was already one basis. No warehouse-basis flag is needed.

    It reads the breakout as an as-of price, which is what the ticket is. The
    breakout scan never crosses a split boundary inside its own window; a split
    in the weeks between that window and the as-of bar leaves [breakout_price]
    itself in the pre-split space (#2973), and this conversion does not repair
    that.

    [None] under [One_basis] when [breakout_price] or [current_raw_close] is
    unknown or the raw close is not positive: with no as-of close there is no
    conversion, so no virginity and no grade are fabricated. *)

val results :
  overhead_supply:Resistance_supply.config option ->
  virgin_crossing_readmission:bool ->
  basis:basis ->
  get_sketch:(unit -> Resistance_supply.sketch option) ->
  breakout_price:float option ->
  current_raw_close:float option ->
  Resistance_supply.result option * bool
(** [results ~overhead_supply ~virgin_crossing_readmission ~basis ~get_sketch
     ~breakout_price ~current_raw_close] returns [(supply, virgin_readmission)].
    Both read the breakout through {!breakout_on_sketch_basis} under [basis], so
    the grade and the virgin test always share one basis.

    - [supply] (resistance-v2 PR-D): [Some r] only when
      [overhead_supply = Some _] AND [get_sketch ()] returns a sketch AND the
      breakout on the sketch's basis exists; else [None], bit-equal to
      pre-feature.
    - [virgin_readmission] (resistance-v2 lever (a)): [true] only when
      [virgin_crossing_readmission] AND [get_sketch ()] returns a sketch AND the
      breakout on the sketch's basis exists AND the breakout is into new high
      ground — {!Resistance_supply.is_virgin} (breakout >= 520-week max high) OR
      {!Resistance_supply.is_clear_of_supply} (no weekly bar at/above the
      current close). The [is_clear_of_supply] arm closes the own-week-high
      artifact that makes [is_virgin] structurally unsatisfiable on a
      close-anchored breakout price (see its docstring — AXTI 2026-01-06).
      Independent of [overhead_supply]: the test needs only the sketch.

    [get_sketch] is read at most once per armed feature — off = no panel read,
    and no fabrication of a score / virginity when the sketch is absent. *)
