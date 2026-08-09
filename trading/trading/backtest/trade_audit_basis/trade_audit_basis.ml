open Core

let window_closes ~adjusted ~raw =
  if Array.for_all adjusted ~f:Float.is_finite then adjusted else raw

let last_close ~adjusted ~raw =
  let closes = window_closes ~adjusted ~raw in
  if Array.is_empty closes then None
  else
    let newest = closes.(Array.length closes - 1) in
    if Float.is_finite newest then Some newest else None
