# Staddress クライアントツール群 開発計画

**版数:** 0.1  
**作成日:** 2026年6月  
**参照:** [Staddress API リファレンス](https://staddress.com/api)  

---

## 1. 目的

[Staddress AI API](https://staddress.com/api) を、開発者が **言語・環境を問わず** 利用できるようにするクライアントツール群を整備する。  
最終的には **汎用 AI エージェント** が、これらの SDK / CLI を内部で利用する。

### 1.1 提供するツール（全体像）

| # | ツール | 配布形式 | 利用イメージ |
|---|--------|----------|--------------|
| 1 | **curl サンプル** | シェルスクリプト | API を試す・CI で smoke test |
| 2 | **Shell CLI** | `install.sh` / Homebrew（将来） | `staddress parse "..."` |
| 3 | **Node.js SDK** | npm / yarn | `import { StaddressClient } from '@staddress/client'` |
| 4 | **Python SDK** | pip / uv | `from staddress import Client` |
| 5 | **Ruby Gem** | gem | `Staddress::Client.new` |
| 6 | **Go module**（Phase 5） | go get | `staddress.NewClient()` |
| 7 | **PHP Composer**（Phase 5） | packagist | 同上 |

---

## 2. 対象 API（共通実装範囲）

すべてのクライアントで **同一のメソッド名・意味** を提供する（命名は各言語の慣習に従う）。

| API | メソッド | HTTP | パス | プラン制限 |
|-----|----------|------|------|------------|
| 利用状況取得 | `getUsage()` | GET | `/api/v1/usage` | 全プラン |
| 単件住所解析 | `parseAddress(input, postalCode?)` | POST | `/api/v1/addresses/parse` | 全プラン |
| 一括住所解析 | `parseBatch(items[])` | POST | `/api/v1/addresses/parse/batch` | Standard+ |

> **対象外:** CSV アップロード／ダウンロード（Enterprise 専用）は別途サポート契約で対応するため、本リポジトリの curl サンプル・SDK・CLI では提供しない。公式 API 仕様は [staddress.com/api](https://staddress.com/api) を参照。

### 2.1 認証・設定（全ツール共通）

| 項目 | 仕様 |
|------|------|
| 認証ヘッダ | `X-Api-Key: <APIキー>` |
| Content-Type | `application/json` |
| ベース URL | 環境変数 `STADDRESS_BASE_URL` または設定ファイル |
| API キー | 環境変数 `STADDRESS_API_KEY` または設定ファイル |
| タイムゾーン | API レスポンスの日時は JST（+09:00） |

**設定の優先順位（CLI / SDK 共通）:**

```
1. 明示的なコンストラクタ引数 / CLI フラグ (--api-key, --base-url)
2. 環境変数 (STADDRESS_API_KEY, STADDRESS_BASE_URL)
3. 設定ファイル (~/.config/staddress/config または ./.staddressrc)
```

### 2.2 エラーハンドリング（全ツール共通）

API エラー形式（[公式仕様](https://staddress.com/api)）:

```json
{
  "error": {
    "code": "quota_exceeded",
    "message": "今月の住所解析の件数上限に達しました。",
    "requestId": "...",
    "retryAfter": "2024-03-01T00:00:00+09:00"
  }
}
```

各 SDK は **`StaddressError`**（言語ごとの例外クラス）を定義し、以下を保持する:

- `code` — `unauthorized`, `quota_exceeded`, `unresolved` 等
- `message` — 人間可読メッセージ
- `httpStatus` — HTTP ステータスコード
- `requestId` — サポート用（任意）
- `retryAfter` — 402 時の再試行可能日時（任意）

422（住所解析不能）では `result: null` と `error` が返る。一括 API では件ごとに成功/失敗が混在する。

---

## 3. ツール別詳細計画

### 3.1 curl サンプル（Phase 0）✅ 優先

**目的:** API 仕様の検証、ドキュメント、CI smoke test のベース。

**配置:** `examples/curl/`

| ファイル | 内容 |
|----------|------|
| `staddress.sh` | 統合スクリプト（usage / single / batch） |
| `_common.sh` | 環境変数読み込み・共通関数 |
| `README.md` | 各サンプルの説明 |

**受け入れ基準:**

- `.env` を source するだけで実行可能
- `jq` で JSON を整形表示（未インストール時は raw 出力にフォールバック）
- 代表入力例（`六本木ヒルズ 森タワー 52F`）を含む

---

### 3.2 Shell CLI — `staddress` コマンド（Phase 1）

**目的:** ターミナルから住所解析・利用状況確認を行う。DevOps / 運用向け。

**配置:** `packages/cli/`

**インストール方法（案）:**

```bash
# 方法 A: install スクリプト
curl -fsSL https://raw.githubusercontent.com/StaddressAI/staddress-agent/main/packages/cli/install.sh | bash

# 方法 B: リポジトリからローカルインストール
cd packages/cli && ./install.sh

# 方法 C（将来）: Homebrew
brew install staddress/tap/staddress
```

**コマンド設計:**

```
staddress
├── parse <address>              # 単件解析
│   └── --postal-code, -p <code>
│   └── --json                   # JSON 出力（デフォルト）
│   └── --pretty                 # 人間可読テーブル出力
├── batch
│   └── --file, -f <path>        # JSON 入力
│   └── --stdin                  # 標準入力から
├── usage                          # 利用状況
├── config
│   ├── set api-key <key>
│   ├── set base-url <url>
│   └── show
└── version
```

**実装方針:**

- **コア:** POSIX 互換シェル + `curl` + `jq`（必須依存）
- **設定:** `~/.config/staddress/config`（INI 風 key=value）
- **バイナリ配置:** `install.sh` が `/usr/local/bin/staddress` または `~/.local/bin/staddress` に symlink
- **テスト:** `bats` または `shellspec` + mock curl

**受け入れ基準:**

- `staddress parse "六本木ヒルズ 森タワー 52F"` が JSON を返す
- API キー未設定時に明確なエラーメッセージ
- `--help` / 終了コード（0=成功, 1=APIエラー, 2=設定エラー）

---

### 3.3 Node.js SDK（Phase 2）

**目的:** Web アプリ、サーバーレス、AI エージェント（TypeScript）から利用。

**配置:** `packages/node/`

**パッケージ名（案）:** `@staddress/client`

**インストール:**

```bash
npm install @staddress/client
# または
yarn add @staddress/client
pnpm add @staddress/client
```

**API 設計（案）:**

```typescript
import { StaddressClient, StaddressError } from '@staddress/client';

const client = new StaddressClient({
  apiKey: process.env.STADDRESS_API_KEY,
  baseUrl: process.env.STADDRESS_BASE_URL,
  timeout: 30_000,
});

// 単件解析
const { result } = await client.parseAddress({
  input: '六本木ヒルズ 森タワー 52F',
  postalCode: '106-6100', // 任意
});

// 一括解析
const { results } = await client.parseBatch({
  items: [
    { id: '1', address: '東京都渋谷区道玄坂1-2-3' },
    { id: '2', address: '大阪府大阪市北区梅田1-1-1' },
  ],
});

// 利用状況
const usage = await client.getUsage();
```

**技術スタック:**

- TypeScript 5+
- 依存: なし（`fetch` ネイティブ、Node 18+）または `undici`（Node 16 互換が必要な場合）
- ビルド: `tsup` / `tsc`
- テスト: `vitest` + MSW（Mock Service Worker）
- 型: API レスポンスの TypeScript 型を `src/types.ts` で公開

**公開:**

- npm registry（`@staddress` scope）
- `exports` フィールドで ESM / CJS デュアルパッケージ

---

### 3.4 Python SDK（Phase 3）

**目的:** データパイプライン、バッチ処理、FastAPI エージェントから利用。

**配置:** `packages/python/`

**パッケージ名（案）:** `staddress`

**インストール:**

```bash
pip install staddress
# または
uv add staddress
poetry add staddress
```

**API 設計（案）:**

```python
from staddress import StaddressClient, StaddressError

client = StaddressClient(
    api_key=os.environ["STADDRESS_API_KEY"],
    base_url=os.environ["STADDRESS_BASE_URL"],
)

result = client.parse_address(
    input="六本木ヒルズ 森タワー 52F",
    postal_code="106-6100",  # optional
)

results = client.parse_batch([
    {"id": "1", "address": "東京都渋谷区道玄坂1-2-3"},
    {"id": "2", "address": "大阪府大阪市北区梅田1-1-1"},
])

usage = client.get_usage()
```

**技術スタック:**

- Python 3.11+
- HTTP: `httpx`（sync + async 両対応）
- 型: `pydantic` v2 モデル
- テスト: `pytest` + `pytest-httpx` / `respx`
- 配布: PyPI

**追加:** `StaddressAsyncClient` を async/await 用に提供。

---

### 3.5 Ruby Gem（Phase 4）

**目的:** Rails アプリ、Ruby バッチから利用。

**配置:** `packages/ruby/`

**Gem 名（案）:** `staddress`

**インストール:**

```bash
gem install staddress
# Gemfile
gem 'staddress'
```

**API 設計（案）:**

```ruby
client = Staddress::Client.new(
  api_key: ENV['STADDRESS_API_KEY'],
  base_url: ENV['STADDRESS_BASE_URL']
)

result = client.parse_address(
  input: '六本木ヒルズ 森タワー 52F',
  postal_code: '106-6100'
)

results = client.parse_batch([
  { id: '1', address: '東京都渋谷区道玄坂1-2-3' },
  { id: '2', address: '大阪府大阪市北区梅田1-1-1' }
])

usage = client.get_usage
```

**技術スタック:**

- Ruby 3.1+
- HTTP: `faraday` または標準 `net/http`
- テスト: `rspec` + `webmock`
- 配布: RubyGems

---

### 3.6 その他言語（Phase 5 — 需要に応じて）

| 言語 | パッケージ名（案） | 優先度 | 理由 |
|------|-------------------|--------|------|
| Go | `github.com/StaddressAI/staddress-go` | 中 | インフラ・CLI 代替 |
| PHP | `staddress/staddress-php` | 中 | EC・CMS 連携 |
| Java/Kotlin | `com.staddress:client` | 低 | エンタープライズ |
| Rust | `staddress` crate | 低 | 高性能バッチ |

**方針:** OpenAPI 定義（`openapi/staddress-api.yaml`）からコード生成を検討し、手書き SDK との整合を保つ。

---

## 4. 共通設計原則

### 4.1 命名規約（言語間マッピング）

| 概念 | Node.js | Python | Ruby | CLI |
|------|---------|--------|------|-----|
| 単件解析 | `parseAddress()` | `parse_address()` | `parse_address` | `staddress parse` |
| 一括解析 | `parseBatch()` | `parse_batch()` | `parse_batch` | `staddress batch` |
| 利用状況 | `getUsage()` | `get_usage()` | `get_usage` | `staddress usage` |

### 4.2 型・モデル（共通）

すべての SDK で以下の型をエクスポート:

- `ParseResult` — normalized, standard, components, confidence
- `AddressComponents` — pref, city, oazaCho, lat, lon, ...
- `Confidence` — score, matchLevel, query
- `BatchItem` — id, address, postalCode（入力）/ id, result|error（出力）
- `UsageResponse` — accountName, plan, usage
- `StaddressError` — 統一例外

### 4.3 テスト戦略

```
tests/
├── fixtures/           # モック JSON レスポンス
│   ├── parse-success.json
│   ├── parse-unresolved.json
│   └── batch-mixed.json
├── integration/        # 実 API（CI では SKIP 可能）
└── contract/           # OpenAPI スキーマ準拠テスト
```

- **単体テスト:** 各 SDK がモック HTTP で 100% エンドポイントカバー
- **結合テスト:** `STADDRESS_API_KEY` がある環境でのみ実行（GitHub Actions secrets）
- **契約テスト:** レスポンスが OpenAPI スキーマに適合

### 4.4 セキュリティ

- API キーをソースコードにハードコードしない
- ログに API キーを出力しない
- 設定ファイルのパーミッション推奨: `600`

---

## 5. AI エージェントとの関係（Phase 6）

汎用 AI エージェント（`agent/`）は、内部で **Python SDK または Node.js SDK** を Tool 実装層として利用する。

```
ユーザー / 他エージェント
        ↓
  agent/ (REST API / MCP)
        ↓
  packages/python または packages/node
        ↓
  Staddress AI API
```

**Tool 定義（OpenAI 互換）** は `agent/tools/` に JSON Schema として配置し、SDK のメソッドと 1:1 対応させる。

| Tool 名 | SDK メソッド |
|---------|-------------|
| `staddress_parse` | `parseAddress` |
| `staddress_parse_batch` | `parseBatch` |
| `staddress_get_usage` | `getUsage` |

---

## 6. 開発スケジュール（案）

| フェーズ | 期間 | 成果物 |
|--------|------|--------|
| **0** | 2026年6月 第1週 | curl サンプル、OpenAPI、本計画書、README |
| **1** | 2026年6月 第2–3週 | Shell CLI v0.1（parse / usage / batch） |
| **2** | 2026年7月 第1–2週 | Node.js SDK v0.1 + npm 公開準備 |
| **3** | 2026年7月 第3–4週 | Python SDK v0.1 + PyPI 公開準備 |
| **4** | 2026年8月 第1週 | Ruby Gem v0.1 |
| **5** | 2026年8月 第2週 | Go / PHP（需要確認後） |
| **6** | 2026年8月–9月 | AI エージェント本体 |
| **7** | 2026年9月–10月 | MCP / 連携仕様書 |

---

## 7. ディレクトリ詳細（確定版）

```
staddress-agent/
├── README.md
├── .env.example
├── .gitignore
├── docs/
│   ├── plan-tools.md              # 本ファイル
│   ├── api-reference.md           # API 要約（公式へのリンク付き）
│   └── agent-architecture.md      # Phase 6 用（後日）
├── openapi/
│   └── staddress-api.yaml         # OpenAPI 3.1
├── examples/
│   └── curl/
│       ├── README.md
│       ├── _common.sh
│       └── staddress.sh
├── packages/
│   ├── cli/
│   │   ├── README.md
│   │   ├── install.sh
│   │   ├── bin/staddress
│   │   └── lib/
│   ├── node/
│   │   ├── README.md
│   │   ├── package.json
│   │   └── src/
│   ├── python/
│   │   ├── README.md
│   │   ├── pyproject.toml
│   │   └── src/staddress/
│   └── ruby/
│       ├── README.md
│       ├── staddress.gemspec
│       └── lib/staddress/
├── agent/                         # Phase 6
│   └── README.md
└── tests/
    └── fixtures/
```

---

## 8. 未決事項

| # | 項目 | 選択肢 |
|---|------|--------|
| 1 | npm scope | `@staddress/client` vs `@staddressai/client` |
| 2 | CLI 配布 | install.sh のみ vs Homebrew tap |
| 3 | 公開レジストリ | npm / PyPI を公式アカウントで公開するか |
| 4 | v0 API サポート | `POST /api/v0/addresses/parse` を SDK に含めるか |
| 5 | モノレポ CI | GitHub Actions で変更パッケージのみテスト |

---

## 9. 改訂履歴

| 版数 | 日付 | 変更内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初版（ツール群計画・ディレクトリ構成） |
