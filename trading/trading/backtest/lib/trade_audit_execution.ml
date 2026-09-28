(** Entry-execution-faithfulness types for the trade audit.

    See [trade_audit_execution.mli]; re-exported by [Trade_audit]. *)

open Core

type designed_order_type =
  | Market
  | Stop_limit of { trigger : float; limit : float }
[@@deriving sexp]

type execution_faithfulness = {
  designed_order_type : designed_order_type;
  designed_trigger : float;
  fill_price : float;
  fill_vs_trigger_pct : float;
  fill_within_band : bool;
  faithful : bool;
}
[@@deriving sexp]
