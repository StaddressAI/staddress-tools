import { StaddressError } from '@staddress/client';
import type { StaddressClient } from '@staddress/client';
import { describe, expect, it } from 'vitest';

import * as tools from '../src/tools.js';

const PARSE_OK = {
  result: {
    normalized: '東京都港区六本木6丁目10-1',
    components: { pref: '東京都', city: '港区' },
    confidence: { score: 0.92, matchLevel: 'residential_detail' },
  },
};

/** 指定したメソッド実装を持つ疑似クライアントを返す。 */
function fakeClient(impl: Partial<StaddressClient>): tools.ClientFactory {
  return () => impl as StaddressClient;
}

/** ツール結果からテキストを取り出す。 */
function text(result: tools.ToolTextResult): string {
  return result.content.map((c) => c.text).join('\n');
}

describe('parseAddress', () => {
  it('成功時に result を JSON で返す', async () => {
    let received: unknown;
    const getClient = fakeClient({
      parseAddress: async (params) => {
        received = params;
        return PARSE_OK;
      },
    });

    const res = await tools.parseAddress(getClient, { input: '六本木ヒルズ', postalCode: '106-6100' });

    expect(res.isError).toBeUndefined();
    expect(received).toEqual({ input: '六本木ヒルズ', postalCode: '106-6100' });
    expect(JSON.parse(text(res))).toEqual(PARSE_OK);
  });

  it('StaddressError を isError として返す', async () => {
    const getClient = fakeClient({
      parseAddress: async () => {
        throw new StaddressError('住所を特定できません。', {
          code: 'unresolved',
          httpStatus: 422,
          requestId: 'req-1',
        });
      },
    });

    const res = await tools.parseAddress(getClient, { input: 'x' });

    expect(res.isError).toBe(true);
    expect(text(res)).toContain('code=unresolved');
    expect(text(res)).toContain('http_status=422');
    expect(text(res)).toContain('request_id=req-1');
  });

  it('クライアント生成失敗（APIキー未設定）を isError として返す', async () => {
    const getClient: tools.ClientFactory = () => {
      throw new StaddressError('API キーが設定されていません。', {
        code: 'unauthorized',
        httpStatus: 0,
      });
    };

    const res = await tools.parseAddress(getClient, { input: 'x' });

    expect(res.isError).toBe(true);
    expect(text(res)).toContain('code=unauthorized');
  });
});

describe('parseBatch', () => {
  it('成功時に results を返す', async () => {
    const body = { results: [{ id: '1', result: PARSE_OK.result }] };
    let received: unknown;
    const getClient = fakeClient({
      parseBatch: async (params) => {
        received = params;
        return body;
      },
    });

    const res = await tools.parseBatch(getClient, { items: [{ id: '1', address: '東京都' }] });

    expect(res.isError).toBeUndefined();
    expect(received).toEqual({ items: [{ id: '1', address: '東京都' }] });
    expect(JSON.parse(text(res))).toEqual(body);
  });
});

describe('getUsage', () => {
  it('成功時に利用状況を返す', async () => {
    const body = { accountName: 'Acme', plan: 'free', usage: { count: 10, monthlyLimit: 100 } };
    const getClient = fakeClient({ getUsage: async () => body });

    const res = await tools.getUsage(getClient);

    expect(res.isError).toBeUndefined();
    expect(JSON.parse(text(res))).toEqual(body);
  });

  it('非 Staddress 例外も安全に整形する', async () => {
    const getClient = fakeClient({
      getUsage: async () => {
        throw new Error('boom');
      },
    });

    const res = await tools.getUsage(getClient);

    expect(res.isError).toBe(true);
    expect(text(res)).toContain('boom');
  });
});
