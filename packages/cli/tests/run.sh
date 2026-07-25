#!/usr/bin/env bash
# =============================================================================
# staddress CLI — 単体テスト（mock curl による、実 API 不要）
#
#   curl をモックに差し替え、各サブコマンドの引数処理・出力・終了コードを検証する。
#
# 実行:
#   ./packages/cli/tests/run.sh
#
# 終了コード: 0 = 全成功 / 1 = 失敗あり
# =============================================================================
set -uo pipefail

TESTS_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CLI_DIR="$(cd "${TESTS_DIR}/.." >/dev/null 2>&1 && pwd)"
STADDRESS="${CLI_DIR}/bin/staddress"

if [[ -t 1 ]]; then
  C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_RST=$'\033[0m'
else
  C_GREEN=""; C_RED=""; C_RST=""
fi

PASS=0; FAIL=0
pass() { echo "${C_GREEN}PASS${C_RST}  $1"; PASS=$((PASS + 1)); }
fail() { echo "${C_RED}FAIL${C_RST}  $1"; [[ -n "${2:-}" ]] && echo "        ${2}"; FAIL=$((FAIL + 1)); }

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: このテストには jq が必要です。" >&2
  exit 1
fi

# --- モック環境のセットアップ -----------------------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

MOCK_BIN="${WORK}/bin"
mkdir -p "${MOCK_BIN}"

# curl モック: 最後の位置引数（-w の書式）を使い <body>\n<status> を出力する。
# body は $MOCK_BODY_FILE、status は $MOCK_STATUS で制御。
# 呼ばれたことの記録として、-d の本文を $MOCK_BODY_CAPTURE に書き出す。
cat > "${MOCK_BIN}/curl" <<'MOCK'
#!/usr/bin/env bash
prev=""
for a in "$@"; do
  if [[ "${prev}" == "-d" ]]; then
    [[ -n "${MOCK_BODY_CAPTURE:-}" ]] && printf '%s' "${a}" > "${MOCK_BODY_CAPTURE}"
  fi
  prev="${a}"
done
status="${MOCK_STATUS:-200}"
if [[ -n "${MOCK_BODY_FILE:-}" && -f "${MOCK_BODY_FILE}" ]]; then
  cat "${MOCK_BODY_FILE}"
else
  body="${MOCK_BODY:-}"
  [[ -z "${body}" ]] && body='{}'
  printf '%s' "${body}"
fi
printf '\n%s' "${status}"
MOCK
chmod +x "${MOCK_BIN}/curl"

export PATH="${MOCK_BIN}:${PATH}"

# CLI が実 API 設定を拾わないよう、テスト用に固定
export STADDRESS_API_KEY="test-key"
export STADDRESS_BASE_URL="https://api.example.test"
export STADDRESS_CONFIG="${WORK}/config"

FIXTURE_PARSE="${WORK}/parse-success.json"
cat > "${FIXTURE_PARSE}" <<'JSON'
{"result":{"normalized":"東京都港区六本木6丁目10-1","standard":"東京都港区六本木六丁目10-1","components":{"pref":"東京都","city":"港区","lat":35.6604,"lon":139.7292},"confidence":{"score":0.92,"matchLevel":"residential_detail"}}}
JSON

FIXTURE_USAGE="${WORK}/usage.json"
echo '{"accountName":"Acme","plan":"free","usage":{"used":10,"limit":100}}' > "${FIXTURE_USAGE}"

FIXTURE_ERR="${WORK}/error.json"
echo '{"error":{"code":"unauthorized","message":"API キーが無効です。"}}' > "${FIXTURE_ERR}"

# =============================================================================
# テストケース
# =============================================================================

# 1) version
out="$("${STADDRESS}" version)"
if [[ "${out}" == "staddress "* ]]; then
  pass "version: '${out}'"
else
  fail "version: 予期しない出力" "${out}"
fi

# 2) help は 0 で終了
if "${STADDRESS}" help >/dev/null 2>&1; then
  pass "help: exit 0"
else
  fail "help: 非0終了"
fi

# 3) 不明コマンドは exit 2
"${STADDRESS}" bogus >/dev/null 2>&1
[[ $? -eq 2 ]] && pass "unknown command: exit 2" || fail "unknown command: exit != 2"

# 4) parse 引数なしは exit 2
"${STADDRESS}" parse >/dev/null 2>&1
[[ $? -eq 2 ]] && pass "parse (no arg): exit 2" || fail "parse (no arg): exit != 2"

# 5) parse 成功（JSON 出力 + リクエストボディ検証）
export MOCK_STATUS=200 MOCK_BODY_FILE="${FIXTURE_PARSE}" MOCK_BODY_CAPTURE="${WORK}/body1.json"
out="$("${STADDRESS}" parse "六本木ヒルズ 森タワー 52F" -p 106-6100)"
if jq -e '.result.components.pref == "東京都"' >/dev/null 2>&1 <<< "${out}"; then
  pass "parse: result.components.pref を取得"
else
  fail "parse: JSON 出力が不正" "${out}"
fi
if jq -e '.input == "六本木ヒルズ 森タワー 52F" and .postalCode == "106-6100"' \
    >/dev/null 2>&1 < "${WORK}/body1.json"; then
  pass "parse: リクエストボディに input/postalCode を含む"
else
  fail "parse: リクエストボディ不正" "$(cat "${WORK}/body1.json")"
fi

# 6) parse --pretty
out="$("${STADDRESS}" parse "六本木ヒルズ" --pretty)"
if grep -q "都道府県: 東京都" <<< "${out}" && grep -q "住所解析結果" <<< "${out}"; then
  pass "parse --pretty: テーブル出力"
else
  fail "parse --pretty: 期待行なし" "${out}"
fi

# 7) parse API エラーは exit 1
export MOCK_STATUS=401 MOCK_BODY_FILE="${FIXTURE_ERR}"
"${STADDRESS}" parse "test" >/dev/null 2>&1
[[ $? -eq 1 ]] && pass "parse (401): exit 1" || fail "parse (401): exit != 1"

# 8) usage 成功
export MOCK_STATUS=200 MOCK_BODY_FILE="${FIXTURE_USAGE}"
out="$("${STADDRESS}" usage)"
if jq -e '.plan == "free"' >/dev/null 2>&1 <<< "${out}"; then
  pass "usage: plan を取得"
else
  fail "usage: JSON 不正" "${out}"
fi

# 9) usage --pretty
out="$("${STADDRESS}" usage --pretty)"
grep -q "プラン" <<< "${out}" && pass "usage --pretty: テーブル出力" || fail "usage --pretty: 期待行なし" "${out}"

# 10) batch（stdin, 成功）+ リクエストボディの items 正規化検証
export MOCK_STATUS=200 MOCK_BODY='{"results":[]}' MOCK_BODY_FILE="" MOCK_BODY_CAPTURE="${WORK}/body2.json"
out="$(printf '[{"id":"1","address":"東京都渋谷区道玄坂1-2-3"}]' | "${STADDRESS}" batch --stdin)"
if jq -e '.results | type == "array"' >/dev/null 2>&1 <<< "${out}"; then
  pass "batch --stdin: results を取得"
else
  fail "batch --stdin: JSON 不正" "${out}"
fi
if jq -e '(.items | length) == 1 and (.items[0].id == "1")' >/dev/null 2>&1 < "${WORK}/body2.json"; then
  pass "batch: 配列入力を {items:[...]} に正規化"
else
  fail "batch: 正規化失敗" "$(cat "${WORK}/body2.json")"
fi

# 11) batch 入力なしは exit 2
unset MOCK_BODY_CAPTURE
"${STADDRESS}" batch >/dev/null 2>&1
[[ $? -eq 2 ]] && pass "batch (no input): exit 2" || fail "batch (no input): exit != 2"

# 12) batch 無効 JSON は exit 2
printf 'not json' | "${STADDRESS}" batch --stdin >/dev/null 2>&1
[[ $? -eq 2 ]] && pass "batch (invalid json): exit 2" || fail "batch (invalid json): exit != 2"

# 13) config set / show（設定ファイル書き込み）
"${STADDRESS}" config set api-key sk_test_1234567890 >/dev/null
"${STADDRESS}" config set base-url https://api.custom.test >/dev/null
out="$("${STADDRESS}" config show)"
if grep -q "sk_t" <<< "${out}" && grep -q "https://api.custom.test" <<< "${out}"; then
  pass "config set/show: 保存・マスク表示"
else
  fail "config show: 期待値なし" "${out}"
fi
# 保存値が config ファイルに正しく書かれているか
if grep -q '^api_key=sk_test_1234567890$' "${STADDRESS_CONFIG}"; then
  pass "config set: api_key を設定ファイルに保存"
else
  fail "config set: 保存内容不正" "$(cat "${STADDRESS_CONFIG}")"
fi

# 14) config set 不明キーは exit 2
"${STADDRESS}" config set bogus x >/dev/null 2>&1
[[ $? -eq 2 ]] && pass "config set (unknown key): exit 2" || fail "config set (unknown key): exit != 2"

# 15) API キー未設定は exit 2（config ファイルも空にする）
env -u STADDRESS_API_KEY STADDRESS_CONFIG="${WORK}/empty-config" \
  MOCK_STATUS=200 MOCK_BODY='{}' \
  "${STADDRESS}" usage >/dev/null 2>&1
[[ $? -eq 2 ]] && pass "no api key: exit 2 (config error)" || fail "no api key: exit != 2"

# =============================================================================
echo
echo "=== 結果: ${C_GREEN}${PASS} passed${C_RST}, ${C_RED}${FAIL} failed${C_RST} ==="
[[ "${FAIL}" -eq 0 ]]
