(** Unit tests for [Tax_lens.Tax_model].

    The realized-basis simulation is pinned against a fully hand-computed 3-year
    fixture (see the arithmetic in each test's comment), plus the carryforward
    offset-ordering rules in isolation via [year_tax], plus the MTM path. *)

open OUnit2
open Matchers
module TC = Tax_lens.Tax_config
module TM = Tax_lens.Tax_model
module TT = Tax_lens.Tax_types

let _trade ~symbol ~exit_year ~days_held ~pnl ?(side = "LONG") () :
    TT.realized_trade =
  { symbol; exit_year; days_held; pnl; side }

(* Round rates (ST 0.5, LT 0.2) chosen so the hand arithmetic is exact. *)
let _realized_config : TC.t =
  {
    mode = Realized_st_lt;
    flat_rate = 0.5;
    st_rate = 0.5;
    lt_rate = 0.2;
    lt_days = 365;
    carryforward = true;
    top_winners = 3;
  }

(* Pre-tax path 1000 → 1300 → 1250 → 1400 over 3 years. *)
let _fixture : TT.run_data =
  {
    trades =
      [
        _trade ~symbol:"A" ~exit_year:2001 ~days_held:100 ~pnl:200. ();
        _trade ~symbol:"B" ~exit_year:2001 ~days_held:400 ~pnl:100. ();
        _trade ~symbol:"C" ~exit_year:2002 ~days_held:30 ~pnl:(-50.) ();
        _trade ~symbol:"D" ~exit_year:2003 ~days_held:50 ~pnl:80. ();
      ];
    equity_year_ends = [ (2001, 1300.); (2002, 1250.); (2003, 1400.) ];
    initial_capital = 1000.;
    span_years = 3.;
  }

(* Hand computation of the after-tax path (scale = at_start / pt_start):
   2001: r=0.30, scale=1. st=200,lt=100 → raw=200*.5+100*.2=120, paid=120.
         AT = 1000*1.30-120 = 1180. CF=0.
   2002: r=-50/1300. st=-50 (loss) → raw=0. AT = 1180*(1250/1300)=1134.6154. CF=50.
   2003: r=0.12, scale=1134.6154/1250=0.9076923. st=80, CF=50 offsets → taxable 30,
         raw=15, paid=13.6154. AT = 1134.6154*1.12-13.6154 = 1257.1538. CF=0. *)
let test_realized_fixture _ =
  let r = TM.simulate _realized_config _fixture in
  assert_that r
    (all_of
       [
         field (fun r -> r.TM.pretax_final) (float_equal 1400.);
         field
           (fun r -> r.TM.aftertax_final)
           (float_equal ~epsilon:1e-2 1257.15);
         field
           (fun r -> r.TM.total_tax_paid)
           (float_equal ~epsilon:1e-2 133.615);
         field (fun r -> r.TM.total_realized_pnl) (float_equal 330.);
         field (fun r -> r.TM.final_unrealized) (float_equal 70.);
       ])

(* The carryforward pool climbs to 50 in the loss year, drains to 0 next year. *)
let test_carryforward_trajectory _ =
  let r = TM.simulate _realized_config _fixture in
  assert_that r.TM.rows
    (elements_are
       [
         field (fun row -> row.TM.carryforward_end) (float_equal 0.);
         field (fun row -> row.TM.carryforward_end) (float_equal 50.);
         field (fun row -> row.TM.carryforward_end) (float_equal 0.);
       ])

(* Carryforward offsets ST gains first: cf=50 against st=80,lt=100 →
   taxable_st=30 at 0.5, lt untouched=100 at 0.2 → 15+20=35, cf drained to 0. *)
let test_year_tax_offset_st_first _ =
  let tax, cf =
    TM.year_tax ~st_rate:0.5 ~lt_rate:0.2 ~carryforward:true ~cf:50. ~st:80.
      ~lt:100.
  in
  assert_that tax (float_equal 35.);
  assert_that cf (float_equal 0.)

(* Net losses are disallowed in-year and grow the pool (no in-year deduction). *)
let test_year_tax_loss_accumulates _ =
  let tax, cf =
    TM.year_tax ~st_rate:0.5 ~lt_rate:0.2 ~carryforward:true ~cf:0. ~st:(-50.)
      ~lt:(-30.)
  in
  assert_that tax (float_equal 0.);
  assert_that cf (float_equal 80.)

(* Without carryforward the pool is ignored and gains are taxed gross. *)
let test_year_tax_no_carryforward _ =
  let tax, cf =
    TM.year_tax ~st_rate:0.5 ~lt_rate:0.2 ~carryforward:false ~cf:999. ~st:100.
      ~lt:100.
  in
  assert_that tax (float_equal 70.);
  assert_that cf (float_equal 999.)

(* MTM taxes the full equity change at the flat rate (trades ignored):
   2001: st=300 → paid 150, AT=1300-150=1150.
   2002: st=-150 → paid 0, AT=1150*(1250/1300)=1105.7692.
   2003: st=150 → raw 75, scale=1105.7692/1250 → paid 66.346,
         AT=1105.7692*1.12-66.346 = 1172.115. *)
let test_mtm_flat_path _ =
  let cfg = { _realized_config with mode = Mtm_flat; carryforward = false } in
  let r = TM.simulate cfg _fixture in
  assert_that r.TM.aftertax_final (float_equal ~epsilon:1e-2 1172.12)

let suite =
  "tax_model"
  >::: [
         "realized_fixture" >:: test_realized_fixture;
         "carryforward_trajectory" >:: test_carryforward_trajectory;
         "year_tax_offset_st_first" >:: test_year_tax_offset_st_first;
         "year_tax_loss_accumulates" >:: test_year_tax_loss_accumulates;
         "year_tax_no_carryforward" >:: test_year_tax_no_carryforward;
         "mtm_flat_path" >:: test_mtm_flat_path;
       ]

let () = run_test_tt_main suite
