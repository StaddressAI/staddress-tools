"""Staddress SDK の例外。"""

from __future__ import annotations

from .models import ErrorBody


class StaddressError(Exception):
    """Staddress API 呼び出しで発生したエラーを表す統一例外。

    - HTTP 4xx / 5xx で API がエラーボディを返した場合
    - ネットワークエラー・タイムアウト（code: "network_error" / "timeout"）
    - 入力バリデーションエラー（code: "invalid_request"）

    Attributes:
        code: API エラーコード（"unauthorized", "quota_exceeded" 等）
        http_status: HTTP ステータスコード（ネットワークエラー時は 0）
        request_id: サポート問い合わせ用のリクエスト ID（あれば）
        retry_after: 再試行可能日時（ISO 8601、あれば）
    """

    def __init__(
        self,
        message: str,
        *,
        code: str = "internal_error",
        http_status: int = 0,
        request_id: str | None = None,
        retry_after: str | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.http_status = http_status
        self.request_id = request_id
        self.retry_after = retry_after

    @classmethod
    def from_body(cls, body: ErrorBody, http_status: int) -> StaddressError:
        """API のエラーボディから StaddressError を生成する。"""
        return cls(
            body.message or f"API error ({body.code})",
            code=body.code,
            http_status=http_status,
            request_id=body.request_id,
            retry_after=body.retry_after,
        )

    def __repr__(self) -> str:  # pragma: no cover - デバッグ表示用
        return (
            f"StaddressError(code={self.code!r}, http_status={self.http_status}, "
            f"message={str(self)!r})"
        )
