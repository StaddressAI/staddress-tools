# Staddress AI API リファレンス（要約）

> **公式ドキュメント:** [https://staddress.com/api](https://staddress.com/api)  
> 本ファイルは開発用のクイックリファレンス。詳細・最新仕様は公式を参照すること。

## 認証

```
X-Api-Key: <APIキー>
Content-Type: application/json
```

## エンドポイント一覧（本リポジトリのクライアント対象）

| 操作 | Method | Path | プラン |
|------|--------|------|--------|
| 利用状況 | GET | `/api/v1/usage` | 全 |
| 単件解析 | POST | `/api/v1/addresses/parse` | 全 |
| 一括解析 | POST | `/api/v1/addresses/parse/batch` | Standard+ |

## 対象外（本リポジトリではクライアント未提供）

CSV アップロード／ダウンロード（`/api/v1/csv/upload`・`/api/v1/csv/download`）は Enterprise 専用であり、契約時に別途サポート契約で対応する。公式仕様は [staddress.com/api](https://staddress.com/api) を参照。

## 単件解析リクエスト

```json
{
  "input": "東京都渋谷区道玄坂1-2 マンション桜 101号",
  "postalCode": "150-0043"
}
```

- `input`: 必須、最大100文字
- `postalCode`: 任意、最大8文字

## 単件解析レスポンス（成功）

```json
{
  "result": {
    "normalized": "東京都渋谷区道玄坂1丁目1-2 マンション桜 101号",
    "standard": "東京都渋谷区道玄坂一丁目1-2 マンション桜 101号",
    "components": {
      "pref": "東京都",
      "prefCode": "13",
      "city": "渋谷区",
      "lat": 35.6579505,
      "lon": 139.7008699
    },
    "confidence": {
      "score": 0.95,
      "matchLevel": "residential_detail",
      "query": "東京都渋谷区道玄坂1丁目1-2"
    }
  }
}
```

## 一括解析リクエスト

```json
{
  "items": [
    { "id": "req-001", "address": "東京都渋谷区道玄坂1-2-3", "postalCode": "150-0002" },
    { "id": "req-002", "address": "大阪府大阪市北区梅田1-1-1" }
  ]
}
```

- 最大100件 / リクエスト
- 各 item に `id`（必須）と `address`（必須）

## エラーコード

| code | HTTP | 説明 |
|------|------|------|
| `invalid_request` | 400 | リクエスト不正 |
| `batch_size_exceeded` | 400 | 一括100件超過 |
| `unauthorized` | 401 | APIキー無効 |
| `quota_exceeded` | 402 | 利用上限超過 |
| `forbidden` | 403 | プラン権限なし |
| `not_found` | 404 | リソースなし |
| `unresolved` | 422 | 住所解析不能 |
| `internal_error` | 500 | サーバーエラー |

## 別紙1 との対応

| 別紙1 要件 | API |
|------------|-----|
| 5.1.1 単件住所解析 | POST `/api/v1/addresses/parse` |
| 5.1.2 一括住所解析 | POST `/api/v1/addresses/parse/batch` |
| 5.1.3 信頼度評価 | `result.confidence`（ABR 照合） |
| 5.1.4 エラーハンドリング | 上記エラーコード + SDK 例外 |
