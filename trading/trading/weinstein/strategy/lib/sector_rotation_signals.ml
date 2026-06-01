(** Pure selection helpers for the sector-rotation Weinstein strategy — see
    [sector_rotation_signals.mli]. *)

open Core

type candidate = { symbol : string; normalized_rs : float }

let is_stage2_advance (r : Stage.result) : bool =
  Spy_only_signals.is_entry_signal r

(* Order by RS descending, then symbol ascending so ties resolve
   deterministically (reproducible runs). *)
let _compare_candidate (a : candidate) (b : candidate) : int =
  match Float.compare b.normalized_rs a.normalized_rs with
  | 0 -> String.compare a.symbol b.symbol
  | c -> c

let rank_top_k ~(candidates : candidate list) ~(k : int) : String.Set.t =
  if k <= 0 then String.Set.empty
  else
    List.sort candidates ~compare:_compare_candidate
    |> (fun sorted -> List.take sorted k)
    |> List.map ~f:(fun c -> c.symbol)
    |> String.Set.of_list
