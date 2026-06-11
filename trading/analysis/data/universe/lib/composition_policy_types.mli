(** Types for the explicit, flag-driven universe-composition policy.

    The composition policy ({!Composition_policy}) takes a candidate universe —
    a rank-ordered list of {!candidate}s carrying just enough per-symbol
    metadata for each policy filter — and applies a {!config} of policy flags,
    producing a filtered candidate list plus a per-filter drop {!report} so a
    human can see exactly what each policy removed.

    Design intent (see [dev/plans/universe-composition-policy-2026-06-11.md]):
    the real tradeable US universe is ~3,500-4,500 operating companies; the
    surplus ticker count is dual-class duplicates, illiquid ADRs, REITs (policy
    TBD), and junk (SPAC / warrant / unit / preferred / CEF). The policy makes
    each of those choices explicit and config-driven.

    {1 Default = current behaviour}

    {!default_config} is the no-op: it keeps everything the current
    {!Build_from_individuals} pipeline keeps, so a universe rebuilt through the
    policy with the default config is bit-identical to one built without it.
    Every flag must be flipped explicitly to change a result — the data-layer
    analog of [.claude/rules/experiment-flag-discipline.md]. *)

type candidate = {
  symbol : string;
  asset_type : Eodhd.Asset_type.t;
      (** Instrument classification, used by the ADR-floor and junk-audit
          filters. *)
  sector : string;
      (** GICS sector label. The REIT filter treats [sector = reit_sector_label]
          (see {!config}) as a REIT. *)
  avg_dollar_volume : float;
      (** Average daily dollar volume over the ranking window. Used by the
          ADR-liquidity-floor filter and as the dual-class tie-breaker (keep the
          more liquid class). *)
  rank : int;
      (** 0-based rank within the incoming candidate pool (most liquid = 0).
          Used as the dual-class tie-breaker when [avg_dollar_volume] ties. *)
}
[@@deriving sexp, eq, show]
(** One member of the candidate universe fed to the policy. *)

(** Whether REITs are kept in or excluded from the universe. *)
type reit_policy =
  | Include  (** Keep REITs (current behaviour). *)
  | Exclude  (** Drop every candidate whose sector is [reit_sector_label]. *)
[@@deriving sexp, eq, show]

type config = {
  reit_policy : reit_policy;
      (** Default [Include] — current behaviour keeps REITs. *)
  reit_sector_label : string;
      (** GICS sector string that identifies a REIT. Default ["Real Estate"]. *)
  adr_min_dollar_volume : float option;
      (** Liquidity floor for ADR / GDR candidates. [None] (default) keeps every
          ADR. [Some floor] drops ADR / GDR candidates whose [avg_dollar_volume]
          is strictly below [floor], keeping only the large / liquid ADRs. *)
  exclude_preferred : bool;
      (** When [true], drop [Preferred_stock] candidates (they trade unlike a
          common stock and are poor Weinstein-stage instruments). Default
          [false] — current behaviour keeps preferred shares, since
          {!Eodhd.Asset_type.is_equity_like} admits them. *)
}
[@@deriving sexp, eq, show]
(** Policy flags. {!default_config} sets every field to the current (pre-policy)
    behaviour. *)

val default_config : config
(** The no-op policy: [reit_policy = Include],
    [reit_sector_label = "Real Estate"], [adr_min_dollar_volume = None],
    [exclude_preferred = false]. Running the policy with this config keeps every
    candidate (the dual-class dedup in {!Composition_policy} is the one filter
    that is always active, because holding two classes of one entity is a bug,
    not a policy choice — see that module's docstring). *)

(** Why a candidate was dropped. Each constructor maps to exactly one policy
    filter so the drop report is unambiguous. *)
type drop_reason =
  | Dual_class_duplicate of { kept_symbol : string }
      (** Collapsed into [kept_symbol], the more-liquid class of the same
          economic entity. *)
  | Reit_excluded
  | Adr_below_liquidity_floor of { floor : float; avg_dollar_volume : float }
  | Preferred_excluded
[@@deriving sexp, eq, show]

type drop = { symbol : string; reason : drop_reason }
[@@deriving sexp, eq, show]
(** A single dropped symbol with its reason. *)

type filter_report = {
  filter : string;  (** Stable filter name, e.g. ["dual_class_dedup"]. *)
  dropped : drop list;  (** Symbols this filter removed, in input order. *)
  kept_count : int;  (** Candidates remaining after this filter ran. *)
}
[@@deriving sexp, eq, show]
(** Per-filter audit record. *)

type result = { kept : candidate list; reports : filter_report list }
[@@deriving sexp, eq, show]
(** Output of {!Composition_policy.apply}: the surviving candidates (rank order
    preserved) plus one {!filter_report} per filter, in application order. *)
