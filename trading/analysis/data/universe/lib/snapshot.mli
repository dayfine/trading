(** Custom universe snapshot — output of either bottom-up composition (real
    per-stock, 1998-2026) or top-down decomposition (synthetic per-stock,
    1926-1997). Backtests consume both interchangeably via the [method_] tag.

    The bidirectional design lives in
    [dev/plans/custom-universe-bidirectional-2026-05-17.md]. Q2-A (composition)
    is parked on EODHD Fundamentals 403; Q2-B (decomposition) lands the type
    here first because both paths converge on the same on-disk shape and the
    decomposition flow has no vendor-tier blocker.

    Reading the [entries] is canonical for downstream consumers: each entry's
    [weight] is the symbol's cap weight inside the snapshot, [symbol] is a real
    ticker (composition) or [SYNTH_<industry>_<rank>] (decomposition), [sector]
    is the real GICS sector or the French bucket name, and [synthetic] is the
    unambiguous discriminator. *)

open Core

type anchor = [ `Shiller_sp_composite ] [@@deriving sexp, show, eq]
(** Anchor source for the decomposition's aggregate-return constraint. Only
    Shiller's monthly S&P composite is supported in v1. *)

type factor_skeleton = [ `French_5_industry | `French_49_industry ]
[@@deriving sexp, show, eq]
(** Kenneth French daily-portfolio skeleton used to provide the per-industry
    factor returns. v1 implements [`French_5_industry] only;
    [`French_49_industry] is reserved for the phase-2 upgrade. *)

(** How the snapshot was produced. *)
type method_ =
  | Composition_from_individuals
      (** Real symbols ranked by current_shares × historical_price (Q2-A,
          parked). *)
  | Decomposition_from_index of {
      anchor : anchor;
      factor_skeleton : factor_skeleton;
    }  (** Synthetic symbols from Shiller + French (Q2-B). *)
[@@deriving sexp, show, eq]

type entry = {
  symbol : string;
      (** Real ticker (composition) or [SYNTH_<industry>_<rank>]
          (decomposition). Decomposition pads [rank] to 4 digits. *)
  weight : float;
      (** Cap weight inside the snapshot, in [[0.0, 1.0]]. The decomposition
          path emits uniform weights [1.0 /. List.length entries]. *)
  sector : string;
      (** Real GICS sector (composition) or French-bucket name [Cnsmr], [Manuf],
          [HiTec], [Hlth], [Other] (decomposition). *)
  synthetic : bool;
      (** [true] for decomposition entries; [false] for composition. The
          [method_] tag carries the same information at the snapshot level but
          the per-entry flag is convenient when downstream filters need to drop
          synthetic names. *)
}
[@@deriving sexp, show, eq]
(** One member of the snapshot. *)

type t = {
  date : Date.t;
      (** Reconstitution anchor date — typically YYYY-05-31 to align with the
          Russell annual reconstitution cadence. *)
  method_ : method_;
  size : int;
      (** Top-N cutoff (e.g. 500 / 1000 / 3000). The decomposition path enforces
          [List.length entries = size]. *)
  entries : entry list;
  aggregate_period_return : float;
      (** Cap-weighted aggregate return for the year following [date]. For
          decomposition this is the post-rescale value anchored to Shiller; for
          composition it would be the realized cap-weighted return. *)
}
[@@deriving sexp, show, eq]
(** A fully-materialized universe snapshot. *)

val save : t -> path:string -> unit Status.status_or
(** [save t ~path] writes the s-expression form of [t] to [path] using an atomic
    temp-file + rename. Returns [Error Status.Internal] on any filesystem
    failure. The on-disk form is [Sexp.to_string_hum] for diff-friendliness. *)

val load : path:string -> t Status.status_or
(** [load ~path] reads and parses a snapshot written by [save]. Returns
    [Error Status.Internal] on read failure, [Error Status.Failed_precondition]
    on sexp decode failure. *)

val total_weight : t -> float
(** [total_weight t] returns [List.sum (List.map entries ~f:weight)]. Should be
    ≈ 1.0 for any well-formed cap-weighted snapshot. Exposed for well-formedness
    checks in tests + downstream validation. *)
