(** Type representing a trend segment *)
type segment = {
  start_idx: int;         (** Starting index of the segment *)
  end_idx: int;          (** Ending index of the segment *)
  trend: string;         (** Trend direction: "increasing", "decreasing", "flat", or "unknown" *)
  r_squared: float;      (** R-squared value indicating fit quality *)
  channel_width: float;  (** Standard deviation of residuals (channel width) *)
}

(** Enhanced segmentation algorithm using Owl's built-in functions *)
val segment_by_trends :
  ?min_segment_length:int ->
  ?preferred_segment_length:int ->
  ?length_flexibility:float ->
  ?min_r_squared:float ->
  ?min_slope:float ->
  ?max_segments:int ->
  ?preferred_channel_width:float ->
  ?max_channel_width:float ->
  ?width_penalty_factor:float ->
  float array ->
  segment array

(** Function to visualize segmentation results with Owl *)
val visualize_segmentation :
  float array ->
  segment array ->
  unit
