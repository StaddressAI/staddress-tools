#!/usr/bin/env bash
# Staddress CLI — `batch` サブコマンド（一括住所解析）

cmd_batch_help() {
  cat <<'EOF'
使い方: staddress batch (--file <path> | --stdin) [オプション]

複数の住所を一括解析します (POST /api/v1/addresses/parse/batch)。
※ Standard プラン以上が必要です。

入力（いずれか必須）:
  -f, --file <path>   JSON ファイルを読み込む
      --stdin         標準入力から JSON を読み込む

オプション:
      --json          JSON で出力（既定）
  -h, --help          このヘルプを表示

入力 JSON 形式:
  {"items": [{"id": "1", "address": "...", "postalCode": "..."}]}
  または items 配列のみ: [{"id": "1", "address": "..."}]
  ※ 最大100件。postalCode は任意。

例:
  staddress batch --file addresses.json
  cat addresses.json | staddress batch --stdin
EOF
}

cmd_batch() {
  local file="" use_stdin="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--file) file="${2:-}"; shift 2 ;;
      --file=*)  file="${1#*=}"; shift ;;
      --stdin)   use_stdin="true"; shift ;;
      --json)    shift ;;
      -h|--help) cmd_batch_help; return 0 ;;
      -*)        staddress_die "${EXIT_CONFIG_ERROR}" "batch: 不明なオプション: $1" ;;
      *)         staddress_die "${EXIT_CONFIG_ERROR}" "batch: 不明な引数: $1" ;;
    esac
  done

  staddress_require_jq

  local input_json
  if [[ "${use_stdin}" == "true" ]]; then
    input_json="$(cat)"
  elif [[ -n "${file}" ]]; then
    [[ -f "${file}" ]] || staddress_die "${EXIT_CONFIG_ERROR}" "ファイルが見つかりません: ${file}"
    input_json="$(cat "${file}")"
  else
    echo "Error: --file <path> または --stdin を指定してください。" >&2
    echo "例: staddress batch --file addresses.json" >&2
    exit "${EXIT_CONFIG_ERROR}"
  fi

  # 配列 / {items:[...]} のどちらも受け付け、{items:[...]} に正規化
  local req_body
  if ! req_body="$(jq -e '
    if type == "array" then {items: .}
    elif type == "object" and (.items | type) == "array" then {items: .items}
    else error("invalid batch format")
    end
  ' <<< "${input_json}" 2>/dev/null)"; then
    echo "Error: 無効な JSON 形式です。" >&2
    echo "       {\"items\": [...]} 形式、または items の配列を指定してください。" >&2
    exit "${EXIT_CONFIG_ERROR}"
  fi

  local count
  count="$(jq '.items | length' <<< "${req_body}")"
  if [[ "${count}" -eq 0 ]]; then
    staddress_die "${EXIT_CONFIG_ERROR}" "items が空です。"
  fi
  if [[ "${count}" -gt 100 ]]; then
    staddress_die "${EXIT_CONFIG_ERROR}" "items は最大100件です（現在: ${count} 件）。"
  fi

  staddress_resolve_config

  staddress_call POST "/api/v1/addresses/parse/batch" -d "${req_body}" \
    | staddress_print_json
}
