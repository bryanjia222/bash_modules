#!/bin/bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
[[ $- == *i* ]] || set -euo pipefail
IFS=$'\n\t'

ENV_FILE="$CUR_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  echo "[Info] Loading environment variables from .env"
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
else
  echo "[Info] No .env file found at $ENV_FILE"
fi

MODULE_DIR="${CUR_DIR}/modules"  # 模块目录
[[ -d "${MODULE_DIR}" ]] || { echo "[Error] Module directory not found: ${MODULE_DIR}" >&2; exit 1; }
declare -gA _MODULE_STATUS  # 模块状态表 (loading/loaded)

# 安全获取所有模块（处理空目录）
ALL_MODULES=()
shopt -s nullglob
for file in "${MODULE_DIR}"/*.sh; do
  modname="$(basename "${file}" .sh)"
  if [[ "${modname}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    ALL_MODULES+=("${modname}")
    echo "[Info] Found valid module: ${modname}"
  else
    echo "[Warn] Invalid module filename: ${file}" >&2
  fi
done
shopt -u nullglob

# 解析 #include 指令的正则表达式
parse_includes() {
  local path="$1"
  local line
  local include_regex='^#[[:space:]]*include[[:space:]]+([a-zA-Z0-9_]+)'

  while IFS= read -r line; do
    # 跳过空行和注释（#开头但不是#include）
    [[ "${line}" =~ ^[[:space:]]*# ]] && ! [[ "${line}" =~ $include_regex ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue

    # 提取依赖模块名
    if [[ "${line}" =~ $include_regex ]]; then
      echo "${BASH_REMATCH[1]}"
    fi
  done < "${path}"
}

load_module() {
  local mod="$1"
  local path="${MODULE_DIR}/${mod}.sh"

  # 状态检查
  case "${_MODULE_STATUS[$mod]:-}" in
    loaded)  return 0 ;;
    loading) echo "[Error] Circular dependency: $mod" >&2; return 1 ;;
  esac

  # 文件存在性检查
  if [[ ! -f "${path}" ]]; then
    echo "[Error] Module '$mod' not found" >&2
    return 1
  fi

  echo "[Info] Loading module: $mod"
  _MODULE_STATUS["$mod"]="loading"

  # 解析依赖项
  local deps=()
  mapfile -t deps < <(parse_includes "${path}")

  # 递归加载依赖
  for dep in "${deps[@]}"; do
    [[ -n "${dep}" ]] || continue
    load_module "${dep}" || return 1
  done

  # 实际加载模块
  if ! source "${path}"; then
    echo "[Error] Failed to source module: $mod" >&2
    _MODULE_STATUS["$mod"]=""  # 重置状态
    return 1
  fi

  _MODULE_STATUS["$mod"]="loaded"
  echo "[Info] Successfully loaded: $mod"
}

# 主加载逻辑
if [[ -n "${MODULES:-}" ]]; then
  IFS=',' read -ra SELECTED <<< "${MODULES}"
  for mod in "${SELECTED[@]}"; do
    mod_clean="${mod//[^a-zA-Z0-9_]/}"  # 清理非法字符
    [[ "${mod}" == "${mod_clean}" ]] || echo "[Warn] Sanitized module name: ${mod} → ${mod_clean}"
    load_module "${mod_clean}" || exit 1
  done
else
  for mod in "${ALL_MODULES[@]}"; do
    load_module "${mod}" || exit 1
  done
fi
