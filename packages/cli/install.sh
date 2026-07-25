#!/usr/bin/env bash
# =============================================================================
# staddress CLI インストーラ
#
#   bin/staddress を PATH の通ったディレクトリに symlink します。
#   既定の配置先: ~/.local/bin（無ければ /usr/local/bin）
#
# 使い方:
#   ./install.sh                 既定の場所へインストール
#   ./install.sh --prefix <dir>  指定ディレクトリへインストール
#   ./install.sh --uninstall     アンインストール
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SOURCE_BIN="${SCRIPT_DIR}/bin/staddress"

PREFIX=""
UNINSTALL="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)   PREFIX="${2:-}"; shift 2 ;;
    --prefix=*) PREFIX="${1#*=}"; shift ;;
    --uninstall) UNINSTALL="true"; shift ;;
    -h|--help)
      sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Error: 不明なオプション: $1" >&2; exit 2 ;;
  esac
done

# --- 配置先の決定 ------------------------------------------------------------
choose_prefix() {
  if [[ -n "${PREFIX}" ]]; then
    echo "${PREFIX}"
  elif [[ -d "${HOME}/.local/bin" ]] || mkdir -p "${HOME}/.local/bin" 2>/dev/null; then
    echo "${HOME}/.local/bin"
  else
    echo "/usr/local/bin"
  fi
}

TARGET_DIR="$(choose_prefix)"
TARGET_LINK="${TARGET_DIR}/staddress"

# --- アンインストール --------------------------------------------------------
if [[ "${UNINSTALL}" == "true" ]]; then
  if [[ -L "${TARGET_LINK}" || -e "${TARGET_LINK}" ]]; then
    rm -f "${TARGET_LINK}"
    echo "アンインストールしました: ${TARGET_LINK}"
  else
    echo "見つかりませんでした: ${TARGET_LINK}"
  fi
  exit 0
fi

# --- 依存チェック ------------------------------------------------------------
missing=()
command -v curl >/dev/null 2>&1 || missing+=("curl")
command -v jq   >/dev/null 2>&1 || missing+=("jq")
if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "警告: 次の依存が見つかりません: ${missing[*]}" >&2
  echo "      staddress の実行前にインストールしてください（例: brew install ${missing[*]}）。" >&2
fi

if [[ ! -f "${SOURCE_BIN}" ]]; then
  echo "Error: エントリポイントが見つかりません: ${SOURCE_BIN}" >&2
  exit 1
fi

# --- 配置 --------------------------------------------------------------------
chmod +x "${SOURCE_BIN}"
mkdir -p "${TARGET_DIR}"

if ! ln -sf "${SOURCE_BIN}" "${TARGET_LINK}" 2>/dev/null; then
  echo "Error: symlink を作成できません: ${TARGET_LINK}" >&2
  echo "       別の配置先を指定してください（例: sudo ./install.sh --prefix /usr/local/bin）。" >&2
  exit 1
fi

echo "インストールしました: ${TARGET_LINK} -> ${SOURCE_BIN}"

# PATH チェック
case ":${PATH}:" in
  *":${TARGET_DIR}:"*) : ;;
  *)
    echo
    echo "注意: ${TARGET_DIR} が PATH に含まれていません。"
    echo "      シェル設定に次を追加してください:"
    echo "        export PATH=\"${TARGET_DIR}:\$PATH\""
    ;;
esac

echo
echo "動作確認: staddress version"
