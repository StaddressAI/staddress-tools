"""Staddress AI API クライアント（同期 / 非同期）。"""

from __future__ import annotations

import json
import os
from collections.abc import Mapping, Sequence
from typing import Any

import httpx

from .errors import StaddressError
from .models import (
    BatchItemResult,
    ErrorBody,
    ParseResult,
    UsageResponse,
    _BatchResponse,
    _ParseResponse,
)

DEFAULT_BASE_URL = "https://api.staddress.com"
DEFAULT_TIMEOUT = 30.0
MAX_BATCH_ITEMS = 100


def _resolve(api_key: str | None, base_url: str | None) -> tuple[str, str]:
    key = api_key or os.environ.get("STADDRESS_API_KEY")
    if not key:
        raise StaddressError(
            "API キーが設定されていません。api_key 引数または環境変数 "
            "STADDRESS_API_KEY を指定してください。",
            code="unauthorized",
            http_status=0,
        )
    url = base_url or os.environ.get("STADDRESS_BASE_URL") or DEFAULT_BASE_URL
    return key, url.rstrip("/")


def _build_parse_body(input: str, postal_code: str | None) -> dict[str, Any]:
    if not input:
        raise StaddressError(
            "input は必須です。", code="invalid_request", http_status=0
        )
    body: dict[str, Any] = {"input": input}
    if postal_code:
        body["postalCode"] = postal_code
    return body


def _build_batch_body(
    items: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    item_list = list(items)
    if not item_list:
        raise StaddressError(
            "items には1件以上を指定してください。",
            code="invalid_request",
            http_status=0,
        )
    if len(item_list) > MAX_BATCH_ITEMS:
        raise StaddressError(
            f"items は最大 {MAX_BATCH_ITEMS} 件です（現在: {len(item_list)} 件）。",
            code="batch_size_exceeded",
            http_status=0,
        )
    return {"items": [dict(item) for item in item_list]}


def _interpret(status_code: int, text: str) -> dict[str, Any]:
    """HTTP レスポンスを解釈し、成功なら dict を返す。エラーなら送出する。"""
    data: Any = None
    if text:
        try:
            data = json.loads(text)
        except json.JSONDecodeError as exc:
            raise StaddressError(
                "レスポンスの JSON 解析に失敗しました。",
                code="internal_error",
                http_status=status_code,
            ) from exc

    if status_code >= 400:
        err = data.get("error") if isinstance(data, dict) else None
        if isinstance(err, dict) and err.get("code") and err.get("message"):
            raise StaddressError.from_body(ErrorBody.model_validate(err), status_code)
        raise StaddressError(
            f"API エラー (HTTP {status_code})",
            code="internal_error",
            http_status=status_code,
        )

    return data if isinstance(data, dict) else {}


class StaddressClient:
    """Staddress AI API 同期クライアント。

    Example:
        >>> client = StaddressClient(api_key="sk_xxx")
        >>> result = client.parse_address(input="六本木ヒルズ 森タワー 52F")
        >>> client.close()

    ``with StaddressClient(...) as client:`` のようにコンテキストマネージャとしても使える。
    """

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        timeout: float = DEFAULT_TIMEOUT,
        *,
        transport: httpx.BaseTransport | None = None,
    ) -> None:
        self._api_key, self._base_url = _resolve(api_key, base_url)
        self._client = httpx.Client(
            base_url=self._base_url,
            timeout=timeout,
            headers={
                "X-Api-Key": self._api_key,
                "Content-Type": "application/json",
            },
            transport=transport,
        )

    def _request(self, method: str, path: str, body: dict[str, Any] | None) -> dict[str, Any]:
        try:
            resp = self._client.request(
                method,
                path,
                content=json.dumps(body) if body is not None else None,
            )
        except httpx.TimeoutException as exc:
            raise StaddressError(
                "リクエストがタイムアウトしました。", code="timeout", http_status=0
            ) from exc
        except httpx.RequestError as exc:
            raise StaddressError(
                "ネットワークエラーが発生しました。",
                code="network_error",
                http_status=0,
            ) from exc
        return _interpret(resp.status_code, resp.text)

    def parse_address(self, input: str, postal_code: str | None = None) -> ParseResult:
        """単件住所解析 (POST /api/v1/addresses/parse)。"""
        body = _build_parse_body(input, postal_code)
        data = self._request("POST", "/api/v1/addresses/parse", body)
        return _ParseResponse.model_validate(data).result or ParseResult()

    def parse_batch(
        self, items: Sequence[Mapping[str, Any]]
    ) -> list[BatchItemResult]:
        """一括住所解析 (POST /api/v1/addresses/parse/batch)。Standard プラン以上。"""
        body = _build_batch_body(items)
        data = self._request("POST", "/api/v1/addresses/parse/batch", body)
        return _BatchResponse.model_validate(data).results

    def get_usage(self) -> UsageResponse:
        """利用状況取得 (GET /api/v1/usage)。"""
        data = self._request("GET", "/api/v1/usage", None)
        return UsageResponse.model_validate(data)

    def close(self) -> None:
        self._client.close()

    def __enter__(self) -> StaddressClient:
        return self

    def __exit__(self, *_exc: object) -> None:
        self.close()


class StaddressAsyncClient:
    """Staddress AI API 非同期クライアント（async/await）。

    Example:
        >>> async with StaddressAsyncClient(api_key="sk_xxx") as client:
        ...     result = await client.parse_address(input="...")
    """

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        timeout: float = DEFAULT_TIMEOUT,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self._api_key, self._base_url = _resolve(api_key, base_url)
        self._client = httpx.AsyncClient(
            base_url=self._base_url,
            timeout=timeout,
            headers={
                "X-Api-Key": self._api_key,
                "Content-Type": "application/json",
            },
            transport=transport,
        )

    async def _request(
        self, method: str, path: str, body: dict[str, Any] | None
    ) -> dict[str, Any]:
        try:
            resp = await self._client.request(
                method,
                path,
                content=json.dumps(body) if body is not None else None,
            )
        except httpx.TimeoutException as exc:
            raise StaddressError(
                "リクエストがタイムアウトしました。", code="timeout", http_status=0
            ) from exc
        except httpx.RequestError as exc:
            raise StaddressError(
                "ネットワークエラーが発生しました。",
                code="network_error",
                http_status=0,
            ) from exc
        return _interpret(resp.status_code, resp.text)

    async def parse_address(
        self, input: str, postal_code: str | None = None
    ) -> ParseResult:
        body = _build_parse_body(input, postal_code)
        data = await self._request("POST", "/api/v1/addresses/parse", body)
        return _ParseResponse.model_validate(data).result or ParseResult()

    async def parse_batch(
        self, items: Sequence[Mapping[str, Any]]
    ) -> list[BatchItemResult]:
        body = _build_batch_body(items)
        data = await self._request("POST", "/api/v1/addresses/parse/batch", body)
        return _BatchResponse.model_validate(data).results

    async def get_usage(self) -> UsageResponse:
        data = await self._request("GET", "/api/v1/usage", None)
        return UsageResponse.model_validate(data)

    async def aclose(self) -> None:
        await self._client.aclose()

    async def __aenter__(self) -> StaddressAsyncClient:
        return self

    async def __aexit__(self, *_exc: object) -> None:
        await self.aclose()
