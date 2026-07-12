open Core

module Config = struct
  type t = {
    enabled : bool;
    min_overlap_days : int;
    match_fraction : float;
    close_epsilon : float;
    prefilter_rel_tol : float;
  }
  [@@deriving sexp, equal]

  let default =
    {
      enabled = false;
      min_overlap_days = 100;
      match_fraction = 0.95;
      close_epsilon = 1e-4;
      prefilter_rel_tol = 2e-2;
    }
end

type series = {
  symbol : string;
  data_end : Date.t;
  closes : (Date.t * float) array;
}
[@@deriving sexp_of]

type pair_match = {
  survivor : string;
  dropped : string;
  overlap_days : int;
  match_fraction : float;
}
[@@deriving sexp_of, equal]

type group = {
  survivor : string;
  dropped : string list;
  matches : pair_match list;
}
[@@deriving sexp_of, equal]

type report = {
  config : Config.t;
  groups : group list;
  dropped_symbols : string list;
}
[@@deriving sexp_of]

(* Relative distance between two closes, guarded against a zero magnitude. *)
let _relative_diff a b =
  let denom = Float.max (Float.abs a) (Float.abs b) in
  if Float.( <= ) denom 0.0 then 0.0 else Float.abs (a -. b) /. denom

(* Merge two date-sorted close arrays, counting shared dates and, among
   those, how many have near-identical closes within [epsilon]. *)
let _overlap_and_match a b ~epsilon =
  let la = Array.length a and lb = Array.length b in
  let i = ref 0 and j = ref 0 in
  let overlap = ref 0 and matched = ref 0 in
  while !i < la && !j < lb do
    let da, ca = a.(!i) and db, cb = b.(!j) in
    let c = Date.compare da db in
    if c < 0 then incr i
    else if c > 0 then incr j
    else begin
      incr overlap;
      if Float.( <= ) (_relative_diff ca cb) epsilon then incr matched;
      incr i;
      incr j
    end
  done;
  (!overlap, !matched)

(* [Some (overlap, fraction)] when [a] and [b] meet the twin criterion. *)
let _twin_stats (config : Config.t) a b =
  let overlap, matched =
    _overlap_and_match a.closes b.closes ~epsilon:config.close_epsilon
  in
  if overlap < config.min_overlap_days then None
  else
    let frac = Float.of_int matched /. Float.of_int overlap in
    if Float.( > ) frac config.match_fraction then Some (overlap, frac)
    else None

(* Adjusted close on [date] via binary search of the sorted array. *)
let _close_on arr ~date =
  match
    Array.binary_search arr
      ~compare:(fun (d1, _) (d2, _) -> Date.compare d1 d2)
      `First_equal_to (date, Float.nan)
  with
  | Some i -> Some (snd arr.(i))
  | None -> None

(* Every distinct date across all series, sorted ascending. *)
let _unique_sorted_dates series_arr =
  let seen = Hash_set.create (module Date) in
  Array.iter series_arr ~f:(fun s ->
      Array.iter s.closes ~f:(fun (d, _) -> Hash_set.add seen d));
  Hash_set.to_list seen |> List.sort ~compare:Date.compare |> Array.of_list

(* Anchor dates: every [stride]-th distinct date. Because [stride <
   min_overlap_days], any twin pair with a dense >=[min_overlap_days]
   overlap shares at least one anchor, so the prefilter keeps it. *)
let _anchor_dates ~stride series_arr =
  let all = _unique_sorted_dates series_arr in
  Array.filteri all ~f:(fun idx _ -> idx % stride = 0)

(* Series active on [date], as (index, close) sorted ascending by close. *)
let _actives_at series_arr ~date =
  Array.filter_mapi series_arr ~f:(fun i s ->
      Option.map (_close_on s.closes ~date) ~f:(fun c -> (i, c)))
  |> Array.to_list
  |> List.sort ~compare:(fun (_, c1) (_, c2) -> Float.compare c1 c2)

(* Partition a close-sorted (index, close) list into maximal runs whose
   consecutive relative gap stays within [rel_tol]. Twins land in one run. *)
let _group_runs ~rel_tol sorted =
  match sorted with
  | [] -> []
  | (i0, c0) :: tl ->
      let runs, cur, _ =
        List.fold tl ~init:([], [ i0 ], c0)
          ~f:(fun (runs, cur, prev_c) (i, c) ->
            if Float.( <= ) (_relative_diff prev_c c) rel_tol then
              (runs, i :: cur, c)
            else (cur :: runs, [ i ], c))
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
let _candidate_pairs (config : Config.t) series_arr =
  let n = Array.length series_arr in
  let stride = Int.max 1 (config.min_overlap_days / 2) in
  let anchors = _anchor_dates ~stride series_arr in
  let seen = Hash_set.create (module Int) in
  Array.iter anchors ~f:(fun date ->
      _actives_at series_arr ~date
      |> _group_runs ~rel_tol:config.prefilter_rel_tol
      |> List.iter ~f:(fun run ->
          List.iter (_run_pairs run) ~f:(fun (i, j) ->
              Hash_set.add seen ((i * n) + j))));
  Hash_set.to_list seen |> List.map ~f:(fun k -> (k / n, k % n))

(* Minimal index union-find. *)
let _uf_make n = Array.init n ~f:Fn.id

let rec _uf_root parents i =
  if Int.equal parents.(i) i then i else _uf_root parents parents.(i)

let _uf_union parents i j =
  let ri = _uf_root parents i and rj = _uf_root parents j in
  if not (Int.equal ri rj) then parents.(ri) <- rj

(* Connected components with >= 2 members, as index lists. *)
let _components parents n =
  let tbl = Hashtbl.create (module Int) in
  for i = 0 to n - 1 do
    Hashtbl.add_multi tbl ~key:(_uf_root parents i) ~data:i
  done;
  Hashtbl.data tbl |> List.filter ~f:(fun l -> List.length l >= 2)

(* Rename survivor: latest [data_end]; ties broken by smaller symbol. *)
let _pick_survivor members =
  List.reduce_exn members ~f:(fun a b ->
      match Date.compare a.data_end b.data_end with
      | c when c > 0 -> a
      | c when c < 0 -> b
      | _ -> if String.compare a.symbol b.symbol <= 0 then a else b)

let _make_pair_match (config : Config.t) survivor dropped =
  let overlap, matched =
    _overlap_and_match survivor.closes dropped.closes
      ~epsilon:config.close_epsilon
  in
  let frac =
    if Int.equal overlap 0 then 0.0
    else Float.of_int matched /. Float.of_int overlap
  in
  {
    survivor = survivor.symbol;
    dropped = dropped.symbol;
    overlap_days = overlap;
    match_fraction = frac;
  }

let _make_group config members =
  let survivor = _pick_survivor members in
  let dropped_series =
    List.filter members ~f:(fun s ->
        not (String.equal s.symbol survivor.symbol))
  in
  let dropped =
    List.map dropped_series ~f:(fun s -> s.symbol)
    |> List.sort ~compare:String.compare
  in
  let matches =
    List.map dropped_series ~f:(_make_pair_match config survivor)
    |> List.sort ~compare:(fun a b -> String.compare a.dropped b.dropped)
  in
  { survivor = survivor.symbol; dropped; matches }

let _empty_report config = { config; groups = []; dropped_symbols = [] }

let detect (config : Config.t) series_list =
  if not config.enabled then _empty_report config
  else begin
    let series_arr = Array.of_list series_list in
    let n = Array.length series_arr in
    let parents = _uf_make n in
    List.iter (_candidate_pairs config series_arr) ~f:(fun (i, j) ->
        match _twin_stats config series_arr.(i) series_arr.(j) with
        | Some _ -> _uf_union parents i j
        | None -> ());
    let groups =
      _components parents n
      |> List.map ~f:(fun idxs ->
          _make_group config (List.map idxs ~f:(fun i -> series_arr.(i))))
      |> List.sort ~compare:(fun a b -> String.compare a.survivor b.survivor)
    in
    let dropped_symbols =
      List.concat_map groups ~f:(fun g -> g.dropped)
      |> List.sort ~compare:String.compare
    in
    { config; groups; dropped_symbols }
  end

let survivors report ~all_symbols =
  let drop = String.Set.of_list report.dropped_symbols in
  List.filter all_symbols ~f:(fun s -> not (Set.mem drop s))

let _render_match (m : pair_match) =
  Printf.sprintf "    %s (overlap=%d, match=%.4f)" m.dropped m.overlap_days
    m.match_fraction

let _render_group (g : group) =
  let hdr =
    Printf.sprintf "  survivor %s <- [%s]" g.survivor
      (String.concat ~sep:"; " g.dropped)
  in
  String.concat ~sep:"\n" (hdr :: List.map g.matches ~f:_render_match)

let render report =
  let cfg = report.config in
  let header =
    Printf.sprintf
      "rename-twin report: enabled=%b min_overlap_days=%d match_fraction=%.4f \
       close_epsilon=%.6g\n\
       %d group(s), %d symbol(s) dropped"
      cfg.enabled cfg.min_overlap_days cfg.match_fraction cfg.close_epsilon
      (List.length report.groups)
      (List.length report.dropped_symbols)
  in
  String.concat ~sep:"\n" (header :: List.map report.groups ~f:_render_group)
