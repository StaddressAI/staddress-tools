#!/usr/bin/env bash
# Staddress AI — 結合テスト（実 API 呼び出し）
#
# examples/curl/staddress.sh を実際の Staddress API に対して実行し、
# レスポンス構造を検証する。
#
# 実行方法:
#   1. リポジトリルートに .env を用意（STADDRESS_BASE_URL / STADDRESS_API_KEY）
#      または環境変数として export
#   2. ./tests/integration/run.sh
#
# 終了コード:
#   0 = 全テスト成功（または環境未設定でスキップ）
#   1 = 失敗あり
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STADDRESS_SH="${ROOT_DIR}/examples/curl/staddress.sh"
BATCH_SAMPLE="${ROOT_DIR}/examples/curl/batch-sample.json"

# 色（端末以外では無効化）
if [[ -t 1 ]]; then
  C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YEL=$'\033[33m'; C_RST=$'\033[0m'
else
  C_GREEN=""; C_RED=""; C_YEL=""; C_RST=""
fi

PASS=0; FAIL=0; SKIP=0

pass() { echo "${C_GREEN}PASS${C_RST}  $1"; PASS=$((PASS + 1)); }
fail() { echo "${C_RED}FAIL${C_RST}  $1"; [[ -n "${2:-}" ]] && echo "        ${2}"; FAIL=$((FAIL + 1)); }
skip() { echo "${C_YEL}SKIP${C_RST}  $1"; [[ -n "${2:-}" ]] && echo "        ${2}"; SKIP=$((SKIP + 1)); }

# 前提チェック ---------------------------------------------------------------

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq が必要です。" >&2
  exit 1
fi

# .env を読み込み（環境変数が未設定の場合）
if [[ -z "${STADDRESS_API_KEY:-}" || -z "${STADDRESS_BASE_URL:-}" ]]; then
  if [[ -f "${ROOT_DIR}/.env" ]]; then
    set -a; # shellcheck disable=SC1091
    source "${ROOT_DIR}/.env"; set +a
  fi
fi

if [[ -z "${STADDRESS_API_KEY:-}" || -z "${STADDRESS_BASE_URL:-}" || "${STADDRESS_API_KEY:-}" == "your-api-key-here" ]]; then
  echo "${C_YEL}結合テストをスキップします${C_RST}"
  echo "  STADDRESS_BASE_URL / STADDRESS_API_KEY が未設定です。"
  echo "  .env を設定するか環境変数を export してください。"
  exit 0
fi

echo "=== Staddress 結合テスト ==="
echo "Base URL: ${STADDRESS_BASE_URL}"
echo

# テストケース ---------------------------------------------------------------

# 1) 利用状況
test_usage() {
  local out
  out=$("${STADDRESS_SH}" -u 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    fail "usage: スクリプトが異常終了"; return
  fi
  if ! jq -e . >/dev/null 2>&1 <<< "${out}"; then
    fail "usage: JSON が不正" "${out}"; return
  fi
  if jq -e '.plan != null and (.usage != null)' >/dev/null 2>&1 <<< "${out}"; then
    pass "usage: plan / usage フィールドを取得 (plan=$(jq -r '.plan' <<< "${out}"))"
  else
    fail "usage: 期待フィールドなし" "${out}"
  fi
}

# 2) 単件解析（代表入力）
test_single() {
  local out
  out=$("${STADDRESS_SH}" -s "六本木ヒルズ 森タワー 52F" 2>/dev/null)
  if ! jq -e . >/dev/null 2>&1 <<< "${out}"; then
    fail "single: JSON が不正" "${out}"; return
  fi
  if jq -e '.result.normalized != null and (.result.components.pref != null)' >/dev/null 2>&1 <<< "${out}"; then
    pass "single: normalized=$(jq -r '.result.normalized' <<< "${out}")"
  else
    fail "single: result.normalized / components.pref なし" "${out}"
  fi
}

# 3) 単件解析（郵便番号付き）
test_single_postal() {
  local out
  out=$("${STADDRESS_SH}" -s "東京都渋谷区道玄坂1-2 マンション桜 101号" "150-0043" 2>/dev/null)
  if jq -e '.result.components.pref == "東京都"' >/dev/null 2>&1 <<< "${out}"; then
    pass "single+postal: pref=東京都 / city=$(jq -r '.result.components.city // "?"' <<< "${out}")"
  else
    fail "single+postal: 期待値と不一致" "${out}"
  fi
}

# 4) 一括解析
test_batch() {
  local out err_code
  out=$("${STADDRESS_SH}" -b "${BATCH_SAMPLE}" 2>/dev/null)
  if ! jq -e . >/dev/null 2>&1 <<< "${out}"; then
    fail "batch: JSON が不正" "${out}"; return
  fi
  # プラン制限（Standard 未満）は forbidden になる → スキップ扱い
  err_code=$(jq -r '.error.code // empty' <<< "${out}")
  if [[ "${err_code}" == "forbidden" ]]; then
    skip "batch: 現在のプランでは一括解析が利用不可 (403 forbidden)"; return
  fi
  local expected actual
  expected=$(jq '.items | length' "${BATCH_SAMPLE}")
  actual=$(jq '.results | length' <<< "${out}")
  if [[ "${actual}" == "${expected}" ]]; then
    pass "batch: ${actual}/${expected} 件の結果を取得"
  else
    fail "batch: 件数不一致 (期待=${expected} 実際=${actual})" "${out}"
  fi
}

# 実行 -----------------------------------------------------------------------
test_usage
test_single
test_single_postal
test_batch

echo
echo "=== 結果: ${C_GREEN}${PASS} passed${C_RST}, ${C_RED}${FAIL} failed${C_RST}, ${C_YEL}${SKIP} skipped${C_RST} ==="

[[ "${FAIL}" -eq 0 ]]
