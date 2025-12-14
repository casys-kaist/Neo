#!/bin/bash

echo "Running experiment for Figure 15"
cd chapter6_evaluation/figure_15
./server_run.sh

echo "Running experiment for Figure 16"
cd ../figure_16
./server_run.sh

echo "Running experiment for Figure 17"
cd ../figure_17
./server_run.sh

echo "Running experiment for Figure 18"
cd ../figure_18
./server_run.sh

echo "Running experiment for Figure 19"
cd ../figure_19
./server_run.sh

echo "Running experiment for Table 2"
cd ../table_2
./server_run.sh
