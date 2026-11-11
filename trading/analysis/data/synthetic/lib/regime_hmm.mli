(** Three-regime hidden Markov model — Bull / Bear / Crisis.

    Synth-v2's regime layer. The HMM models market regime persistence — the
    statistical property that block bootstrap (Synth-v1) demonstrably misses
    because block boundaries break regime continuity. Here, regime evolution is
    driven by an explicit Markov chain over [Bull], [Bear], [Crisis]; the
    per-step output (volatility, drift) lives in sibling modules ([Garch],
    [Synth_v2]).

    A regime path is sampled by repeatedly drawing the next regime from the
    current regime's row of the transition matrix. Determinism: same
    [initial_regime] + same transition matrix + same seed produces an identical
    path.

    Calibration TODO: the hand-set defaults below were chosen so that mean
    durations roughly match historical SPY bull/bear/crisis cycles (~33 / 15 / 3
    months respectively). A follow-up PR will fit the matrix from real history
    (Baum-Welch / EM). *)

type regime = Bull | Bear | Crisis [@@deriving sexp, eq, show]

type transition_matrix = (regime * (regime * float) list) list
(** Row-stochastic 3x3 matrix expressed as an association list.
    [List.assoc r matrix] yields [(r', p)] pairs; the inner list's [p] values
    must sum to 1.0 (within [_prob_epsilon]) and be non-negative. *)

type t = {
  initial_regime : regime;
      (** Starting regime for sampled paths; treated as the regime at step 0. *)
  transitions : transition_matrix;
      (** Row-stochastic matrix governing per-step regime transitions. *)
}

val default_transitions : transition_matrix
(** Hand-set defaults documented in the module-level comment. Chosen so:
    - Mean Bull duration ≈ 1 / (1 - 0.97) ≈ 33 steps (interpreted as months when
      paired with monthly drivers; the HMM itself is unitless).
    - Mean Bear duration ≈ 1 / (1 - 0.93) ≈ 15 steps.
    - Mean Crisis duration ≈ 1 / (1 - 0.65) ≈ ~3 steps; Crisis is rarely entered
      (Bull→Crisis 0.005, Bear→Crisis 0.02).

    Calibration TODO: re-derive from a Baum-Welch fit on 30y SPY history. *)

val default : t
(** Bull initial regime + [default_transitions]. Convenience constructor for
    callers that want the canonical hand-set HMM. *)

val validate : t -> (unit, Status.t) Result.t
(** Returns [Error Status.Invalid_argument] if any of:
    - a transition row is missing (must have entries for all three regimes);
    - a probability is negative or > 1.0;
    - a row's probabilities don't sum to 1.0 (within numerical tolerance). *)

val sample_path : t -> n_steps:int -> seed:int -> regime list
(** [sample_path t ~n_steps ~seed] returns a regime sequence of length
    [n_steps]. The first element is [t.initial_regime]; element [k+1] is drawn
    from the row of [t.transitions] keyed by element [k].

    Returns the empty list when [n_steps <= 0]. Raises [Invalid_argument] if [t]
    fails [validate]; callers should validate up front. *)
