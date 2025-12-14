#!/bin/bash

. ../../env.sh

source /workspace/.venv/bin/activate

REPOSITORY_PATH=$(git rev-parse --show-toplevel)
UTILS_PATH=$REPOSITORY_PATH/script/utils
OUTPUT_PATH=$OUTPUT_PATH/chapter6_evaluation/table_2

rm -rf $OUTPUT_PATH/reuse-true
mkdir -p $OUTPUT_PATH/reuse-true

rm -rf $OUTPUT_PATH/reuse-false
mkdir -p $OUTPUT_PATH/reuse-false

for SCENE in "family" "francis" "horse" "lighthouse" "playground" "train"; do
    RESOLUTION="QHD"

    for REUSE_MODE in true false; do
        CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
            python $UTILS_PATH/generate_trace_yaml.py \
            --chunk_size 256 \
            --tile_size 64 \
            --subtile_size 8 \
            --resolution $RESOLUTION \
            --frame_start_idx 0 \
            --frame_end_idx 150 \
            --frame_step 1 \
            --output_path $OUTPUT_PATH/reuse-$REUSE_MODE/neo/$SCENE/$RESOLUTION \
            --image_mode \
            $([ "$REUSE_MODE" = true ] && echo "--reuse_mode")

        CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
            python $UTILS_PATH/run.py \
            --dataset_path $DATASET_PATH \
            --model_path $MODEL_PATH \
            --yaml_path $OUTPUT_PATH/reuse-$REUSE_MODE/neo/$SCENE/$RESOLUTION/trace.yaml \
            --output_path $OUTPUT_PATH/reuse-$REUSE_MODE \
            --device neo \
            --resolution $RESOLUTION \
            --scene $SCENE \
            --iteration 150 \
            --algorithm neo \
            --figure_idx 1002
    done
done

CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
    python $UTILS_PATH/postprocess.py \
    --dataset_path $DATASET_PATH \
    --model_path $MODEL_PATH \
    --output_path $OUTPUT_PATH \
    --figure_idx 1002 \
    --device server
