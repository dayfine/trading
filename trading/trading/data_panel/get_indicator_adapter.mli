(** Adapter from {!Indicator_panels} to the strategy's [get_indicator_fn] type.

    Builds the closure shape expected by
    [Trading_strategy.Strategy_interface.get_indicator_fn]:
    [string -> indicator_name -> int -> Types.Cadence.t -> float option]

    Reads the matching panel cell at row [Symbol_index.to_row symbol] / column
    [t]; returns [None] when:

    - the symbol is not in the universe (no row mapping),
    - the spec has no panel (not registered at [create] time),
    - the cell value is NaN (warmup region or missing data).

    Otherwise returns [Some v]. O(1) per call, no allocation except the option
    constructor. *)

val make :
  Indicator_panels.t ->
  t:int ->
  Trading_strategy.Strategy_interface.get_indicator_fn
(** [make panels ~t] returns a [get_indicator_fn] closure that reads column [t]
    of [panels]. The cursor [t] is captured by value at call time — to advance
    the cursor, call [make] again with a new value (cheap; only allocates the
    closure). *)
