#!/bin/bash

echo "Running experiment for Figure 5"
cd chapter3_motivation/figure_5
./orin_run.sh

echo "Running experiment for Figure 10"
cd ../../chapter4_algorithm/figure_10
./orin_run.sh

echo "Running experiment for Figure 15"
cd ../../chapter6_evaluation/figure_15
./orin_run.sh

echo "Running experiment for Figure 16"
cd ../figure_16
./orin_run.sh

echo "Running experiment for Figure 17"
cd ../figure_17
./orin_run.sh
