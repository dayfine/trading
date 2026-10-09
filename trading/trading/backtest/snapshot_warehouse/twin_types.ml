open Core

module Config = struct
  type basis = Levels | Returns [@@deriving sexp, equal]

  type t = {
    enabled : bool;
    min_overlap_days : int;
    match_fraction : float;
    close_epsilon : float;
    basis : basis; [@sexp.default Levels]
    ret_epsilon : float; [@sexp.default 1e-3]
    prefilter_rel_tol : float;
    require_direct_match : bool; [@sexp.default false]
    max_group_size : int option; [@sexp.option]
    min_matching_run : int option; [@sexp.option]
  }
  [@@deriving sexp, equal]

  let default =
    {
      enabled = false;
      min_overlap_days = 100;
      match_fraction = 0.95;
      close_epsilon = 1e-4;
      basis = Levels;
      ret_epsilon = 1e-3;
      prefilter_rel_tol = 2e-2;
      require_direct_match = false;
      max_group_size = None;
      min_matching_run = None;
    }
end

type series = {
  symbol : string;
  data_end : Date.t;
  closes : (Date.t * float) array;
}
[@@deriving sexp_of]

type pair_match = {
  survivor : string;
  dropped : string;
  overlap_days : int;
  match_fraction : float;
}
[@@deriving sexp_of, equal]

type group = {
  survivor : string;
  dropped : string list;
  matches : pair_match list;
}
[@@deriving sexp_of, equal]

type rejection_reason = Transitive | Hub [@@deriving sexp, equal]

type rejection = {
  reason : rejection_reason;
  survivor : string;
  kept : string;
  overlap_days : int;
  match_fraction : float;
}
[@@deriving sexp, equal]

type report = {
  config : Config.t;
  groups : group list;
  dropped_symbols : string list;
  rejected : rejection list;
}
[@@deriving sexp_of]
