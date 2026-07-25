/**
 * Staddress AI API の型定義。
 * OpenAPI 定義（openapi/staddress-api.yaml）に準拠する。
 */

/** 住所の構成要素 */
export interface AddressComponents {
  pref?: string;
  prefCode?: string;
  city?: string;
  cityCode?: string;
  oazaCho?: string;
  chomeKoaza?: string;
  chomeKoazaNormalized?: string;
  chomeNumber?: string;
  streetNumberBlock?: string;
  buildingName?: string;
  roomNumber?: string;
  roomNumberUnit?: string;
  lon?: number;
  lat?: number;
  lgCode?: string;
  machiazaId?: string;
}

/** マッチレベル */
export type MatchLevel =
  | 'prefecture'
  | 'city'
  | 'machiaza'
  | 'residential_block'
  | 'residential_detail'
  | 'parcel'
  | 'unknown'
  | 'error'
  | '';

/** 解析の信頼度 */
export interface Confidence {
  score?: number;
  matchLevel?: MatchLevel;
  query?: string;
}

/** 住所解析結果 */
export interface ParseResult {
  normalized?: string;
  standard?: string;
  components?: AddressComponents;
  confidence?: Confidence;
}

/** API エラー本体（エラーレスポンスの error フィールド） */
export type ErrorCode =
  | 'invalid_request'
  | 'batch_size_exceeded'
  | 'unauthorized'
  | 'quota_exceeded'
  | 'forbidden'
  | 'not_found'
  | 'processing'
  | 'csv_upload_limit_exceeded'
  | 'file_too_large'
  | 'unresolved'
  | 'internal_error'
  | (string & {});

export interface ErrorBody {
  code: ErrorCode;
  message: string;
  requestId?: string;
  /** 402 時などの再試行可能日時（ISO 8601） */
  retryAfter?: string;
}

/** 単件解析リクエスト */
export interface ParseAddressParams {
  input: string;
  postalCode?: string;
}

/** 単件解析レスポンス */
export interface ParseResponse {
  result: ParseResult;
}

/** 一括解析の入力アイテム */
export interface BatchItemInput {
  id: string;
  address: string;
  postalCode?: string;
}

/** 一括解析リクエスト */
export interface ParseBatchParams {
  items: BatchItemInput[];
}

/** 一括解析の結果アイテム（result か error のいずれかを持つ） */
export interface BatchItemResult {
  id: string;
  result?: ParseResult;
  error?: ErrorBody;
}

/** 一括解析レスポンス */
export interface ParseBatchResponse {
  results: BatchItemResult[];
}

/** 利用状況レスポンス */
export interface UsageResponse {
  accountName?: string;
  plan?: string;
  usage?: {
    period?: {
      start?: string;
      end?: string;
    } | null;
    count?: number;
    monthlyLimit?: number;
    contractPeriodRemaining?: number | null;
    credits?: Array<{
      validUntil?: string;
      totalAmount?: number;
      usedAmount?: number;
      remaining?: number;
    }>;
  };
}

/** クライアント設定 */
export interface StaddressClientOptions {
  /** API キー（X-Api-Key ヘッダに付与）。未指定時は環境変数 STADDRESS_API_KEY */
  apiKey?: string;
  /** ベース URL。未指定時は環境変数 STADDRESS_BASE_URL、既定は https://api.staddress.com */
  baseUrl?: string;
  /** リクエストタイムアウト（ミリ秒）。既定 30000 */
  timeout?: number;
  /** fetch 実装の差し替え（テスト用）。既定はグローバル fetch */
  fetch?: typeof fetch;
}
