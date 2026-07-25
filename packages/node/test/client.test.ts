import { describe, expect, it, vi } from 'vitest';
import { StaddressClient, StaddressError } from '../src/index.js';

interface RecordedCall {
  url: string;
  init: RequestInit | undefined;
}

/** 固定レスポンスを返す fetch モックと、呼び出し記録を生成する */
function makeFetch(
  status: number,
  body: unknown,
): { fetch: typeof fetch; calls: RecordedCall[] } {
  const calls: RecordedCall[] = [];
  const fetchImpl = (async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init });
    return new Response(typeof body === 'string' ? body : JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    });
  }) as unknown as typeof fetch;
  return { fetch: fetchImpl, calls };
}

const PARSE_OK = {
  result: {
    normalized: '東京都港区六本木6丁目10-1',
    standard: '東京都港区六本木六丁目10-1',
    components: { pref: '東京都', city: '港区', lat: 35.6604, lon: 139.7292 },
    confidence: { score: 0.92, matchLevel: 'residential_detail' },
  },
};

describe('StaddressClient constructor', () => {
  it('API キーが無い場合は StaddressError を投げる', () => {
    const { fetch } = makeFetch(200, {});
    expect(() => new StaddressClient({ fetch, apiKey: '' })).toThrowError(StaddressError);
  });

  it('末尾スラッシュを除去する', async () => {
    const { fetch, calls } = makeFetch(200, PARSE_OK);
    const client = new StaddressClient({
      apiKey: 'k',
      baseUrl: 'https://api.example.test/',
      fetch,
    });
    await client.parseAddress({ input: 'x' });
    expect(calls[0]!.url).toBe('https://api.example.test/api/v1/addresses/parse');
  });
});

describe('parseAddress', () => {
  it('成功時に result を返し、ヘッダ/ボディを正しく送る', async () => {
    const { fetch, calls } = makeFetch(200, PARSE_OK);
    const client = new StaddressClient({ apiKey: 'sk_test', baseUrl: 'https://x.test', fetch });

    const res = await client.parseAddress({ input: '六本木ヒルズ', postalCode: '106-6100' });

    expect(res.result.components?.pref).toBe('東京都');
    const call = calls[0]!;
    expect(call.init?.method).toBe('POST');
    const headers = call.init?.headers as Record<string, string>;
    expect(headers['X-Api-Key']).toBe('sk_test');
    expect(headers['Content-Type']).toBe('application/json');
    expect(JSON.parse(String(call.init?.body))).toEqual({
      input: '六本木ヒルズ',
      postalCode: '106-6100',
    });
  });

  it('postalCode 未指定なら body に含めない', async () => {
    const { fetch, calls } = makeFetch(200, PARSE_OK);
    const client = new StaddressClient({ apiKey: 'k', baseUrl: 'https://x.test', fetch });
    await client.parseAddress({ input: 'a' });
    expect(JSON.parse(String(calls[0]!.init?.body))).toEqual({ input: 'a' });
  });

  it('input が空なら invalid_request で throw', async () => {
    const { fetch } = makeFetch(200, PARSE_OK);
    const client = new StaddressClient({ apiKey: 'k', baseUrl: 'https://x.test', fetch });
    await expect(client.parseAddress({ input: '' })).rejects.toMatchObject({
      code: 'invalid_request',
    });
  });

  it('422 の場合は StaddressError（code/message/httpStatus）を投げる', async () => {
    const { fetch } = makeFetch(422, {
      result: null,
      error: { code: 'unresolved', message: '住所を特定できません。', requestId: 'req-1' },
    });
    const client = new StaddressClient({ apiKey: 'k', baseUrl: 'https://x.test', fetch });
    await expect(client.parseAddress({ input: 'x' })).rejects.toMatchObject({
      code: 'unresolved',
      httpStatus: 422,
      requestId: 'req-1',
    });
  });
});

describe('parseBatch', () => {
  it('成功時に results を返し、items を送る', async () => {
    const { fetch, calls } = makeFetch(200, { results: [{ id: '1', result: PARSE_OK.result }] });
    const client = new StaddressClient({ apiKey: 'k', baseUrl: 'https://x.test', fetch });
    const res = await client.parseBatch({ items: [{ id: '1', address: '東京都' }] });
    expect(res.results).toHaveLength(1);
    expect(JSON.parse(String(calls[0]!.init?.body))).toEqual({
      items: [{ id: '1', address: '東京都' }],
    });
  });

  it('空配列は invalid_request で throw', async () => {
    const { fetch } = makeFetch(200, {});
    const client = new StaddressClient({ apiKey: 'k', baseUrl: 'https://x.test', fetch });
    await expect(client.parseBatch({ items: [] })).rejects.toMatchObject({
      code: 'invalid_request',
    });
  });

  it('100件超は batch_size_exceeded で throw', async () => {
    const { fetch } = makeFetch(200, {});
    const client = new StaddressClient({ apiKey: 'k', baseUrl: 'https://x.test', fetch });
    const items = Array.from({ length: 101 }, (_, i) => ({ id: String(i), address: 'x' }));
    await expect(client.parseBatch({ items })).rejects.toMatchObject({
      code: 'batch_size_exceeded',
    });
  });

  it('403（プラン制限）は StaddressError forbidden を投げる', async () => {
    const { fetch } = makeFetch(403, {
      error: { code: 'forbidden', message: 'このプランでは利用できません。' },
    });
    const client = new StaddressClient({ apiKey: 'k', baseUrl: 'https://x.test', fetch });
    await expect(
      client.parseBatch({ items: [{ id: '1', address: 'x' }] }),
    ).rejects.toMatchObject({ code: 'forbidden', httpStatus: 403 });
  });
});

describe('getUsage', () => {
  it('成功時に plan/usage を返す', async () => {
    const { fetch, calls } = makeFetch(200, {
      accountName: 'Acme',
      plan: 'free',
      usage: { count: 10, monthlyLimit: 100 },
    });
    const client = new StaddressClient({ apiKey: 'k', baseUrl: 'https://x.test', fetch });
    const res = await client.getUsage();
    expect(res.plan).toBe('free');
    expect(calls[0]!.init?.method).toBe('GET');
    expect(calls[0]!.url).toBe('https://x.test/api/v1/usage');
  });

  it('401 は unauthorized を投げる', async () => {
    const { fetch } = makeFetch(401, {
      error: { code: 'unauthorized', message: 'API キーが無効です。' },
    });
    const client = new StaddressClient({ apiKey: 'k', baseUrl: 'https://x.test', fetch });
    await expect(client.getUsage()).rejects.toMatchObject({
      code: 'unauthorized',
      httpStatus: 401,
    });
  });
});

describe('ネットワーク / タイムアウト', () => {
  it('fetch が reject するとネットワークエラーになる', async () => {
    const fetchImpl = (async () => {
      throw new TypeError('failed to fetch');
    }) as unknown as typeof fetch;
    const client = new StaddressClient({ apiKey: 'k', baseUrl: 'https://x.test', fetch: fetchImpl });
    await expect(client.getUsage()).rejects.toMatchObject({ httpStatus: 0 });
  });

  it('タイムアウトで abort されると processing エラーになる', async () => {
    const fetchImpl = (async (_url: unknown, init?: RequestInit) => {
      // abort シグナルを待って AbortError を模倣
      return await new Promise<Response>((_resolve, reject) => {
        const signal = init?.signal;
        if (signal) {
          signal.addEventListener('abort', () => {
            const e = new Error('aborted');
            e.name = 'AbortError';
            reject(e);
          });
        }
      });
    }) as unknown as typeof fetch;
    const client = new StaddressClient({
      apiKey: 'k',
      baseUrl: 'https://x.test',
      timeout: 10,
      fetch: fetchImpl,
    });
    await expect(client.getUsage()).rejects.toMatchObject({ code: 'processing' });
  });
});
