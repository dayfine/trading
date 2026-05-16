(** Pure-precondition validators for [Bayesian_opt] config fields. Each function
    raises [Invalid_argument] with a [Bayesian_opt.create:] prefix when the
    precondition fails; returns [()] otherwise. *)

val bound : string * (float * float) -> unit
(** Bound for parameter [k] must satisfy [lo <= hi]. *)

val length_scales :
  (string * (float * float)) list -> float array option -> unit
(** When [scales] is [Some], its length must equal [List.length bounds] and
    every entry must be strictly positive. *)

val early_stop : window:int -> epsilon:float -> unit
(** Component-wise check: [window >= 1] and [epsilon >= 0]. *)

val config :
  bounds:(string * (float * float)) list ->
  initial_random:int ->
  total_budget:int ->
  length_scales:float array option ->
  early_stop:(int * float) option ->
  unit
(** Composite check: non-empty bounds, all bounds valid, non-negative
    [initial_random] and [total_budget], length-scales valid, early-stop valid.
*)
