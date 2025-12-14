#!/usr/bin/env bash
set -eo pipefail

git config --global --add safe.directory /workspace

apt update -y
apt upgrade -y

INDEX_URL="https://pypi.jetson-ai-lab.io/jp6/cu126"

# Setup Bash Macros
cat ./macro.sh >>~/.bashrc
source ~/.bashrc

# Install GLM
cd /workspace
mkdir -p temp
cd ./temp
rm -rf glm
git clone --recursive https://github.com/g-truc/glm.git
cd glm
git checkout 5c46b9c

mkdir -p /workspace/src/app/gaussian_splatting/gaussian_splatting_backend/src/gaussian_splatting_backend/third_party
cd /workspace/src/app/gaussian_splatting/gaussian_splatting_backend/src/gaussian_splatting_backend/third_party
rm -rf glm
ln -s /workspace/temp/glm glm

mkdir -p /workspace/src/app/neo_sw/neo_sw_backend/src/neo_sw_backend/third_party
cd /workspace/src/app/neo_sw/neo_sw_backend/src/neo_sw_backend/third_party
rm -rf glm
ln -s /workspace/temp/glm glm

# Install Formatters
pip install ruff --index-url $INDEX_URL
pip install clang-format --index-url $INDEX_URL
pip install shfmt-py --index-url $INDEX_URL
pip install google-yamlfmt --index-url $INDEX_URL

# Install Python Dependencies
cd /workspace
pip install opencv-python --index-url $INDEX_URL
apt install libgl1 -y
pip install plyfile --index-url $INDEX_URL
pip install joblib --index-url $INDEX_URL
pip install matplotlib --index-url $INDEX_URL

# Install Original Gaussian Splatting Packages
cd /workspace/src/app/gaussian_splatting/gaussian_splatting_frontend
pip install -e . --index-url $INDEX_URL

cd /workspace/src/app/gaussian_splatting/gaussian_splatting_backend
pip install -e . --index-url $INDEX_URL

cd /workspace/src/app/neo_sw/neo_sw_frontend
pip install -e . --index-url $INDEX_URL

cd /workspace/src/app/neo_sw/neo_sw_backend
pip install -e . --index-url $INDEX_URL

cd /workspace
pip install -e . --index-url $INDEX_URL

# Download Dataset and Models
cd /workspace/script
./orin_download.sh

# Go to Workspace
cd /workspace
