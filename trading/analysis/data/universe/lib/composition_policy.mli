(** Apply the explicit universe-composition policy to a candidate universe.

    Takes a rank-ordered list of {!Composition_policy_types.candidate}s and a
    {!Composition_policy_types.config}, runs the policy filters in a fixed
    order, and returns the surviving candidates plus a per-filter drop
    {!Composition_policy_types.filter_report}. See the plan at
    [dev/plans/universe-composition-policy-2026-06-11.md].

    {1 Filter order}

    Filters run in this order, each consuming the previous filter's survivors:

    1. {b Dual-class dedup} — collapse share classes of one economic entity (per
    {!Dual_class.entity_key}) to a single member, keeping the higher-ranked
    (more-liquid) class. {b Always active}: holding two classes of one company
    is a correctness bug, not a policy choice, so this filter is not gated by
    any flag. 2. {b REIT policy} — when [config.reit_policy = Exclude], drop
    every candidate whose [sector = config.reit_sector_label]. 3.
    {b ADR liquidity floor} — when [config.adr_min_dollar_volume = Some floor],
    drop [ADR] / [GDR] candidates whose [avg_dollar_volume < floor]. 4.
    {b Preferred exclusion} — when [config.exclude_preferred = true], drop
    [Preferred_stock] candidates.

    {1 Default = current behaviour}

    With {!Composition_policy_types.default_config}, filters 2-4 are no-ops, so
    the only candidates removed are genuine dual-class duplicates. A candidate
    pool with no dual-class pairs passes through unchanged — see {!apply}'s pin
    in the test suite. *)

open Composition_policy_types

val apply : config:config -> candidate list -> result
(** [apply ~config candidates] runs the policy filters described above over
    [candidates] (assumed in rank order, most-liquid first) and returns the
    {!result}: the surviving candidates in their original relative order, plus
    one {!filter_report} per filter (always all four, even when a filter dropped
    nothing) in application order.

    Pure: same inputs -> same output. Each dropped candidate appears in exactly
    one report, attributed to the first filter that removed it. *)
