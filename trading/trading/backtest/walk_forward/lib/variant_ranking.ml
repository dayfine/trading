open Core
module T = Walk_forward_types

type ranked_variant = {
  label : string;
  stability : T.variant_stability;
  on_frontier : bool;
  dominated_by : string list;
}
[@@deriving sexp]

type ranking = { variants : ranked_variant list; frontier : string list }
[@@deriving sexp]

(* One objective axis: the mean to compare and whether higher is better. We
   normalise "lower is better" (MaxDrawdown%) by negating so every axis is a
   plain "higher is better" comparison. *)
let _objectives (s : T.variant_stability) =
  [
    s.sharpe_ratio.mean; s.calmar_ratio.mean; Float.neg s.max_drawdown_pct.mean;
  ]

(* [a] is at-least-as-good as [b] on an axis, and strictly-better, ignoring NaN
   (a NaN on either side is not comparable: never at-least, never strictly). *)
let _at_least x y = Float.is_finite x && Float.is_finite y && Float.(x >= y)
let _strictly x y = Float.is_finite x && Float.is_finite y && Float.(x > y)

let dominates (a : T.variant_stability) (b : T.variant_stability) =
  let axes = List.zip_exn (_objectives a) (_objectives b) in
  List.for_all axes ~f:(fun (x, y) -> _at_least x y)
  && List.exists axes ~f:(fun (x, y) -> _strictly x y)

let _check_unique_labels stabilities =
  let labels =
    List.map stabilities ~f:(fun (s : T.variant_stability) -> s.variant_label)
  in
  if List.contains_dup labels ~compare:String.compare then
    invalid_arg
      "Variant_ranking.rank: duplicate variant label; labels must be unique"

let rank stabilities =
  _check_unique_labels stabilities;
  let variants =
    List.map stabilities ~f:(fun (s : T.variant_stability) ->
        let dominated_by =
          List.filter_map stabilities ~f:(fun (other : T.variant_stability) ->
              let is_self = String.equal other.variant_label s.variant_label in
              if (not is_self) && dominates other s then
                Some other.variant_label
              else None)
        in
        {
          label = s.variant_label;
          stability = s;
          on_frontier = List.is_empty dominated_by;
          dominated_by;
        })
  in
  let frontier =
    List.filter_map variants ~f:(fun v ->
        if v.on_frontier then Some v.label else None)
  in
  { variants; frontier }

let _fmt_dsr deflated_sharpe_by_label label =
  match List.Assoc.find deflated_sharpe_by_label label ~equal:String.equal with
  | Some d -> sprintf "%.4f" d
  | None -> "n/a"

let _variant_row deflated_sharpe_by_label (v : ranked_variant) =
  let s = v.stability in
  sprintf "| %s | %.3f | %.3f | %.2f | %s | %s |" v.label s.sharpe_ratio.mean
    s.calmar_ratio.mean s.max_drawdown_pct.mean
    (if v.on_frontier then "yes" else "no")
    (_fmt_dsr deflated_sharpe_by_label v.label)

let render ranking ~deflated_sharpe_by_label =
  let frontier_section =
    sprintf "## Pareto frontier (Sharpe up, Calmar up, MaxDD down)\n\n%s"
      (if List.is_empty ranking.frontier then "_(none)_"
       else
         String.concat ~sep:"\n"
           (List.map ranking.frontier ~f:(fun l -> sprintf "- %s" l)))
  in
  let header =
    "| Variant | Sharpe | Calmar | MaxDD % | Frontier | Deflated Sharpe |\n\
     |---------|-------:|-------:|--------:|:--------:|----------------:|"
  in
  let rows =
    List.map ranking.variants ~f:(_variant_row deflated_sharpe_by_label)
  in
  String.concat ~sep:"\n"
    [
      frontier_section;
      "";
      "## Variants";
      "";
      header;
      String.concat ~sep:"\n" rows;
    ]
