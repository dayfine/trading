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

(* Virgin-crossing re-admission eligibility: armed AND sketch present AND the
   breakout is virgin (crosses the 520-week max high). *)
let _virgin_readmission ~virgin_crossing_readmission ~get_sketch ~breakout_price
    : bool =
  match (virgin_crossing_readmission, get_sketch (), breakout_price) with
  | true, Some sketch, Some bp ->
      Resistance_supply.is_virgin ~sketch ~breakout_price:bp
  | _ -> false

let results ~overhead_supply ~virgin_crossing_readmission ~get_sketch
    ~breakout_price =
  ( _supply ~overhead_supply ~get_sketch ~breakout_price,
    _virgin_readmission ~virgin_crossing_readmission ~get_sketch ~breakout_price
  )
