#!/bin/bash

. ../../env.sh

source /workspace/.venv/bin/activate

REPOSITORY_PATH=$(git rev-parse --show-toplevel)
SIMULATOR_PATH=$REPOSITORY_PATH/src/simulator
UTILS_PATH=$REPOSITORY_PATH/script/utils
OUTPUT_PATH=$OUTPUT_PATH/chapter6_evaluation/figure_19

SCENE=$1
RESOLUTION=$2
ITERATION=$3

MAX_CORE=32
RUN_CORE=0

CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
    python $UTILS_PATH/generate_trace_yaml.py \
    --chunk_size 256 \
    --tile_size 64 \
    --subtile_size 8 \
    --resolution $RESOLUTION \
    --frame_start_idx 0 \
    --frame_end_idx $ITERATION \
    --frame_step 1 \
    --output_path $OUTPUT_PATH/neo/$SCENE/$RESOLUTION \
    --reuse_mode \
    --trace_mode \
    --image_mode

CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
    python $UTILS_PATH/run.py \
    --dataset_path $DATASET_PATH \
    --model_path $MODEL_PATH \
    --yaml_path $OUTPUT_PATH/neo/$SCENE/$RESOLUTION/trace.yaml \
    --output_path $OUTPUT_PATH \
    --device neo \
    --resolution $RESOLUTION \
    --scene $SCENE \
    --iteration $ITERATION \
    --algorithm neo \
    --figure_idx 19

for ((i = 1; i < $ITERATION; i++)); do
    if [ $RUN_CORE -ge $MAX_CORE ]; then
        wait
        RUN_CORE=0
    fi
    RUN_CORE=$((RUN_CORE + 1))

    CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
        python $UTILS_PATH/generate_simulator_yaml.py \
        --dram_path $REPOSITORY_PATH/src/simulator/neo/config/dram/LPDDR4-4CH.cfg \
        --trace_path $OUTPUT_PATH/neo/$SCENE/$RESOLUTION/trace/$i \
        --chunk_size 256 \
        --tile_size 64 \
        --output_path $OUTPUT_PATH/neo/$SCENE/$RESOLUTION/trace/$i

    cd $OUTPUT_PATH/neo/$SCENE/$RESOLUTION/trace/$i
    ln -s $SIMULATOR_PATH/neo/build/sim ./sim
    ./sim -f ./simulator.yaml >sim.log &
done
wait
