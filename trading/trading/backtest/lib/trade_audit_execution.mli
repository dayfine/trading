(** Entry-execution-faithfulness types for the trade audit.

    Split out of [Trade_audit] purely to keep that file under the file-length
    limit; [Trade_audit] [include]s this module, so callers keep using
    [Trade_audit.designed_order_type] / [Trade_audit.execution_faithfulness].
    The constructor- and field-level documentation lives on
    {!Trade_audit.execution_faithfulness} — the public contract — and is not
    repeated here. *)

(** The order the strategy designed for the entry. *)
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
(** Per-entry execution-quality record; see
    {!Trade_audit.execution_faithfulness}. *)
