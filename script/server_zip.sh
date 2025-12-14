#!/bin/bash

. ./env.sh

rm -rf $OUTPUT_PATH/server
mkdir -p $OUTPUT_PATH/server

cp $OUTPUT_PATH/chapter6_evaluation/figure_15/server.csv $OUTPUT_PATH/server/server_figure_15.csv
cp $OUTPUT_PATH/chapter6_evaluation/figure_16/server.csv $OUTPUT_PATH/server/server_figure_16.csv
cp $OUTPUT_PATH/chapter6_evaluation/figure_17/server-A.csv $OUTPUT_PATH/server/server_figure_17_A.csv
cp $OUTPUT_PATH/chapter6_evaluation/figure_17/server-B.csv $OUTPUT_PATH/server/server_figure_17_B.csv
cp $OUTPUT_PATH/chapter6_evaluation/figure_18/server.csv $OUTPUT_PATH/server/server_figure_18.csv
cp $OUTPUT_PATH/chapter6_evaluation/figure_19/server.csv $OUTPUT_PATH/server/server_figure_19.csv
cp $OUTPUT_PATH/chapter6_evaluation/table_2/server.csv $OUTPUT_PATH/server/server_table_2.csv

cd $OUTPUT_PATH
tar -cvf server.tar ./server
