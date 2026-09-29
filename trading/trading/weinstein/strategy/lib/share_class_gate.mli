(** #3015 — the one-share-class-per-issuer long entry rule
    ({!Weinstein_strategy_config.config.max_one_share_class_per_issuer}).

    GOOG / GOOGL, BRK-A / BRK-B, ... are live share classes of one issuer:
    holding two at once is a doubled position in one business (the post-run
    validator's V6 twin-position invariant). With the flag on, the entry walk
    skips a long candidate whose issuer group ({!Share_class_map}) already has
    an {b open or pending} long, recording [Audit_recorder.Share_class_held].

    {b Open or pending} (the group's "occupied" state, seeded once per walk):
    - a portfolio position on the [Long] side that is not [Closed] — [Entering]
      (a resting or partly-filled entry ticket), [Holding], or [Exiting] (an
      exit in flight has not yet released the exposure);
    - a symbol in the entry-ticket suspension set ({!Entry_ticket_suspend.run}'s
      [suspended_held]): a ticket withdrawn while the macro gate is closed is
      re-issued unchanged when it reopens, so it is still a claim on its group;
      the re-issue tick is covered too, because the re-issued [CreateEntering]
      is not yet in the portfolio;
    - a candidate this same walk has already {b entered} ([Kept]). Candidates
      are walked in the screener's ranking order, so when two classes of one
      issuer qualify in the same week the higher-ranked one wins. A
      higher-ranked class that is itself skipped (cash, stop width, ...) does
      not occupy the group — its sibling may still be entered.

    Scope: long candidates only (the rule is about the long book; shorts pass
    through untouched). Unmapped symbols are never affected. A candidate whose
    own symbol is already held is left to the walk's existing [Already_held]
    check, so that reason keeps precedence.

    {b Default off.} With the flag [false], {!create} returns [None] and
    {!classify} [None] is exactly [decide ()] — the entry walk is bit-identical
    to the pre-#3015 path and neither the map nor its file is ever read (R1). *)

val resolve_config :
  data_dir:string ->
  Weinstein_strategy_config.config ->
  Weinstein_strategy_config.config
(** Fill [config.share_class_groups] from the committed map for a run. When the
    flag is on and the field is empty, loads
    [data_dir / Share_class_map.default_file_name] via {!Share_class_map.load}
    (which fails loudly on a missing or malformed file). Otherwise returns
    [config] unchanged — in particular the default-off path never touches the
    file, and a spec that sets the groups inline keeps its own map. Called once
    per run by the backtest runner. *)

val validate : Weinstein_strategy_config.config -> unit
(** Raise [Failure] when the flag is on but [config.share_class_groups] is
    empty: the rule would silently do nothing. Called by
    {!Weinstein_strategy.make}, so a caller that skipped {!resolve_config} fails
    at construction instead of running an unarmed arm. No-op with the flag off.
*)

type t
(** One entry walk's gate state: the map plus the mutable set of occupied
    groups. *)

val create :
  config:Weinstein_strategy_config.config ->
  portfolio:Trading_strategy.Portfolio_view.t ->
  suspended_held:string list ->
  t option
(** Seed a walk's gate from the open-or-pending longs described above. [None]
    when [config.max_one_share_class_per_issuer] is [false]. *)

val classify :
  t option ->
  held_set:Core.String.Set.t ->
  Screener.scored_candidate ->
  decide:(unit -> Entry_audit_capture.candidate_decision) ->
  Entry_audit_capture.candidate_decision
(** Classify one candidate. [decide] runs the walk's existing gate chain
    ({!Entry_audit_capture.classify_candidate}) and is called at most once.

    - [None] gate, a short, an unmapped symbol, or a symbol in [held_set]:
      [decide ()] unchanged.
    - A long whose group is occupied: [Skipped Share_class_held]; [decide] is
      {b not} called, so no sizing, stop state, position id or cash is touched.
    - Otherwise [decide ()]; a [Kept] result marks the group occupied for the
      rest of the walk. *)
