open Core

(* Index of [date] in the date-sorted array, if present. *)
let _index_on arr ~date =
  Array.binary_search arr
    ~compare:(fun (d1, _) (d2, _) -> Date.compare d1 d2)
    `First_equal_to (date, Float.nan)

(* Adjusted close on [date] via binary search of the sorted array. *)
let close_on arr ~date =
  Option.map (_index_on arr ~date) ~f:(fun i -> snd arr.(i))

(* Simple daily return on [date] — close on [date] vs the leg's own prior bar.
   [None] when [date] is the leg's first bar (no prior) or the prior close is
   non-positive (undefined return). *)
let return_on arr ~date =
  match _index_on arr ~date with
  | Some i when i > 0 ->
      let prev = snd arr.(i - 1) and cur = snd arr.(i) in
      if Float.( > ) prev 0.0 then Some ((cur -. prev) /. prev) else None
  | _ -> None

(* Every distinct date across all series, sorted ascending. *)
let _unique_sorted_dates closes_arr =
  let seen = Hash_set.create (module Date) in
  Array.iter closes_arr ~f:(fun closes ->
      Array.iter closes ~f:(fun (d, _) -> Hash_set.add seen d));
  Hash_set.to_list seen |> List.sort ~compare:Date.compare |> Array.of_list

(* Anchor dates: every [stride]-th distinct date. Because [stride <
   min_overlap_days], any twin pair with a dense >=[min_overlap_days]
   overlap shares at least one anchor, so the prefilter keeps it. *)
let _anchor_dates ~stride closes_arr =
  let all = _unique_sorted_dates closes_arr in
  Array.filteri all ~f:(fun idx _ -> idx % stride = 0)

(* Series with a defined anchor key on [date], as (index, key) sorted ascending
   by key. Under [Returns] a leg without a prior bar on [date] is omitted. *)
let _actives_at ~anchor_key closes_arr ~date =
  Array.filter_mapi closes_arr ~f:(fun i closes ->
      Option.map (anchor_key closes ~date) ~f:(fun k -> (i, k)))
  |> Array.to_list
  |> List.sort ~compare:(fun (_, k1) (_, k2) -> Float.compare k1 k2)

(* Partition a key-sorted (index, key) list into maximal runs whose consecutive
   keys stay near per [close_enough]. Twins land in one run. *)
let _group_runs ~close_enough sorted =
  match sorted with
  | [] -> []
  | (i0, k0) :: tl ->
      let runs, cur, _ =
        List.fold tl ~init:([], [ i0 ], k0)
          ~f:(fun (runs, cur, prev_k) (i, k) ->
            if close_enough prev_k k then (runs, i :: cur, k)
            else (cur :: runs, [ i ], k))
      in
      cur :: runs

(* All unordered index pairs within a run, canonicalised as (min, max). *)
let _run_pairs run =
  let arr = Array.of_list run in
  let acc = ref [] in
  for a = 0 to Array.length arr - 1 do
    for b = a + 1 to Array.length arr - 1 do
      let x = arr.(a) and y = arr.(b) in
      acc := (Int.min x y, Int.max x y) :: !acc
    done
  done;
  !acc

(* Deduplicated candidate index pairs from the anchor-date prefilter. *)
let candidate_pairs ~min_overlap_days ~anchor_key ~close_enough closes_arr =
  let n = Array.length closes_arr in
  let stride = Int.max 1 (min_overlap_days / 2) in
  let anchors = _anchor_dates ~stride closes_arr in
  let seen = Hash_set.create (module Int) in
  Array.iter anchors ~f:(fun date ->
      _actives_at ~anchor_key closes_arr ~date
      |> _group_runs ~close_enough
      |> List.iter ~f:(fun run ->
          List.iter (_run_pairs run) ~f:(fun (i, j) ->
              Hash_set.add seen ((i * n) + j))));
  Hash_set.to_list seen |> List.map ~f:(fun k -> (k / n, k % n))
