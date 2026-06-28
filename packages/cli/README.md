# Staddress CLI

ターミナルから Staddress AI API を呼び出す `staddress` コマンド。

## ステータス

**Phase 1 — 未実装**（計画確定済み）

## 計画コマンド

```bash
staddress parse "六本木ヒルズ 森タワー 52F"
staddress parse "東京都渋谷区..." --postal-code 150-0043
staddress batch --file addresses.json
staddress usage
staddress config set api-key <key>
staddress version
```

## 対象外

CSV アップロード／ダウンロード（Enterprise 専用）は別途サポート契約で対応するため、CLI では提供しません。

## インストール（予定）

```bash
./install.sh
# → ~/.local/bin/staddress または /usr/local/bin/staddress
```

## 依存

- bash 4+
- curl
- jq

詳細: [docs/plan-tools.md §3.2](../../docs/plan-tools.md)
