import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StaddressClient } from '@staddress/client';
import { z } from 'zod';

import { requestAuth } from './requestAuth.js';
import type { ClientFactory } from './tools.js';
import * as tools from './tools.js';

export const SERVER_NAME = 'staddress-mcp';
export const SERVER_VERSION = '0.2.0';

const readOnly = { readOnlyHint: true, openWorldHint: true } as const;

/**
 * HTTP リクエストのヘッダ認証があればそれを使い、なければ環境変数から生成する。
 */
function defaultClientFactory(): StaddressClient {
  const scoped = requestAuth.getStore();
  if (scoped?.apiKey) {
    return new StaddressClient({ apiKey: scoped.apiKey, baseUrl: scoped.baseUrl });
  }
  return new StaddressClient();
}

/**
 * Staddress AI API を MCP ツールとして公開するサーバを構築する。
 *
 * @param getClient テスト用に差し替え可能なクライアントファクトリ
 */
export function createServer(getClient: ClientFactory = defaultClientFactory): McpServer {
  const server = new McpServer({ name: SERVER_NAME, version: SERVER_VERSION });

  server.registerTool(
    'staddress_parse',
    {
      title: '住所を解析',
      description:
        '日本語の住所文字列を正規化し、都道府県・市区町村・番地・建物などの構成要素に分解する。' +
        '緯度経度や信頼度も返す。API: POST /api/v1/addresses/parse',
      inputSchema: {
        input: z.string().describe('解析する住所文字列（例: 六本木ヒルズ 森タワー 52F）'),
        postalCode: z.string().optional().describe('郵便番号（任意、例: 106-6100）'),
      },
      annotations: readOnly,
    },
    async (args) => tools.parseAddress(getClient, args),
  );

  server.registerTool(
    'staddress_parse_batch',
    {
      title: '住所を一括解析',
      description:
        '複数の住所をまとめて解析する（Standard プラン以上、最大100件）。' +
        '各アイテムは id で結果と対応づく。API: POST /api/v1/addresses/parse/batch',
      inputSchema: {
        items: z
          .array(
            z.object({
              id: z.string().describe('結果を対応づける任意の識別子'),
              address: z.string().describe('住所文字列'),
              postalCode: z.string().optional().describe('郵便番号（任意）'),
            }),
          )
          .min(1)
          .max(100)
          .describe('解析する住所の配列（最大100件）'),
      },
      annotations: readOnly,
    },
    async (args) => tools.parseBatch(getClient, args),
  );

  server.registerTool(
    'staddress_get_usage',
    {
      title: '利用状況を取得',
      description:
        'API の利用状況（アカウント名・プラン・解析件数・月次上限・クレジット残高など）を取得する。' +
        'API: GET /api/v1/usage',
      inputSchema: {},
      annotations: readOnly,
    },
    async () => tools.getUsage(getClient),
  );

  return server;
}
