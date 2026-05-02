(** Phase C of the optimal-strategy counterfactual: greedy sizing-constrained
    fill.

    See [optimal_portfolio_filler.mli] for the API contract. *)

open Core

type config = {
  starting_cash : float;
  risk_per_trade_pct : float;
  max_positions : int;
  max_sector_concentration : int;
}
[@@deriving sexp]

let default_config : config =
  {
    starting_cash = 100_000.0;
    risk_per_trade_pct = 0.01;
    max_positions = 20;
    max_sector_concentration = 5;
  }

type fill_input = {
  candidates : Optimal_types.scored_candidate list;
  variant : Optimal_types.variant_label;
}

type _open_position = {
  scored : Optimal_types.scored_candidate;
  shares : float;
  initial_risk_dollars : float;
}
(** In-flight position tracked by the filler. Becomes an [optimal_round_trip]
    when its [exit_week] is reached. *)

type _book = {
  mutable cash : float;
  mutable opens : _open_position list;
  mutable closed : Optimal_types.optimal_round_trip list;
}
(** Mutable book the filler maintains as it walks Fridays. The mutability is
    contained — the public [fill] function is pure. *)

(** Tag a candidate as admissible under the chosen variant. *)
let _candidate_admissible ~(variant : Optimal_types.variant_label)
    (sc : Optimal_types.scored_candidate) : bool =
  match variant with
  | Relaxed_macro -> true
  | Constrained | Score_picked -> sc.entry.passes_macro

(** All distinct entry-Fridays in [scored], in ascending order. Drives the walk.
*)
let _distinct_entry_fridays (scored : Optimal_types.scored_candidate list) :
    Date.t list =
  scored
  |> List.map ~f:(fun (sc : Optimal_types.scored_candidate) ->
      sc.entry.entry_week)
  |> List.dedup_and_sort ~compare:Date.compare

(** Comparator for sorting same-Friday candidates under [variant].

    - [Constrained] / [Relaxed_macro] sort by realised [r_multiple] descending.
      The R-multiple is computed forward from the candidate, so this picks
      winners by hindsight — useful as a ceiling, contaminating as a target.
    - [Score_picked] sorts by pre-trade [cascade_score] descending — the same
      signal the actual strategy uses at decision time. Ties broken by [symbol]
      ascending so the order is deterministic across runs. *)
let _entry_comparator ~(variant : Optimal_types.variant_label) :
    Optimal_types.scored_candidate -> Optimal_types.scored_candidate -> int =
  match variant with
  | Constrained | Relaxed_macro ->
      fun (a : Optimal_types.scored_candidate)
        (b : Optimal_types.scored_candidate)
      -> Float.compare b.r_multiple a.r_multiple
  | Score_picked ->
      fun (a : Optimal_types.scored_candidate)
        (b : Optimal_types.scored_candidate)
      ->
        let by_score =
          Int.compare b.entry.cascade_score a.entry.cascade_score
        in
        if by_score <> 0 then by_score
        else String.compare a.entry.symbol b.entry.symbol

(** Candidates entering on [friday], sorted by the variant-specific key:
    [r_multiple] DESC for [Constrained] / [Relaxed_macro], [cascade_score] DESC
    (with [symbol] ASC tie-break) for [Score_picked]. *)
let _entries_on ~(variant : Optimal_types.variant_label)
    (scored : Optimal_types.scored_candidate list) (friday : Date.t) :
    Optimal_types.scored_candidate list =
  scored
  |> List.filter ~f:(fun (sc : Optimal_types.scored_candidate) ->
      Date.equal sc.entry.entry_week friday)
  |> List.sort ~compare:(_entry_comparator ~variant)

(** Number of currently open positions in [sector] in [book]. *)
let _sector_count (book : _book) (sector : string) : int =
  List.count book.opens ~f:(fun op ->
      String.equal op.scored.entry.sector sector)

(** Whether [book] currently holds an open position in [symbol]. *)
let _holds_symbol (book : _book) (symbol : string) : bool =
  List.exists book.opens ~f:(fun op ->
      String.equal op.scored.entry.symbol symbol)

(** Risk-per-trade dollars for this fill — fixed at
    [starting_cash * risk_per_trade_pct]. *)
let _risk_per_trade_dollars (config : config) : float =
  config.starting_cash *. config.risk_per_trade_pct

(** Compute the share count for a candidate. Floors to whole shares so the
    risk-per-trade envelope is never exceeded. Returns [0.0] when
    [initial_risk_per_share] is non-positive (defensive — the scorer should have
    rejected such candidates upstream). *)
let _compute_shares ~(config : config) (sc : Optimal_types.scored_candidate) :
    float =
  if Float.(sc.initial_risk_per_share <= 0.0) then 0.0
  else
    let raw = _risk_per_trade_dollars config /. sc.initial_risk_per_share in
    Float.round_down raw

(** Build an [optimal_round_trip] from an [_open_position] at exit time. The
    exit fields come from the scored candidate (the scorer determined them in
    Phase B). *)
let _close_position (op : _open_position) : Optimal_types.optimal_round_trip =
  let entry = op.scored.entry in
  let pnl_per_share =
    match entry.side with
    | Trading_base.Types.Long -> op.scored.exit_price -. entry.entry_price
    | Short -> entry.entry_price -. op.scored.exit_price
  in
  let pnl_dollars = pnl_per_share *. op.shares in
  let r_multiple =
    if Float.(op.initial_risk_dollars <= 0.0) then 0.0
    else pnl_dollars /. op.initial_risk_dollars
  in
  {
    symbol = entry.symbol;
    side = entry.side;
    entry_week = entry.entry_week;
    entry_price = entry.entry_price;
    exit_week = op.scored.exit_week;
    exit_price = op.scored.exit_price;
    exit_trigger = op.scored.exit_trigger;
    shares = op.shares;
    initial_risk_dollars = op.initial_risk_dollars;
    pnl_dollars;
    r_multiple;
    cascade_grade = entry.cascade_grade;
    passes_macro = entry.passes_macro;
  }

(** Close every position whose [exit_week] equals [friday], accruing proceeds to
    cash. Mutates [book] in place. *)
let _close_due (book : _book) (friday : Date.t) : unit =
  let due, still_open =
    List.partition_tf book.opens ~f:(fun op ->
        Date.equal op.scored.exit_week friday)
  in
  List.iter due ~f:(fun op ->
      let exit_value = op.scored.exit_price *. op.shares in
      book.cash <- book.cash +. exit_value;
      book.closed <- _close_position op :: book.closed);
  book.opens <- still_open

(** Try to admit [sc] into [book] under [config]. Returns [true] iff the
    candidate cleared every check and was admitted; [false] otherwise. Mutates
    [book] when admitting.

    All checks are evaluated upfront into a single boolean; mutation only
    happens on the admit branch. The pre-checks ([_compute_shares] and the cost
    computation) are cheap pure expressions, so eager evaluation costs nothing
    and avoids a five-deep [if/else] cascade. *)
let _try_admit ~(config : config) (book : _book)
    (sc : Optimal_types.scored_candidate) : bool =
  let shares = _compute_shares ~config sc in
  let cost = shares *. sc.entry.entry_price in
  let admissible =
    (not (_holds_symbol book sc.entry.symbol))
    && List.length book.opens < config.max_positions
    && _sector_count book sc.entry.sector < config.max_sector_concentration
    && Float.(shares > 0.0)
    && Float.(cost <= book.cash)
  in
  if not admissible then false
  else
    let initial_risk_dollars = sc.initial_risk_per_share *. shares in
    book.cash <- book.cash -. cost;
    book.opens <- { scored = sc; shares; initial_risk_dollars } :: book.opens;
    true

(** Process all entries on [friday] in R-descending order. *)
let _process_entries ~config (book : _book)
    (entries : Optimal_types.scored_candidate list) : unit =
  List.iter entries ~f:(fun sc -> ignore (_try_admit ~config book sc : bool))

(** Close every remaining open position at end-of-run, in exit-week order. *)
let _close_remaining (book : _book) : unit =
  let remaining =
    List.sort book.opens ~compare:(fun a b ->
        Date.compare a.scored.exit_week b.scored.exit_week)
  in
  List.iter remaining ~f:(fun op ->
      let exit_value = op.scored.exit_price *. op.shares in
      book.cash <- book.cash +. exit_value;
      book.closed <- _close_position op :: book.closed);
  book.opens <- []

(** Sort closed round-trips by entry-week ascending, ties broken by R-multiple
    descending — matches the order they were admitted within each Friday. *)
let _final_order (closed : Optimal_types.optimal_round_trip list) :
    Optimal_types.optimal_round_trip list =
  List.sort closed ~compare:(fun a b ->
      let by_entry = Date.compare a.entry_week b.entry_week in
      if by_entry <> 0 then by_entry
      else Float.compare b.r_multiple a.r_multiple)

let fill ~(config : config) (input : fill_input) :
    Optimal_types.optimal_round_trip list =
  let admissible =
    List.filter input.candidates
      ~f:(_candidate_admissible ~variant:input.variant)
  in
  if List.is_empty admissible then []
  else
    let book = { cash = config.starting_cash; opens = []; closed = [] } in
    let fridays = _distinct_entry_fridays admissible in
    List.iter fridays ~f:(fun friday ->
        _close_due book friday;
        let entries = _entries_on ~variant:input.variant admissible friday in
        _process_entries ~config book entries);
    _close_remaining book;
    _final_order book.closed
