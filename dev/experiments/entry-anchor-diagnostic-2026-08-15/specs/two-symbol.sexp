;; Two-symbol diagnostic universe: the canonical Stop_too_wide rejections.
;; AXTI (decision 2025-06-27) and BFX (decision 2020-04-17) are both rejected
;; by the 15% max_stop_distance_pct gate in the faithful arms, so neither name
;; appears in any faithful run's audit. This universe exists to make them
;; enter — with the gate widened — so the computed installed_stop can be read
;; per support_floor_anchor_scope.
(Pinned (
  ((symbol AXTI) (sector "Information Technology"))
  ((symbol BFX) (sector "Consumer Staples"))
))
