(** Why the stop state machine moved a position into its [Tightened] state.

    One constructor per branch of {!Weinstein_stops}' tightening test, and no
    more: the machine does not tell Stage 3 from Stage 4 for a long (nor Stage 1
    from Stage 2 for a short), so neither does this type. Each trigger maps to
    the exact reason string the machine has always written into
    [Stop_types.Entered_tightening] and [Stop_types.Tightened], so typing the
    trigger changes no state, event or serialized stop. *)

type t =
  | Stage3_or_4
      (** Long: the stock is in Stage 3 or Stage 4 (book §5.2, tighten as the
          top forms). *)
  | Ma_flat_in_stage2
      (** Long, Stage 2, [tighten_on_flat_ma]: the 30-week MA has gone flat. *)
  | Ma_falling_in_stage2
      (** Long, Stage 2, [tighten_on_flat_ma]: the 30-week MA is falling. *)
  | Stage1_or_2
      (** Short: the stock is in Stage 1 or Stage 2 (a bullish recovery). *)
  | Ma_rising_in_stage4
      (** Short, Stage 4, [tighten_on_flat_ma]: the 30-week MA is rising. *)
  | Ma_flat_in_stage4
      (** Short, Stage 4, [tighten_on_flat_ma]: the 30-week MA has gone flat. *)
[@@deriving show, eq, sexp]

val all : t list
(** Every trigger, in declaration order. *)

val to_reason : t -> string
(** The reason string the state machine records for this trigger (e.g.
    ["Stage 3/4 detected"]). Distinct for every trigger. *)

val of_reason : string -> t option
(** Inverse of {!to_reason}. [None] for a string {!to_reason} never produces — a
    [Tightened] state built by hand (tests, an old checkpoint) rather than by
    the state machine. *)
