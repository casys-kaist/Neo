#!/bin/bash

. ../../env.sh

REPOSITORY_PATH=$(git rev-parse --show-toplevel)
OUTPUT_PATH=$OUTPUT_PATH/chapter3_motivation/figure_5
UTILS_PATH=$REPOSITORY_PATH/script/utils

rm -rf $OUTPUT_PATH
mkdir -p $OUTPUT_PATH

generate_target() {
    target="python $UTILS_PATH/run.py \
                --dataset_path $DATASET_PATH \
                --model_path $MODEL_PATH \
                --output_path $OUTPUT_PATH \
                --device orin \
                --resolution $1 \
                --scene family \
                --iteration 3 \
                --algorithm gs \
                --figure_idx 5"
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

for RESOLUTION in "HD" "FHD" "QHD"; do
    target=$(generate_target $RESOLUTION)

    /ncu/ncu \
        --set full \
        --target-processes all \
        -k $kernel_name \
        -f \
        -o $OUTPUT_PATH/orin-$RESOLUTION \
        $target

    /ncu/ncu \
        -i $OUTPUT_PATH/orin-$RESOLUTION.ncu-rep \
        --page raw \
        --csv \
        --metrics "$(
            IFS=','
            echo "${metrics[*]}"
        )" \
        --log-file $OUTPUT_PATH/orin-$RESOLUTION.csv
done

python $UTILS_PATH/postprocess.py \
    --dataset_path $DATASET_PATH \
    --model_path $MODEL_PATH \
    --output_path $OUTPUT_PATH \
    --iteration 3 \
    --figure_idx 5 \
    --device orin
