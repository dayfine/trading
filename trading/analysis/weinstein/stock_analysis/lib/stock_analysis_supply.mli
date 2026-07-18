(** Resistance-v2 sketch-consuming results for {!Stock_analysis}: the continuous
    overhead-supply score and the virgin-crossing re-admission predicate.

    Split out of [stock_analysis.ml] for file-length hygiene. Consumes only
    {!Resistance_supply} plus primitives (a [get_sketch] closure + breakout
    price), carrying no dependency on the [Stock_analysis.t] / [callbacks]
    records — so this stays a leaf module and the extraction introduces no
    cycle. *)

val results :
  overhead_supply:Resistance_supply.config option ->
  virgin_crossing_readmission:bool ->
  get_sketch:(unit -> Resistance_supply.sketch option) ->
  breakout_price:float option ->
  Resistance_supply.result option * bool
(** [results ~overhead_supply ~virgin_crossing_readmission ~get_sketch
     ~breakout_price] returns [(supply, virgin_readmission)]:

    - [supply] (resistance-v2 PR-D): [Some r] only when
      [overhead_supply = Some _] AND [get_sketch ()] returns a sketch AND a
      breakout price exists; else [None], bit-equal to pre-feature.
    - [virgin_readmission] (resistance-v2 lever (a)): [true] only when
      [virgin_crossing_readmission] AND [get_sketch ()] returns a sketch AND a
      breakout price exists AND the breakout is into new high ground —
      {!Resistance_supply.is_virgin} (breakout >= 520-week max high) OR
      {!Resistance_supply.is_clear_of_supply} (no weekly bar at/above the
      current close). The [is_clear_of_supply] arm closes the own-week-high
      artifact that makes [is_virgin] structurally unsatisfiable on a
      close-anchored breakout price (see its docstring — AXTI 2026-01-06).
      Independent of [overhead_supply]: the test needs only the sketch.

    [get_sketch] is read at most once per armed feature — off = no panel read,
    and no fabrication of a score / virginity when the sketch is absent. *)
