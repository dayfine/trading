(** Pairwise match statistics for the rename-twin detector: how closely two
    date-sorted close series agree, on levels or on daily returns. Pure helpers
    split out of {!Twin_detector}; they take explicit tolerances rather than a
    config so they carry no dependency on it. *)

open Core

val relative_diff : float -> float -> float
(** Relative distance between two closes, [|a - b| / max |a| |b|], guarded
    against a zero magnitude (returns [0.0]). *)

val shared_closes :
  (Date.t * float) array -> (Date.t * float) array -> (float * float) array
(** [shared_closes a b] merges two date-sorted close arrays into the
    [(close_a, close_b)] pairs on the dates both have, in ascending date order.
*)

val levels_match_stats : (float * float) array -> epsilon:float -> float * int
(** [Levels] stats over shared closes: the fraction of shared dates whose closes
    match within [epsilon], and the longest run of consecutive matching dates.
*)

val returns_match_stats : (float * float) array -> epsilon:float -> float * int
(** [Returns] stats over consecutive-shared-date return pairs: the fraction
    whose simple daily returns differ by at most [epsilon] (absolute), and the
    longest run of consecutive matching pairs. A pair with a non-positive prior
    close on either leg is skipped: left out of the fraction and breaks the run.
    Fraction [0.0] when no valid pair exists. *)
