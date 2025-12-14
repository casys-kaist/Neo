#!/bin/bash

. ../../env.sh

source /workspace/.venv/bin/activate

SCRIPT_PATH=$(pwd)
REPOSITORY_PATH=$(git rev-parse --show-toplevel)
SIMULATOR_PATH=$REPOSITORY_PATH/src/simulator
UTILS_PATH=$REPOSITORY_PATH/script/utils

OUTPUT_PATH=$OUTPUT_PATH/chapter6_evaluation/figure_18
rm -rf $OUTPUT_PATH
mkdir -p $OUTPUT_PATH

if [ ! -d $OUTPUT_PATH/../figure_17 ]; then
    echo "Figure 17 data not found. Generating Figure 17 data first..."
    cd ../figure_17
    ./server_run.sh
    cd $SCRIPT_PATH
else
    echo "Figure 17 data found. Skipping Figure 17 data generation."
fi

DEVICE=neo_s
SCENE=family
RESOLUTION=QHD

CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
    python $UTILS_PATH/generate_trace_yaml.py \
    --chunk_size 256 \
    --tile_size 64 \
    --subtile_size 8 \
    --resolution $RESOLUTION \
    --frame_start_idx 0 \
    --frame_end_idx 16 \
    --frame_step 1 \
    --output_path $OUTPUT_PATH/$DEVICE/$SCENE/$RESOLUTION \
    --reuse_mode \
    --trace_mode

CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
    python $UTILS_PATH/run.py \
    --dataset_path $DATASET_PATH \
    --model_path $MODEL_PATH \
    --yaml_path $OUTPUT_PATH/$DEVICE/$SCENE/$RESOLUTION/trace.yaml \
    --output_path $OUTPUT_PATH \
    --device $DEVICE \
    --resolution $RESOLUTION \
    --scene $SCENE \
    --iteration 16 \
    --algorithm neo \
    --figure_idx 18

MAX_CORE=32
RUN_CORE=0

for ((i = 1; i < 16; i++)); do
    if [ $RUN_CORE -ge $MAX_CORE ]; then
        wait
        RUN_CORE=0
    fi
    RUN_CORE=$((RUN_CORE + 1))

    CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
        python $UTILS_PATH/generate_simulator_yaml.py \
        --dram_path $SIMULATOR_PATH/$DEVICE/config/dram/LPDDR4-4CH.cfg \
        --trace_path $OUTPUT_PATH/$DEVICE/$SCENE/$RESOLUTION/trace/$i \
        --chunk_size 256 \
        --tile_size 64 \
        --output_path $OUTPUT_PATH/$DEVICE/$SCENE/$RESOLUTION/trace/$i

    cd $OUTPUT_PATH/$DEVICE/$SCENE/$RESOLUTION/trace/$i
    ln -s $SIMULATOR_PATH/neo_s/build/sim ./sim
    ./sim -f ./simulator.yaml >sim.log &
done

wait

CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
    python $UTILS_PATH/postprocess.py \
    --dataset_path $DATASET_PATH \
    --model_path $MODEL_PATH \
    --output_path $OUTPUT_PATH \
    --figure_idx 18 \
    --device server
