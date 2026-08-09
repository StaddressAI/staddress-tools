"""Staddress AI API 公式 Python SDK。"""

from __future__ import annotations

from .client import StaddressAsyncClient, StaddressClient
from .errors import StaddressError
from .models import (
    AddressComponents,
    BatchItemResult,
    Confidence,
    ErrorBody,
    ParseResult,
    UsageResponse,
)

__version__ = "0.1.0"

__all__ = [
    "StaddressClient",
    "StaddressAsyncClient",
    "StaddressError",
    "AddressComponents",
    "BatchItemResult",
    "Confidence",
    "ErrorBody",
    "ParseResult",
    "UsageResponse",
    "__version__",
]
