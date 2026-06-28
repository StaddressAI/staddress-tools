# staddress (Python)

Staddress AI API 公式 Python SDK。

## ステータス

**Phase 3 — 未実装**

## インストール（予定）

```bash
pip install staddress
uv add staddress
```

## 使用例（予定）

```python
from staddress import StaddressClient

client = StaddressClient(
    api_key="...",
    base_url="https://api.staddress.com",
)

result = client.parse_address(input="六本木ヒルズ 森タワー 52F")
```

## 開発

```bash
cd packages/python
uv sync
pytest
```

詳細: [docs/plan-tools.md §3.4](../../docs/plan-tools.md)
