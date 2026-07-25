#!/usr/bin/env bash
# Staddress CLI — `config` サブコマンド（設定ファイルの管理）

cmd_config_help() {
  cat <<'EOF'
使い方: staddress config <サブコマンド>

設定ファイル (~/.config/staddress/config) を管理します。

サブコマンド:
  set api-key <key>     API キーを保存
  set base-url <url>    ベース URL を保存
  set timeout <sec>     リクエストタイムアウト（秒）を保存
  show                  現在の設定を表示（API キーはマスク）
  path                  設定ファイルのパスを表示
  -h, --help            このヘルプを表示

例:
  staddress config set api-key sk_xxx
  staddress config set base-url https://api.staddress.com
  staddress config show
EOF
}

# キー名（api-key / base-url / timeout）を設定ファイルのキーに変換
staddress_config_map_key() {
  case "$1" in
    api-key|api_key)   echo "api_key" ;;
    base-url|base_url) echo "base_url" ;;
    timeout)           echo "timeout" ;;
    *)                 return 1 ;;
  esac
}

staddress_mask_key() {
  local key="$1"
  local len="${#key}"
  if [[ "${len}" -le 8 ]]; then
    printf '%s' "********"
  else
    printf '%s****%s' "${key:0:4}" "${key: -4}"
  fi
}

cmd_config() {
  local sub="${1:-}"
  case "${sub}" in
    -h|--help|"")
      cmd_config_help
      return 0
      ;;
    set)
      shift
      local raw_key="${1:-}" value="${2:-}"
      if [[ -z "${raw_key}" || -z "${value}" ]]; then
        staddress_die "${EXIT_CONFIG_ERROR}" "使い方: staddress config set <api-key|base-url|timeout> <値>"
      fi
      local mapped
      if ! mapped="$(staddress_config_map_key "${raw_key}")"; then
        staddress_die "${EXIT_CONFIG_ERROR}" "config set: 不明なキー: ${raw_key}（api-key / base-url / timeout）"
      fi
      staddress_config_set "${mapped}" "${value}"
      echo "設定を保存しました: ${raw_key} → $(staddress_config_path)"
      ;;
    show)
      local file api_key base_url timeout
      file="$(staddress_config_path)"
      if [[ ! -f "${file}" ]]; then
        echo "設定ファイルはまだありません: ${file}"
        echo "作成するには: staddress config set api-key <key>"
        return 0
      fi
      api_key="$(staddress_config_get api_key)"
      base_url="$(staddress_config_get base_url)"
      timeout="$(staddress_config_get timeout)"
      echo "設定ファイル: ${file}"
      echo "  api-key  : $([[ -n "${api_key}" ]] && staddress_mask_key "${api_key}" || echo "(未設定)")"
      echo "  base-url : ${base_url:-(未設定 → 既定 ${DEFAULT_BASE_URL})}"
      echo "  timeout  : ${timeout:-(未設定 → 既定 ${DEFAULT_TIMEOUT})}"
      ;;
    path)
      staddress_config_path
      ;;
    *)
      staddress_die "${EXIT_CONFIG_ERROR}" "config: 不明なサブコマンド: ${sub}"
      ;;
  esac
}
