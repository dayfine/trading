(** Skinny per-step portfolio projection.

    A [step_result] used to carry a full {!Trading_portfolio.Portfolio.t}, which
    in turn carries [trade_history] (grows monotonically with the run) and
    [positions] with full [lots]. Retaining this on every step balloons live
    memory at long windows: at 15y / 4350 steps / ~5 open positions / cumulative
    trade_history per step, retained `step_history × full Portfolio.t` exceeds
    several GB and OOMs the 8 GB GHA runner.

    [t] is the projection metric computers and writers actually consume:
    [current_cash], a small per-position summary (symbol / signed quantity /
    cost basis), and the mark-to-market [position_value_total]. The full
    [Portfolio.t] is kept in [run_result.final_portfolio] for the reconciler
    writers that need it. See [dev/notes/15y-memory-cliff-2026-05-08.md] §"Fix
    B". *)

type position_summary = {
  symbol : string;
  quantity : float;
      (** Signed share count: positive for long, negative for short. *)
  cost_basis : float;
      (** Total cost basis (signed quantity × average per-share cost). For longs
          this is positive, for shorts negative. Mirrors
          [Trading_portfolio.Calculations.position_cost_basis]. *)
}
[@@deriving show, eq, sexp]
(** Per-position summary, projected from
    [Trading_portfolio.Types.portfolio_position]. Drops [lots] /
    [accounting_method]; retains the two scalars metric computers and per-step
    audits actually read. *)

type t = {
  current_cash : float;  (** Mirrors [Portfolio.t.current_cash]. *)
  positions : position_summary list;
      (** One entry per open position. Order matches the source portfolio's
          [positions] list (insertion-ordered). *)
  position_value_total : float;
      (** Sum of position market values at this step's mark-to-market prices,
          forward-filled per [Simulator._compute_portfolio_value]. Equals
          [step_result.portfolio_value -. current_cash] on bar-bearing days
          {b for a cash account}; under a long-margin debit (margin M1b-2)
          [portfolio_value] reads
          [equity_cash = current_cash -. long_margin_debit], so the identity
          becomes [portfolio_value -. current_cash +. long_margin_debit]. May be
          0 on weekends/holidays when the simulator falls back to cash-only
          valuation. Carried explicitly here to avoid re-deriving it downstream.
      *)
}
[@@deriving show, eq, sexp]
(** Per-step portfolio projection. Independent of any [Portfolio.t] reference;
    safe to retain for the entire simulation. *)

val of_portfolio :
  Trading_portfolio.Portfolio.t -> position_value_total:float -> t
(** Project a full [Portfolio.t] to the skinny summary at step time.
    [position_value_total] is the simulator's already-computed mark-to-market
    sum of position values (cash-fallback applied). *)

val empty : t
(** An empty summary with no positions and zero cash. Useful as a test
    placeholder when the consumer under test ignores [step_result.portfolio]
    (e.g. metric computers that read only [portfolio_value] / [trades] /
    [date]). Production code paths should use [of_portfolio]. *)

val with_cash : float -> t
(** A summary with the given [current_cash], no positions, and zero
    [position_value_total]. Test placeholder for fixtures that need a specific
    cash value but no open positions. *)

val positions_count : t -> int
(** Number of open positions in the summary. *)

val find_position : t -> symbol:string -> position_summary option
(** Lookup an open position by symbol. Returns [None] when the symbol is not
    held. Linear scan; positions list is small in practice. *)

val position_cost_basis_total : t -> float
(** Sum of [cost_basis] across all open positions in the summary. Used by
    [Portfolio_state_computer] to derive unrealized P&L without needing the full
    [Portfolio.t]. *)
