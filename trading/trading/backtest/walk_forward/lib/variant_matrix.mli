(** Variant-matrix generator for walk-forward CV.

    Declares experiment *axes* in a spec and expands them into the
    {!Walk_forward_runner.variant} list the runner already consumes. An axis is
    a config key-path (or a single-component flag) paired with a list of values;
    the matrix expands either as the full cartesian product of axis values
    ([Cartesian]) or as a deterministic seeded subset ([Sampled]).

    Motivation (plan Gap A, 2026-05-29): every variant used to be hand-written
    in the spec sexp, so a combination experiment
    (["enable_X" in on/off cross "knob" in 0, 0.02, 0.05]) needed 6+
    hand-written cells. This lets the spec declare the axes and have them
    expand. The 2026-05-29 hysteresis rejection exposed the deeper problem: we
    tested one *point*, never a *surface*.

    Hardening (plan Gap B): every generated override is validated against the
    canonical default {!Weinstein_strategy.config} via
    [Overlay_validator.apply_overrides] *at expansion time*, so a typo'd axis
    key raises [Failure] loudly rather than silently producing a no-op cell that
    yields bit-identical metrics (the 2026-05-12 81-cell bug class). *)

open Core

(** On-disk an axis is a record (not a variant tag), with exactly one of [key] /
    [flag] alongside [values]:
    {[
    ((key (stage3_force_exit_config hysteresis_weeks)) (values (1 2 3)))
      ((flag enable_laggard_rotation) (values (true false)))
    ]}
    [key]'s value is the dotted key-path as a flat sexp list; [flag]'s value is
    a single atom. *)
type axis =
  | Key of { path : string list; values : Sexp.t list }
      (** A config key-path axis. [path = [a; b]] with value [v] generates the
          partial-config override sexp [((a ((b v))))]; a single-component path
          [[a]] generates [((a v))]. [values] are arbitrary sexp atoms
          (int/float/bool/string). *)
  | Flag of { name : string; values : Sexp.t list }
      (** Sugar for a single-component {!Key} axis: [Flag { name; values }] is
          exactly [Key { path = [ name ]; values }]. Reads naturally for the
          [enable_*] boolean toggles. *)
[@@deriving sexp]

type expansion =
  | Cartesian  (** Full cartesian product of all axis values. *)
  | Sampled of { n : int; seed : int }
      (** Deterministic seeded subset of [n] cells drawn (without replacement)
          from the full cartesian product, using a {!Core.Random.State.t} seeded
          by [seed] — no global [Random] state is touched. If
          [n >= product_size], falls back to the full cartesian product. *)
[@@deriving sexp]

type t = { axes : axis list; expansion : expansion } [@@deriving sexp]
(** An axis declaration block. [axes] are expanded according to [expansion]. *)

val expand : t -> Walk_forward_runner.variant list
(** [expand t] = the generated variant list.

    - [Cartesian]: one variant per cell of the full cartesian product, in
      lexicographic axis order (first axis varies slowest).
    - [Sampled { n; seed }]: a deterministic subset of [n] distinct cells; same
      [seed] gives the same cells and the same labels. Falls back to the full
      cartesian product when [n] is at least the product size.

    Each generated variant:
    - [label] = a deterministic compact join of [key=value] pairs joined by
      ["__"], e.g. ["hysteresis_weeks=2__enable_laggard_rotation=false"]. The
      key segment is the last component of the axis key-path (the flag/leaf
      name).
    - [overrides] = one partial-config sexp per axis (see {!axis}).

    Raises [Failure] if any generated override fails
    [Overlay_validator.apply_overrides] against the canonical default config —
    i.e. an axis key-path that does not resolve to a real config field.
    Validation happens once per (axis, value) pair (cheaper than per full cell,
    same guarantee). Also raises [Failure] if [axes] is empty. *)
