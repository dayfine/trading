open Core

let window_closes ~adjusted ~raw =
  if Array.for_all adjusted ~f:Float.is_finite then adjusted else raw
