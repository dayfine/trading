(* Continuous overhead-supply score: [Some] only when armed AND a sketch and a
   breakout price are both present. *)
let _supply ~overhead_supply ~get_sketch ~breakout_price :
    Resistance_supply.result option =
  match (overhead_supply, get_sketch (), breakout_price) with
  | Some supply_config, Some sketch, Some bp ->
      Some
        (Resistance_supply.analyze ~config:supply_config ~sketch
           ~breakout_price:bp)
  | _ -> None

(* Virgin-crossing re-admission eligibility: armed AND a sketch and a breakout
   price both present AND the breakout is into new high ground. New high ground
   is [is_virgin] (breakout >= 520w max high) OR [is_clear_of_supply] (no weekly
   bar at/above the current close). The OR closes the own-week-high artifact
   that makes [is_virgin] structurally unsatisfiable on a close-anchored
   breakout price — see [Resistance_supply.is_clear_of_supply] (AXTI 2026-01-06:
   close 20.17, max_high_520w 20.345, hist_sum 0). *)
let _virgin_readmission ~virgin_crossing_readmission ~get_sketch ~breakout_price
    : bool =
  match (virgin_crossing_readmission, get_sketch (), breakout_price) with
  | true, Some sketch, Some bp ->
      Resistance_supply.is_virgin ~sketch ~breakout_price:bp
      || Resistance_supply.is_clear_of_supply ~sketch
  | _ -> false

let results ~overhead_supply ~virgin_crossing_readmission ~get_sketch
    ~breakout_price =
  ( _supply ~overhead_supply ~get_sketch ~breakout_price,
    _virgin_readmission ~virgin_crossing_readmission ~get_sketch ~breakout_price
  )
