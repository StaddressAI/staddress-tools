import { StaddressError } from './errors.js';
import type {
  ParseAddressParams,
  ParseBatchParams,
  ParseBatchResponse,
  ParseResponse,
  StaddressClientOptions,
  UsageResponse,
} from './types.js';

const DEFAULT_BASE_URL = 'https://api.staddress.com';
const DEFAULT_TIMEOUT = 30_000;
const MAX_BATCH_ITEMS = 100;

/**
 * Staddress AI API クライアント。
 *
 * @example
 * ```ts
 * const client = new StaddressClient({ apiKey: 'sk_xxx' });
 * const { result } = await client.parseAddress({ input: '六本木ヒルズ 森タワー 52F' });
 * ```
 */
export class StaddressClient {
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly timeout: number;
  private readonly fetchImpl: typeof fetch;

  constructor(options: StaddressClientOptions = {}) {
    const env = typeof process !== 'undefined' ? process.env : undefined;

    const apiKey = options.apiKey ?? env?.STADDRESS_API_KEY;
    if (!apiKey) {
      throw new StaddressError(
        'API キーが設定されていません。options.apiKey または環境変数 STADDRESS_API_KEY を指定してください。',
        { code: 'unauthorized', httpStatus: 0 },
      );
    }

    const baseUrl = options.baseUrl ?? env?.STADDRESS_BASE_URL ?? DEFAULT_BASE_URL;

    const fetchImpl = options.fetch ?? globalThis.fetch;
    if (typeof fetchImpl !== 'function') {
      throw new StaddressError(
        'fetch が利用できません。Node.js 18+ を使用するか、options.fetch を指定してください。',
        { code: 'internal_error', httpStatus: 0 },
      );
    }

    this.apiKey = apiKey;
    this.baseUrl = baseUrl.replace(/\/+$/, '');
    this.timeout = options.timeout ?? DEFAULT_TIMEOUT;
    this.fetchImpl = fetchImpl;
  }

  /** 単件住所解析 (POST /api/v1/addresses/parse) */
  async parseAddress(params: ParseAddressParams): Promise<ParseResponse> {
    if (!params?.input) {
      throw new StaddressError('input は必須です。', {
        code: 'invalid_request',
        httpStatus: 0,
      });
    }
    const body: ParseAddressParams = { input: params.input };
    if (params.postalCode) body.postalCode = params.postalCode;

    return this.request<ParseResponse>('POST', '/api/v1/addresses/parse', body);
  }

  /** 一括住所解析 (POST /api/v1/addresses/parse/batch)。Standard プラン以上。 */
  async parseBatch(params: ParseBatchParams): Promise<ParseBatchResponse> {
    const items = params?.items;
    if (!Array.isArray(items) || items.length === 0) {
      throw new StaddressError('items には1件以上の配列を指定してください。', {
        code: 'invalid_request',
        httpStatus: 0,
      });
    }
    if (items.length > MAX_BATCH_ITEMS) {
      throw new StaddressError(
        `items は最大 ${MAX_BATCH_ITEMS} 件です（現在: ${items.length} 件）。`,
        { code: 'batch_size_exceeded', httpStatus: 0 },
      );
    }

    return this.request<ParseBatchResponse>('POST', '/api/v1/addresses/parse/batch', {
      items,
    });
  }

  /** 利用状況取得 (GET /api/v1/usage) */
  async getUsage(): Promise<UsageResponse> {
    return this.request<UsageResponse>('GET', '/api/v1/usage');
  }

  private async request<T>(method: string, path: string, body?: unknown): Promise<T> {
    const url = `${this.baseUrl}${path}`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeout);

    let response: Response;
    try {
      response = await this.fetchImpl(url, {
        method,
        headers: {
          'X-Api-Key': this.apiKey,
          'Content-Type': 'application/json',
        },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: controller.signal,
      });
    } catch (err) {
      const isAbort = err instanceof Error && err.name === 'AbortError';
      throw new StaddressError(
        isAbort
          ? `リクエストがタイムアウトしました（${this.timeout}ms）。`
          : 'ネットワークエラーが発生しました。',
        {
          code: isAbort ? 'processing' : 'network_error',
          httpStatus: 0,
          cause: err,
        },
      );
    } finally {
      clearTimeout(timer);
    }

    const text = await response.text();
    let data: unknown;
    if (text) {
      try {
        data = JSON.parse(text);
      } catch (err) {
        throw new StaddressError('レスポンスの JSON 解析に失敗しました。', {
          code: 'internal_error',
          httpStatus: response.status,
          cause: err,
        });
      }
    }

    if (!response.ok) {
      const errBody =
        data && typeof data === 'object' && 'error' in data
          ? (data as { error?: { code?: string; message?: string; requestId?: string; retryAfter?: string } }).error
          : undefined;
      if (errBody?.code && errBody?.message) {
        throw StaddressError.fromBody(
          {
            code: errBody.code,
            message: errBody.message,
            requestId: errBody.requestId,
            retryAfter: errBody.retryAfter,
          },
          response.status,
        );
      }
      throw new StaddressError(`API エラー (HTTP ${response.status})`, {
        code: 'internal_error',
        httpStatus: response.status,
      });
    }

    return data as T;
  }
}
