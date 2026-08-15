# staddress (Ruby Gem)

Staddress AI API 公式 Ruby SDK。

## ステータス

**Phase 4 — v0.1 公開済み**（[RubyGems: staddress](https://rubygems.org/gems/staddress)。`parse_address` / `parse_batch` / `get_usage`）

- HTTP: 標準ライブラリ `net/http`（**ランタイム依存なし**）
- Ruby 3.1+

## インストール

```bash
gem install staddress
```

```ruby
# Gemfile
gem "staddress"
```

## 使い方

```ruby
require "staddress"

client = Staddress::Client.new(
  api_key: "sk_xxx",                      # 省略時は環境変数 STADDRESS_API_KEY
  base_url: "https://api.staddress.com",  # 省略時は既定値（STADDRESS_BASE_URL も可）
  timeout: 30                             # 任意（秒）
)

# 単件解析
result = client.parse_address(input: "六本木ヒルズ 森タワー 52F", postal_code: "106-6100")
puts result.normalized
puts result.components.pref

# 一括解析（Standard プラン以上、最大 100 件）
results = client.parse_batch([
  { id: "1", address: "東京都渋谷区道玄坂1-2-3" },
  { id: "2", address: "大阪府大阪市北区梅田1-1-1" }
])
results.each { |item| puts "#{item.id}: #{item.result&.normalized}" }

# 利用状況
usage = client.get_usage
puts "#{usage.plan} / #{usage.account_name}"
```

## エラーハンドリング

API エラー・ネットワークエラーは `Staddress::Error` として送出されます。

```ruby
begin
  client.parse_address(input: "...")
rescue Staddress::Error => err
  err.code         # 例: "unauthorized", "quota_exceeded", "unresolved"
  err.http_status  # HTTP ステータス（ネットワークエラー時は 0）
  err.request_id   # サポート問い合わせ用（あれば）
  err.retry_after  # 再試行可能日時（あれば）
end
```

## API

| メソッド | HTTP | 説明 |
| --- | --- | --- |
| `parse_address(input:, postal_code: nil)` | `POST /api/v1/addresses/parse` | 単件解析 → `Models::ParseResult` |
| `parse_batch(items)` | `POST /api/v1/addresses/parse/batch` | 一括解析 → `Array<Models::BatchItemResult>` |
| `get_usage` | `GET /api/v1/usage` | 利用状況 → `Models::UsageResponse` |

レスポンスモデルは snake_case アクセサ（`match_level` 等）でアクセスでき、未知フィールドは `#raw`（元の Hash）から参照できます。

## 開発

```bash
cd packages/ruby
bundle install
bundle exec rspec     # 単体テスト（webmock でモック、実 API 不要）
gem build staddress.gemspec
```

詳細: [docs/plan-tools.md §3.6](../../docs/plan-tools.md)
