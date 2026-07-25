# Staddress CLI

ターミナルから Staddress AI API を呼び出す `staddress` コマンド。

## ステータス

**Phase 1 — v0.1 実装済み**（`parse` / `batch` / `usage` / `config` / `version`）

## インストール

```bash
# リポジトリからローカルインストール（~/.local/bin または /usr/local/bin に symlink）
cd packages/cli && ./install.sh

# 配置先を指定する場合
./install.sh --prefix /usr/local/bin

# アンインストール
./install.sh --uninstall
```

インストール後、`~/.local/bin` が PATH に無い場合はシェル設定に追加してください:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## 依存

- bash 4+
- curl
- jq

## 設定

設定の解決順（上が優先）:

1. コマンドフラグ `--api-key` / `--base-url`
2. 環境変数 `STADDRESS_API_KEY` / `STADDRESS_BASE_URL`
3. 設定ファイル `~/.config/staddress/config`
4. 既定（base-url: `https://api.staddress.com`）

```bash
# API キーを設定ファイルに保存（パーミッションは 600）
staddress config set api-key sk_xxx
staddress config set base-url https://api.staddress.com

# 現在の設定を確認（API キーはマスク表示）
staddress config show
```

環境変数 `STADDRESS_CONFIG` で設定ファイルのパスを変更できます。

## 使い方

```bash
# 単件解析（既定は JSON 出力）
staddress parse "六本木ヒルズ 森タワー 52F"
staddress parse "東京都渋谷区道玄坂1-2" --postal-code 150-0043

# 人間可読なテーブル表示
staddress parse "六本木ヒルズ 森タワー 52F" --pretty

# 一括解析（Standard プラン以上、最大100件）
staddress batch --file addresses.json
cat addresses.json | staddress batch --stdin

# 利用状況
staddress usage
staddress usage --pretty

# バージョン / ヘルプ
staddress version
staddress --help
staddress parse --help
```

一括解析の入力 JSON 形式:

```json
{"items": [{"id": "1", "address": "東京都渋谷区道玄坂1-2-3", "postalCode": "150-0002"}]}
```

`items` の配列のみ（トップレベルが配列）でも受け付けます。

## 終了コード

| コード | 意味 |
|--------|------|
| `0` | 成功 |
| `1` | API エラー / ネットワークエラー |
| `2` | 設定エラー / 使い方エラー |

## テスト

実 API 不要（`curl` をモック化）の単体テスト:

```bash
./tests/run.sh
```

## 対象外

CSV アップロード／ダウンロード（Enterprise 専用）は別途サポート契約で対応するため、CLI では提供しません。

詳細: [docs/plan-tools.md §3.3](../../docs/plan-tools.md)
