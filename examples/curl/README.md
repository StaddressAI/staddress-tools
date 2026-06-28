# curl サンプル

Staddress AI API を curl で呼び出すサンプル集。

## 前提

1. リポジトリルートで `.env` を作成（`.env.example` をコピー）
2. `STADDRESS_BASE_URL` と `STADDRESS_API_KEY` を設定
3. 推奨: [`jq`](https://jqlang.github.io/jq/) をインストール（JSON 整形・単件解析用）

```bash
cp ../../.env.example ../../.env
# .env を編集
```

## 統合スクリプト

`staddress.sh` に利用状況・単件・一括の3機能をまとめています。

```bash
# 利用案内
./staddress.sh

# 利用状況
./staddress.sh -u
./staddress.sh --usage

# 単件解析
./staddress.sh -s "六本木ヒルズ 森タワー 52F"
./staddress.sh --single "東京都渋谷区道玄坂1-2 マンション桜 101号" "150-0043"

# 一括解析（JSON ファイルを指定）
./staddress.sh -b batch-sample.json
./staddress.sh --batch /path/to/addresses.json
```

| オプション | 短縮 | API |
|------------|------|-----|
| `--usage` | `-u` | GET /api/v1/usage |
| `--single <住所> [郵便番号]` | `-s` | POST /api/v1/addresses/parse |
| `--batch <ファイル>` | `-b` | POST /api/v1/addresses/parse/batch |

一括 JSON ファイル形式（最大100件）:

```json
{
  "items": [
    { "id": "req-001", "address": "東京都渋谷区...", "postalCode": "150-0002" },
    { "id": "req-002", "address": "大阪府大阪市..." }
  ]
}
```

`items` 配列のみ（`[{ "id": "...", "address": "..." }, ...]`）も可。サンプル: `batch-sample.json`。

## ファイル一覧

| ファイル | 内容 |
|----------|------|
| `staddress.sh` | 統合スクリプト |
| `_common.sh` | 共通設定・ヘルパー |
| `batch-sample.json` | 一括解析用サンプル JSON |

## 対象外

CSV アップロード／ダウンロード API（Enterprise 専用）は、別途サポート契約で対応するため、本リポジトリではサンプル・クライアントを提供しません。仕様は [公式 API ドキュメント](https://staddress.com/api) を参照してください。
