(** Per-symbol split divisor for true-dollar liquidity readings (issue #3136).

    The bar store's [volume] column is restated for every later split while its
    [close] is raw, so [close *. volume] on day [t] is off by [F(t)], the
    product of the factors of the splits after [t]. This module computes [F] the
    same way the PIT ranking does ({!Universe.Dollar_volume_basis} under
    [true_dollars_config]): a vendor split from the symbol's [splits.csv] counts
    only when the raw close confirms it and the stored volume is restated for
    it.

    Armed by {!Panel_corporate_actions} when
    [config.liquidity_config.true_dollar_volume] is on, and attached to the
    strategy's bar reader ({!Weinstein_strategy.Bar_reader.with_split_divisor}).
    Reading the whole [data.csv] to confirm a split looks past the decision
    date; that only undoes the look-ahead the stored volume already carries. *)

val of_data_dir : data_dir:Fpath.t -> symbol:string -> Core.Date.t -> float
(** [of_data_dir ~data_dir] is a divisor [f] with [f ~symbol date = F(date)]
    over [symbol]'s applied splits, read from
    [<data_dir>/<L1>/<L2>/<symbol>/{data,splits}.csv] on the first call for that
    symbol and cached for the life of [f]. A symbol with no bars or no
    [splits.csv] reads [1.0] on every date (the stored product). *)
