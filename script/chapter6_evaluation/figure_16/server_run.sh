#!/bin/bash

. ../../env.sh

source /workspace/.venv/bin/activate

REPOSITORY_PATH=$(git rev-parse --show-toplevel)
SIMULATOR_PATH=$REPOSITORY_PATH/src/simulator/neo
UTILS_PATH=$REPOSITORY_PATH/script/utils

OUTPUT_PATH=$OUTPUT_PATH/chapter6_evaluation/figure_16
rm -rf $OUTPUT_PATH
mkdir -p $OUTPUT_PATH

if [ ! -d $OUTPUT_PATH/../figure_15 ]; then
    echo "Figure 15 data not found. Generating Figure 15 data first..."
    cd ../figure_15
    ./neo_run.sh
else
    echo "Figure 15 data found. Skipping Figure 15 data generation."
fi

CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
    python $UTILS_PATH/postprocess.py \
    --dataset_path $DATASET_PATH \
    --model_path $MODEL_PATH \
    --output_path $OUTPUT_PATH \
    --figure_idx 16 \
    --device server
