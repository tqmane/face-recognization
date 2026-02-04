#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO_ROOT="$(cd "${APP_ROOT}/.." && pwd)"

TF_SRC="${TENSORFLOW_SOURCE_DIR:-${TF_SOURCE_DIR:-"${REPO_ROOT}/../tensorflow_src"}}"
BUILD_DIR="${BUILD_DIR:-"${REPO_ROOT}/../tflite_build_c_linux"}"

if [[ ! -d "${TF_SRC}" ]]; then
  echo "TensorFlowソースが見つかりません: ${TF_SRC}" >&2
  echo "環境変数 TENSORFLOW_SOURCE_DIR で tensorflow checkout のパスを指定してください。" >&2
  exit 1
fi

mkdir -p "${BUILD_DIR}"

cmake -S "${TF_SRC}/tensorflow/lite/c" -B "${BUILD_DIR}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DTFLITE_C_BUILD_SHARED_LIBS=ON \
  -DTF_SOURCE_DIR="${TF_SRC}" \
  -DTENSORFLOW_SOURCE_DIR="${TF_SRC}"

cmake --build "${BUILD_DIR}" --target tensorflowlite_c -- -j"$(nproc)"

OUT_SO="${BUILD_DIR}/libtensorflowlite_c.so"
if [[ ! -f "${OUT_SO}" ]]; then
  # CMake generatorによってはサブディレクトリに出ることがある
  OUT_SO="$(find "${BUILD_DIR}" -maxdepth 3 -name 'libtensorflowlite_c.so' -print -quit)"
fi

if [[ -z "${OUT_SO}" || ! -f "${OUT_SO}" ]]; then
  echo "ビルド成果物 libtensorflowlite_c.so が見つかりません (BUILD_DIR=${BUILD_DIR})" >&2
  exit 1
fi

mkdir -p "${APP_ROOT}/blobs"
cp -f "${OUT_SO}" "${APP_ROOT}/blobs/libtensorflowlite_c-linux.so"

echo "OK: ${APP_ROOT}/blobs/libtensorflowlite_c-linux.so を更新しました"