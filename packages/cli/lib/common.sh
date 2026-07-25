#!/usr/bin/env bash
# Staddress CLI — 共通ライブラリ（設定解決・HTTP・出力・エラー処理）
#
# このファイルは bin/staddress および各サブコマンドから source される。
# 単体では実行しない。

# ---------------------------------------------------------------------------
# グローバル状態（bin/staddress で上書きされる）
# ---------------------------------------------------------------------------
: "${ARG_API_KEY:=}"          # --api-key で指定された値
: "${ARG_BASE_URL:=}"         # --base-url で指定された値
: "${OUTPUT_MODE:=json}"      # json | pretty

DEFAULT_BASE_URL="https://api.staddress.com"
DEFAULT_TIMEOUT="30"

# 終了コード規約:
#   0 = 成功
#   1 = API エラー / ネットワークエラー
#   2 = 設定エラー / 使い方エラー
EXIT_API_ERROR=1
EXIT_CONFIG_ERROR=2

# ---------------------------------------------------------------------------
# メッセージヘルパ
# ---------------------------------------------------------------------------
staddress_die() {
  # staddress_die <exit_code> <message...>
  local code="$1"; shift
  echo "Error: $*" >&2
  exit "${code}"
}

staddress_require_jq() {
  command -v jq >/dev/null 2>&1 \
    || staddress_die "${EXIT_CONFIG_ERROR}" "jq が必要です。https://stedolan.github.io/jq/ を参照してインストールしてください。"
}

# ---------------------------------------------------------------------------
# 設定ファイル（~/.config/staddress/config、key=value 形式）
# ---------------------------------------------------------------------------
staddress_config_path() {
  echo "${STADDRESS_CONFIG:-${HOME}/.config/staddress/config}"
}

# staddress_config_get <key>
staddress_config_get() {
  local key="$1" file
  file="$(staddress_config_path)"
  [[ -f "${file}" ]] || return 0
  # 先頭一致の最後の定義を採用。値の前後空白は除去。
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "${file}" | tail -n 1
}

# staddress_config_set <key> <value>
staddress_config_set() {
  local key="$1" value="$2" file dir tmp
  file="$(staddress_config_path)"
  dir="$(dirname "${file}")"
  mkdir -p "${dir}" || staddress_die "${EXIT_CONFIG_ERROR}" "設定ディレクトリを作成できません: ${dir}"

  tmp="$(mktemp "${dir}/.config.XXXXXX")" \
    || staddress_die "${EXIT_CONFIG_ERROR}" "一時ファイルを作成できません。"

  if [[ -f "${file}" ]]; then
    # 既存の同キー行を除去してコピー
    grep -v -E "^[[:space:]]*${key}[[:space:]]*=" "${file}" > "${tmp}" || true
  fi
  printf '%s=%s\n' "${key}" "${value}" >> "${tmp}"

  mv "${tmp}" "${file}"
  chmod 600 "${file}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 設定解決（優先順位: フラグ > 環境変数 > 設定ファイル > 既定）
# 成功時: STADDRESS_BASE_URL / STADDRESS_API_KEY / STADDRESS_TIMEOUT を確定
# ---------------------------------------------------------------------------
staddress_resolve_config() {
  # ベース URL
  if [[ -n "${ARG_BASE_URL}" ]]; then
    STADDRESS_BASE_URL="${ARG_BASE_URL}"
  elif [[ -n "${STADDRESS_BASE_URL:-}" ]]; then
    :
  else
    STADDRESS_BASE_URL="$(staddress_config_get base_url)"
    [[ -n "${STADDRESS_BASE_URL}" ]] || STADDRESS_BASE_URL="${DEFAULT_BASE_URL}"
  fi

  # API キー
  if [[ -n "${ARG_API_KEY}" ]]; then
    STADDRESS_API_KEY="${ARG_API_KEY}"
  elif [[ -n "${STADDRESS_API_KEY:-}" ]]; then
    :
  else
    STADDRESS_API_KEY="$(staddress_config_get api_key)"
  fi

  # タイムアウト
  if [[ -z "${STADDRESS_TIMEOUT:-}" ]]; then
    STADDRESS_TIMEOUT="$(staddress_config_get timeout)"
    [[ -n "${STADDRESS_TIMEOUT}" ]] || STADDRESS_TIMEOUT="${DEFAULT_TIMEOUT}"
  fi

  # 検証
  if [[ -z "${STADDRESS_API_KEY:-}" ]]; then
    cat >&2 <<'EOF'
Error: API キーが設定されていません。

以下のいずれかで設定してください:
  1. staddress config set api-key <あなたのキー>
  2. 環境変数: export STADDRESS_API_KEY=<あなたのキー>
  3. コマンドフラグ: --api-key <あなたのキー>

キーの取得: https://www.staddress.com/
EOF
    exit "${EXIT_CONFIG_ERROR}"
  fi

  # 末尾スラッシュ除去
  STADDRESS_BASE_URL="${STADDRESS_BASE_URL%/}"
}

# ---------------------------------------------------------------------------
# HTTP リクエスト
# staddress_raw_request <METHOD> <PATH> [curl args...]
#   標準出力: <レスポンスボディ>\n<HTTPステータスコード>
#   curl 自体の失敗（ネットワーク/タイムアウト）は非0で返す
# ---------------------------------------------------------------------------
staddress_raw_request() {
  local method="$1" path="$2"
  shift 2
  curl -sS -m "${STADDRESS_TIMEOUT}" -X "${method}" \
    "${STADDRESS_BASE_URL}${path}" \
    -H "X-Api-Key: ${STADDRESS_API_KEY}" \
    -H "Content-Type: application/json" \
    -w $'\n%{http_code}' \
    "$@"
}

# API エラーの要約を stderr に出力
staddress_error_summary() {
  local body="$1" status="$2" code message
  if command -v jq >/dev/null 2>&1; then
    code="$(jq -r '.error.code // empty' <<< "${body}" 2>/dev/null)"
    message="$(jq -r '.error.message // empty' <<< "${body}" 2>/dev/null)"
  fi
  if [[ -n "${message}" ]]; then
    echo "Error: API エラー (HTTP ${status}${code:+, ${code}}): ${message}" >&2
  else
    echo "Error: API エラー (HTTP ${status})" >&2
  fi
}

# staddress_call <METHOD> <PATH> [curl args...]
#   成功時: レスポンスボディ(JSON)を stdout に出力
#   HTTP 4xx/5xx: ボディを stdout に出しつつエラー要約を stderr に出して exit 1
#   ネットワークエラー: exit 1
staddress_call() {
  local method="$1" path="$2"
  shift 2
  local raw status body
  if ! raw="$(staddress_raw_request "${method}" "${path}" "$@")"; then
    staddress_die "${EXIT_API_ERROR}" "リクエストに失敗しました（ネットワーク接続またはタイムアウト）。接続先: ${STADDRESS_BASE_URL}"
  fi

  status="${raw##*$'\n'}"
  body="${raw%$'\n'*}"
  [[ "${status}" =~ ^[0-9]+$ ]] || status=0

  if [[ "${status}" -ge 400 ]]; then
    staddress_error_summary "${body}" "${status}"
    printf '%s\n' "${body}"
    exit "${EXIT_API_ERROR}"
  fi

  printf '%s\n' "${body}"
}

# ---------------------------------------------------------------------------
# 出力
# ---------------------------------------------------------------------------
staddress_print_json() {
  # <stdin> or $1 を JSON 整形（jq が無ければそのまま）
  if command -v jq >/dev/null 2>&1; then
    jq .
  else
    cat
  fi
}
