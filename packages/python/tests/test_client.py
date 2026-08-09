"""staddress Python SDK の単体テスト（httpx.MockTransport による、実 API 不要）。"""

from __future__ import annotations

import json

import httpx
import pytest

from staddress import (
    StaddressAsyncClient,
    StaddressClient,
    StaddressError,
)

PARSE_OK = {
    "result": {
        "normalized": "東京都港区六本木6丁目10-1",
        "standard": "東京都港区六本木六丁目10-1",
        "components": {"pref": "東京都", "city": "港区", "lat": 35.6604, "lon": 139.7292},
        "confidence": {"score": 0.92, "matchLevel": "residential_detail"},
    }
}


def make_transport(status: int, body: dict, sink: dict | None = None) -> httpx.MockTransport:
    """固定レスポンスを返し、最後のリクエストを sink に記録する MockTransport。"""

    def handler(request: httpx.Request) -> httpx.Response:
        if sink is not None:
            sink["request"] = request
            sink["url"] = str(request.url)
            sink["method"] = request.method
            sink["headers"] = dict(request.headers)
            raw = request.content
            sink["json"] = json.loads(raw) if raw else None
        return httpx.Response(status, json=body)

    return httpx.MockTransport(handler)


# --- コンストラクタ ---------------------------------------------------------

def test_missing_api_key_raises(monkeypatch):
    monkeypatch.delenv("STADDRESS_API_KEY", raising=False)
    with pytest.raises(StaddressError) as exc:
        StaddressClient()
    assert exc.value.code == "unauthorized"


def test_base_url_trailing_slash_stripped():
    sink: dict = {}
    client = StaddressClient(
        api_key="k",
        base_url="https://api.example.test/",
        transport=make_transport(200, PARSE_OK, sink),
    )
    client.parse_address(input="x")
    assert sink["url"] == "https://api.example.test/api/v1/addresses/parse"


# --- parse_address ----------------------------------------------------------

def test_parse_address_success_and_request():
    sink: dict = {}
    client = StaddressClient(
        api_key="sk_test",
        base_url="https://x.test",
        transport=make_transport(200, PARSE_OK, sink),
    )
    result = client.parse_address(input="六本木ヒルズ", postal_code="106-6100")

    assert result.components.pref == "東京都"
    assert result.confidence.match_level == "residential_detail"
    assert sink["method"] == "POST"
    assert sink["headers"]["x-api-key"] == "sk_test"
    assert sink["json"] == {"input": "六本木ヒルズ", "postalCode": "106-6100"}


def test_parse_address_without_postal_code():
    sink: dict = {}
    client = StaddressClient(
        api_key="k", base_url="https://x.test", transport=make_transport(200, PARSE_OK, sink)
    )
    client.parse_address(input="a")
    assert sink["json"] == {"input": "a"}


def test_parse_address_empty_input():
    client = StaddressClient(
        api_key="k", base_url="https://x.test", transport=make_transport(200, PARSE_OK)
    )
    with pytest.raises(StaddressError) as exc:
        client.parse_address(input="")
    assert exc.value.code == "invalid_request"


def test_parse_address_422():
    body = {
        "result": None,
        "error": {"code": "unresolved", "message": "住所を特定できません。", "requestId": "req-1"},
    }
    client = StaddressClient(
        api_key="k", base_url="https://x.test", transport=make_transport(422, body)
    )
    with pytest.raises(StaddressError) as exc:
        client.parse_address(input="x")
    assert exc.value.code == "unresolved"
    assert exc.value.http_status == 422
    assert exc.value.request_id == "req-1"


# --- parse_batch ------------------------------------------------------------

def test_parse_batch_success():
    sink: dict = {}
    body = {"results": [{"id": "1", "result": PARSE_OK["result"]}]}
    client = StaddressClient(
        api_key="k", base_url="https://x.test", transport=make_transport(200, body, sink)
    )
    results = client.parse_batch([{"id": "1", "address": "東京都"}])
    assert len(results) == 1
    assert results[0].id == "1"
    assert results[0].result.components.pref == "東京都"
    assert sink["json"] == {"items": [{"id": "1", "address": "東京都"}]}


def test_parse_batch_empty():
    client = StaddressClient(
        api_key="k", base_url="https://x.test", transport=make_transport(200, {})
    )
    with pytest.raises(StaddressError) as exc:
        client.parse_batch([])
    assert exc.value.code == "invalid_request"


def test_parse_batch_over_limit():
    client = StaddressClient(
        api_key="k", base_url="https://x.test", transport=make_transport(200, {})
    )
    items = [{"id": str(i), "address": "x"} for i in range(101)]
    with pytest.raises(StaddressError) as exc:
        client.parse_batch(items)
    assert exc.value.code == "batch_size_exceeded"


def test_parse_batch_forbidden():
    body = {"error": {"code": "forbidden", "message": "このプランでは利用できません。"}}
    client = StaddressClient(
        api_key="k", base_url="https://x.test", transport=make_transport(403, body)
    )
    with pytest.raises(StaddressError) as exc:
        client.parse_batch([{"id": "1", "address": "x"}])
    assert exc.value.code == "forbidden"
    assert exc.value.http_status == 403


# --- get_usage --------------------------------------------------------------

def test_get_usage_success():
    body = {"accountName": "Acme", "plan": "free", "usage": {"count": 10, "monthlyLimit": 100}}
    sink: dict = {}
    client = StaddressClient(
        api_key="k", base_url="https://x.test", transport=make_transport(200, body, sink)
    )
    usage = client.get_usage()
    assert usage.plan == "free"
    assert usage.account_name == "Acme"
    assert usage.usage.monthly_limit == 100
    assert sink["method"] == "GET"


def test_get_usage_401():
    body = {"error": {"code": "unauthorized", "message": "API キーが無効です。"}}
    client = StaddressClient(
        api_key="k", base_url="https://x.test", transport=make_transport(401, body)
    )
    with pytest.raises(StaddressError) as exc:
        client.get_usage()
    assert exc.value.code == "unauthorized"
    assert exc.value.http_status == 401


# --- ネットワーク / タイムアウト -------------------------------------------

def test_network_error():
    def handler(_request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("boom")

    client = StaddressClient(
        api_key="k", base_url="https://x.test", transport=httpx.MockTransport(handler)
    )
    with pytest.raises(StaddressError) as exc:
        client.get_usage()
    assert exc.value.code == "network_error"


def test_timeout_error():
    def handler(_request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("slow")

    client = StaddressClient(
        api_key="k", base_url="https://x.test", transport=httpx.MockTransport(handler)
    )
    with pytest.raises(StaddressError) as exc:
        client.get_usage()
    assert exc.value.code == "timeout"


# --- 非同期クライアント -----------------------------------------------------

async def test_async_parse_address_success():
    sink: dict = {}
    async with StaddressAsyncClient(
        api_key="k", base_url="https://x.test", transport=make_transport(200, PARSE_OK, sink)
    ) as client:
        result = await client.parse_address(input="六本木ヒルズ")
    assert result.normalized == "東京都港区六本木6丁目10-1"
    assert sink["json"] == {"input": "六本木ヒルズ"}


async def test_async_get_usage_401():
    body = {"error": {"code": "unauthorized", "message": "無効"}}
    async with StaddressAsyncClient(
        api_key="k", base_url="https://x.test", transport=make_transport(401, body)
    ) as client:
        with pytest.raises(StaddressError) as exc:
            await client.get_usage()
    assert exc.value.code == "unauthorized"
