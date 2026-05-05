(** Bar-shaped view records — see [panel_views.mli]. *)

open Core

type weekly_view = {
  closes : float array;
  raw_closes : float array;
  highs : float array;
  lows : float array;
  volumes : float array;
  dates : Date.t array;
  n : int;
}

type daily_view = {
  highs : float array;
  lows : float array;
  closes : float array;
  dates : Date.t array;
  n_days : int;
}
