open Core

let window_closes ~adjusted ~raw =
  if Array.for_all adjusted ~f:Float.is_finite then adjusted else raw

let last_close closes =
  let n = Array.length closes in
  if n = 0 then None
  else
    let last = closes.(n - 1) in
    if Float.is_finite last then Some last else None
