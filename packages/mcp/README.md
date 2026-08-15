# @staddress/mcp

[![npm version](https://img.shields.io/npm/v/@staddress/mcp.svg)](https://www.npmjs.com/package/@staddress/mcp)
[![CI](https://github.com/StaddressAI/staddress-tools/actions/workflows/smoke.yml/badge.svg)](https://github.com/StaddressAI/staddress-tools/actions/workflows/smoke.yml)
[![license](https://img.shields.io/npm/l/@staddress/mcp.svg)](../../LICENSE)

Staddress AI 住所解析 API を [Model Context Protocol (MCP)](https://modelcontextprotocol.io) のツールとして公開するサーバ。Cursor / Claude Desktop / ChatGPT などの MCP 対応クライアントから、住所の正規化・分解をツールとして呼び出せます。

## ワンクリック導入

[![Add to Cursor](https://cursor.com/deeplink/mcp-install-dark.svg)](cursor://anysphere.cursor-deeplink/mcp/install?name=staddress&config=eyJjb21tYW5kIjoibnB4IiwiYXJncyI6WyIteSIsIkBzdGFkZHJlc3MvbWNwIl0sImVudiI6eyJTVEFERFJFU1NfQVBJX0tFWSI6IiJ9fQ==)
[![Install in VS Code](https://img.shields.io/badge/VS_Code-Install_MCP-blue?logo=visualstudiocode&logoColor=white)](vscode:mcp/install?%7B%22name%22%3A%22staddress%22%2C%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22%40staddress%2Fmcp%22%5D%2C%22env%22%3A%7B%22STADDRESS_API_KEY%22%3A%22%24%7Binput%3Astaddress_api_key%7D%22%7D%7D)

> ボタンで追加した後、`STADDRESS_API_KEY` に自分の API キーを設定してください（Cursor は `~/.cursor/mcp.json` の鉛筆アイコンから編集できます）。

## 提供ツール

| ツール | 対応 API | 説明 |
| --- | --- | --- |
| `staddress_parse` | `POST /api/v1/addresses/parse` | 単件の住所を正規化・分解 |
| `staddress_parse_batch` | `POST /api/v1/addresses/parse/batch` | 複数住所を一括解析（Standard プラン以上、最大100件） |
| `staddress_get_usage` | `GET /api/v1/usage` | 利用状況（プラン・件数・クレジット）を取得 |

いずれも読み取り専用（`readOnlyHint`）です。

## 前提

- Node.js 18 以上
- Staddress AI の API キー（環境変数 `STADDRESS_API_KEY`）

## クライアント設定

### Cursor

`~/.cursor/mcp.json`（プロジェクト単位なら `.cursor/mcp.json`）に追加します。

```json
{
  "mcpServers": {
    "staddress": {
      "command": "npx",
      "args": ["-y", "@staddress/mcp"],
      "env": {
        "STADDRESS_API_KEY": "sk_xxx"
      }
    }
  }
}
```

### Claude Desktop

`claude_desktop_config.json` に同様に追加します。

```json
{
  "mcpServers": {
    "staddress": {
      "command": "npx",
      "args": ["-y", "@staddress/mcp"],
      "env": {
        "STADDRESS_API_KEY": "sk_xxx"
      }
    }
  }
}
```

自前 API エンドポイントを使う場合は `env` に `STADDRESS_BASE_URL` を追加してください（既定: `https://api.staddress.com`）。

## 動作確認（MCP Inspector）

```bash
STADDRESS_API_KEY=sk_xxx npx @modelcontextprotocol/inspector npx -y @staddress/mcp
```

## 使い方の例（AI への指示）

> 「六本木ヒルズ 森タワー 52F を staddress で正規化して、緯度経度も教えて」

AI が `staddress_parse` を呼び出し、正規化住所・構成要素・信頼度・緯度経度を返します。

## エラー時の挙動

API エラー・ネットワークエラー・APIキー未設定は、ツール結果を `isError: true` として返し、`code` / `http_status` / `request_id` を含む説明テキストを添えます（サーバは落ちません）。

## 開発

```bash
cd packages/mcp
npm install
npm run typecheck
npm test          # vitest（ツールハンドラの単体テスト、実 API 不要）
npm run build     # dist/index.js（stdio 実行ファイル）を生成
```

内部では公式 Node.js SDK [`@staddress/client`](../node/) を利用しています。

## レジストリ掲載（露出向上）

MCP ディレクトリに掲載されると継続的な流入が見込めます。

- **Smithery**: リポジトリ直下に [`smithery.yaml`](../../smithery.yaml) を用意済み。[smithery.ai](https://smithery.ai) でリポジトリ `StaddressAI/staddress-tools` を接続すると掲載できます。
- **mcp.so**: [mcp.so](https://mcp.so) の submit から npm パッケージ `@staddress/mcp` を登録。
- **Cursor Directory**: [cursor.com/directory](https://cursor.com/directory) の MCP 一覧に申請。
- **公式 MCP レジストリ**: [registry.modelcontextprotocol.io](https://registry.modelcontextprotocol.io)（`mcp-publisher` CLI で公開）。

詳細: [docs/plan-tools.md §5](../../docs/plan-tools.md)
