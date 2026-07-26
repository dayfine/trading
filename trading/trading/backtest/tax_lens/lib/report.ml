open Core
module M = Tax_model
module D = Diagnostics

let _m x = x /. 1_000_000.
let _pct x = 100. *. x

let _mode_line (c : Tax_config.t) =
  match c.mode with
  | Tax_config.Mtm_flat ->
      Printf.sprintf "mtm_flat (rate %.3f) carryforward=%b" c.flat_rate
        c.carryforward
  | Tax_config.Realized_st_lt ->
      Printf.sprintf
        "realized_st_lt (st %.3f) (lt %.3f) (lt_days %d) carryforward=%b"
        c.st_rate c.lt_rate c.lt_days c.carryforward

let _summary (r : M.result) buf =
  Buffer.add_string buf "## After-tax performance lens\n\n";
  Buffer.add_string buf (Printf.sprintf "Mode: `%s`\n\n" (_mode_line r.config));
  Buffer.add_string buf "| Metric | Pre-tax | After-tax |\n|---|---|---|\n";
  Buffer.add_string buf
    (Printf.sprintf "| Terminal equity ($M) | %.2f | %.2f |\n"
       (_m r.pretax_final) (_m r.aftertax_final));
  Buffer.add_string buf
    (Printf.sprintf "| CAGR | %.1f%% | %.1f%% |\n" (_pct r.pretax_cagr)
       (_pct r.aftertax_cagr));
  Buffer.add_string buf
    (Printf.sprintf
       "\n\
        Total tax paid: $%.2fM. Realized P&L: $%.2fM. Final-year unrealized \
        (deferred, untaxed): $%.2fM.\n\n"
       (_m r.total_tax_paid) (_m r.total_realized_pnl) (_m r.final_unrealized))

let _year_table (r : M.result) buf =
  Buffer.add_string buf "### Per-year path & carryforward trajectory\n\n";
  Buffer.add_string buf
    "| Year | Pretax end ($M) | ST gain ($) | LT gain ($) | Raw tax ($) | Paid \
     tax ($) | Carryforward ($) | Aftertax end ($M) |\n";
  Buffer.add_string buf "|---|---|---|---|---|---|---|---|\n";
  List.iter r.rows ~f:(fun row ->
      Buffer.add_string buf
        (Printf.sprintf
           "| %d | %.2f | %.0f | %.0f | %.0f | %.0f | %.0f | %.2f |\n" row.year
           (_m row.pretax_end) row.st_gain row.lt_gain row.raw_tax row.paid_tax
           row.carryforward_end (_m row.aftertax_end)))

let _winners_table (winners : D.winner_row list) buf =
  Buffer.add_string buf
    "\n### Top winners — days-to-LT at exit (measurement only)\n\n";
  Buffer.add_string buf
    "Raw ST-vs-LT boundary tax delta (pre path-scaling). Measures the boundary \
     cost; no exit mechanic is proposed.\n\n";
  Buffer.add_string buf
    "| Symbol | Exit yr | Days held | Days to LT | LT? | P&L ($M) | Boundary \
     tax delta ($M) |\n";
  Buffer.add_string buf "|---|---|---|---|---|---|---|\n";
  List.iter winners ~f:(fun w ->
      Buffer.add_string buf
        (Printf.sprintf "| %s | %d | %d | %d | %b | %.2f | %.2f |\n" w.symbol
           w.exit_year w.days_held w.days_to_lt w.is_long_term (_m w.pnl)
           (_m w.boundary_tax_delta)))

let render (r : M.result) (winners : D.winner_row list) =
  let buf = Buffer.create 4096 in
  _summary r buf;
  _year_table r buf;
  _winners_table winners buf;
  Buffer.contents buf
