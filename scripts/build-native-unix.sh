#!/usr/bin/env bash
# This script should be run from the repository root
 
# Default number of jobs
NUM_JOBS_MAKE=8
 
# Parse command line options
while getopts "j:" opt; do
  case $opt in
    j)
      NUM_JOBS_MAKE=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done
 
# CUDA layout: conda-forge places headers/libs under targets/x86_64-linux
export CUDA_HOME="${CONDA_PREFIX}"
CUDA_TARGETS="${CONDA_PREFIX}/targets/x86_64-linux"
CUDA_INCLUDE="${CUDA_TARGETS}/include"
 
# nvcc invokes the host compiler with -include cuda_runtime.h but doesn't
# add -I for its own include dir in the conda split layout. CPATH makes the
# host compiler find it regardless of how nvcc constructs its invocation.
export CPATH="${CUDA_INCLUDE}:${CPATH}"
TORCH_CMAKE_PREFIX="$(python -c 'import torch;print(torch.utils.cmake_prefix_path)')"
 
# Flags only needed for LibTorchSharp, to work around Caffe2's legacy cmake
# CUDA detection. NativeAcceleration uses modern cmake and finds CUDA on its
# own via the conda nvcc wrapper -- do not add these flags there.
LIBTORCH_CUDA_FLAGS=(
  -DCMAKE_CUDA_COMPILER="${CONDA_PREFIX}/bin/nvcc"
  -DCUDA_NVCC_EXECUTABLE:FILEPATH="${CONDA_PREFIX}/bin/nvcc"
  -DCUDA_TOOLKIT_ROOT_DIR:PATH="${CUDA_TARGETS}"
  -DCUDA_INCLUDE_DIRS:PATH="${CUDA_INCLUDE}"
  -DCUDAToolkit_ROOT="${CONDA_PREFIX}"
  -DCUDAToolkit_INCLUDE_DIR:PATH="${CUDA_INCLUDE}"
  -Dnvtx3_dir="${CUDA_INCLUDE}/nvtx3"
  -Wno-dev
)
 
set -e
 
cd NativeAcceleration
rm -rf build
mkdir build
cd build
cmake \
  -DCMAKE_PREFIX_PATH="${CONDA_PREFIX}" \
  ..
make -j "${NUM_JOBS_MAKE}"
cd ../..
 
# LibTorchSharp uses an in-source build (cmake writes Makefiles into the
# source tree). Do not use a separate build subdirectory.
cd LibTorchSharp
cmake . \
  -DCMAKE_PREFIX_PATH="${TORCH_CMAKE_PREFIX};${CONDA_PREFIX}" \
  "${LIBTORCH_CUDA_FLAGS[@]}"
make -j "${NUM_JOBS_MAKE}"
cd ..
 
mkdir -p Release/linux-x64/publish
cp NativeAcceleration/build/lib/libNativeAcceleration.so Release/linux-x64/publish/
cp LibTorchSharp/LibTorchSharp/libLibTorchSharp.so Release/linux-x64/publish/

