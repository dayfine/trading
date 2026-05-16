open Core

let _at running_best ~k =
  let n = List.length running_best in
  if k < 0 || k >= n then None else List.nth running_best (n - 1 - k)

let should_stop ~window ~epsilon ~initial_random ~running_best =
  let n = List.length running_best in
  if n <= initial_random + window then false
  else
    match (_at running_best ~k:0, _at running_best ~k:window) with
    | Some recent, Some past -> Float.( < ) (recent -. past) epsilon
    | _ -> false
