(** Anchor-date prefilter for the rename-twin detector. Proposes candidate index
    pairs cheaply so the full overlap criterion only runs on series that sit
    near each other on a shared anchor date. Pure helpers split out of
    {!Twin_detector}; they work on bare date-sorted close arrays and take the
    basis-dependent pieces as functions, so they depend on no config. *)

open Core

val close_on : (Date.t * float) array -> date:Date.t -> float option
(** Adjusted close on [date] via binary search of the date-sorted array. *)

val return_on : (Date.t * float) array -> date:Date.t -> float option
(** Simple daily return on [date] against the leg's own prior bar. [None] when
    [date] is the leg's first bar or the prior close is non-positive. *)

val candidate_pairs :
  min_overlap_days:int ->
  anchor_key:((Date.t * float) array -> date:Date.t -> float option) ->
  close_enough:(float -> float -> bool) ->
  (Date.t * float) array array ->
  (int * int) list
(** Deduplicated candidate index pairs [(i, j)], [i < j]. Anchors are every
    [min_overlap_days/2]-th distinct date; at each anchor the series with a
    defined [anchor_key] are sorted by key and split into maximal runs whose
    consecutive keys satisfy [close_enough]; every pair within a run is a
    candidate. *)
