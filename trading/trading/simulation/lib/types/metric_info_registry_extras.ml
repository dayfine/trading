(** Per-variant metric_info for the benchmark-relative (CAPM-style) family.
    Carved out of {!Metric_info_registry} to keep that file under the
    file-length linter limit. {!Metric_info_registry.get_metric_info} delegates
    the five cases handled here. *)

open Metric_types
open Metric_info_types

let _info name desc unit = { display_name = name; description = desc; unit }

let info_for_benchmark_relative : metric_type -> metric_info option = function
  | BenchmarkAlphaPctAnnualized ->
      Some
        (_info "Alpha (annualized)"
           "OLS intercept α (annualized %) from r_strat = α + β·r_bench. 0 \
            with no benchmark."
           Percent)
  | BenchmarkBeta ->
      Some
        (_info "Beta" "OLS slope β. 0 when benchmark variance is zero." Ratio)
  | TrackingErrorPctAnnualized ->
      Some
        (_info "Tracking Error (annualized)"
           "Annualized stdev of (r_strat − r_bench). 0 with no benchmark."
           Percent)
  | InformationRatio ->
      Some
        (_info "Information Ratio"
           "Annualized α / Tracking Error. 0 when TE is zero." Ratio)
  | CorrelationToBenchmark ->
      Some
        (_info "Correlation to Benchmark"
           "Pearson r in [−1, 1]. 0 when either series is constant." Ratio)
  | _ -> None
