(** Universe composition cleanup filter.

    Drops noise symbols (SPACs, warrants, preferreds, unit trusts, indexes,
    ETFs, bond funds, etc.) from a flat row list without touching legitimate
    common stocks or allow-listed ETFs.

    The filter is config-driven so the rule-set can evolve without code changes.
    Configs live under [dev/config/universe_filter/<name>.sexp] and parse into
    {!config} values via {!load_config}.

    Row enrichment — the row type carries {!name} and {!exchange} in addition to
    sector, loaded by joining [data/sectors.csv] against [data/universe.sexp]
    (see {!load_rows_with_universe}). This lets rules target instrument names
    ("ETF" / "Fund" / "Trust" / "Notes") and primary exchange ("NYSE ARCA" ≈ ETF
    listing venue), not just the symbol ticker.

    Rescue rules — {!Keep_allowlist} preserves individual symbols; the newer
    {!Keep_if_sector} preserves entire sectors (e.g. Real Estate) so that
    legitimate REITs are not swept up by a name-pattern drop rule. *)

type row = {
  symbol : string;
  sector : string;
  name : string;
      (** Instrument display name from [data/universe.sexp]; [""] if the symbol
          is absent from the universe file. *)
  exchange : string;
      (** Primary exchange from [data/universe.sexp]; [""] if absent. Typical
          values: [NYSE], [NASDAQ], ["NYSE ARCA"]. *)
}
[@@deriving sexp, equal]
(** One enriched row. Symbol + sector come from [data/sectors.csv]; name and
    exchange come from [data/universe.sexp]. *)

(** A drop rule. Each {b non-allowlist} rule decides independently whether to
    drop a row. A row survives only if no non-allowlist rule matches {i and/or}
    an allow-list matches the symbol. *)
type rule =
  | Symbol_pattern of {
      name : string;  (** Short label used in stats output. *)
      pattern : string;
          (** Perl-style regex matched against [row.symbol]. A row is dropped
              when this regex matches the symbol. *)
    }
  | Name_pattern of {
      name : string;  (** Short label used in stats output. *)
      pattern : string;
          (** Perl-style regex matched against [row.name]. Prepend [(?i)] to
              make the match case-insensitive (this prefix is stripped and
              translated to the [`Caseless] flag — the rest of the pattern is
              compiled as normal Perl syntax). A row is dropped when the regex
              matches the instrument name. *)
    }
  | Exchange_equals of {
      name : string;  (** Short label used in stats output. *)
      exchange : string;
          (** Exact (case-sensitive) match against [row.exchange]. A row is
              dropped when [row.exchange = exchange]. *)
    }
  | Keep_allowlist of {
      name : string;
      symbols : string list;
          (** Symbols in this list are preserved even if a drop rule matches.
              Allow-list rescue is final — it cannot be overridden by any other
              rule. *)
    }
  | Keep_if_sector of {
      name : string;
      sectors : string list;
          (** Rows whose [row.sector] is an exact (case-sensitive) member of
              [sectors] are preserved even if a drop rule matches. Rescue is
              final — identical semantics to {!Keep_allowlist} but keyed on
              sector rather than individual symbol.

              Typical use-case: preserve legitimate REITs and royalty trusts
              (sector ["Real Estate"], ["Energy"], ["Materials"]) that would
              otherwise be swept up by a {!Name_pattern} targeting the word
              "Trust". *)
    }
[@@deriving sexp]

type config = { rules : rule list } [@@deriving sexp]
(** A rule-set.

    Evaluation: for each row, collect matches from every non-allow-list rule in
    declaration order. If any drop rule matches, the row is dropped — unless a
    [Keep_allowlist] contains its symbol, in which case the row is preserved
    regardless.

    Empty [rules] means no-op — everything is kept. *)

type rule_stat = {
  rule_name : string;
  drop_count : int;
      (** How many rows would have been dropped by this rule, before allow-list
          override. Rows rescued by an allow-list are counted here (so per-rule
          stats show the raw hit count) and the rescue itself is counted
          separately in {!filter_result.rescued_by_allowlist}. *)
}
[@@deriving sexp]

type filter_result = {
  kept : row list;
  dropped : row list;
  rule_stats : rule_stat list;
      (** Per-rule drop counts (raw, pre-rescue). See {!rule_stat.drop_count}.
      *)
  rescued_by_allowlist : int;
      (** Count of rows that at least one drop rule would have dropped but were
          preserved because an allow-list matched. *)
}
[@@deriving sexp]

val filter : config -> row list -> filter_result
(** [filter config rows] applies [config.rules] to [rows] and partitions them
    into kept / dropped with per-rule stats.

    Pure: same input, same output. Does no I/O. *)

val load_config : string -> (config, string) Result.t
(** [load_config path] loads and parses a sexp config file.

    Returns [Error msg] with a descriptive message on:
    - file not found / not readable
    - malformed sexp
    - sexp shape does not match [config_of_sexp]

    Does not silently return an empty / default config on parse failure —
    callers should surface the error. *)

val read_csv : string -> (row list, string) Result.t
(** [read_csv path] reads a [symbol,sector] CSV (with header row). Skips blank
    lines. Returns [Error msg] if the file cannot be opened. Rows loaded this
    way have [name = ""] and [exchange = ""]; use {!load_rows_with_universe}
    when those fields are needed. *)

val load_rows_with_universe :
  sectors_csv:string -> universe_sexp:string -> (row list, string) Result.t
(** [load_rows_with_universe ~sectors_csv ~universe_sexp] reads [sectors_csv] as
    the source of truth for the row set (one row per symbol with its sector) and
    enriches each row with [name] + [exchange] pulled from [universe_sexp].

    Symbols present in [sectors_csv] but absent from [universe_sexp] get
    [name = ""] and [exchange = ""] — they are {i not} dropped; the filter is
    applied downstream.

    Returns [Error msg] on I/O / parse failures. [universe_sexp] is expected to
    be a sexp-serialized [Types.Instrument_info.t list]; malformed or missing
    universe sexp yields an error (not a silent fallback). *)

val write_csv : string -> row list -> (unit, string) Result.t
(** [write_csv path rows] writes [rows] to [path] with header [symbol,sector].
    Only [symbol] + [sector] are persisted — [name] and [exchange] come from
    universe.sexp and are not part of the sectors schema. Writes atomically via
    [path.tmp] + rename. *)

val sector_breakdown : row list -> (string * int) list
(** Count rows per sector, sorted by descending count. Convenience for
    before/after summaries. *)
