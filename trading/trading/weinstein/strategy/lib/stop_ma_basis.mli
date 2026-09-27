(** Restates a weekly MA read on the {b adjusted}-close basis onto the {b raw}
    price basis of one daily bar.

    The weekly view feeding {!Stage} reads [adjusted_close], which is
    back-adjusted for every later split and dividend. The stop machine and the
    Stage-3 margin gate compare that MA with raw daily prices (bar lows, closes
    and stop levels). Multiplying the MA by the bar's
    [close_price /. adjusted_close] puts it on the same basis as the bar
    (issue #2982, [Weinstein_stops.config.stop_ma_same_basis]). *)

val raw_basis_factor : Types.Daily_price.t -> float option
(** [raw_basis_factor bar] is [Some (bar.close_price /. bar.adjusted_close)]
    when both prices are finite and strictly positive, [None] otherwise. *)

val restate_to_raw : bar:Types.Daily_price.t -> float -> float
(** [restate_to_raw ~bar ma] is [ma *. factor] where [factor] is
    {!raw_basis_factor}[ bar]; [ma] unchanged when the factor is [None]. *)

val for_stops : enabled:bool -> bar:Types.Daily_price.t -> float -> float
(** [for_stops ~enabled ~bar ma] is {!restate_to_raw}[ ~bar ma] when [enabled],
    and [ma] itself (the pre-#2982 mixed-basis value) when not. *)
