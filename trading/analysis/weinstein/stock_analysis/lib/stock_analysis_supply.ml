open Core

type basis = Legacy_mixed | One_basis [@@deriving show, eq, sexp]

(* The breakout on the sketch's price basis. The sketch's own [anchor_close] is
   the as-of close on the sketch's basis; [current_raw_close] is the same close
   on the raw basis of [breakout_price]. Their ratio carries a raw as-of price
   onto the sketch's basis — the as-of split factor on an adjusted-basis sketch,
   1 on a raw-basis one — so this needs no flag for which warehouse it reads. *)
let breakout_on_sketch_basis ~basis ~(sketch : Resistance_supply.sketch)
    ~breakout_price ~current_raw_close =
  match (basis, breakout_price, current_raw_close) with
  | Legacy_mixed, _, _ -> breakout_price
  | One_basis, Some bp, Some raw_close when Float.(raw_close > 0.0) ->
      Some (bp *. sketch.anchor_close /. raw_close)
  | One_basis, _, _ -> None

(* The supply score of one sketch, when the breakout on its basis is known. *)
let _scored ~config ~breakout_of sketch =
  Option.map (breakout_of sketch) ~f:(fun bp ->
      Resistance_supply.analyze ~config ~sketch ~breakout_price:bp)

(* Continuous overhead-supply score: [Some] only when armed AND a sketch and a
   breakout price (on the sketch's basis, [breakout_of]) are both present. The
   sketch is read only when the score is armed. *)
let _supply ~overhead_supply ~get_sketch ~breakout_of :
    Resistance_supply.result option =
  Option.bind overhead_supply ~f:(fun config ->
      Option.bind (get_sketch ()) ~f:(_scored ~config ~breakout_of))

(* New high ground: [is_virgin] (breakout >= 520w max high) OR
   [is_clear_of_supply] (no weekly bar at/above the current close). The OR
   closes the own-week-high artifact that makes [is_virgin] structurally
   unsatisfiable on a close-anchored breakout price — see
   [Resistance_supply.is_clear_of_supply] (AXTI 2026-01-06: close 20.17,
   max_high_520w 20.345, hist_sum 0). No breakout, no new high ground. *)
let _is_new_high_ground ~breakout_of sketch =
  Option.exists (breakout_of sketch) ~f:(fun bp ->
      Resistance_supply.is_virgin ~sketch ~breakout_price:bp
      || Resistance_supply.is_clear_of_supply ~sketch)

(* Virgin-crossing re-admission eligibility: armed AND a sketch AND new high
   ground. The sketch is read only when the lever is armed. *)
let _virgin_readmission ~virgin_crossing_readmission ~get_sketch ~breakout_of :
    bool =
  virgin_crossing_readmission
  && Option.exists (get_sketch ()) ~f:(_is_new_high_ground ~breakout_of)

let results ~overhead_supply ~virgin_crossing_readmission ~basis ~get_sketch
    ~breakout_price ~current_raw_close =
  let breakout_of sketch =
    breakout_on_sketch_basis ~basis ~sketch ~breakout_price ~current_raw_close
  in
  ( _supply ~overhead_supply ~get_sketch ~breakout_of,
    _virgin_readmission ~virgin_crossing_readmission ~get_sketch ~breakout_of )
