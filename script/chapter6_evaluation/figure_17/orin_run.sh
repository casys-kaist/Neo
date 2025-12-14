#!/bin/bash

. ../../env.sh

REPOSITORY_PATH=$(git rev-parse --show-toplevel)
OUTPUT_PATH=$OUTPUT_PATH/chapter6_evaluation/figure_17
UTILS_PATH=$REPOSITORY_PATH/script/utils

rm -rf $OUTPUT_PATH
mkdir -p $OUTPUT_PATH

for SCENE in "rubble" "building"; do
    python $UTILS_PATH/run.py \
        --dataset_path $DATASET_PATH \
        --model_path $MODEL_PATH \
        --output_path $OUTPUT_PATH \
        --device orin \
        --resolution QHD \
        --scene $SCENE \
        --iteration 200 \
        --algorithm gs \
        --runtime_measurement \
        --figure_idx 17
done

python $UTILS_PATH/postprocess.py \
    --dataset_path $DATASET_PATH \
    --model_path $MODEL_PATH \
    --output_path $OUTPUT_PATH \
    --figure_idx 17 \
    --device orin
