(** Module for segmenting time series data into trend-based segments. This
    module provides functionality to break down a time series into segments
    where each segment represents a distinct trend (increasing, decreasing, or
    flat). The segmentation is based on statistical analysis of the data points
    and optimization of various quality metrics. *)

type segmentation_params = {
  min_segment_length : int;
      (** Minimum number of data points required for a valid segment. Segments
          shorter than this will be merged with adjacent segments. *)
  preferred_segment_length : int;
      (** Target length for segments. The algorithm will try to create segments
          close to this length, but may deviate based on other constraints. *)
  length_flexibility : float;
      (** How much deviation from preferred_segment_length is allowed. Higher
          values allow more variation in segment lengths. *)
  min_r_squared : float;
      (** Minimum R-squared value required for a valid segment. This ensures
          each segment has a statistically significant trend. *)
  min_slope : float;
      (** Minimum absolute slope value to consider a segment as trending.
          Segments with slopes below this are considered "flat". *)
  max_segments : int;
      (** Maximum number of segments to create. The algorithm will stop
          splitting when this limit is reached. *)
  preferred_channel_width : float;
      (** Target width for the price channel around the trend line. Used to
          measure volatility and fit quality. *)
  max_channel_width : float;
      (** Maximum allowed channel width. Segments with wider channels are
          penalized in the scoring. *)
  width_penalty_factor : float;
      (** Factor used to penalize segments that deviate from
          preferred_channel_width. Higher values make the algorithm more strict
          about channel width. *)
  r_squared_tolerance : float;
      (** Additional tolerance for R-squared threshold when determining if a
          segment should be split. This allows for slightly lower R-squared
          values before forcing a split. *)
  max_width_penalty : float;
      (** Maximum allowed width penalty before a segment is split. This controls
          how much deviation from the preferred channel width is tolerated
          before forcing a split. *)
}
[@@deriving show, eq]
(** Parameters that control the behavior of the segmentation algorithm. These
    parameters allow fine-tuning of how the algorithm identifies and processes
    trend segments in the data. *)

val default_params : segmentation_params
(** Default parameters for segmentation. These values provide a good starting
    point for most time series data. They can be adjusted based on specific
    requirements or data characteristics. *)

type segment = {
  start_idx : int;  (** Starting index of the segment in the input array *)
  end_idx : int;  (** Ending index of the segment in the input array *)
  trend : Trend_type.t;  (** Trend direction *)
  r_squared : float;
      (** R-squared value indicating how well the linear regression fits the
          data. Values range from 0 to 1, with higher values indicating better
          fit. *)
  channel_width : float;
      (** Standard deviation of residuals from the trend line. Measures the
          volatility or "width" of the price channel around the trend. *)
  slope : float;  (** Slope of the regression line *)
  intercept : float;
      (** Y-intercept of the regression line for **this** segment, which should
          be close to the first data point of the segment *)
}
[@@deriving show, eq]
(** Represents a single trend segment in the time series. Each segment contains
    information about its position in the data, trend characteristics, and
    statistical quality metrics. *)

val segment_by_trends :
  ?params:segmentation_params -> float array -> segment list
(** Main function that segments a time series into trend-based segments.
    @param params
      Optional parameters to customize the segmentation behavior. If not
      provided, default_params will be used.
    @param data Array of float values representing the time series to segment.
    @return
      List of segments, ordered from earliest to latest in the time series. *)
