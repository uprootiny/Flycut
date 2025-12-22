(ns fluxus.schema
  (:require [malli.core :as m]))

;; Robust schema for the Gimbal state and LLM parameters
(def GimbalState
  [:map
   [:position [:map [:x :double] [:y :double] [:z :double]]]
   [:velocity [:map [:x :double] [:y :double] [:z :double]]]
   [:pressure :double]
   [:tilt [:map [:pitch :double] [:roll :double] [:yaw :double]]]
   [:timestamp :long]])

(def GenerationConfig
  [:map
   [:semantic-vector [:vector :double]]
   [:granularity [:enum :coarse :medium :fine :token]]
   [:iteration-pace :double]
   [:constraint-strength :double]])

(defn validate [schema data]
  (if (m/validate schema data)
    data
    (throw (ex-info "Invalid data structure" 
                    {:error (m/explain schema data)}))))
