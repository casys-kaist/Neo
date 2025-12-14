#!/bin/bash
set -eo pipefail

. ../../env/server_env.sh

IMAGE=neo-ae
TAG=latest
NAME=neo-ae-container
ROOT_PATH="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

docker run -dit \
    --name=${NAME} \
    -v ${ROOT_PATH}:/workspace \
    -v ${NSYS_PATH}:/nsys \
    -v ${NCU_PATH}:/ncu \
    -v ${STORAGE_PATH}:/mnt \
    --ulimit core=-1 \
    --privileged \
    --gpus all \
    --runtime nvidia \
    --net host \
    --ipc host \
    --cap-add=SYS_ADMIN \
    --security-opt seccomp=unconfined \
    ${IMAGE}:${TAG} /bin/bash
