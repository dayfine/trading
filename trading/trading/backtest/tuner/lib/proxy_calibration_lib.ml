open Core
module Wf = Walk_forward.Walk_forward_types

(* Plan-pinned acceptance ρ for proxy-fidelity calibration. See
   `dev/plans/tuning-research-driven-program-v2-2026-05-25.md` §M1 T1.4. *)
let acceptance_threshold = 0.7

(* -------------------------- ranking ----------------------------------- *)

(* [_ranks xs] returns the mid-rank vector: equal values share the average of
   the ranks they would occupy if distinguishable. Ranks are 1-based to match
   the textbook Spearman definition (though the correlation is invariant under
   a constant shift, the convention keeps debug output familiar). *)
let _ranks (xs : float array) : float array =
  let n = Array.length xs in
  if n = 0 then [||]
  else
    let indexed = Array.mapi xs ~f:(fun i x -> (x, i)) in
    Array.sort indexed ~compare:(fun (a, _) (b, _) -> Float.compare a b);
    let ranks = Array.create ~len:n 0.0 in
    let i = ref 0 in
    while !i < n do
      let j = ref (!i + 1) in
      (* Walk forward while values tie. *)
      while !j < n && Float.equal (fst indexed.(!j)) (fst indexed.(!i)) do
        incr j
      done;
      (* The tied block spans [!i, !j). Assign each the average rank. *)
      let block_lo = !i + 1 in
      (* 1-based *)
      let block_hi = !j in
      (* 1-based, inclusive *)
      let avg = Float.of_int (block_lo + block_hi) /. 2.0 in
      for k = !i to !j - 1 do
        let _, original_idx = indexed.(k) in
        ranks.(original_idx) <- avg
      done;
      i := !j
    done;
    ranks

(* -------------------------- Pearson correlation ----------------------- *)

let _mean (xs : float array) : float =
  let n = Array.length xs in
  if n = 0 then 0.0
  else Array.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int n

let _pearson (xs : float array) (ys : float array) : float =
  let n = Array.length xs in
  if n <= 1 then 0.0
  else
    let mx = _mean xs in
    let my = _mean ys in
    let num = ref 0.0 in
    let sxx = ref 0.0 in
    let syy = ref 0.0 in
    for i = 0 to n - 1 do
      let dx = xs.(i) -. mx in
      let dy = ys.(i) -. my in
      num := !num +. (dx *. dy);
      sxx := !sxx +. (dx *. dx);
      syy := !syy +. (dy *. dy)
    done;
    let denom = Float.sqrt (!sxx *. !syy) in
    if Float.( <= ) denom 0.0 then 0.0 else !num /. denom

let spearman_rho (xs : float array) (ys : float array) : float =
  let nx = Array.length xs in
  let ny = Array.length ys in
  if nx <> ny then
    invalid_arg
      (Printf.sprintf "spearman_rho: array length mismatch (%d vs %d)" nx ny)
  else if nx = 0 then 0.0
  else
    let rx = _ranks xs in
    let ry = _ranks ys in
    _pearson rx ry

(* -------------------------- fold-actual joining ---------------------- *)

type fold_pair = {
  fold_name : string;
  cheap : float;
  expensive : float;
}

let _metric_of (fa : Wf.fold_actual)
    (metric :
      [ `Sharpe
      | `Total_return_pct
      | `Calmar
      | `CAGR
      | `Max_drawdown_pct ]) : float =
  match metric with
  | `Sharpe -> fa.sharpe_ratio
  | `Total_return_pct -> fa.total_return_pct
  | `Calmar -> fa.calmar_ratio
  | `CAGR -> fa.cagr_pct
  | `Max_drawdown_pct -> fa.max_drawdown_pct

let matched_pairs ~(cheap_actuals : Wf.fold_actual list)
    ~(expensive_actuals : Wf.fold_actual list)
    ~(metric :
       [ `Sharpe
       | `Total_return_pct
       | `Calmar
       | `CAGR
       | `Max_drawdown_pct ]) : fold_pair list =
  let exp_table = String.Table.create () in
  List.iter expensive_actuals ~f:(fun fa ->
      Hashtbl.set exp_table ~key:fa.fold_name ~data:fa);
  List.filter_map cheap_actuals ~f:(fun cheap_fa ->
      match Hashtbl.find exp_table cheap_fa.fold_name with
      | None -> None
      | Some exp_fa ->
          Some
            {
              fold_name = cheap_fa.fold_name;
              cheap = _metric_of cheap_fa metric;
              expensive = _metric_of exp_fa metric;
            })

(* -------------------------- verdict ---------------------------------- *)

type verdict = Pass | Fail [@@deriving show, eq]

let classify ~threshold ~rho =
  if Float.is_nan rho then Fail
  else if Float.( >= ) rho threshold then Pass
  else Fail
