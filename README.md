# staddress-tools

Staddress AI（ストアドレス）住所解析サービス向けの **クライアントツール群** および **汎用 AI エージェント** の開発リポジトリ。

- 公式 API 仕様: [https://staddress.com/api](https://staddress.com/api)

## このリポジトリについて

Staddress AI（住所解析サービス）の解析精度を確認するだけであれば、**GUI で手軽に行えます**。まずは [公式サイト](https://staddress.com) からお試しください。

**コードで動作検証や開発を行う場合**に、本リポジトリが役立ちます。さまざまなプログラミング言語から Staddress AI API を利用できるよう、**サンプルコード**および**各言語に対応した SDK（ライブラリ）**を提供します。

## リポジトリ構成

```
staddress-tools/
├── README.md                 # 本ファイル
├── .env.example              # 環境変数テンプレート
├── docs/                     # 設計・計画・仕様書
├── examples/
│   ├── curl/                 # curl サンプル
│   └── powershell/           # PowerShell サンプル
├── openapi/                  # Staddress API OpenAPI 定義
├── packages/
│   ├── cli/                  # staddress シェルコマンド
│   ├── node/                 # Node.js SDK (@staddress/client)
│   ├── python/               # Python SDK (staddress)
│   └── ruby/                 # Ruby Gem (staddress)
├── agent/                    # 汎用 AI エージェント
└── tests/                    # 横断テスト・フィクスチャ
```

## 利用方法

事前に、リポジトリルートで環境変数を設定します。

```bash
cp .env.example .env
# STADDRESS_API_KEY と STADDRESS_BASE_URL を設定
```

| 変数 | 説明 |
|------|------|
| `STADDRESS_API_KEY` | API キー（[取得方法は .env.example を参照](.env.example)） |
| `STADDRESS_BASE_URL` | ベース URL（既定: `https://api.staddress.com`） |

### curl サンプル（Mac／Linux 向け）

```bash
source .env
./examples/curl/staddress.sh -s "六本木ヒルズ 森タワー 52F"
```

詳細は [`examples/curl/`](examples/curl/) を参照。

### PowerShell サンプル（Windows 向け）

```powershell
.\examples\powershell\staddress.ps1 -Single "六本木ヒルズ 森タワー 52F"
```

詳細は [`examples/powershell/`](examples/powershell/) を参照。

### SDK / CLI（開発予定）

各言語の SDK と Shell CLI を順次提供予定です（[開発ロードマップ](#開発ロードマップ) を参照）。

```bash
# 例: Shell CLI（予定）
staddress parse "東京都渋谷区道玄坂1-2 マンション桜 101号"
staddress usage
staddress batch --file addresses.json
```

## 開発ロードマップ

詳細は [docs/plan-tools.md](docs/plan-tools.md) を参照。

| フェーズ | 内容 | 状態 |
|--------|------|------|
| 1 | curl サンプル | 完了 |
| 2 | PowerShell サンプル（Windows 向け） | 計画中 |
| 3 | Shell CLI (`staddress`) | 未着手 |
| 4 | Node.js SDK | 未着手 |
| 5 | Python SDK | 未着手 |
| 6 | Ruby SDK | 未着手 |
| 7 | その他言語（Go / PHP 等） | 計画中 |
| 8 | 汎用 AI エージェント | 未着手 |

## ライセンス

[MIT License](LICENSE) © 2026 StaddressAI
