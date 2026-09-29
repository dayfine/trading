(** Which macro condition suspends resting long entry tickets (#2976). The
    config-facing half of {!Entry_ticket_suspend}, kept in its own module so
    {!Weinstein_strategy_config} can name the type without depending on the
    runner (which itself reads the config).

    {b Book authority.} Ch. 8 ("Stage Analysis for the Market Averages"): when
    the market average breaks down into Stage 4, "Suspend buying even if you see
    a few stocks breaking out on their charts" —
    [docs/design/weinstein-book-reference.md] §2.1, block "Resolved 2026-09-16".
    The book's word is {e suspend}, not cancel; it is silent on the mechanics of
    a standing buy-stop written before the tape turned (Ch. 3's only cancel rule
    is "if the pattern changes"). *)

type t =
  | Off
      (** Today's behaviour and the no-op default: a resting ticket stays live
          whatever the tape and fills whenever price reaches its trigger. *)
  | On_bearish_macro
      (** Suspend whenever the strategy's whole long-entry macro gate
          ({!Long_entry_macro_gate.admits}) would reject a {e fresh} long this
          week — the predicate the cascade applies to new candidates, so a
          resting ticket can no longer fill into a tape that admits nothing
          else. *)
  | On_index_stage4
      (** Suspend only while the primary index itself is classified Stage 4 —
          the book-literal condition. A [Bearish] weight-of-evidence composite
          with the index outside Stage 4 does {e not} suspend. *)
[@@deriving show, eq, sexp]
