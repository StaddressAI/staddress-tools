#!/usr/bin/env bash
# Staddress curl サンプル共通設定
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# .env を読み込み（存在する場合）。環境変数が未設定の場合の補完に使う。
if [[ -f "${ROOT_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "${ROOT_DIR}/.env"
  set +a
fi

# 設定の解決（優先順位）:
#   1. コマンドライン引数 (ARG_BASE_URL / ARG_API_KEY)
#   2. 環境変数 / .env (STADDRESS_BASE_URL / STADDRESS_API_KEY)
#   3. どちらもなければ対話入力
staddress_resolve_config() {
  # ベース URL
  if [[ -n "${ARG_BASE_URL:-}" ]]; then
    STADDRESS_BASE_URL="${ARG_BASE_URL}"
  elif [[ -n "${STADDRESS_BASE_URL:-}" ]]; then
    : # 環境変数 / .env の値を使用
  else
    read -r -p "STADDRESS_BASE_URL を入力してください [https://api.staddress.com]: " _input_url
    STADDRESS_BASE_URL="${_input_url:-https://api.staddress.com}"
  fi

  # API キー
  if [[ -n "${ARG_API_KEY:-}" ]]; then
    STADDRESS_API_KEY="${ARG_API_KEY}"
  elif [[ -n "${STADDRESS_API_KEY:-}" ]]; then
    : # 環境変数 / .env の値を使用
  else
    read -r -s -p "STADDRESS_API_KEY を入力してください: " STADDRESS_API_KEY
    echo >&2
  fi

  if [[ -z "${STADDRESS_BASE_URL:-}" ]]; then
    echo "Error: STADDRESS_BASE_URL が設定されていません。" >&2
    exit 2
  fi
  if [[ -z "${STADDRESS_API_KEY:-}" ]]; then
    echo "Error: STADDRESS_API_KEY が設定されていません。" >&2
    exit 2
  fi

  # 末尾スラッシュを除去
  STADDRESS_BASE_URL="${STADDRESS_BASE_URL%/}"
}

staddress_request() {
  local method="$1"
  local path="$2"
  shift 2

  curl -sS -X "${method}" \
    "${STADDRESS_BASE_URL}${path}" \
    -H "X-Api-Key: ${STADDRESS_API_KEY}" \
    -H "Content-Type: application/json" \
    "$@"
}

staddress_pretty() {
  if command -v jq >/dev/null 2>&1; then
    jq .
  else
    cat
  fi
}
