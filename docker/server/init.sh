#!/bin/env bash
set -eo pipefail

git config --global --add safe.directory /workspace

apt update -y
apt upgrade -y

# Setup Bash Macros
cat ./macro.sh >>~/.bashrc

# Install uv
if command -v uv >/dev/null 2>&1; then
    echo "uv is already installed: $(command -v uv)"
else
    export UV_INSTALL_DIR="${HOME}/.local/bin"
    mkdir -p "${UV_INSTALL_DIR}"
    if command -v wget >/dev/null 2>&1; then
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        echo "wget not found. Install wget or curl and retry." >&2
        exit 1
    fi
fi

if ! echo ":$PATH:" | grep -q ":${HOME}/.local/bin:"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >>"${HOME}/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >>"${HOME}/.profile"
fi

source "${HOME}/.bashrc"

echo "uv version: $(uv --version)"

# Install GLM
cd /workspace
mkdir -p temp
cd ./temp
rm -rf glm
git clone --recursive https://github.com/g-truc/glm.git
cd glm
git checkout 5c46b9c

mkdir -p /workspace/src/trace/neo_trace/neo_trace_backend/src/neo_trace_backend/third_party
cd /workspace/src/trace/neo_trace/neo_trace_backend/src/neo_trace_backend/third_party
rm -rf glm
ln -s /workspace/temp/glm glm

mkdir -p /workspace/src/trace/neo_trace/periodic_sorting_trace_backend/src/periodic_sorting_trace_backend/third_party
cd /workspace/src/trace/neo_trace/periodic_sorting_trace_backend/src/periodic_sorting_trace_backend/third_party
rm -rf glm
ln -s /workspace/temp/glm glm

# Install Neo dependencies
cd /workspace
uv sync --group neo
apt install libgl1 -y
apt install libgl1-mesa-glx -y
apt install libglib2.0-0 -y

# Build Neo
mkdir -p /workspace/src/simulator/neo/build
cd /workspace/src/simulator/neo/build
uv run cmake .. -DCMAKE_BUILD_TYPE=Release
uv run cmake --build . --config Release -- -j$(nproc)

# Build Neo_S
mkdir -p /workspace/src/simulator/neo_s/build
cd /workspace/src/simulator/neo_s/build
uv run cmake .. -DCMAKE_BUILD_TYPE=Release
uv run cmake --build . --config Release -- -j$(nproc)

# Build Neo_HS
mkdir -p /workspace/src/simulator/neo_hs/build
cd /workspace/src/simulator/neo_hs/build
uv run cmake .. -DCMAKE_BUILD_TYPE=Release
uv run cmake --build . --config Release -- -j$(nproc)

# Build Neo_Only_S
mkdir -p /workspace/src/simulator/neo_only_s/build
cd /workspace/src/simulator/neo_only_s/build
uv run cmake .. -DCMAKE_BUILD_TYPE=Release
uv run cmake --build . --config Release -- -j$(nproc)

# PDF generation dependencies
apt install -y texlive-extra-utils

# Download Dataset and Models
cd /workspace/script
./server_download.sh

# Go to Workspace
cd /workspace
