# Xserver（本番 Ubuntu + nginx）へ Remote MCP を載せる

既存の **https://api.staddress.com**（nginx → Node :3000）と同じ型です。MCP は別プロセス（:8787）にし、同じホストの `/mcp` で公開します。

- 申請 URL: `https://api.staddress.com/mcp`
- 前提: **VPS / クラウド**（常駐 Node + systemd）。レンタルサーバー共用プランでは常駐プロセスが使えません。

## 1. サーバに配置

API と同じユーザ（例: `appuser` / `wei`）で SSH します。

```bash
sudo mkdir -p /opt/staddress-mcp
sudo chown "$USER" /opt/staddress-mcp
cd /opt/staddress-mcp

# 公開 npm（0.2.0 タグ後）:
# npm install @staddress/mcp@0.2.0
# またはリポジトリから:
git clone --depth 1 https://github.com/StaddressAI/staddress-tools.git /tmp/staddress-tools
cd /tmp/staddress-tools/packages/mcp
npm ci
npm run build
cp -a dist package.json package-lock.json /opt/staddress-mcp/
cd /opt/staddress-mcp
npm ci --omit=dev
```

Node 18 以上が `/usr/bin/node` にあることを確認します（API と同じで可）。

## 2. systemd で常駐

```bash
sudo cp /tmp/staddress-tools/packages/mcp/deploy/staddress-mcp.service /etc/systemd/system/
# User= を API と同じ実行ユーザに合わせる
sudo systemctl daemon-reload
sudo systemctl enable --now staddress-mcp
sudo systemctl status staddress-mcp
curl -sS http://127.0.0.1:8787/health
```

共通の `STADDRESS_API_KEY` は **入れない**。各クライアントがヘッダで自分のキーを送ります。

## 3. nginx で HTTPS 公開

`api.staddress.com` の **443 server ブロック**に `deploy/nginx-mcp.location.conf` を追記します。

```bash
sudo nginx -t && sudo systemctl reload nginx
```

DNS / 証明書の追加は不要です（既存の api サブドメインを流用）。

## 4. 外から確認

```bash
curl -sS https://api.staddress.com/health
curl -sS -o /dev/null -w "%{http_code}\n" -X POST https://api.staddress.com/mcp
# 401 なら認証必須の経路は生きている

curl -sS -X POST https://api.staddress.com/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "X-Api-Key: st_あなたのキー" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"curl","version":"0"}}}'
```

## 5. Smithery

[smithery.ai/servers/new](https://smithery.ai/servers/new)

- Namespace: `staddress`（選べれば）
- Server ID: `mcp`
- MCP Server URL: `https://api.staddress.com/mcp`

## レンタルサーバー共用の場合

常駐 Node と任意ポートのリバースプロキシが使えないことが多いです。その場合は VPS 側（いま API が動いているマシン）に載せてください。
