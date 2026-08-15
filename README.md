# staddress-tools

[![CI](https://github.com/StaddressAI/staddress-tools/actions/workflows/smoke.yml/badge.svg)](https://github.com/StaddressAI/staddress-tools/actions/workflows/smoke.yml)
[![npm](https://img.shields.io/npm/v/@staddress/client.svg?label=npm%20%40staddress%2Fclient)](https://www.npmjs.com/package/@staddress/client)
[![PyPI](https://img.shields.io/pypi/v/staddress.svg?label=PyPI%20staddress)](https://pypi.org/project/staddress/)
[![Gem](https://img.shields.io/gem/v/staddress.svg?label=gem%20staddress)](https://rubygems.org/gems/staddress)
[![MCP](https://img.shields.io/npm/v/@staddress/mcp.svg?label=npm%20%40staddress%2Fmcp)](https://www.npmjs.com/package/@staddress/mcp)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

[![Add to Cursor](https://cursor.com/deeplink/mcp-install-dark.svg)](cursor://anysphere.cursor-deeplink/mcp/install?name=staddress&config=eyJjb21tYW5kIjoibnB4IiwiYXJncyI6WyIteSIsIkBzdGFkZHJlc3MvbWNwIl0sImVudiI6eyJTVEFERFJFU1NfQVBJX0tFWSI6IiJ9fQ==)

Staddress AI（ストアドレス）住所解析サービス向けの **クライアントツール群** および **汎用 AI エージェント** の開発リポジトリ。

- 公式 API 仕様: [https://staddress.com/api](https://staddress.com/api)

## このリポジトリについて

Staddress AI（住所解析サービス）の解析精度を確認するだけであれば、**GUI で手軽に行えます**。まずは [公式サイト](https://staddress.com) からお試しください。

**コードで動作検証や開発を行う場合**に、本リポジトリが役立ちます。さまざまなプログラミング言語から Staddress AI API を利用できるよう、**サンプルコード**および**各言語に対応した SDK（ライブラリ）**を提供します。

## リポジトリ構成

```
staddress-tools/
├── README.md                 # 本ファイル
├── .env.example              # 環境変数テンプレート
├── docs/                     # 設計・計画・仕様書
├── examples/
│   ├── curl/                 # curl サンプル
│   └── powershell/           # PowerShell サンプル
├── openapi/                  # Staddress API OpenAPI 定義
├── packages/
│   ├── cli/                  # staddress シェルコマンド
│   ├── node/                 # Node.js SDK (@staddress/client)
│   ├── python/               # Python SDK (staddress)
│   ├── ruby/                 # Ruby Gem (staddress)
│   └── mcp/                  # MCP サーバー (@staddress/mcp)
├── agent/                    # 汎用 AI エージェント
└── tests/                    # 横断テスト・フィクスチャ
```

## 利用方法

事前に、リポジトリルートで環境変数を設定します。

```bash
cp .env.example .env
# STADDRESS_API_KEY と STADDRESS_BASE_URL を設定
```

| 変数 | 説明 |
|------|------|
| `STADDRESS_API_KEY` | API キー（[取得方法は .env.example を参照](.env.example)） |
| `STADDRESS_BASE_URL` | ベース URL（既定: `https://api.staddress.com`） |

### curl サンプル（Mac／Linux 向け）

```bash
source .env
./examples/curl/staddress.sh -s "六本木ヒルズ 森タワー 52F"
```

詳細は [`examples/curl/`](examples/curl/) を参照。

### PowerShell サンプル（Windows 向け）

```powershell
.\examples\powershell\staddress.ps1 -Single "六本木ヒルズ 森タワー 52F"
```

詳細は [`examples/powershell/`](examples/powershell/) を参照。

### Shell CLI（`staddress`）

ターミナル向けの `staddress` コマンドを提供しています（詳細: [`packages/cli/`](packages/cli/)）。

```bash
cd packages/cli && ./install.sh
staddress config set api-key <あなたのキー>

staddress parse "東京都渋谷区道玄坂1-2 マンション桜 101号"
staddress usage
staddress batch --file addresses.json
```

### 各言語 SDK（開発予定）

Node.js / Python / Ruby などの SDK を順次提供予定です（[開発ロードマップ](#開発ロードマップ) を参照）。

## 開発ロードマップ

詳細は [docs/plan-tools.md](docs/plan-tools.md) を参照。

| フェーズ | 内容 | 状態 |
|--------|------|------|
| 1 | curl サンプル | 完了 |
| 2 | PowerShell サンプル | 完了 |
| 3 | Shell CLI | 完了 |
| 4 | Node.js SDK | 完了（[npm 公開](https://www.npmjs.com/package/@staddress/client)） |
| 5 | Python SDK | 完了（[PyPI 公開](https://pypi.org/project/staddress/)） |
| 6 | Ruby SDK | 完了（[RubyGems 公開](https://rubygems.org/gems/staddress)） |
| 7 | MCP サーバー（`@staddress/mcp`） | 完了（[npm 公開](https://www.npmjs.com/package/@staddress/mcp)・Cursor / Claude 対応） |
| 8 | その他言語（Go / PHP 等） | 計画中 |
| 9 | 汎用 AI エージェント | 未着手 |

## Agent Plugins マニフェスト（Cursor Directory 等の自動検出用）

リポジトリ直下の `plugin.json` と `mcp.json` は [Agent Plugins（Open Plugins）標準](https://open-plugins.com) のマニフェストです。Cursor Directory などのレジストリがこれを自動検出し、MCP サーバー `@staddress/mcp` をプラグインとして掲載します（**削除しないでください**）。

- `plugin.json`: プラグイン名・メタデータ（`$schema` は Agent Plugins 1.0.0）
- `mcp.json`: MCP サーバー定義（stdio、`npx -y @staddress/mcp`）。API キーは各クライアントの環境変数 `STADDRESS_API_KEY` で指定します。

## ライセンス

[MIT License](LICENSE) © 2026 StaddressAI
