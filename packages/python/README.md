# staddress (Python)

Staddress AI API 公式 Python SDK。

## ステータス

**Phase 3 — v0.1 公開済み**（[PyPI: staddress](https://pypi.org/project/staddress/)。`parse_address` / `parse_batch` / `get_usage`、同期・非同期対応）

- HTTP: `httpx`（sync + async）
- 型: `pydantic` v2 モデル（`py.typed` 同梱）

## インストール

```bash
pip install staddress
# または
uv add staddress
poetry add staddress
```

## 使い方（同期）

```python
from staddress import StaddressClient, StaddressError

client = StaddressClient(
    api_key="sk_xxx",              # 省略時は環境変数 STADDRESS_API_KEY
    base_url="https://api.staddress.com",  # 省略時は既定値
    timeout=30.0,                  # 任意（秒）
)

# 単件解析
result = client.parse_address(input="六本木ヒルズ 森タワー 52F", postal_code="106-6100")
print(result.normalized, result.components.pref)

# 一括解析（Standard プラン以上、最大100件）
results = client.parse_batch([
    {"id": "1", "address": "東京都渋谷区道玄坂1-2-3"},
    {"id": "2", "address": "大阪府大阪市北区梅田1-1-1"},
])

# 利用状況
usage = client.get_usage()

client.close()  # または with StaddressClient(...) as client:
```

## 使い方（非同期）

```python
import asyncio
from staddress import StaddressAsyncClient

async def main():
    async with StaddressAsyncClient(api_key="sk_xxx") as client:
        result = await client.parse_address(input="六本木ヒルズ 森タワー 52F")
        print(result.normalized)

asyncio.run(main())
```

## エラーハンドリング

API エラー・ネットワークエラーは `StaddressError` として送出されます。

```python
from staddress import StaddressClient, StaddressError

try:
    client.parse_address(input="...")
except StaddressError as err:
    print(err.code)         # 例: "unauthorized", "quota_exceeded", "unresolved"
    print(err.http_status)  # HTTP ステータス（ネットワークエラー時は 0）
    print(err.request_id)   # サポート問い合わせ用（あれば）
    print(err.retry_after)  # 再試行可能日時（あれば）
```

## API

| メソッド | HTTP | 説明 |
|----------|------|------|
| `parse_address(input, postal_code=None)` | POST `/api/v1/addresses/parse` | 単件解析 → `ParseResult` |
| `parse_batch(items)` | POST `/api/v1/addresses/parse/batch` | 一括解析 → `list[BatchItemResult]` |
| `get_usage()` | GET `/api/v1/usage` | 利用状況 → `UsageResponse` |

同名の非同期メソッドを `StaddressAsyncClient` が提供します（`await` して呼び出し）。

## 開発

```bash
cd packages/python
uv sync --extra dev
uv run ruff check .
uv run pytest
uv build            # dist/ に sdist + wheel を出力
```

詳細: [docs/plan-tools.md §3.5](../../docs/plan-tools.md)
