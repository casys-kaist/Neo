#!/bin/bash

. ../../env.sh

source /workspace/.venv/bin/activate

REPOSITORY_PATH=$(git rev-parse --show-toplevel)
SIMULATOR_PATH=$REPOSITORY_PATH/src/simulator/neo
UTILS_PATH=$REPOSITORY_PATH/script/utils

OUTPUT_PATH=$OUTPUT_PATH/chapter6_evaluation/figure_17
rm -rf $OUTPUT_PATH
mkdir -p $OUTPUT_PATH

ITERATION=20

MAX_CORE=32
RUN_CORE=0

for SCENE in "rubble" "building"; do
    case $SCENE in
    building) FRAME_START_IDX=190 ;;
    rubble) FRAME_START_IDX=0 ;;
    *) FRAME_START_IDX=0 ;;
    esac

    FRAME_END_IDX=$((FRAME_START_IDX + ITERATION))

    CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
        python $UTILS_PATH/generate_trace_yaml.py \
        --chunk_size 256 \
        --tile_size 64 \
        --subtile_size 8 \
        --resolution QHD \
        --frame_start_idx $FRAME_START_IDX \
        --frame_end_idx $FRAME_END_IDX \
        --frame_step 1 \
        --output_path $OUTPUT_PATH/A/neo/$SCENE/QHD \
        --reuse_mode \
        --trace_mode

    CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
        python $UTILS_PATH/run.py \
        --dataset_path $DATASET_PATH \
        --model_path $MODEL_PATH \
        --yaml_path $OUTPUT_PATH/A/neo/$SCENE/QHD/trace.yaml \
        --output_path $OUTPUT_PATH/A \
        --device neo \
        --resolution QHD \
        --scene $SCENE \
        --iteration $ITERATION \
        --algorithm neo \
        --figure_idx 170

    for ((i = 1; i < $ITERATION; i++)); do
        if [ $RUN_CORE -ge $MAX_CORE ]; then
            wait
            RUN_CORE=0
        fi
        RUN_CORE=$((RUN_CORE + 1))

        CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
            python $UTILS_PATH/generate_simulator_yaml.py \
            --dram_path $REPOSITORY_PATH/src/simulator/neo/config/dram/LPDDR4-4CH.cfg \
            --trace_path $OUTPUT_PATH/A/neo/$SCENE/QHD/trace/$i \
            --chunk_size 256 \
            --tile_size 64 \
            --output_path $OUTPUT_PATH/A/neo/$SCENE/QHD/trace/$i

        cd $OUTPUT_PATH/A/neo/$SCENE/QHD/trace/$i
        ln -s $SIMULATOR_PATH/build/sim ./sim
        ./sim -f ./simulator.yaml >sim.log &
    done

    wait
done

ITERATION=16
FRAME_START_IDX=0

RUN_CORE=0

for FRAME_STEP in 1 2 4 8 16; do
    FRAME_END_IDX=$((FRAME_START_IDX + ITERATION * FRAME_STEP))

    CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
        python $UTILS_PATH/generate_trace_yaml.py \
        --chunk_size 256 \
        --tile_size 64 \
        --subtile_size 8 \
        --resolution QHD \
        --frame_start_idx $FRAME_START_IDX \
        --frame_end_idx $FRAME_END_IDX \
        --frame_step $FRAME_STEP \
        --output_path $OUTPUT_PATH/B/step-$FRAME_STEP/neo/family/QHD \
        --reuse_mode \
        --trace_mode

    CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
        python $UTILS_PATH/run.py \
        --dataset_path $DATASET_PATH \
        --model_path $MODEL_PATH \
        --yaml_path $OUTPUT_PATH/B/step-$FRAME_STEP/neo/family/QHD/trace.yaml \
        --output_path $OUTPUT_PATH/B/step-$FRAME_STEP \
        --device neo \
        --resolution QHD \
        --scene family \
        --iteration $ITERATION \
        --algorithm neo \
        --figure_idx 171

    for ((i = 1; i < $ITERATION; i++)); do
        if [ $RUN_CORE -ge $MAX_CORE ]; then
            wait
            RUN_CORE=0
        fi
        RUN_CORE=$((RUN_CORE + 1))

        CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
            python $UTILS_PATH/generate_simulator_yaml.py \
            --dram_path $REPOSITORY_PATH/src/simulator/neo/config/dram/LPDDR4-4CH.cfg \
            --trace_path $OUTPUT_PATH/B/step-$FRAME_STEP/neo/family/QHD/trace/$i \
            --chunk_size 256 \
            --tile_size 64 \
            --output_path $OUTPUT_PATH/B/step-$FRAME_STEP/neo/family/QHD/trace/$i

        cd $OUTPUT_PATH/B/step-$FRAME_STEP/neo/family/QHD/trace/$i
        ln -s $SIMULATOR_PATH/build/sim ./sim
        ./sim -f ./simulator.yaml >sim.log &
    done

    wait
done

CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
    python $UTILS_PATH/postprocess.py \
    --dataset_path $DATASET_PATH \
    --model_path $MODEL_PATH \
    --output_path $OUTPUT_PATH \
    --figure_idx 17 \
    --device server
