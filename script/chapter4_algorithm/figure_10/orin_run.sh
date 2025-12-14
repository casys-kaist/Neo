#!/bin/bash

. ../../env.sh

REPOSITORY_PATH=$(git rev-parse --show-toplevel)
OUTPUT_PATH=$OUTPUT_PATH/chapter4_algorithm/figure_10
UTILS_PATH=$REPOSITORY_PATH/script/utils

rm -rf $OUTPUT_PATH
mkdir -p $OUTPUT_PATH

generate_target() {
    if $3; then
        target="python $UTILS_PATH/run.py \
                --dataset_path $DATASET_PATH \
                --model_path $MODEL_PATH \
                --output_path $OUTPUT_PATH \
                --device orin \
                --resolution QHD \
                --scene family \
                --iteration $1 \
                --algorithm $2 \
                --runtime_measurement \
                --figure_idx 10"
        echo $target
    else
        target="python $UTILS_PATH/run.py \
                --dataset_path $DATASET_PATH \
                --model_path $MODEL_PATH \
                --output_path $OUTPUT_PATH \
                --device orin \
                --resolution QHD \
                --scene family \
                --iteration $1 \
                --algorithm $2 \
                --figure_idx 10"
        echo $target
    fi
}

gs_kernel_name='regex:"preprocessCUDA'
gs_kernel_name+="|DeviceScanInitKernel"
gs_kernel_name+="|DeviceScanKernel"
gs_kernel_name+="|duplicateWithKeys"
gs_kernel_name+="|DeviceRadixSortHistogramKernel"
gs_kernel_name+="|DeviceRadixSortExclusiveSumKernel"
gs_kernel_name+="|DeviceRadixSortOnesweepKernel"
gs_kernel_name+="|identifyTileRanges"
gs_kernel_name+='|renderCUDA"'

neo_kernel_name='regex:"preprocessCUDA'
neo_kernel_name+="|preprocess_reuseCUDA"
neo_kernel_name+="|DeviceScanInitKernel"
neo_kernel_name+="|DeviceScanKernel"
neo_kernel_name+="|duplicateWithKeys"
neo_kernel_name+="|duplicateWithKeys_reuse"
neo_kernel_name+="|DeviceRadixSortHistogramKernel"
neo_kernel_name+="|DeviceRadixSortExclusiveSumKernel"
neo_kernel_name+="|DeviceRadixSortOnesweepKernel"
neo_kernel_name+="|identifyTileRanges"
neo_kernel_name+="|optimized_mergingCUDA"
neo_kernel_name+="|renderCUDA"
neo_kernel_name+='|render_reuseCUDA"'

metrics=(
    "gpu__time_duration.avg"
    "lts__d_sectors_fill_sysmem.sum"
    "lts__t_sectors_aperture_sysmem_op_write.sum"
)

for ALGORITHM in "gs" "neo"; do
    if [ "$ALGORITHM" == "gs" ]; then
        kernel_name=$gs_kernel_name
    else
        kernel_name=$neo_kernel_name
    fi

    target=$(generate_target 3 $ALGORITHM)

    /ncu/ncu \
        --set full \
        --target-processes all \
        -k $kernel_name \
        -f \
        -o $OUTPUT_PATH/orin-$ALGORITHM \
        $target

    /ncu/ncu \
        -i $OUTPUT_PATH/orin-$ALGORITHM.ncu-rep \
        --page raw \
        --csv \
        --metrics "$(
            IFS=','
            echo "${metrics[*]}"
        )" \
        --log-file $OUTPUT_PATH/orin-$ALGORITHM.csv

    bash -c "$(generate_target 200 $ALGORITHM)"
done

python $UTILS_PATH/postprocess.py \
    --dataset_path $DATASET_PATH \
    --model_path $MODEL_PATH \
    --output_path $OUTPUT_PATH \
    --iteration 3 \
    --figure_idx 10 \
    --device orin
