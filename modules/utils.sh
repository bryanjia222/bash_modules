#! /bin/bash


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
