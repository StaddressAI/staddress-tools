import { afterEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { AddressInfo } from 'node:net';

import { createHttpListener } from '../src/http.js';
import { extractApiKey } from '../src/requestAuth.js';
import { SERVER_NAME } from '../src/server.js';

describe('extractApiKey', () => {
  it('X-Api-Key を読む', () => {
    expect(extractApiKey({ 'x-api-key': 'st_abc' })).toBe('st_abc');
  });

  it('Authorization Bearer を読む', () => {
    expect(extractApiKey({ authorization: 'Bearer st_abc' })).toBe('st_abc');
  });

  it('無いときは undefined', () => {
    expect(extractApiKey({})).toBeUndefined();
    expect(extractApiKey({ authorization: 'Basic xxx' })).toBeUndefined();
  });
});

describe('HTTP server', () => {
  let server: Server | undefined;

  afterEach(async () => {
    if (!server) return;
    await new Promise<void>((resolve, reject) => {
      server?.close((err) => (err ? reject(err) : resolve()));
    });
    server = undefined;
  });

  async function listen(): Promise<string> {
    server = createHttpListener();
    await new Promise<void>((resolve, reject) => {
      server?.once('error', reject);
      server?.listen(0, '127.0.0.1', () => resolve());
    });
    const addr = server.address() as AddressInfo;
    return `http://127.0.0.1:${addr.port}`;
  }

  it('GET /health が 200 を返す', async () => {
    const base = await listen();
    const res = await fetch(`${base}/health`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; name: string };
    expect(body.ok).toBe(true);
    expect(body.name).toBe(SERVER_NAME);
  });

  it('キー無しでも initialize は 200 を返す（Smithery スキャン用）', async () => {
    const base = await listen();
    const res = await fetch(`${base}/mcp`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json, text/event-stream',
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: 1,
        method: 'initialize',
        params: {
          protocolVersion: '2025-03-26',
          capabilities: {},
          clientInfo: { name: 'vitest', version: '0' },
        },
      }),
    });
    expect(res.status).toBe(200);
    const payload = (await res.json()) as { result?: { serverInfo?: { name: string } } };
    expect(payload.result?.serverInfo?.name).toBe(SERVER_NAME);
  });

  it('OAuth 保護リソースメタデータを 200 で返す', async () => {
    const base = await listen();
    const res = await fetch(`${base}/.well-known/oauth-protected-resource/mcp`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { resource: string };
    expect(body.resource).toContain('/mcp');
  });

  it('キー付き initialize でサーバ情報を返す', async () => {
    const base = await listen();
    const res = await fetch(`${base}/mcp`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Api-Key': 'st_test_dummy',
        Accept: 'application/json, text/event-stream',
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: 1,
        method: 'initialize',
        params: {
          protocolVersion: '2025-03-26',
          capabilities: {},
          clientInfo: { name: 'vitest', version: '0' },
        },
      }),
    });

    expect(res.status).toBe(200);
    const payload = await res.json();
    const result = (payload as { result?: { serverInfo?: { name: string } } }).result
      ?? (payload as { jsonrpc?: string; result?: { serverInfo?: { name: string } } }).result;
    expect(result?.serverInfo?.name).toBe(SERVER_NAME);
  });

  it('server-card を公開する', async () => {
    const base = await listen();
    const res = await fetch(`${base}/.well-known/mcp/server-card.json`);
    expect(res.status).toBe(200);
    const card = (await res.json()) as { authentication: { required: boolean } };
    expect(card.authentication.required).toBe(true);
  });
});
