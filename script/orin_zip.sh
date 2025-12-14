#!/bin/bash

. ./env.sh

rm -rf $OUTPUT_PATH/orin
mkdir -p $OUTPUT_PATH/orin

cp $OUTPUT_PATH/chapter3_motivation/figure_5/orin.csv $OUTPUT_PATH/orin/orin_figure_5.csv
cp $OUTPUT_PATH/chapter4_algorithm/figure_10/orin.csv $OUTPUT_PATH/orin/orin_figure_10.csv
cp $OUTPUT_PATH/chapter6_evaluation/figure_15/orin.csv $OUTPUT_PATH/orin/orin_figure_15.csv
cp $OUTPUT_PATH/chapter6_evaluation/figure_16/orin.csv $OUTPUT_PATH/orin/orin_figure_16.csv
cp $OUTPUT_PATH/chapter6_evaluation/figure_17/orin.csv $OUTPUT_PATH/orin/orin_figure_17.csv

cd $OUTPUT_PATH
tar -cvf orin.tar ./orin
