#!/bin/bash

. ../../env.sh

source /workspace/.venv/bin/activate

REPOSITORY_PATH=$(git rev-parse --show-toplevel)
SIMULATOR_PATH=$REPOSITORY_PATH/src/simulator
UTILS_PATH=$REPOSITORY_PATH/script/utils

OUTPUT_PATH=$OUTPUT_PATH/chapter6_evaluation/figure_19
rm -rf $OUTPUT_PATH
mkdir -p $OUTPUT_PATH

MAX_CORE=32
RUN_CORE=0

SCENE=train
RESOLUTION=QHD
ITERATION=170

./server_neo_run.sh $SCENE $RESOLUTION $ITERATION
./server_periodic_sorting_run.sh $SCENE $RESOLUTION $ITERATION
./server_background_sorting_run.sh $SCENE $RESOLUTION $ITERATION
./server_hierarchical_sorting_run.sh $SCENE $RESOLUTION $ITERATION

CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
    python $UTILS_PATH/postprocess.py \
    --dataset_path $DATASET_PATH \
    --model_path $MODEL_PATH \
    --output_path $OUTPUT_PATH \
    --figure_idx 19 \
    --device server
