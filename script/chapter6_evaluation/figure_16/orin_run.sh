#!/bin/bash

. ../../env.sh

REPOSITORY_PATH=$(git rev-parse --show-toplevel)
OUTPUT_PATH=$OUTPUT_PATH/chapter6_evaluation/figure_16
UTILS_PATH=$REPOSITORY_PATH/script/utils

rm -rf $OUTPUT_PATH
mkdir -p $OUTPUT_PATH

generate_target() {
    target="python $UTILS_PATH/run.py \
                --dataset_path $DATASET_PATH \
                --model_path $MODEL_PATH \
                --output_path $OUTPUT_PATH \
                --device orin \
                --resolution QHD \
                --scene $1 \
                --iteration 3 \
                --algorithm gs \
                --runtime_measurement \
                --figure_idx 16"
    echo $target
}

kernel_name='regex:"preprocessCUDA'
kernel_name+="|DeviceScanInitKernel"
kernel_name+="|DeviceScanKernel"
kernel_name+="|duplicateWithKeys"
kernel_name+="|DeviceRadixSortHistogramKernel"
kernel_name+="|DeviceRadixSortExclusiveSumKernel"
kernel_name+="|DeviceRadixSortOnesweepKernel"
kernel_name+="|identifyTileRanges"
kernel_name+='|renderCUDA"'

metrics=(
    "lts__d_sectors_fill_sysmem.sum"
    "lts__t_sectors_aperture_sysmem_op_write.sum"
)

for SCENE in "family" "francis" "horse" "lighthouse" "playground" "train"; do
    target=$(generate_target $SCENE)

    /ncu/ncu \
        --set full \
        --target-processes all \
        -k $kernel_name \
        -f \
        -o $OUTPUT_PATH/orin-gs-$SCENE-QHD \
        $target

    /ncu/ncu \
        -i $OUTPUT_PATH/orin-gs-$SCENE-QHD.ncu-rep \
        --page raw \
        --csv \
        --metrics "$(
            IFS=','
            echo "${metrics[*]}"
        )" \
        --log-file $OUTPUT_PATH/orin-gs-$SCENE-QHD.csv
done

python $UTILS_PATH/postprocess.py \
    --dataset_path $DATASET_PATH \
    --model_path $MODEL_PATH \
    --output_path $OUTPUT_PATH \
    --iteration 3 \
    --figure_idx 16 \
    --device orin
