(** Configuration for the after-tax performance lens.

    Every rate, threshold and toggle lives here and is sexp-serialisable — no
    tax parameter is hardcoded in the model (per [experiment-flag-discipline]
    R2: all rates/toggles routed through config). *)

(** Taxation basis.

    - [Mtm_flat]: mark-to-market — every year's full (realized + unrealized)
      equity change is taxed at [flat_rate]. A naive upper-bound comparator.
    - [Realized_st_lt]: realization basis — only closed trades are taxed, in
      their exit year, split into short-term ([days_held < lt_days], [st_rate])
      and long-term ([days_held >= lt_days], [lt_rate]) buckets. *)
type mode = Mtm_flat | Realized_st_lt [@@deriving sexp, equal]

type t = {
  mode : mode;
  flat_rate : float;  (** MTM flat rate; ignored under [Realized_st_lt] *)
  st_rate : float;  (** short-term rate (e.g. 0.35) *)
  lt_rate : float;  (** long-term rate (e.g. 0.238 = 20% LTCG + 3.8% NIIT) *)
  lt_days : int;  (** holding days for LT treatment (e.g. 365) *)
  carryforward : bool;
      (** when [true], net losses are disallowed in-year and carried forward to
          offset future gains (ST gains first). When [false], losses are simply
          ignored (gains taxed gross, no offset). *)
  top_winners : int;  (** how many top winners in the days-to-LT diagnostic *)
}
[@@deriving sexp, equal]

val default : t
(** [realized_st_lt (st 0.35) (lt 0.238) (lt_days 365)] with carryforward on —
    the Phase-1 reference model. *)

val load_exn : string -> t
(** Load a [t] from a sexp file. *)

val effective_rates : t -> float * float
(** [(st_rate, lt_rate)] the model should apply given [mode]. Under [Mtm_flat]
    both are [flat_rate] (LT bucket is always empty in that mode). *)
