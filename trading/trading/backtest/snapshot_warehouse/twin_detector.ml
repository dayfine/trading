open Core
include Twin_types

(* Number of shared dates, the basis-appropriate match fraction, and the
   longest contiguous matching run. *)
let _overlap_stats (config : Config.t) a b =
  let shared = Twin_match_stats.shared_closes a b in
  let frac, run =
    match config.basis with
    | Levels ->
        Twin_match_stats.levels_match_stats shared ~epsilon:config.close_epsilon
    | Returns ->
        Twin_match_stats.returns_match_stats shared ~epsilon:config.ret_epsilon
  in
  (Array.length shared, frac, run)

let _overlap_and_fraction config a b =
  let overlap, frac, _ = _overlap_stats config a b in
  (overlap, frac)

(* The #3057 run criterion: armed only by [min_matching_run]. *)
let _run_qualifies (config : Config.t) run =
  Option.value_map config.min_matching_run ~default:false ~f:(fun n -> run >= n)

(* [Some (overlap, fraction)] when [a] and [b] meet the twin criterion: enough
   overlap, and either the match fraction or (when armed) the longest
   contiguous matching run clears its bar. *)
let _twin_stats (config : Config.t) a b =
  let overlap, frac, run = _overlap_stats config a.closes b.closes in
  if overlap < config.min_overlap_days then None
  else if Float.( > ) frac config.match_fraction || _run_qualifies config run
  then Some (overlap, frac)
  else None

(* Anchor key of a close array on [date] under the configured basis: the close
   ([Levels]) or the anchor-date return ([Returns]). *)
let _anchor_key (config : Config.t) closes ~date =
  match config.basis with
  | Levels -> Twin_prefilter.close_on closes ~date
  | Returns -> Twin_prefilter.return_on closes ~date

(* Whether two anchor keys are near enough to co-run in the prefilter: a
   relative close gap ([Levels]) or an absolute return gap ([Returns]). *)
let _prefilter_close_enough (config : Config.t) a b =
  match config.basis with
  | Levels ->
      Float.( <= ) (Twin_match_stats.relative_diff a b) config.prefilter_rel_tol
  | Returns -> Float.( <= ) (Float.abs (a -. b)) config.prefilter_rel_tol

(* Candidate index pairs from the anchor-date prefilter under [config]. *)
let _candidate_pairs (config : Config.t) series_arr =
  Twin_prefilter.candidate_pairs ~min_overlap_days:config.min_overlap_days
    ~anchor_key:(_anchor_key config)
    ~close_enough:(_prefilter_close_enough config)
    (Array.map series_arr ~f:(fun s -> s.closes))

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

(* A group of [survivor] plus the legs that are actually dropped for it. *)
let _group_of config survivor dropped_series =
  let dropped =
    List.map dropped_series ~f:(fun s -> s.symbol)
    |> List.sort ~compare:String.compare
  in
  let matches =
    List.map dropped_series ~f:(_make_pair_match config survivor)
    |> List.sort ~compare:(fun a b -> String.compare a.dropped b.dropped)
  in
  { survivor = survivor.symbol; dropped; matches }

let _make_rejection config reason survivor leg =
  let overlap, frac = _overlap_and_fraction config survivor.closes leg.closes in
  {
    reason;
    survivor = survivor.symbol;
    kept = leg.symbol;
    overlap_days = overlap;
    match_fraction = frac;
  }

(* A component exceeds the hub guard when it has more members than the cap. *)
let _over_cap (config : Config.t) members =
  match config.max_group_size with
  | None -> false
  | Some cap -> List.length members > cap

(* Split a component into the group it yields (if any) and the legs a guard
   spared. Without either guard every non-survivor leg is dropped, which is the
   pre-#2823 behaviour. Only the hub guard suppresses a component's group
   entirely: [require_direct_match] can never empty [direct], because a
   component of >= 2 members is connected by verified [_twin_stats] edges and
   [_twin_stats] is symmetric, so the survivor's own verified partner always
   passes the direct re-check. *)
let _classify_component (config : Config.t) members =
  let survivor = _pick_survivor members in
  let legs =
    List.filter members ~f:(fun s ->
        not (String.equal s.symbol survivor.symbol))
  in
  let spare reason =
    List.map legs ~f:(_make_rejection config reason survivor)
  in
  if _over_cap config members then (None, spare Hub)
  else if not config.require_direct_match then
    (Some (_group_of config survivor legs), [])
  else
    let direct, indirect =
      List.partition_tf legs ~f:(fun leg ->
          Option.is_some (_twin_stats config survivor leg))
    in
    let rejected =
      List.map indirect ~f:(_make_rejection config Transitive survivor)
    in
    (Some (_group_of config survivor direct), rejected)

let _empty_report config =
  { config; groups = []; dropped_symbols = []; rejected = [] }

(* Union-find over the pairs the prefilter proposed and the full criterion
   verified. Grouping is transitive by construction — that is what the #2823
   guards in [_classify_component] compensate for. *)
let _union_verified_pairs config series_arr =
  let parents = _uf_make (Array.length series_arr) in
  List.iter (_candidate_pairs config series_arr) ~f:(fun (i, j) ->
      match _twin_stats config series_arr.(i) series_arr.(j) with
      | Some _ -> _uf_union parents i j
      | None -> ());
  parents

let detect (config : Config.t) series_list =
  if not config.enabled then _empty_report config
  else begin
    let series_arr = Array.of_list series_list in
    let n = Array.length series_arr in
    let classified =
      _components (_union_verified_pairs config series_arr) n
      |> List.map ~f:(fun idxs ->
          _classify_component config
            (List.map idxs ~f:(fun i -> series_arr.(i))))
    in
    let groups =
      List.filter_map classified ~f:fst
      |> List.sort ~compare:(fun a b -> String.compare a.survivor b.survivor)
    in
    let rejected =
      List.concat_map classified ~f:snd
      |> List.sort ~compare:(fun a b -> String.compare a.kept b.kept)
    in
    let dropped_symbols =
      List.concat_map groups ~f:(fun g -> g.dropped)
      |> List.sort ~compare:String.compare
    in
    { config; groups; dropped_symbols; rejected }
  end

module Alias_map = struct
  type entry = {
    dropped : string;
    survivor : string;
    match_fraction : float;
    overlap_days : int;
  }
  [@@deriving sexp, equal]

  type t = { aliases : entry list; rejected : rejection list }
  [@@deriving sexp, equal]

  let of_report report =
    let aliases =
      List.concat_map report.groups ~f:(fun g -> g.matches)
      |> List.map ~f:(fun (m : pair_match) ->
          {
            dropped = m.dropped;
            survivor = m.survivor;
            match_fraction = m.match_fraction;
            overlap_days = m.overlap_days;
          })
      |> List.sort ~compare:(fun a b -> String.compare a.dropped b.dropped)
    in
    { aliases; rejected = report.rejected }
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

let _reason_label = function
  | Transitive -> "rejected_transitive"
  | Hub -> "rejected_hub"

let _render_rejection (r : rejection) =
  Printf.sprintf "  %s %s (survivor=%s, overlap=%d, match=%.4f)"
    (_reason_label r.reason) r.kept r.survivor r.overlap_days r.match_fraction

(* Guards name themselves in the header only when armed, so a default-config
   report renders exactly as it did before the guards existed. *)
let _guard_suffix (cfg : Config.t) =
  let parts =
    List.filter_opt
      [
        (if cfg.require_direct_match then Some "require_direct_match=true"
         else None);
        Option.map cfg.max_group_size ~f:(Printf.sprintf "max_group_size=%d");
        Option.map cfg.min_matching_run
          ~f:(Printf.sprintf "min_matching_run=%d");
      ]
  in
  if List.is_empty parts then "" else " " ^ String.concat ~sep:" " parts

let render report =
  let cfg = report.config in
  let header =
    Printf.sprintf
      "rename-twin report: basis=%s enabled=%b min_overlap_days=%d \
       match_fraction=%.4f close_epsilon=%.6g ret_epsilon=%.6g%s\n\
       %d group(s), %d symbol(s) dropped"
      (_basis_label cfg.basis) cfg.enabled cfg.min_overlap_days
      cfg.match_fraction cfg.close_epsilon cfg.ret_epsilon (_guard_suffix cfg)
      (List.length report.groups)
      (List.length report.dropped_symbols)
  in
  String.concat ~sep:"\n"
    ((header :: List.map report.groups ~f:_render_group)
    @ List.map report.rejected ~f:_render_rejection)
