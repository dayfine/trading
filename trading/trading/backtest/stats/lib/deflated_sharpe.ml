open Core

let euler_mascheroni = 0.5772156649

(* Population central moments of [xs]: mean and the k-th standardised moment.
   Divisor is [n] (population), matching the Bailey/Lopez de Prado convention
   for the skew/kurtosis adjustment terms. *)
let _standardised_moment xs ~order =
  let n = List.length xs in
  if n < 2 then
    invalid_arg
      (Printf.sprintf "Deflated_sharpe: need at least 2 observations, got %d" n);
  let nf = Float.of_int n in
  let mean = List.sum (module Float) xs ~f:Fn.id /. nf in
  let variance =
    List.sum (module Float) xs ~f:(fun x -> (x -. mean) ** 2.0) /. nf
  in
  if Float.(variance <= 0.0) then
    invalid_arg "Deflated_sharpe: zero variance, higher moment undefined";
  let stdev = Float.sqrt variance in
  List.sum (module Float) xs ~f:(fun x -> ((x -. mean) /. stdev) ** order) /. nf

let skewness xs = _standardised_moment xs ~order:3.0
let kurtosis xs = _standardised_moment xs ~order:4.0

let psr ~observed_sharpe ~benchmark_sharpe ~n_obs ~skewness ~kurtosis =
  if n_obs < 2 then
    invalid_arg
      (Printf.sprintf "Deflated_sharpe.psr: n_obs must be >= 2, got %d" n_obs);
  let sr = observed_sharpe in
  let variance_term =
    1.0 -. (skewness *. sr) +. ((kurtosis -. 1.0) /. 4.0 *. sr *. sr)
  in
  if Float.(variance_term <= 0.0) then
    invalid_arg
      (Printf.sprintf
         "Deflated_sharpe.psr: non-positive variance term %.17g (degenerate \
          higher moments)"
         variance_term);
  let z =
    (sr -. benchmark_sharpe)
    *. Float.sqrt (Float.of_int n_obs -. 1.0)
    /. Float.sqrt variance_term
  in
  Normal_dist.cdf z

let expected_max_sharpe ~n_trials ~sharpe_variance =
  if n_trials < 2 then
    invalid_arg
      (Printf.sprintf
         "Deflated_sharpe.expected_max_sharpe: n_trials must be >= 2, got %d"
         n_trials);
  if Float.(sharpe_variance < 0.0) then
    invalid_arg
      (Printf.sprintf
         "Deflated_sharpe.expected_max_sharpe: sharpe_variance must be >= 0, \
          got %.17g"
         sharpe_variance);
  let nf = Float.of_int n_trials in
  let g = euler_mascheroni in
  let term1 = (1.0 -. g) *. Normal_dist.inv_cdf (1.0 -. (1.0 /. nf)) in
  let term2 =
    g *. Normal_dist.inv_cdf (1.0 -. (1.0 /. (nf *. Float.exp 1.0)))
  in
  Float.sqrt sharpe_variance *. (term1 +. term2)

let deflated_sharpe ~observed_sharpe ~fold_returns ~n_trials
    ~sharpe_variance_across_trials =
  let benchmark_sharpe =
    expected_max_sharpe ~n_trials ~sharpe_variance:sharpe_variance_across_trials
  in
  psr ~observed_sharpe ~benchmark_sharpe ~n_obs:(List.length fold_returns)
    ~skewness:(skewness fold_returns) ~kurtosis:(kurtosis fold_returns)
