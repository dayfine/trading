(** The one comparison every protective-stop trigger uses (issue #3505).

    A stop level is usually derived arithmetically (a percentage off a price, a
    split adjustment), so it is stored with float noise: a stop that is 23.76 to
    the cent can be stored as [23.759999999999998]. A bare [low <= stop] then
    misses a bar whose low prints exactly 23.76, and the stop fires a day late
    (SGNT-wein-703, 2014-08-04 vs 08-05).

    Every stop-trigger site (the strategy's stop check, the simulator's same-bar
    stop fill, the engine's stop fill) compares through these two functions so
    they agree on the same bar. The tolerance is far below one tick: it absorbs
    float representation noise only, so a price a tick or more short of the stop
    never triggers it. *)

val tolerance : float
(** Absolute price tolerance, [1e-6]: well above float noise for any traded
    price, well below one tick ([0.01]). *)

val sell_stop_reached : price:float -> stop:float -> bool
(** [price <= stop], within {!tolerance}: a sell stop (long exit) at [stop] is
    hit by a trade at [price]. *)

val buy_stop_reached : price:float -> stop:float -> bool
(** [price >= stop], within {!tolerance}: a buy stop (short exit, or a buy-stop
    entry) at [stop] is hit by a trade at [price]. *)
