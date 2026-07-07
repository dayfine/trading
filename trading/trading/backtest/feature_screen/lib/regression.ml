(** See [regression.mli] for the API contract. *)

open Core

type term = { name : string; coef : float; se : float; stat : float }
type ols_result = { terms : term list; r2 : float; n : int; p : int }

type logit_result = {
  terms : term list;
  auc : float;
  converged : bool;
  n : int;
  p : int;
}

(* ---------------------------------------------------------------- *)
(* Dense linear algebra                                             *)
(* ---------------------------------------------------------------- *)

let _singular_eps = 1e-12

let _dot beta row =
  Array.foldi row ~init:0.0 ~f:(fun j acc v -> acc +. (v *. beta.(j)))

(* Accumulate [w * row row'] (a rank-1 outer product) into [p × p] matrix [m]. *)
let _add_weighted_outer m ~row ~w ~p =
  for a = 0 to p - 1 do
    for b = 0 to p - 1 do
      m.(a).(b) <- m.(a).(b) +. (w *. row.(a) *. row.(b))
    done
  done

(* Index of the max-|value| row in [col] at or below [col], for partial pivoting. *)
let _pivot_row m ~col ~p =
  let pivot = ref col in
  for r = col + 1 to p - 1 do
    if Float.( > ) (Float.abs m.(r).(col)) (Float.abs m.(!pivot).(col)) then
      pivot := r
  done;
  !pivot

(* Eliminate [col] from every other row of the augmented matrix [m]. *)
let _reduce_rows m ~col ~p =
  for r = 0 to p - 1 do
    if r <> col then
      let factor = m.(r).(col) /. m.(col).(col) in
      Array.iteri m.(r) ~f:(fun j v ->
          m.(r).(j) <- v -. (factor *. m.(col).(j)))
  done

(* Gauss-Jordan elimination with partial pivoting on augmented matrix [m]. *)
let _eliminate m ~p : (unit, string) result =
  let ok = ref true in
  for col = 0 to p - 1 do
    let pivot = _pivot_row m ~col ~p in
    let tmp = m.(col) in
    m.(col) <- m.(pivot);
    m.(pivot) <- tmp;
    if Float.( < ) (Float.abs m.(col).(col)) _singular_eps then ok := false
    else _reduce_rows m ~col ~p
  done;
  if !ok then Ok () else Error "singular matrix"

let solve (a : float array array) (b : float array) :
    (float array, string) result =
  let p = Array.length b in
  let aug =
    Array.init p ~f:(fun i -> Array.append (Array.copy a.(i)) [| b.(i) |])
  in
  Result.map (_eliminate aug ~p) ~f:(fun () ->
      Array.init p ~f:(fun i -> aug.(i).(p) /. aug.(i).(i)))

let inverse (a : float array array) : (float array array, string) result =
  let p = Array.length a in
  let ident i j = if i = j then 1.0 else 0.0 in
  let aug =
    Array.init p ~f:(fun i ->
        Array.append (Array.copy a.(i)) (Array.init p ~f:(ident i)))
  in
  Result.map (_eliminate aug ~p) ~f:(fun () ->
      Array.init p ~f:(fun i ->
          Array.init p ~f:(fun j -> aug.(i).(p + j) /. aug.(i).(i))))

(* [x'x] via repeated rank-1 outer products. *)
let _gram (x : float array array) : float array array =
  let p = Array.length x.(0) in
  let g = Array.make_matrix ~dimx:p ~dimy:p 0.0 in
  Array.iter x ~f:(fun row -> _add_weighted_outer g ~row ~w:1.0 ~p);
  g

let _xty (x : float array array) (y : float array) : float array =
  let p = Array.length x.(0) in
  let v = Array.create ~len:p 0.0 in
  Array.iteri x ~f:(fun i row ->
      for a = 0 to p - 1 do
        v.(a) <- v.(a) +. (row.(a) *. y.(i))
      done);
  v

(* ---------------------------------------------------------------- *)
(* OLS with HC1-robust standard errors                              *)
(* ---------------------------------------------------------------- *)

let _make_term name coef se =
  let stat = if Float.( > ) se _singular_eps then coef /. se else 0.0 in
  { name; coef; se; stat }

(* [a]-th diagonal element of the sandwich [bread * meat * bread]. *)
let _sandwich_diag bread meat ~p ~a =
  let var = ref 0.0 in
  for b = 0 to p - 1 do
    for d = 0 to p - 1 do
      var := !var +. (bread.(a).(b) *. meat.(b).(d) *. bread.(d).(a))
    done
  done;
  !var

(* HC1 covariance diagonal: c * diag(bread * sum_i e_i^2 x_i x_i' * bread),
   with the small-sample correction c = n/(n-p). *)
let _hc1_var ~x ~resid ~bread ~n ~p : float array =
  let meat = Array.make_matrix ~dimx:p ~dimy:p 0.0 in
  Array.iteri x ~f:(fun i row ->
      _add_weighted_outer meat ~row ~w:(resid.(i) *. resid.(i)) ~p);
  let c = Float.of_int n /. Float.of_int (n - p) in
  Array.init p ~f:(fun a -> c *. _sandwich_diag bread meat ~p ~a)

let _r2 ~y ~resid =
  let ybar =
    Array.fold y ~init:0.0 ~f:( +. ) /. Float.of_int (Array.length y)
  in
  let sst =
    Array.fold y ~init:0.0 ~f:(fun acc v -> acc +. ((v -. ybar) ** 2.0))
  in
  let sse = Array.fold resid ~init:0.0 ~f:(fun acc e -> acc +. (e *. e)) in
  if Float.( <= ) sst _singular_eps then 0.0 else 1.0 -. (sse /. sst)

let _ols_fit ~x ~y ~names ~n ~p : (ols_result, string) result =
  let%bind.Result beta = solve (_gram x) (_xty x y) in
  let%bind.Result bread = inverse (_gram x) in
  let resid = Array.mapi y ~f:(fun i yi -> yi -. _dot beta x.(i)) in
  let vars = _hc1_var ~x ~resid ~bread ~n ~p in
  let terms =
    List.mapi names ~f:(fun j name ->
        _make_term name beta.(j) (Float.sqrt vars.(j)))
  in
  Ok { terms; r2 = _r2 ~y ~resid; n; p }

let ols ~x ~y ~names : (ols_result, string) result =
  let n = Array.length x in
  let p = if n = 0 then 0 else Array.length x.(0) in
  if n <= p then Error (Printf.sprintf "ols: need n > p (n=%d, p=%d)" n p)
  else _ols_fit ~x ~y ~names ~n ~p

(* ---------------------------------------------------------------- *)
(* Logistic regression (Newton / IRLS)                              *)
(* ---------------------------------------------------------------- *)

let _sigmoid z = 1.0 /. (1.0 +. Float.exp (-.z))
let _ridge = 1e-8
let _max_iter = 50
let _tol = 1e-8
let _weight_floor = 1e-10

(* [x' W x] with W = diag(mu_i (1 - mu_i)) at the current [beta]. *)
let _weighted_gram ~x ~beta ~p =
  let m = Array.make_matrix ~dimx:p ~dimy:p 0.0 in
  Array.iter x ~f:(fun row ->
      let mu = _sigmoid (_dot beta row) in
      let w = Float.max (mu *. (1.0 -. mu)) _weight_floor in
      _add_weighted_outer m ~row ~w ~p);
  m

(* Score vector [x' (y - mu)] at the current [beta]. *)
let _gradient ~x ~y ~beta ~p =
  let grad = Array.create ~len:p 0.0 in
  Array.iteri x ~f:(fun i row ->
      let r = y.(i) -. _sigmoid (_dot beta row) in
      for a = 0 to p - 1 do
        grad.(a) <- grad.(a) +. (row.(a) *. r)
      done);
  grad

(* One IRLS step: returns the updated [beta] and the max coefficient change. *)
let _irls_step ~x ~y ~beta ~p : (float array * float, string) result =
  let xwx = _weighted_gram ~x ~beta ~p in
  for a = 0 to p - 1 do
    xwx.(a).(a) <- xwx.(a).(a) +. _ridge
  done;
  Result.map
    (solve xwx (_gradient ~x ~y ~beta ~p))
    ~f:(fun delta ->
      let next = Array.mapi beta ~f:(fun j v -> v +. delta.(j)) in
      let step =
        Array.fold delta ~init:0.0 ~f:(fun m d -> Float.max m (Float.abs d))
      in
      (next, step))

let rec _fit_logit ~x ~y ~beta ~p ~iter : float array * bool =
  if iter >= _max_iter then (beta, false)
  else
    match _irls_step ~x ~y ~beta ~p with
    | Error _ -> (beta, false)
    | Ok (next, step) ->
        if Float.( < ) step _tol then (next, true)
        else _fit_logit ~x ~y ~beta:next ~p ~iter:(iter + 1)

(* Average ranks (1-based) of [scores], resolving ties by their mean rank. *)
let _average_ranks scores : float array =
  let n = Array.length scores in
  let idx = Array.init n ~f:Fn.id in
  Array.sort idx ~compare:(fun a b -> Float.compare scores.(a) scores.(b));
  let ranks = Array.create ~len:n 0.0 in
  let i = ref 0 in
  while !i < n do
    let j = ref !i in
    while !j + 1 < n && Float.( = ) scores.(idx.(!j + 1)) scores.(idx.(!i)) do
      incr j
    done;
    let avg = (Float.of_int (!i + !j) /. 2.0) +. 1.0 in
    for k = !i to !j do
      ranks.(idx.(k)) <- avg
    done;
    i := !j + 1
  done;
  ranks

(* Rank-based (Mann-Whitney) AUC; [0.5] when a class is absent. *)
let _auc ~scores ~y : float =
  let ranks = _average_ranks scores in
  let n = Array.length y in
  let n_pos = Array.count y ~f:(fun v -> Float.( > ) v 0.5) in
  let n_neg = n - n_pos in
  if n_pos = 0 || n_neg = 0 then 0.5
  else
    let sum_pos =
      Array.foldi y ~init:0.0 ~f:(fun k acc v ->
          if Float.( > ) v 0.5 then acc +. ranks.(k) else acc)
    in
    (sum_pos -. (Float.of_int (n_pos * (n_pos + 1)) /. 2.0))
    /. Float.of_int (n_pos * n_neg)

let _logit_terms ~x ~beta ~names ~p : term list =
  match inverse (_weighted_gram ~x ~beta ~p) with
  | Error _ -> List.mapi names ~f:(fun j name -> _make_term name beta.(j) 0.0)
  | Ok cov ->
      List.mapi names ~f:(fun j name ->
          _make_term name beta.(j) (Float.sqrt (Float.max cov.(j).(j) 0.0)))

let logistic ~x ~y ~names : (logit_result, string) result =
  let n = Array.length x in
  let p = if n = 0 then 0 else Array.length x.(0) in
  if n <= p then Error (Printf.sprintf "logistic: need n > p (n=%d, p=%d)" n p)
  else
    let beta, converged =
      _fit_logit ~x ~y ~beta:(Array.create ~len:p 0.0) ~p ~iter:0
    in
    let scores = Array.map x ~f:(fun row -> _dot beta row) in
    Ok
      {
        terms = _logit_terms ~x ~beta ~names ~p;
        auc = _auc ~scores ~y;
        converged;
        n;
        p;
      }
