#!/bin/bash

source /workspace/.venv/bin/activate

cd /mnt
gdown --continue --folder "https://drive.google.com/drive/folders/1mUzsvWb_Z1KXMZGqM3z8ycKECcDYBzH3" # Datasets
gdown --continue --folder "https://drive.google.com/drive/folders/1LwQ0unXLBi-sQItYvJJdrvPwZfB-zvg4" # Models

for scene in "building" "rubble" "family" "francis" "horse" "lighthouse" "playground" "train"; do
    cd /mnt/dataset
    rm -rf $scene
    tar -xvf $scene.tar

    cd /mnt/model
    rm -rf $scene
    tar -xvf $scene.tar
done
