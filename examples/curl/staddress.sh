#!/usr/bin/env bash
# Staddress AI API — curl サンプル（統合スクリプト）
#
# Usage:
#   ./staddress.sh                     利用案内を表示
#   ./staddress.sh -u | --usage        利用状況を取得
#   ./staddress.sh -s | --single <住所> [郵便番号]   単件解析
#   ./staddress.sh -b | --batch <ファイル>   一括解析（JSON ファイル必須）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<'EOF'
Staddress AI API — curl サンプル

使い方:
  ./staddress.sh [オプション] [引数]

オプション:
  -u, --usage              利用状況を取得 (GET /api/v1/usage)
  -s, --single <住所>      単件住所解析 (POST /api/v1/addresses/parse)
                           任意: 第2引数に郵便番号
  -b, --batch <ファイル>   一括住所解析 (POST /api/v1/addresses/parse/batch)
                           JSON ファイルを指定（サンプル: batch-sample.json）
  -h, --help               このメッセージを表示

例:
  ./staddress.sh -u
  ./staddress.sh -s "六本木ヒルズ 森タワー 52F"
  ./staddress.sh --single "東京都渋谷区道玄坂1-2 マンション桜 101号" "150-0043"
  ./staddress.sh -b batch-sample.json

一括 JSON ファイル形式:
  {"items": [{"id": "...", "address": "...", "postalCode": "..."}]}
  または items 配列のみ: [{"id": "...", "address": "..."}]
  ※ 最大100件。postalCode は任意。

前提:
  1. リポジトリルートに .env を作成（.env.example を参照）
  2. STADDRESS_BASE_URL / STADDRESS_API_KEY を設定
  3. jq をインストール（JSON 生成・整形に使用）

公式 API: https://staddress.com/api
EOF
}

load_env() {
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/_common.sh"
}

cmd_usage() {
  load_env
  curl -sS -X GET \
    "${STADDRESS_BASE_URL}/api/v1/usage" \
    -H "X-Api-Key: ${STADDRESS_API_KEY}" \
    | staddress_pretty
}

cmd_single() {
  local input="${1:-}"
  local postal_code="${2:-}"

  if [[ -z "${input}" ]]; then
    echo "Error: 住所を指定してください。" >&2
    echo "例: ./staddress.sh -s \"六本木ヒルズ 森タワー 52F\"" >&2
    exit 2
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq が必要です（単件解析の JSON 生成に使用）。" >&2
    exit 2
  fi

  load_env

  local body
  if [[ -n "${postal_code}" ]]; then
    body=$(jq -n \
      --arg input "${input}" \
      --arg postalCode "${postal_code}" \
      '{input: $input, postalCode: $postalCode}')
  else
    body=$(jq -n \
      --arg input "${input}" \
      '{input: $input}')
  fi

  staddress_request POST "/api/v1/addresses/parse" \
    -d "${body}" \
    | staddress_pretty
}

cmd_batch() {
  local file="${1:-}"

  if [[ -z "${file}" ]]; then
    echo "Error: 一括解析する JSON ファイルを指定してください。" >&2
    echo "例: ./staddress.sh -b batch-sample.json" >&2
    exit 2
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq が必要です（一括解析の JSON 処理に使用）。" >&2
    exit 2
  fi

  if [[ ! -f "${file}" ]]; then
    echo "Error: ファイルが見つかりません: ${file}" >&2
    exit 2
  fi

  load_env

  local body
  if ! body=$(jq -e '
    if type == "array" then {items: .}
    elif type == "object" and (.items | type) == "array" then .
    else error("invalid batch format")
    end
  ' "${file}"); then
    echo "Error: 無効な JSON 形式: ${file}" >&2
    echo "       {\"items\": [...]} 形式、または items 配列を指定してください。" >&2
    exit 2
  fi

  local count
  count=$(jq '.items | length' <<< "${body}")
  if [[ "${count}" -eq 0 ]]; then
    echo "Error: items が空です。" >&2
    exit 2
  fi
  if [[ "${count}" -gt 100 ]]; then
    echo "Error: items は最大100件です（現在: ${count} 件）。" >&2
    exit 2
  fi

  staddress_request POST "/api/v1/addresses/parse/batch" \
    -d "${body}" \
    | staddress_pretty
}

# メイン
if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi

case "${1}" in
  -u|--usage)
    cmd_usage
    ;;
  -s|--single)
    shift
    cmd_single "$@"
    ;;
  -b|--batch)
    shift
    cmd_batch "$@"
    ;;
  -h|--help)
    show_help
    ;;
  *)
    echo "Error: 不明なオプション: ${1}" >&2
    echo >&2
    show_help >&2
    exit 1
    ;;
esac
