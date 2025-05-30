#!/usr/bin/env bash

#include logging
#include proxy

# === 安全 Trap 管理 ===
trap_add() {
  local cmd="$1"
  local sig="${2:-EXIT}"
  local old_cmd="$(trap -p "$sig" | sed -E "s/^trap -- '(.*)' .*$/\1/")"
  [[ -n "$old_cmd" ]] && cmd="${old_cmd}; ${cmd}"
  trap "$cmd" "$sig"
}

# === 临时目录创建（自动清理） ===
create_tmpdir() {
  local prefix="${1:-tmp}"
  local template="${TMPDIR:-/tmp}/${prefix}.XXXXXX"
  local tmp_dir
  tmp_dir=$(mktemp -d "$template" || die "Failed to create temp dir")
  trap_add "rm -rf '$tmp_dir'" EXIT
  echo "$tmp_dir"
}

sc_send() {
    local text="$1"
    local desp="$2"
    if [[ -z "$SERVER_CHAN_KEY" ]]; then
        log::warn "SERVER_CHAN_KEY is not set."
        return 1
    fi
    local key=$SERVER_CHAN_KEY

    postdata="text=$text&desp=$desp"
    opts=(
        "--header" "Content-type: application/x-www-form-urlencoded"
        "--data" "$postdata"
    )
  response=$(curl --noproxy '*' -X POST -s -w "\n%{http_code}" "https://sctapi.ftqq.com/${key}.send" "${opts[@]}")
  http_body=$(echo "$response" | sed '$d')     
  http_code=$(echo "$response" | tail -n1)  

  if [[ "$http_code" -ne 200 ]]; then
      log::warn "Failed to send message via ServerChan. HTTP status: $http_code, Response: $http_body"
      return 1
  fi
  log::debug "Message sent successfully via ServerChan. Response: $http_body"

}
