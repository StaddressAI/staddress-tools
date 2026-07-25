#!/usr/bin/env bash
# Staddress CLI — `usage` サブコマンド（利用状況取得）

cmd_usage_help() {
  cat <<'EOF'
使い方: staddress usage [オプション]

アカウントの利用状況を取得します (GET /api/v1/usage)。

オプション:
      --pretty   人間可読なテーブル形式で出力
      --json     JSON で出力（既定）
  -h, --help     このヘルプを表示
EOF
}

staddress_render_usage_pretty() {
  local body="$1"
  jq -r '
    [
      "利用状況",
      "  アカウント : \(.accountName // "-")",
      "  プラン     : \(.plan // "-")",
      "  利用状況   : \(.usage // "-" | tostring)"
    ] | join("\n")
  ' <<< "${body}"
}

cmd_usage() {
  local mode="${OUTPUT_MODE}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pretty)  mode="pretty"; shift ;;
      --json)    mode="json"; shift ;;
      -h|--help) cmd_usage_help; return 0 ;;
      *)         staddress_die "${EXIT_CONFIG_ERROR}" "usage: 不明な引数: $1" ;;
    esac
  done

  staddress_resolve_config

  local resp
  resp="$(staddress_call GET "/api/v1/usage")"

  if [[ "${mode}" == "pretty" ]] && command -v jq >/dev/null 2>&1; then
    staddress_render_usage_pretty "${resp}"
  else
    printf '%s\n' "${resp}" | staddress_print_json
  fi
}
