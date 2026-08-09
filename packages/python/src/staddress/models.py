"""Staddress AI API のデータモデル（pydantic v2）。

OpenAPI 定義（openapi/staddress-api.yaml）に準拠する。
API は camelCase、Python 側は snake_case 属性でアクセスできるよう alias を設定する。
"""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class _Base(BaseModel):
    # API の camelCase を alias として受け付け、未知フィールドも保持する（前方互換）
    model_config = ConfigDict(populate_by_name=True, extra="allow")


class AddressComponents(_Base):
    """住所の構成要素。"""

    pref: str | None = None
    pref_code: str | None = Field(default=None, alias="prefCode")
    city: str | None = None
    city_code: str | None = Field(default=None, alias="cityCode")
    oaza_cho: str | None = Field(default=None, alias="oazaCho")
    chome_koaza: str | None = Field(default=None, alias="chomeKoaza")
    chome_koaza_normalized: str | None = Field(default=None, alias="chomeKoazaNormalized")
    chome_number: str | None = Field(default=None, alias="chomeNumber")
    street_number_block: str | None = Field(default=None, alias="streetNumberBlock")
    building_name: str | None = Field(default=None, alias="buildingName")
    room_number: str | None = Field(default=None, alias="roomNumber")
    room_number_unit: str | None = Field(default=None, alias="roomNumberUnit")
    lon: float | None = None
    lat: float | None = None
    lg_code: str | None = Field(default=None, alias="lgCode")
    machiaza_id: str | None = Field(default=None, alias="machiazaId")


class Confidence(_Base):
    """解析の信頼度。"""

    score: float | None = None
    match_level: str | None = Field(default=None, alias="matchLevel")
    query: str | None = None


class ParseResult(_Base):
    """住所解析結果。"""

    normalized: str | None = None
    standard: str | None = None
    components: AddressComponents | None = None
    confidence: Confidence | None = None


class ErrorBody(_Base):
    """API エラー本体（エラーレスポンスの error フィールド）。"""

    code: str
    message: str
    request_id: str | None = Field(default=None, alias="requestId")
    retry_after: str | None = Field(default=None, alias="retryAfter")


class BatchItemResult(_Base):
    """一括解析の結果アイテム（result か error のいずれかを持つ）。"""

    id: str
    result: ParseResult | None = None
    error: ErrorBody | None = None


class UsagePeriod(_Base):
    start: str | None = None
    end: str | None = None


class UsageCredit(_Base):
    valid_until: str | None = Field(default=None, alias="validUntil")
    total_amount: float | None = Field(default=None, alias="totalAmount")
    used_amount: float | None = Field(default=None, alias="usedAmount")
    remaining: float | None = None


class UsageDetail(_Base):
    period: UsagePeriod | None = None
    count: float | None = None
    monthly_limit: float | None = Field(default=None, alias="monthlyLimit")
    contract_period_remaining: float | None = Field(
        default=None, alias="contractPeriodRemaining"
    )
    credits: list[UsageCredit] | None = None


class UsageResponse(_Base):
    """利用状況レスポンス。"""

    account_name: str | None = Field(default=None, alias="accountName")
    plan: str | None = None
    usage: UsageDetail | None = None


# 内部レスポンスラッパ（API の {"result": ...} / {"results": [...]} 用）
class _ParseResponse(_Base):
    result: ParseResult | None = None
    error: ErrorBody | None = None


class _BatchResponse(_Base):
    results: list[BatchItemResult] = Field(default_factory=list)
