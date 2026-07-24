(** Per-trade "days-to-LT at exit" diagnostic for a run's top winners.

    Measures how far each big winner exited from the long-term-holding boundary
    ([lt_days]). Pure measurement only — this exposes the ST/LT boundary tax
    cost on monster winners (e.g. a winner exiting at 336d pays the ST rate,
    missing LT by 29 days); it does NOT propose or model any tax-aware exit
    mechanic, which would touch the exit spine (out of scope, per
    no-reversal-timing / winner-touching discipline). *)

type winner_row = {
  symbol : string;
  exit_year : int;
  days_held : int;
  days_to_lt : int;
      (** [max 0 (lt_days - days_held)] — days short of LT; [0] if already LT *)
  pnl : float;
  is_long_term : bool;
  st_tax : float;  (** raw tax if this gain were taxed short-term *)
  lt_tax : float;  (** raw tax if this gain were taxed long-term *)
  boundary_tax_delta : float;
      (** extra raw tax paid because it exited short-term rather than long-term
          ([pnl * (st_rate - lt_rate)]); [0.] when already LT or a loss. These
          are pre-path-scaling raw dollars. *)
}
[@@deriving sexp, equal]

val top_winners :
  Tax_config.t -> Tax_types.realized_trade list -> winner_row list
(** Top [config.top_winners] closed trades by realized P&L (winners only),
    descending, with their days-to-LT boundary measurement. *)
