# Staddress クライアントツール群 開発計画

**版数:** 0.5  
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
| 2 | **PowerShell サンプル** | `.ps1` スクリプト | Windows で `./staddress.ps1 -Single "..."` |
| 3 | **Shell CLI** | `install.sh` / Homebrew（将来） | `staddress parse "..."` |
| 4 | **Node.js SDK** | npm / yarn | `import { StaddressClient } from '@staddress/client'` |
| 5 | **Python SDK** | pip / uv | `from staddress import Client` |
| 6 | **Ruby Gem** | gem | `Staddress::Client.new` |
| 7 | **Go module**（Phase 5） | go get | `staddress.NewClient()` |
| 8 | **PHP Composer**（Phase 5） | packagist | 同上 |

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

### 3.1 curl サンプル（Phase 0）✅ 完了

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

### 3.2 PowerShell サンプル（Phase 0）

**目的:** Windows ユーザーが追加ツール（`curl` / `jq`）なしで API を試せるようにする。PowerShell 標準機能のみで完結。

**配置:** `examples/powershell/`

| ファイル | 内容 |
|----------|------|
| `staddress.ps1` | 統合スクリプト（usage / single / batch） |
| `batch-sample.json` | 一括解析用サンプル JSON |
| `README.md` | 実行方法・実行ポリシーの説明 |

**対応環境:**

- Windows PowerShell 5.1（Windows 10 / 11 標準搭載）
- PowerShell 7+（クロスプラットフォーム）

**実装方針:**

- HTTP は `Invoke-RestMethod`（標準コマンドレット、外部依存なし）
- JSON は `ConvertTo-Json` / `ConvertFrom-Json`（`jq` 不要）
- 認証ヘッダ `X-Api-Key` を `-Headers` で付与
- 設定読み込み: リポジトリルートの `.env` を解析、または環境変数 `$env:STADDRESS_API_KEY` / `$env:STADDRESS_BASE_URL`
- パラメータ: `-Usage` / `-Single <住所> [-PostalCode <code>]` / `-Batch <path>` / `-Help`

**実行例:**

```powershell
# 利用状況
./staddress.ps1 -Usage

# 単件解析
./staddress.ps1 -Single "六本木ヒルズ 森タワー 52F"
./staddress.ps1 -Single "東京都渋谷区道玄坂1-2 マンション桜 101号" -PostalCode "150-0043"

# 一括解析
./staddress.ps1 -Batch .\batch-sample.json
```

**受け入れ基準:**

- Windows 標準の PowerShell 5.1 で追加インストールなしに動作
- `Invoke-RestMethod` の例外（4xx / 5xx）を捕捉し、API エラー JSON を整形表示
- API キー未設定時に明確なエラーメッセージ
- 終了コード（0=成功, 1=APIエラー, 2=設定エラー）
- 実行ポリシー対策として `pwsh -File ./staddress.ps1 ...` の実行手順を README に明記

---

### 3.3 Shell CLI — `staddress` コマンド（Phase 1）✅ v0.1 実装済み

**目的:** ターミナルから住所解析・利用状況確認を行う。DevOps / 運用向け。

**配置:** `packages/cli/`

**実装状況（v0.1）:**

- `bin/staddress`（エントリポイント、symlink 経由の呼び出しに対応）
- `lib/`（設定解決・HTTP・エラー処理・`parse` / `batch` / `usage` / `config` サブコマンド）
- `install.sh`（`~/.local/bin` または `/usr/local/bin` へ symlink、`--prefix` / `--uninstall` 対応）
- `tests/run.sh`（curl をモック化した実 API 不要の単体テスト、18 ケース）

**インストール方法:**

```bash
# 方法 A: リポジトリを clone してローカルインストール
#   （CLI は bin/staddress と lib/*.sh の複数ファイル構成のため、リポジトリ一式が必要）
git clone https://github.com/StaddressAI/staddress-tools.git
cd staddress-tools/packages/cli && ./install.sh

# 方法 B（将来）: Homebrew
brew install staddress/tap/staddress
```

> 注: `install.sh` は同じディレクトリの `bin`・`lib` を配置先へ symlink するため、`curl ... install.sh | bash` の単体パイプ実行では動作しません。上記の clone 手順を使用してください。

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

- `staddress parse "六本木ヒルズ 森タワー 52F"` が JSON を返す ✅
- API キー未設定時に明確なエラーメッセージ ✅
- `--help` / 終了コード（0=成功, 1=APIエラー, 2=設定エラー）✅

---

### 3.4 Node.js SDK（Phase 2）✅ v0.1 実装済み

**目的:** Web アプリ、サーバーレス、AI エージェント（TypeScript）から利用。

**配置:** `packages/node/`

**実装状況（v0.1）:**

- `src/client.ts`（`StaddressClient`: `parseAddress` / `parseBatch` / `getUsage`、タイムアウト・AbortController 対応）
- `src/errors.ts`（`StaddressError`: `code` / `httpStatus` / `requestId` / `retryAfter`）
- `src/types.ts`（OpenAPI 準拠の型を公開）
- 依存パッケージなし（Node 18+ ネイティブ `fetch`）、tsup による ESM/CJS デュアル + 型定義出力
- `test/client.test.ts`（vitest + fetch モック、14 ケース）

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
- ビルド: `tsup`（ESM/CJS + 型定義）
- テスト: `vitest`（`fetch` をモック化。MSW は依存追加を避けるため v0.1 では不採用）
- 型: API レスポンスの TypeScript 型を `src/types.ts` で公開

**公開:**

- npm registry（`@staddress` scope）
- `exports` フィールドで ESM / CJS デュアルパッケージ

---

### 3.5 Python SDK（Phase 3）✅ v0.1 公開済み（PyPI: staddress 0.1.0）

**目的:** データパイプライン、バッチ処理、FastAPI エージェントから利用。

**配置:** `packages/python/`

**公開:** [PyPI: staddress](https://pypi.org/project/staddress/)（Trusted Publishing。タグ `py-v0.1.0` push で `publish-python.yml` が自動公開）

**実装状況（v0.1）:**

- `src/staddress/client.py`（`StaddressClient` 同期 + `StaddressAsyncClient` 非同期、`parse_address` / `parse_batch` / `get_usage`、タイムアウト・コンテキストマネージャ対応）
- `src/staddress/errors.py`（`StaddressError`: `code` / `http_status` / `request_id` / `retry_after`）
- `src/staddress/models.py`（pydantic v2、camelCase↔snake_case alias、`py.typed` 同梱）
- HTTP は `httpx`、`tests/test_client.py`（pytest + `httpx.MockTransport`、同期/非同期 16 ケース）

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
- テスト: `pytest` + `httpx.MockTransport`（実 API 不要。追加依存を避けるため pytest-httpx/respx は不採用）
- 配布: PyPI（trusted publishing）

**追加:** `StaddressAsyncClient` を async/await 用に提供。

---

### 3.6 Ruby Gem（Phase 4）✅ v0.1 実装済み

**目的:** Rails アプリ、Ruby バッチから利用。

**配置:** `packages/ruby/`

**実装状況（v0.1）:**

- `lib/staddress/client.rb`（`Staddress::Client`、`parse_address` / `parse_batch` / `get_usage`、タイムアウト対応）
- `lib/staddress/errors.rb`（`Staddress::Error`: `code` / `http_status` / `request_id` / `retry_after`）
- `lib/staddress/models.rb`（camelCase→snake_case マッピング、未知フィールドは `#raw` から参照）
- HTTP は標準 `net/http`（**ランタイム依存なし**）、`spec/`（rspec + webmock、15 ケース）

**Gem 名:** `staddress`

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
- HTTP: 標準 `net/http`（ランタイム依存を増やさないため faraday は不採用）
- テスト: `rspec` + `webmock`（実 API 不要）
- 配布: RubyGems（Trusted Publishing。タグ `ruby-v*` push で `publish-ruby.yml` が公開）

---

### 3.7 その他言語（Phase 5 — 需要に応じて）

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
| **0** | 2026年6月 第1週 | curl サンプル、OpenAPI、本計画書、README（完了） |
| **0** | 2026年6月 第2週 | PowerShell サンプル（Windows 向け）（完了） |
| **1** | 2026年6月 第2–3週 | Shell CLI v0.1（parse / usage / batch / config）（完了） |
| **2** | 2026年7月 第1–2週 | Node.js SDK v0.1 + npm 公開準備（完了） |
| **3** | 2026年7月 第3–4週 | Python SDK v0.1 + PyPI 公開（完了・公開済み） |
| **4** | 2026年8月 第1週 | Ruby Gem v0.1（完了） |
| **5** | 2026年8月 第2週 | Go / PHP（需要確認後） |
| **6** | 2026年8月–9月 | AI エージェント本体 |
| **7** | 2026年9月–10月 | MCP / 連携仕様書 |

---

## 7. ディレクトリ詳細（確定版）

```
staddress-tools/
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
│   ├── curl/
│   │   ├── README.md
│   │   ├── _common.sh
│   │   ├── batch-sample.json
│   │   └── staddress.sh
│   └── powershell/
│       ├── README.md
│       ├── batch-sample.json
│       └── staddress.ps1
├── packages/
│   ├── cli/
│   │   ├── README.md
│   │   ├── install.sh
│   │   ├── bin/staddress
│   │   ├── lib/                   # common.sh, cmd_parse.sh, cmd_batch.sh, cmd_usage.sh, cmd_config.sh
│   │   └── tests/run.sh
│   ├── node/
│   │   ├── README.md
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   ├── tsup.config.ts
│   │   ├── src/                   # index.ts, client.ts, errors.ts, types.ts
│   │   └── test/client.test.ts
│   ├── python/
│   │   ├── README.md
│   │   ├── pyproject.toml
│   │   ├── src/staddress/         # __init__.py, client.py, errors.py, models.py, py.typed
│   │   └── tests/test_client.py
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
| 1 | ~~npm scope~~（確定） | **`@staddress/client`** に決定。`publishConfig.access=public` / `provenance=true` を設定済み。GitHub Release で自動公開（`.github/workflows/publish-node.yml`、要 `NPM_TOKEN`） |
| 2 | CLI 配布 | install.sh のみ vs Homebrew tap |
| 3 | 公開レジストリ | npm / PyPI を公式アカウントで公開するか |
| 4 | v0 API サポート | `POST /api/v0/addresses/parse` を SDK に含めるか |
| 5 | モノレポ CI | GitHub Actions で変更パッケージのみテスト |

---

## 9. 改訂履歴

| 版数 | 日付 | 変更内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初版（ツール群計画・ディレクトリ構成） |
| 0.2 | 2026-06-28 | curl サンプル完了。PowerShell サンプル（Windows 向け）の計画を追加 |
| 0.3 | 2026-07-25 | Shell CLI v0.1 実装完了（parse / batch / usage / config、install.sh、単体テスト） |
| 0.4 | 2026-07-25 | Node.js SDK v0.1 実装完了（StaddressClient、StaddressError、型定義、vitest） |
| 0.5 | 2026-08-09 | Python SDK v0.1 実装完了（同期/非同期クライアント、pydantic v2、pytest） |
| 0.6 | 2026-08-09 | Python SDK v0.1 を PyPI 公開（staddress 0.1.0、Trusted Publishing）。公開トリガーをタグ方式（py-v* / node-v*）へ変更 |
| 0.7 | 2026-08-15 | Ruby Gem v0.1 実装完了（Staddress::Client、net/http、rspec + webmock）。RubyGems 公開ワークフロー（ruby-v*）を追加 |
