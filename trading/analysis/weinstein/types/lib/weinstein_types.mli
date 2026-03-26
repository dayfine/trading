(** Shared domain types for the Weinstein analysis pipeline.

    Used across the stage classifier, stop state machine, and screener.
    Centralised here to avoid circular dependencies. *)

(** Weinstein stage — the four-stage price cycle model. *)
type stage =
  | Stage1 of { weeks_in_base : int }
      (** Basing / accumulation: MA flattening after decline, price oscillating
          around MA. *)
  | Stage2 of {
      weeks_advancing : int;
      late : bool;
          (** MA deceleration detected — still hold, but no longer a new buy. *)
    }  (** Advancing / markup: MA rising, price consistently above MA. *)
  | Stage3 of { weeks_topping : int }
      (** Top / distribution: MA flattening after advance, price oscillating
          around MA. Exit with profits. *)
  | Stage4 of { weeks_declining : int }
      (** Declining / markdown: MA falling, price consistently below MA. Never
          buy or hold in Stage 4. *)
[@@deriving show, eq]

(** Direction of the 30-week moving average.

    Derived from the MA slope value; [Flat] means within the configured
    threshold. A [Rising] MA with price above is Stage 2 territory; [Declining]
    with price below is Stage 4. *)
type ma_direction = Rising | Flat | Declining [@@deriving show, eq]
