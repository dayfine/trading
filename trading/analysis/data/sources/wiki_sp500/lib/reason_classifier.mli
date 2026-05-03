(** Coarse-bucket classifier for the Wikipedia "Reason" free-text column.

    Companion plan: [dev/plans/wiki-eodhd-historical-universe-2026-05-03.md]
    §PR-A. The classifier groups free-text reasons (e.g.
    ["Market capitalization change."],
    ["Lehman Brothers filed for bankruptcy."],
    ["Blackstone Inc. and TPG Inc. acquired Hologic."]) into a small number of
    categories suitable for downstream auditing and price-fetch policy
    decisions.

    The classifier is intentionally simple — case-insensitive substring match
    over a fixed keyword list. The full reason text is preserved by the upstream
    [Changes_parser]; this module only assigns a category. *)

type reason_category =
  | M_and_A
      (** Acquisition or merger. Triggered by ["acquired"], ["purchased"],
          ["merged with"], or ["acquisition"]. *)
  | Bankruptcy
      (** Bankruptcy or formal default. Triggered by ["bankruptcy"] or
          ["filed for"]. *)
  | Mcap_change
      (** Market-cap-driven index rebalance. Triggered by
          ["market capitalization"] or ["market cap"]. *)
  | Spinoff
      (** Spin-off / split-off. Triggered by ["spinoff"], ["spun off"], or
          ["split off"]. *)
  | Other  (** Anything that does not match the above. *)
[@@deriving show, eq]

val classify : string -> reason_category
(** [classify reason_text] returns the category for [reason_text]. Matching is
    case-insensitive substring. When multiple keywords match, the precedence
    order (highest first) is:

    + [M_and_A]
    + [Bankruptcy]
    + [Mcap_change]
    + [Spinoff]
    + [Other]

    Rationale: M&A language often co-occurs with mcap or spinoff phrasing (e.g.
    ["…acquired due to market capitalization change…"] — the M&A action is the
    dominant fact). Bankruptcy beats Mcap when both appear because the business
    event is more specific than the rebalance trigger. *)
