(** Window-based early-stopping helper for the Bayesian optimisation loop.

    [should_stop ~window ~epsilon ~initial_random ~running_best] returns [true]
    iff the [running_best] series has gained less than [epsilon] over the last
    [window] iterations beyond the initial random-sampling phase. *)
val should_stop :
  window:int ->
  epsilon:float ->
  initial_random:int ->
  running_best:float list ->
  bool
