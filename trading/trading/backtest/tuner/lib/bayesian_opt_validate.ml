open Core

let bound (k, (lo, hi)) =
  if Float.( > ) lo hi then
    invalid_arg
      (sprintf "Bayesian_opt.create: bound for %s has min > max (%g > %g)" k lo
         hi)

let _length_scales_dim_msg ~got ~expected =
  sprintf
    "Bayesian_opt.create: length_scales dim %d disagrees with bounds dim %d" got
    expected

let _length_scales_dim_check ~expected scales =
  let got = Array.length scales in
  if got <> expected then invalid_arg (_length_scales_dim_msg ~got ~expected)

let _length_scales_entry_check s =
  if Float.( <= ) s 0.0 then
    invalid_arg
      (sprintf "Bayesian_opt.create: length_scales entries must be > 0 (got %g)"
         s)

let length_scales bounds = function
  | None -> ()
  | Some scales ->
      _length_scales_dim_check ~expected:(List.length bounds) scales;
      Array.iter scales ~f:_length_scales_entry_check

let early_stop ~window ~epsilon =
  if window < 1 then
    invalid_arg "Bayesian_opt.create: early_stop_config.window must be >= 1";
  if Float.( < ) epsilon 0.0 then
    invalid_arg "Bayesian_opt.create: early_stop_config.epsilon must be >= 0"

let _early_stop_opt = function
  | None -> ()
  | Some (window, epsilon) -> early_stop ~window ~epsilon

let config ~bounds ~initial_random ~total_budget ~length_scales:ls
    ~early_stop:es =
  if List.is_empty bounds then
    invalid_arg "Bayesian_opt.create: bounds must be non-empty";
  List.iter bounds ~f:bound;
  if initial_random < 0 then
    invalid_arg "Bayesian_opt.create: initial_random must be >= 0";
  if total_budget < 0 then
    invalid_arg "Bayesian_opt.create: total_budget must be >= 0";
  length_scales bounds ls;
  _early_stop_opt es
