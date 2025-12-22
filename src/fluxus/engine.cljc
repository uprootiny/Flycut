(ns fluxus.engine
  "Core translation engine for mapping physical gimbal movement across
   etched convex surfaces to semantic LLM generation parameters."
  (:require [fluxus.schema :as schema]
            [malli.core :as m]))

;; Design Brief: Convex Mapping
;; The surface is a geodesic dome segment. Z-height represents convex curvature.
;; Etched pathways (highways) act as conceptual corridors.
;; We map:
;; - X/Y position -> Semantic Latent Space Vector
;; - Velocity -> Generation Iteration Frequency (Pace)
;; - Z-Pressure -> Constraint Adherence Strength
;; - Tilt (Pitch/Roll) -> Perspective or Voice Modulation

(defn calculate-semantic-drift
  "Translates coordinates on the etched surface to a semantic vector.
   Snap-to-path logic can be added here."
  [pos]
  {:vector [(:x pos) (:y pos) (:z pos)]})

(defn map-motion-to-generation
  "High-level translation from physical sensor data to LLM config.
   Conforms to fluxus.schema/GenerationConfig."
  [gimbal-state]
  (let [{:keys [position velocity pressure tilt]} gimbal-state]
    {:semantic-vector (:vector (calculate-semantic-drift position))
     :granularity (cond
                    (< (:z velocity) 0.1) :fine
                    (< (:z velocity) 0.5) :medium
                    :else :coarse)
     :iteration-pace (Math/abs (:x velocity))
     :constraint-strength pressure}))

(defn update-state
  "Pure function to evolve the generation state based on gimbal input."
  [current-state new-gimbal-data]
  (let [valid-gimbal (schema/validate schema/GimbalState new-gimbal-data)]
    (merge current-state (map-motion-to-generation valid-gimbal))))
