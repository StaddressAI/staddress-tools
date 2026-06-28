#!/usr/bin/env bash
# Staddress curl サンプル共通設定
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# .env を読み込み（存在する場合）
if [[ -f "${ROOT_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "${ROOT_DIR}/.env"
  set +a
fi

: "${STADDRESS_BASE_URL:?STADDRESS_BASE_URL is not set. Copy .env.example to .env and configure it.}"
: "${STADDRESS_API_KEY:?STADDRESS_API_KEY is not set. Copy .env.example to .env and configure it.}"

# 末尾スラッシュを除去
STADDRESS_BASE_URL="${STADDRESS_BASE_URL%/}"

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
