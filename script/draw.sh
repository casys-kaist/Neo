#!/bin/bash

. ./env.sh

source /workspace/.venv/bin/activate

REPOSITORY_PATH=$(git rev-parse --show-toplevel)
UTILS_PATH=$REPOSITORY_PATH/script/utils

rm -rf $OUTPUT_PATH/summary
mkdir -p $OUTPUT_PATH/summary

cp $OUTPUT_PATH/orin.tar $OUTPUT_PATH/summary/
cp $OUTPUT_PATH/server.tar $OUTPUT_PATH/summary/

cd $OUTPUT_PATH/summary
tar -xvf orin.tar
tar -xvf server.tar

rm -f orin.tar
rm -f server.tar

for idx in 5 10 15 16 17 18 19; do
    CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
        python $UTILS_PATH/draw.py \
        --figure_idx $idx \
        --summary_path $OUTPUT_PATH/summary
done

cp $OUTPUT_PATH/summary/server/server_table_2.csv $OUTPUT_PATH/summary/table_2.csv
