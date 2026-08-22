import { AsyncLocalStorage } from 'node:async_hooks';
import type { IncomingHttpHeaders } from 'node:http';

/** HTTP リクエスト単位の認証情報（stdio では未設定）。 */
export interface RequestAuth {
  apiKey: string;
  baseUrl?: string;
}

export const requestAuth = new AsyncLocalStorage<RequestAuth>();

/**
 * `X-Api-Key` または `Authorization: Bearer` から API キーを取り出す。
 * 値は返すがログには出さない。
 */
export function extractApiKey(headers: IncomingHttpHeaders): string | undefined {
  const rawKey = firstHeader(headers['x-api-key']);
  if (rawKey) return rawKey.trim() || undefined;

  const auth = firstHeader(headers.authorization);
  if (!auth) return undefined;

  const trimmed = auth.trim();
  const bearer = trimmed.match(/^Bearer\s+(.+)$/i);
  if (bearer?.[1]) return bearer[1].trim() || undefined;

  return undefined;
}

function firstHeader(value: string | string[] | undefined): string | undefined {
  if (Array.isArray(value)) return value[0];
  return value;
}
