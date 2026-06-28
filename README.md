# staddress-agent

Staddress AI（ストアドレス）住所解析サービス向けの **クライアントツール群** および **汎用 AI エージェント** の開発リポジトリ。

- 公式 API 仕様: [https://staddress.com/api](https://staddress.com/api)

## リポジトリ構成

```
staddress-agent/
├── README.md                 # 本ファイル
├── .env.example              # 環境変数テンプレート
├── docs/                     # 設計・計画・仕様書
├── examples/
│   ├── curl/                 # curl サンプル（そのまま実行可能）
│   └── powershell/           # PowerShell サンプル（Windows 向け・計画中）
├── openapi/                  # Staddress API OpenAPI 定義（参照用）
├── packages/
│   ├── cli/                  # staddress シェルコマンド
│   ├── node/                 # Node.js SDK (@staddress/client)
│   ├── python/               # Python SDK (staddress)
│   └── ruby/                 # Ruby Gem (staddress)
├── agent/                    # 汎用 AI エージェント
└── tests/                    # 横断テスト・フィクスチャ
```

## クイックスタート

### 1. 環境変数

```bash
cp .env.example .env
# STADDRESS_API_KEY と STADDRESS_BASE_URL を設定
```

| 変数 | 説明 |
|------|------|
| `STADDRESS_API_KEY` | API キー（[取得方法は .env.example を参照](.env.example)） |
| `STADDRESS_BASE_URL` | ベース URL（既定: `https://api.staddress.com`） |

### 2. curl で試す

```bash
source .env
./examples/curl/staddress.sh -s "六本木ヒルズ 森タワー 52F"
```

### 3. CLI（開発予定）

```bash
# packages/cli をインストール後
staddress parse "東京都渋谷区道玄坂1-2 マンション桜 101号"
staddress usage
staddress batch --file addresses.json
```

## 開発ロードマップ

詳細は [docs/plan-tools.md](docs/plan-tools.md) を参照。

| フェーズ | 内容 | 状態 |
|--------|------|------|
| 0 | curl サンプル・OpenAPI・計画書 | 完了 |
| 0 | PowerShell サンプル（Windows 向け） | 計画中 |
| 1 | Shell CLI (`staddress`) | 未着手 |
| 2 | Node.js SDK | 未着手 |
| 3 | Python SDK | 未着手 |
| 4 | Ruby SDK | 未着手 |
| 5 | その他言語（Go / PHP 等） | 計画中 |
| 6 | 汎用 AI エージェント | 未着手 |

## ライセンス

[MIT License](LICENSE) © 2026 StaddressAI
