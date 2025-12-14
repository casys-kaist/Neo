#!/bin/bash

. ../../env.sh

REPOSITORY_PATH=$(git rev-parse --show-toplevel)
OUTPUT_PATH=$OUTPUT_PATH/chapter6_evaluation/figure_15
UTILS_PATH=$REPOSITORY_PATH/script/utils

rm -rf $OUTPUT_PATH
mkdir -p $OUTPUT_PATH

for SCENE in "family" "francis" "horse" "lighthouse" "playground" "train"; do
    for RESOLUTION in "HD" "FHD" "QHD"; do
        python $UTILS_PATH/run.py \
            --dataset_path $DATASET_PATH \
            --model_path $MODEL_PATH \
            --output_path $OUTPUT_PATH \
            --device orin \
            --resolution $RESOLUTION \
            --scene $SCENE \
            --iteration 200 \
            --algorithm gs \
            --runtime_measurement \
            --figure_idx 15
    done
done

python $UTILS_PATH/postprocess.py \
    --dataset_path $DATASET_PATH \
    --model_path $MODEL_PATH \
    --output_path $OUTPUT_PATH \
    --figure_idx 15 \
    --device orin
