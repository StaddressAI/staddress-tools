#!/usr/bin/env bash
# Staddress CLI — `parse` サブコマンド（単件住所解析）

cmd_parse_help() {
  cat <<'EOF'
使い方: staddress parse <住所> [オプション]

単件の住所を解析します (POST /api/v1/addresses/parse)。

オプション:
  -p, --postal-code <code>   郵便番号（任意）
      --pretty               人間可読なテーブル形式で出力
      --json                 JSON で出力（既定）
  -h, --help                 このヘルプを表示

例:
  staddress parse "六本木ヒルズ 森タワー 52F"
  staddress parse "東京都渋谷区道玄坂1-2 マンション桜 101号" -p 150-0043
  staddress parse "六本木ヒルズ 森タワー 52F" --pretty
EOF
}

# result JSON をテーブル整形して出力
staddress_render_parse_pretty() {
  local body="$1"
  jq -r '
    def row($label; $value): "  \($label): \($value // "-")";
    if .result == null then
      "解析結果なし" + (if .error then " (\(.error.code)): \(.error.message)" else "" end)
    else
      .result as $r |
      [
        "住所解析結果",
        "  normalized : \($r.normalized // "-")",
        "  standard   : \($r.standard // "-")",
        "  --- 構成要素 ---",
        row("都道府県"; $r.components.pref),
        row("市区町村"; $r.components.city),
        row("大字町丁目"; $r.components.oazaCho),
        row("丁目小字"; $r.components.chomeKoaza),
        row("街区番号"; $r.components.streetNumberBlock),
        row("建物名"; $r.components.buildingName),
        row("部屋番号"; (($r.components.roomNumber // "") + ($r.components.roomNumberUnit // ""))),
        row("緯度"; $r.components.lat),
        row("経度"; $r.components.lon),
        "  --- 信頼度 ---",
        row("スコア"; $r.confidence.score),
        row("マッチレベル"; $r.confidence.matchLevel)
      ] | join("\n")
    end
  ' <<< "${body}"
}

cmd_parse() {
  local address="" postal_code=""
  local mode="${OUTPUT_MODE}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--postal-code) postal_code="${2:-}"; shift 2 ;;
      --postal-code=*)  postal_code="${1#*=}"; shift ;;
      --pretty)         mode="pretty"; shift ;;
      --json)           mode="json"; shift ;;
      -h|--help)        cmd_parse_help; return 0 ;;
      -*)               staddress_die "${EXIT_CONFIG_ERROR}" "parse: 不明なオプション: $1" ;;
      *)
        if [[ -z "${address}" ]]; then
          address="$1"
        else
          staddress_die "${EXIT_CONFIG_ERROR}" "parse: 住所は1つだけ指定してください: '$1' は余分です"
        fi
        shift
        ;;
    esac
  done

  if [[ -z "${address}" ]]; then
    echo "Error: 住所を指定してください。" >&2
    echo "例: staddress parse \"六本木ヒルズ 森タワー 52F\"" >&2
    exit "${EXIT_CONFIG_ERROR}"
  fi

  staddress_require_jq
  staddress_resolve_config

  local req_body
  if [[ -n "${postal_code}" ]]; then
    req_body="$(jq -n --arg input "${address}" --arg postalCode "${postal_code}" \
      '{input: $input, postalCode: $postalCode}')"
  else
    req_body="$(jq -n --arg input "${address}" '{input: $input}')"
  fi

  local resp
  resp="$(staddress_call POST "/api/v1/addresses/parse" -d "${req_body}")"

  if [[ "${mode}" == "pretty" ]]; then
    staddress_render_parse_pretty "${resp}"
  else
    printf '%s\n' "${resp}" | staddress_print_json
  fi
}
