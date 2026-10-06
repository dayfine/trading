let combine ~enable_short_side ~short_min_price ~short_price_of ~buy_candidates
    ~short_candidates =
  if enable_short_side then
    buy_candidates
    @ Short_min_price_gate.filter ~price_of:short_price_of ~short_min_price
        short_candidates
  else buy_candidates
