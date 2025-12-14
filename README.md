# Neo: Real-Time On-Device 3D Gaussian Splatting with Reuse-and-Update Sorting Acceleration

This repository contains the performance simulator and accuracy evaluation code developed for the Neo project, accepted at ASPLOS'26. The steps below rebuild both evaluation environments, rerun the experiments, and regenerate the figures needed for artifact evaluation.

## Table of Contents

- [1. Hardware Requirements](#1-hardware-requirements)
- [2. Build the Environments](#2-build-the-environments)
  - [2.1. NVIDIA Jetson Orin AGX](#21-nvidia-jetson-orin-agx)
    - [A. Set Up the Environment](#a-set-up-the-environment)
    - [B. Build the Docker Image](#b-build-the-docker-image)
    - [C. Initialize the Container](#c-initialize-the-container)
    - [D. Download Datasets and Models](#d-download-datasets-and-models)
  - [2.2. NVIDIA RTX Server](#22-nvidia-rtx-server)
    - [A. Set Up the Environment](#a-set-up-the-environment-1)
    - [B. Build the Docker Image](#b-build-the-docker-image-1)
    - [C. Initialize the Container](#c-initialize-the-container-1)
    - [D. Download Datasets and Models](#d-download-datasets-and-models-1)
- [3. Reproducing Results](#3-reproducing-results)
  - [3.1. NVIDIA Jetson Orin AGX](#31-nvidia-jetson-orin-agx)
    - [A. Run All Experiments](#a-run-all-experiments)
    - [B. Running Individual Experiments](#b-running-individual-experiments)
  - [3.2. NVIDIA RTX Server](#32-nvidia-rtx-server)
    - [A. Run All Experiments](#a-run-all-experiments-1)
    - [B. Running Individual Experiments](#b-running-individual-experiments-1)
- [4. Generate Figures](#4-generate-figures)
  - [4.1. Package Results](#41-package-results)
    - [A. Compressing Orin Results](#a-compressing-orin-results)
    - [B. Transfer Orin Results to RTX Server](#b-transfer-orin-results-to-rtx-server)
    - [C. Compressing RTX Results](#c-compressing-rtx-results)
  - [4.2. Generating Figures](#42-generating-figures)

## 1. Hardware Requirements
- ```GPU```
  - We evaluate 3DGS on the ```NVIDIA Jetson Orin AGX```, representing an edge-class deployment device.
  - We simulate Neo on an ```NVIDIA RTX 3090```, but any recent GPU with CUDA support should work.
- ```Storage```
  - At least ```100GB``` of available storage to accommodate model weights, datasets, and generated outputs.

## 2. Build the Environments

We require two separate build environments, and you can build each one using the provided commands.

### 2.1. NVIDIA Jetson Orin AGX

Environment for evaluating 3DGS performance on an edge-class device.

#### A. Set Up the Environment

```bash
cd {REPOSITORY}/env
vim ./orin_env.sh
```

In orin_env.sh, replace placeholders with the appropriate absolute paths:

```bash
NSYS_PATH={PLACEHOLDER}      # Path to Nsight Systems
NCU_PATH={PLACEHOLDER}       # Path to Nsight Compute
STORAGE_PATH={PLACEHOLDER}   # Path to storage directory
```

#### B. Build the Docker Image

```bash
cd {REPOSITORY}/docker/orin
./build.sh
./run.sh
```

#### C. Initialize the Container

Enter the container built in step B, then run:

```bash
cd /workspace/docker/orin
. ./init.sh
```

#### D. Download Datasets and Models

The init.sh script downloads datasets and models automatically. If any download fails, rerun the helper script directly:

```bash
cd /workspace/script
./orin_download.sh
```

### 2.2. NVIDIA RTX Server

Environment for evaluating Neo and its variants on an RTX-class GPU. The container mirrors the software stack used for the paper’s server-side experiments.

#### A. Set Up the Environment

```bash
cd {REPOSITORY}/env
vim ./server_env.sh
```

In server_env.sh, replace placeholders with the appropriate absolute paths:

```bash
NSYS_PATH={PLACEHOLDER}      # Path to Nsight Systems
NCU_PATH={PLACEHOLDER}       # Path to Nsight Compute
STORAGE_PATH={PLACEHOLDER}   # Path to storage directory
```

#### B. Build the Docker Image

```bash
cd {REPOSITORY}/docker/server
./build.sh
./run.sh
```

#### C. Initialize the Container

Enter the container built in step B, then run:

```bash
cd /workspace/docker/server
. ./init.sh
```

#### D. Download Datasets and Models

The init.sh script downloads datasets and models automatically. If any download fails, rerun the helper script directly:

```bash
cd /workspace/script
./server_download.sh
```

## 3. Reproducing Results

Use the Orin and RTX environments to execute the profiling and accuracy experiments described in the paper. Each run produces logs and result files under ```/mnt/output``` (inside the container).

### 3.1. NVIDIA Jetson Orin AGX

#### A. Run All Experiments

Run every Orin experiment end-to-end, including profiling:

```bash
cd /workspace/script
./orin_run.sh
```

#### B. Running Individual Experiments

You can also reproduce each experiment independently. Each figure directory contains the exact scripts and configs used for that plot or table.

For example, to reproduce **Figure 15** from the Orin results:

```bash
cd /workspace/script/chapter6_evaluation/figure_15
./orin_run.sh
```

### 3.2. NVIDIA RTX Server

#### A. Run All Experiments

Run every RTX/server experiment end-to-end, including profiling and accuracy sweeps:

```bash
cd /workspace/script
./server_run.sh
```

#### B. Running Individual Experiments

You can also reproduce each experiment independently. Each figure directory contains the exact scripts and configs used for that plot or table.

For example, to reproduce **Figure 15** from the server-side experiments (non-Orin):

```bash
cd /workspace/script/chapter6_evaluation/figure_15
./server_run.sh
```

## 4. Generate Figures

Collect results from both environments, then render each figure. The drawing step expects Orin and RTX archives in the paths noted below.

### 4.1. Package Results

#### A. Compressing Orin Results

```bash
cd /workspace/script
./orin_zip.sh
```

#### B. Transfer Orin Results to RTX Server

After finishing step A, you get ```orin.tar``` at ```/mnt/output/orin.tar```. Copy this file into the RTX server environment (to the same path) so the figure-generation step can find the Orin results.

#### C. Compressing RTX Results

```bash
cd /workspace/script
./server_zip.sh
```

### 4.2. Generating Figures

```bash
cd /workspace/script
./draw.sh
```

After running draw.sh, the expected output directory is written to ```/mnt/output/summary``` with this structure:

```
summary
   ├─ Figure 5
   │     ├─ figure_5_3dgs.pdf
   │     └─ figure_5_gscore.pdf
   ├─ Figure 10
   │     ├─ figure_10_memory.pdf
   │     └─ figure_10_runtime.pdf
   ├─ Figure 15
   │     └─ figure_15.pdf
   ├─ Figure 16
   │     └─ figure_16.pdf
   ├─ Figure 17
   │     ├─ figure_17_large_scale_scene.pdf
   │     └─ figure_17_rapid_camera_movement.pdf
   ├─ Figure 18
   │     ├─ figure_18_runtime.pdf
   │     └─ figure_18_traffic.pdf
   ├─ Figure 19
   │     ├─ figure_19_accuracy.pdf
   │     └─ figure_19_latency.pdf
   └─ Table 2
         └─ table_2.csv
```
