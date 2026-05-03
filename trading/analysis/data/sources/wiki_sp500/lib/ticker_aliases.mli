(** Curated map of ticker renames + dual-class quirks the Wikipedia changes
    table tracks loosely.

    Companion plan: [dev/plans/wiki-eodhd-historical-universe-2026-05-03.md]
    §PR-B Open question 3. The Wikipedia changes table sometimes records
    corporate renames as ticker swaps (e.g. ["FB" removed, "META" added]) and
    sometimes only on the company's own page. This module is the manual curation
    point: a small list of well-attested renames that [Membership_replay] can
    consult to keep historical universes consistent.

    Conservative-by-default: [canonicalize] returns its input unchanged unless a
    curated alias matches. Adding a new alias is a one-line change in
    [ticker_aliases.ml] with a citation in the rationale field; no architectural
    change. *)

type alias = {
  current_symbol : string;
      (** EODHD-style ticker after the rename. E.g. ["META"]. *)
  historical_symbol : string;
      (** EODHD-style ticker before the rename. E.g. ["FB"]. *)
  effective_date : Core.Date.t;
      (** Date the rename took effect. [canonicalize ~as_of:d] returns the
          [historical_symbol] for any [d] strictly before [effective_date]. *)
  rationale : string;
      (** Short human-readable note + source. E.g.
          ["Renamed FB → META 2022-06-09 (Meta Platforms rebrand)"]. *)
}
[@@deriving show, eq]

val all : alias list
(** All curated aliases. Ordered by [effective_date] descending (newest first)
    for documentation purposes; [canonicalize] does not depend on the order.

    Each entry has a citation in its [rationale] field. The list is
    intentionally short — only well-attested renames where the historical ticker
    is observable in the EODHD price data should appear here. New entries should
    cite a press release or SEC filing. *)

val canonicalize : symbol:string -> as_of:Core.Date.t -> string
(** [canonicalize ~symbol ~as_of] resolves [symbol] to its name as of [as_of].

    Resolution rules:
    - If [symbol] matches an alias's [current_symbol] AND [as_of] is strictly
      before that alias's [effective_date], return the [historical_symbol].
    - Otherwise return [symbol] unchanged.

    Example: with [d_2020 = Date.create_exn ~y:2020 ~m:Jan ~d:1] and
    [d_2023 = Date.create_exn ~y:2023 ~m:Jan ~d:1]:
    - [canonicalize ~symbol:"META" ~as_of:d_2020] returns ["FB"];
    - [canonicalize ~symbol:"META" ~as_of:d_2023] returns ["META"]
      (post-rename);
    - [canonicalize ~symbol:"AAPL" ~as_of:d_2020] returns ["AAPL"] (no alias).

    [canonicalize] is idempotent: calling it twice on the same input gives the
    same result. *)
