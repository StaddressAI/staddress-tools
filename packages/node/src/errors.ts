import type { ErrorBody, ErrorCode } from './types.js';

/**
 * Staddress API 呼び出しで発生したエラーを表す統一例外。
 *
 * - HTTP 4xx / 5xx で API がエラーボディを返した場合
 * - ネットワークエラー・タイムアウト（code: 'network_error' / 'timeout'）
 */
export class StaddressError extends Error {
  /** API エラーコード（unauthorized, quota_exceeded 等） */
  readonly code: ErrorCode;
  /** HTTP ステータスコード（ネットワークエラー時は 0） */
  readonly httpStatus: number;
  /** サポート問い合わせ用のリクエスト ID（あれば） */
  readonly requestId?: string;
  /** 再試行可能日時（ISO 8601、あれば） */
  readonly retryAfter?: string;
  /** 元となった例外（ネットワークエラー等） */
  readonly cause?: unknown;

  constructor(
    message: string,
    options: {
      code?: ErrorCode;
      httpStatus?: number;
      requestId?: string;
      retryAfter?: string;
      cause?: unknown;
    } = {},
  ) {
    super(message);
    this.name = 'StaddressError';
    this.code = options.code ?? 'internal_error';
    this.httpStatus = options.httpStatus ?? 0;
    this.requestId = options.requestId;
    this.retryAfter = options.retryAfter;
    this.cause = options.cause;
    Object.setPrototypeOf(this, StaddressError.prototype);
  }

  /** API のエラーボディから StaddressError を生成 */
  static fromBody(body: ErrorBody, httpStatus: number): StaddressError {
    return new StaddressError(body.message || `API error (${body.code})`, {
      code: body.code,
      httpStatus,
      requestId: body.requestId,
      retryAfter: body.retryAfter,
    });
  }
}
