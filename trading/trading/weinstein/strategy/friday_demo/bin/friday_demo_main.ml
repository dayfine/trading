(* Print the stage-by-stage trace of the synthetic Friday demo. *)
let () =
  print_string
    (Friday_demo.Friday_trace_printer.render
       (Friday_demo.Friday_demo_fixture.trace ()))
