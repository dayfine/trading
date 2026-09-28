open Core

let _is_positive_price x = Float.is_finite x && Float.( > ) x 0.0

let raw_basis_factor (bar : Types.Daily_price.t) =
  if _is_positive_price bar.close_price && _is_positive_price bar.adjusted_close
  then Some (bar.close_price /. bar.adjusted_close)
  else None

let restate_to_raw ~bar ma =
  match raw_basis_factor bar with Some factor -> ma *. factor | None -> ma

let for_stops ~enabled ~bar ma = if enabled then restate_to_raw ~bar ma else ma
