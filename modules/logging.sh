#!/usr/bin/env bash

# === 初始化脚本名称 ===
declare -g SCRIPT_NAME="$(basename "$0")"

# === 默认日志级别（可通过环境变量覆盖） ===
: "${LOG_LEVEL:=INFO}"

declare -gA LOG_LEVELS=(
  [OFF]=-1
  [ERROR]=0
  [WARN]=1
  [INFO]=2
  [DEBUG]=3
)

# === 日志函数 ===
log::_log() {
  local level=$1
  shift

  # 判断是否输出该日志级别
  local level_num="${LOG_LEVELS[$level]}"
  local config_level_num="${LOG_LEVELS[$LOG_LEVEL]}"
  if [[ -z "$level_num" || -z "$config_level_num" || $level_num -gt $config_level_num ]]; then
    return
  fi

  local timestamp
  timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")
  local log_line="[$timestamp] [$SCRIPT_NAME] [$level] $*"

  # 终端颜色处理
  if [[ -t 2 ]]; then
    local color_code
    case "$level" in
      DEBUG) color_code="\033[0;36m" ;; # 青色
      INFO)  color_code="\033[1;32m" ;;
      WARN)  color_code="\033[1;33m" ;;
      ERROR) color_code="\033[1;31m" ;;
      *)     color_code="" ;;
    esac
    echo -e "[${color_code}${level}\033[0m] ${timestamp}  $*" >&2
  else
    echo "[$level]  $*" >&2
  fi

  # 文件日志记录（无颜色）
  if [[ -n "${LOG_PATH:-}" ]]; then
    mkdir -p "$(dirname "$LOG_PATH")" 2>/dev/null || true
    echo "$log_line" >> "$LOG_PATH" 2>/dev/null || {
      echo "[ERROR] Unable to write log: $LOG_PATH" >&2
    }
  fi
}

# === 封装函数 ===
log::debug() { log::_log "DEBUG" "$@"; }
log::info()  { log::_log "INFO"  "$@"; }
log::warn()  { log::_log "WARN"  "$@"; }
log::error() { log::_log "ERROR" "$@"; }
log::die() {
  log::error "$1"
  exit "${2:-1}"
}
