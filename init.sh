#!/bin/bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

ENV_FILE="$CUR_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  echo "[Info] Loading environment variables from .env"
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
else
  echo "[Info] No .env file found at $ENV_FILE"
fi

[[ $- == *i* ]] || set -euo pipefail
IFS=$'\n\t'

MODULE_DIR="$CUR_DIR/modules"

# 自动获取所有模块名（去掉 .sh 扩展名）
ALL_MODULES=()
for file in "$MODULE_DIR"/*.sh; do
  [[ -f "$file" ]] || continue
  modname=$(basename "$file" .sh)
  ALL_MODULES+=("$modname")
  echo $"[Info] Found module: $modname"
done

# 加载模块函数
load_module() {
  local mod=$1
  local path="$MODULE_DIR/$mod.sh"
  if [[ -f "$path" ]]; then
    source "$path"
  else
    echo "[Error] Module '$mod' not found in $MODULE_DIR"
    exit 1
  fi
}

# 判断是否指定了 MODULES 环境变量
if [[ -n "${MODULES:-}" ]]; then
  IFS=',' read -ra SELECTED <<< "$MODULES"
  for mod in "${SELECTED[@]}"; do
    load_module "$mod"
  done
else
  # 默认加载全部模块
  for mod in "${ALL_MODULES[@]}"; do
    load_module "$mod"
  done
fi
