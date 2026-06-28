# 結合テスト（実 API）

`examples/curl/staddress.sh` を実際の Staddress AI API に対して実行し、レスポンス構造を検証します。

## 実行

```bash
# 1. リポジトリルートに .env を用意（または環境変数を export）
cp .env.example .env
#   STADDRESS_BASE_URL / STADDRESS_API_KEY を設定

# 2. テスト実行
./tests/integration/run.sh
```

## 動作

| 状況 | 挙動 |
|------|------|
| API キー未設定 | スキップ（exit 0） |
| API キー設定済み | 実 API を呼び出して検証 |
| 一括解析が plan 制限 (403) | その項目のみスキップ |

## テスト項目

| # | 対象 | 検証内容 |
|---|------|----------|
| 1 | `-u` 利用状況 | `plan` / `usage` フィールドの存在 |
| 2 | `-s` 単件解析 | `result.normalized` / `components.pref` の存在 |
| 3 | `-s` + 郵便番号 | `components.pref == "東京都"` |
| 4 | `-b` 一括解析 | `results` 件数が入力件数と一致（Standard+ プラン） |

## 注意

- 実 API を呼ぶため、**住所解析の件数を消費**します（利用枠に注意）。
- 一括解析は Standard プラン以上が必要です。未満のプランでは 403 となり、該当項目はスキップされます。
- 終了コード: `0`=成功/スキップ、`1`=失敗あり。CI ではシークレットがある場合のみ実行する想定です。
