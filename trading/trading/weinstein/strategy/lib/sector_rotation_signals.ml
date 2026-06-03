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

(* An unmapped symbol is its own singleton sector, keyed distinctly so it never
   collides with a real GICS sector name (or another unmapped symbol). *)
let _sector_key ~sector_of (symbol : string) : string =
  match sector_of symbol with
  | Some sector -> "sector:" ^ sector
  | None -> "symbol:" ^ symbol

(* Fold step: admit candidate [c] into the running ([counts], [acc]) only while
   fewer than [k] symbols are picked overall and [c]'s sector holds fewer than
   [cap] picks; otherwise leave the accumulator unchanged. *)
let _admit ~k ~cap ~sector_of (counts, acc) (c : candidate) =
  let key = _sector_key ~sector_of c.symbol in
  let n = Map.find counts key |> Option.value ~default:0 in
  if List.length acc >= k || n >= cap then (counts, acc)
  else (Map.set counts ~key ~data:(n + 1), c.symbol :: acc)

(* Walk candidates in RS-descending, symbol-ascending order, admitting each only
   while the total pick count is below [k] and the candidate's sector holds
   fewer than [cap] picks. Returns the admitted symbols. *)
let _take_capped ~(sorted : candidate list) ~(k : int) ~(cap : int) ~sector_of :
    String.Set.t =
  let _picked, symbols =
    List.fold sorted ~init:(String.Map.empty, []) ~f:(_admit ~k ~cap ~sector_of)
  in
  String.Set.of_list symbols

let rank_top_k_capped ~(candidates : candidate list) ~(k : int)
    ~(sector_cap : int option) ~(sector_of : string -> string option) :
    String.Set.t =
  match sector_cap with
  | None -> rank_top_k ~candidates ~k
  | Some cap ->
      if k <= 0 || cap <= 0 then String.Set.empty
      else
        let sorted = List.sort candidates ~compare:_compare_candidate in
        _take_capped ~sorted ~k ~cap ~sector_of
