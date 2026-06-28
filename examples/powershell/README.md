# PowerShell サンプル

Staddress AI API を PowerShell で呼び出すサンプル。**Windows 標準の PowerShell 5.1** および **PowerShell 7+** で、追加ツール（`curl` / `jq`）なしに動作します（`Invoke-RestMethod` のみ使用）。

## 接続設定（API キー・サーバー）

`STADDRESS_API_KEY` と `STADDRESS_BASE_URL` は次の優先順位で解決されます。

1. **コマンドライン引数**（最優先）
   - `-Key <APIキー>` → `STADDRESS_API_KEY`
   - `-Server <ベースURL>` → `STADDRESS_BASE_URL`
2. **環境変数 / `.env`**（リポジトリルートの `.env` を自動読み込み）
3. **対話入力**（いずれも未設定なら確認プロンプト。API キーは非表示で入力）

```powershell
# 1) 引数で指定（環境変数より優先）
.\staddress.ps1 -Server https://api.staddress.com -Key sk_xxx -Usage

# 2) .env で指定（Copy-Item ..\..\.env.example ..\..\.env して編集）
.\staddress.ps1 -Usage

# 3) 環境変数で指定
$env:STADDRESS_BASE_URL = "https://api.staddress.com"
$env:STADDRESS_API_KEY  = "<your-api-key>"
.\staddress.ps1 -Usage

# 4) 何も指定しなければ対話的に入力を求められます
.\staddress.ps1 -Usage
```

## 実行方法

PowerShell の実行ポリシーにより `.ps1` の直接実行がブロックされる場合は、次のいずれかで実行します。

```powershell
# 方法 A: 現在のセッションだけ許可して実行
powershell -ExecutionPolicy Bypass -File .\staddress.ps1 -Usage

# 方法 B: PowerShell 7+ の場合
pwsh -File .\staddress.ps1 -Usage

# 方法 C: 直接実行（実行ポリシーが RemoteSigned / Unrestricted の場合）
.\staddress.ps1 -Usage
```

## 使い方

```powershell
# 利用案内
.\staddress.ps1 -Help

# 利用状況
.\staddress.ps1 -Usage

# 単件解析
.\staddress.ps1 -Single "六本木ヒルズ 森タワー 52F"
.\staddress.ps1 -Single "東京都渋谷区道玄坂1-2 マンション桜 101号" -PostalCode "150-0043"

# 一括解析（JSON ファイルを指定）
.\staddress.ps1 -Batch .\batch-sample.json
.\staddress.ps1 -Batch C:\path\to\addresses.json
```

| オプション | API |
|------------|-----|
| `-Usage` | GET /api/v1/usage |
| `-Single <住所> [-PostalCode <郵便番号>]` | POST /api/v1/addresses/parse |
| `-Batch <ファイル>` | POST /api/v1/addresses/parse/batch |

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

## 終了コード

| コード | 意味 |
|--------|------|
| `0` | 成功 |
| `1` | API エラー（4xx / 5xx） |
| `2` | 設定エラー（API キー未設定・入力不正・ファイル不正など） |

## ファイル一覧

| ファイル | 内容 |
|----------|------|
| `staddress.ps1` | 統合スクリプト（usage / single / batch） |
| `batch-sample.json` | 一括解析用サンプル JSON |

## 文字エンコーディングについて

日本語住所を正しく送信するため、リクエストボディは UTF-8 バイト列に変換して送信しています（Windows PowerShell 5.1 での文字化け対策）。`.env` やバッチ JSON ファイルは **UTF-8** で保存してください。

## 対象外

CSV アップロード／ダウンロード API（Enterprise 専用）は、別途サポート契約で対応するため、本リポジトリではサンプル・クライアントを提供しません。仕様は [公式 API ドキュメント](https://staddress.com/api) を参照してください。
