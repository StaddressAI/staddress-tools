import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';

import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';

import { extractApiKey, requestAuth } from './requestAuth.js';
import { SERVER_NAME, SERVER_VERSION, createServer as createMcpServer } from './server.js';

export interface HttpListenOptions {
  host?: string;
  port?: number;
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers':
    'Content-Type, Authorization, X-Api-Key, MCP-Protocol-Version, Mcp-Session-Id, Last-Event-ID',
  'Access-Control-Expose-Headers': 'Mcp-Session-Id, MCP-Protocol-Version',
} as const;

function applyCors(res: ServerResponse): void {
  for (const [key, value] of Object.entries(CORS_HEADERS)) {
    res.setHeader(key, value);
  }
}

function sendJson(res: ServerResponse, status: number, body: unknown): void {
  applyCors(res);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(body));
}

function pathnameOf(req: IncomingMessage): string {
  try {
    return new URL(req.url ?? '/', 'http://localhost').pathname;
  } catch {
    return '/';
  }
}

function serverCard(): Record<string, unknown> {
  return {
    serverInfo: { name: SERVER_NAME, version: SERVER_VERSION },
    authentication: {
      required: true,
      schemes: ['header'],
      headers: ['X-Api-Key', 'Authorization'],
    },
    tools: [
      {
        name: 'staddress_parse',
        description: '日本語の住所文字列を正規化し、構成要素・緯度経度・信頼度を返す',
      },
      {
        name: 'staddress_parse_batch',
        description: '複数の住所を一括解析する（Standard プラン以上、最大100件）',
      },
      {
        name: 'staddress_get_usage',
        description: 'API の利用状況（プラン・件数・クレジット）を取得する',
      },
    ],
    resources: [],
    prompts: [],
  };
}

async function handleMcp(req: IncomingMessage, res: ServerResponse): Promise<void> {
  applyCors(res);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const apiKey = extractApiKey(req.headers);
  if (!apiKey) {
    res.setHeader('WWW-Authenticate', 'Bearer realm="staddress", charset="UTF-8"');
    sendJson(res, 401, {
      error: {
        code: 'unauthorized',
        message: 'API キーが必要です。X-Api-Key または Authorization: Bearer を指定してください。',
      },
    });
    return;
  }

  const mcp = createMcpServer();
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
    enableJsonResponse: true,
  });
  await mcp.connect(transport);
  try {
    await requestAuth.run({ apiKey }, () => transport.handleRequest(req, res));
  } finally {
    await transport.close().catch(() => undefined);
    await mcp.close().catch(() => undefined);
  }
}

/** Streamable HTTP で MCP を公開する Node サーバを作る。 */
export function createHttpListener(): Server {
  return createServer((req, res) => {
    void (async () => {
      const path = pathnameOf(req);

      if (req.method === 'OPTIONS') {
        applyCors(res);
        res.writeHead(204);
        res.end();
        return;
      }

      if (path === '/health' && req.method === 'GET') {
        sendJson(res, 200, { ok: true, name: SERVER_NAME, version: SERVER_VERSION });
        return;
      }

      if (path === '/.well-known/mcp/server-card.json' && req.method === 'GET') {
        sendJson(res, 200, serverCard());
        return;
      }

      if (path === '/' && req.method === 'GET') {
        sendJson(res, 200, {
          name: SERVER_NAME,
          version: SERVER_VERSION,
          transport: 'streamable-http',
          mcp: '/mcp',
          health: '/health',
        });
        return;
      }

      if (path === '/mcp') {
        await handleMcp(req, res);
        return;
      }

      sendJson(res, 404, { error: { code: 'not_found', message: 'Not Found' } });
    })().catch((err) => {
      console.error(`${SERVER_NAME}: http handler error`, err);
      if (!res.headersSent) {
        sendJson(res, 500, { error: { code: 'internal_error', message: 'Internal Server Error' } });
      } else {
        res.end();
      }
    });
  });
}

/** HTTP サーバを起動する。 */
export async function listenHttp(options: HttpListenOptions = {}): Promise<Server> {
  const host = options.host ?? process.env.HOST ?? '0.0.0.0';
  const port = options.port ?? Number(process.env.PORT ?? 8787);
  const server = createHttpListener();

  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, host, () => resolve());
  });

  const address = server.address();
  const shown =
    typeof address === 'object' && address
      ? `${address.address}:${address.port}`
      : `${host}:${port}`;
  console.error(`${SERVER_NAME} v${SERVER_VERSION}: started (streamable-http http://${shown}/mcp)`);
  return server;
}
