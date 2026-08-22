#!/usr/bin/env bash
# Desktop Extension（.mcpb）を梱包する。
# 依存関係は tsup --no-external で server/index.js に同梱し、Claude Desktop 同梱の Node だけで動かす。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="${ROOT}/.mcpb-stage"
OUT="${ROOT}/staddress.mcpb"
ICON_SRC="${ROOT}/mcpb/icon.png"

cd "${ROOT}"

if [[ ! -f "${ICON_SRC}" ]]; then
  echo "error: icon not found: ${ICON_SRC}" >&2
  exit 1
fi

if [[ ! -d node_modules ]]; then
  echo "error: run npm ci (or npm install) in packages/mcp first" >&2
  exit 1
fi

rm -rf "${STAGE}"
mkdir -p "${STAGE}/server"

echo "bundling MCP server (deps included)..."
npx tsup --config tsup.mcpb.config.ts

# ESM として解決できるようにする（entry は .js）
printf '%s\n' '{"type":"module","private":true}' > "${STAGE}/package.json"

cp "${ROOT}/mcpb/manifest.json" "${STAGE}/manifest.json"
cp "${ICON_SRC}" "${STAGE}/icon.png"
if [[ -f "${ROOT}/../../LICENSE" ]]; then
  cp "${ROOT}/../../LICENSE" "${STAGE}/LICENSE"
fi

echo "validating manifest..."
npx --yes @anthropic-ai/mcpb validate "${STAGE}/manifest.json"

echo "packing ${OUT}..."
rm -f "${OUT}"
npx --yes @anthropic-ai/mcpb pack "${STAGE}" "${OUT}"

python3 - "${OUT}" <<'PY'
import sys, zipfile
path = sys.argv[1]
with zipfile.ZipFile(path) as zf:
    names = zf.namelist()
need = ("manifest.json", "icon.png", "server/index.js")
missing = [n for n in need if n not in names]
if missing:
    raise SystemExit(f"mcpb missing entries: {missing}; had {names}")
print("entries:", ", ".join(sorted(names)))
PY

ls -lh "${OUT}"
echo "packed: ${OUT}"
