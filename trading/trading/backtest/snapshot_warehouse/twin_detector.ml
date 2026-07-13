open Core

module Config = struct
  type basis = Levels | Returns [@@deriving sexp, equal]

  type t = {
    enabled : bool;
    min_overlap_days : int;
    match_fraction : float;
    close_epsilon : float;
    basis : basis; [@sexp.default Levels]
    ret_epsilon : float; [@sexp.default 1e-3]
    prefilter_rel_tol : float;
  }
  [@@deriving sexp, equal]

  let default =
    {
      enabled = false;
      min_overlap_days = 100;
      match_fraction = 0.95;
      close_epsilon = 1e-4;
      basis = Levels;
      ret_epsilon = 1e-3;
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

(* Merge two date-sorted close arrays into the (close_a, close_b) pairs on the
   dates both series have, in ascending date order. *)
let _shared_closes a b =
  let la = Array.length a and lb = Array.length b in
  let i = ref 0 and j = ref 0 in
  let acc = ref [] in
  while !i < la && !j < lb do
    let da, ca = a.(!i) and db, cb = b.(!j) in
    let c = Date.compare da db in
    if c < 0 then incr i
    else if c > 0 then incr j
    else begin
      acc := (ca, cb) :: !acc;
      incr i;
      incr j
    end
  done;
  Array.of_list (List.rev !acc)

(* [Levels] fraction: shared dates whose closes match within [epsilon]. *)
let _levels_match_fraction shared ~epsilon =
  let overlap = Array.length shared in
  if Int.equal overlap 0 then 0.0
  else
    let matched =
      Array.count shared ~f:(fun (ca, cb) ->
          Float.( <= ) (_relative_diff ca cb) epsilon)
    in
    Float.of_int matched /. Float.of_int overlap

(* [Returns] fraction: consecutive-shared-date return pairs whose simple daily
   returns differ by at most [epsilon] (absolute). A pair is skipped when the
   prior close of either leg is <= 0 (undefined return); the fraction is over
   the surviving (valid) pairs. Returns 0.0 when no valid pair exists. *)
let _returns_match_fraction shared ~epsilon =
  let valid = ref 0 and matched = ref 0 in
  for k = 1 to Array.length shared - 1 do
    let pa, pb = shared.(k - 1) and ca, cb = shared.(k) in
    if Float.( > ) pa 0.0 && Float.( > ) pb 0.0 then begin
      incr valid;
      let ra = (ca -. pa) /. pa and rb = (cb -. pb) /. pb in
      if Float.( <= ) (Float.abs (ra -. rb)) epsilon then incr matched
    end
  done;
  if Int.equal !valid 0 then 0.0
  else Float.of_int !matched /. Float.of_int !valid

(* Number of shared dates and the basis-appropriate match fraction. *)
let _overlap_and_fraction (config : Config.t) a b =
  let shared = _shared_closes a b in
  let frac =
    match config.basis with
    | Levels -> _levels_match_fraction shared ~epsilon:config.close_epsilon
    | Returns -> _returns_match_fraction shared ~epsilon:config.ret_epsilon
  in
  (Array.length shared, frac)

(* [Some (overlap, fraction)] when [a] and [b] meet the twin criterion. *)
let _twin_stats (config : Config.t) a b =
  let overlap, frac = _overlap_and_fraction config a.closes b.closes in
  if overlap < config.min_overlap_days then None
  else if Float.( > ) frac config.match_fraction then Some (overlap, frac)
  else None

(* Index of [date] in the date-sorted array, if present. *)
let _index_on arr ~date =
  Array.binary_search arr
    ~compare:(fun (d1, _) (d2, _) -> Date.compare d1 d2)
    `First_equal_to (date, Float.nan)

(* Adjusted close on [date] via binary search of the sorted array. *)
let _close_on arr ~date =
  Option.map (_index_on arr ~date) ~f:(fun i -> snd arr.(i))

(* Simple daily return on [date] — close on [date] vs the leg's own prior bar.
   [None] when [date] is the leg's first bar (no prior) or the prior close is
   non-positive (undefined return). *)
let _return_on arr ~date =
  match _index_on arr ~date with
  | Some i when i > 0 ->
      let prev = snd arr.(i - 1) and cur = snd arr.(i) in
      if Float.( > ) prev 0.0 then Some ((cur -. prev) /. prev) else None
  | _ -> None

(* Anchor key of series [s] on [date] under the configured basis: the close
   ([Levels]) or the anchor-date return ([Returns]). *)
let _anchor_key (config : Config.t) s ~date =
  match config.basis with
  | Levels -> _close_on s.closes ~date
  | Returns -> _return_on s.closes ~date

(* Whether two anchor keys are near enough to co-run in the prefilter: a
   relative close gap ([Levels]) or an absolute return gap ([Returns]). *)
let _prefilter_close_enough (config : Config.t) a b =
  match config.basis with
  | Levels -> Float.( <= ) (_relative_diff a b) config.prefilter_rel_tol
  | Returns -> Float.( <= ) (Float.abs (a -. b)) config.prefilter_rel_tol

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

(* Series with a defined anchor key on [date], as (index, key) sorted ascending
   by key. Under [Returns] a leg without a prior bar on [date] is omitted. *)
let _actives_at (config : Config.t) series_arr ~date =
  Array.filter_mapi series_arr ~f:(fun i s ->
      Option.map (_anchor_key config s ~date) ~f:(fun k -> (i, k)))
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
let _candidate_pairs (config : Config.t) series_arr =
  let n = Array.length series_arr in
  let stride = Int.max 1 (config.min_overlap_days / 2) in
  let anchors = _anchor_dates ~stride series_arr in
  let seen = Hash_set.create (module Int) in
  let close_enough = _prefilter_close_enough config in
  Array.iter anchors ~f:(fun date ->
      _actives_at config series_arr ~date
      |> _group_runs ~close_enough
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
  let overlap, frac =
    _overlap_and_fraction config survivor.closes dropped.closes
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

let _basis_label = function
  | Config.Levels -> "levels"
  | Config.Returns -> "returns"

let render report =
  let cfg = report.config in
  let header =
    Printf.sprintf
      "rename-twin report: basis=%s enabled=%b min_overlap_days=%d \
       match_fraction=%.4f close_epsilon=%.6g ret_epsilon=%.6g\n\
       %d group(s), %d symbol(s) dropped"
      (_basis_label cfg.basis) cfg.enabled cfg.min_overlap_days
      cfg.match_fraction cfg.close_epsilon cfg.ret_epsilon
      (List.length report.groups)
      (List.length report.dropped_symbols)
  in
  String.concat ~sep:"\n" (header :: List.map report.groups ~f:_render_group)
