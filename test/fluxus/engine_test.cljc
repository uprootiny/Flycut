(ns fluxus.engine-test
  (:require [clojure.test :refer [deftest is testing]]
            [fluxus.engine :as engine]
            [fluxus.schema :as schema]))

(deftest translation-engine-test
  (testing "Mapping stationary gimbal at center"
    (let [input {:position {:x 0.0 :y 0.0 :z 0.0}
                 :velocity {:x 0.0 :y 0.0 :z 0.0}
                 :pressure 0.5
                 :tilt {:pitch 0.0 :roll 0.0 :yaw 0.0}
                 :timestamp 1700000000000}
          result (engine/map-motion-to-generation input)]
      (is (= [0.0 0.0 0.0] (:semantic-vector result)))
      (is (= :fine (:granularity result)))
      (is (= 0.5 (:constraint-strength result)))))

  (testing "Mapping high velocity and pressure"
    (let [input {:position {:x 1.0 :y -1.0 :z 0.5}
                 :velocity {:x 2.5 :y 0.0 :z 0.8}
                 :pressure 0.9
                 :tilt {:pitch 15.0 :roll 0.0 :yaw 0.0}
                 :timestamp 1700000000001}
          result (engine/map-motion-to-generation input)]
      (is (= [1.0 -1.0 0.5] (:semantic-vector result)))
      (is (= :coarse (:granularity result))) ; velocity.z > 0.5
      (is (= 2.5 (:iteration-pace result)))
      (is (= 0.9 (:constraint-strength result))))))
