#!/usr/bin/env node
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

import { listenHttp } from './http.js';
import { SERVER_NAME, SERVER_VERSION, createServer } from './server.js';

function wantsHttp(argv: string[]): boolean {
  if (argv.includes('--http')) return true;
  const transport = process.env.STADDRESS_MCP_TRANSPORT?.toLowerCase();
  return transport === 'http' || transport === 'streamable-http';
}

function parsePort(argv: string[]): number | undefined {
  const idx = argv.indexOf('--port');
  if (idx >= 0 && argv[idx + 1]) {
    const n = Number(argv[idx + 1]);
    if (Number.isFinite(n)) return n;
  }
  return undefined;
}

function parseHost(argv: string[]): string | undefined {
  const idx = argv.indexOf('--host');
  if (idx >= 0 && argv[idx + 1]) return argv[idx + 1];
  return undefined;
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);

  if (argv.includes('--help') || argv.includes('-h')) {
    console.error(`Usage: staddress-mcp [--http] [--host HOST] [--port PORT]

  (default)   stdio transport for Cursor / Claude Desktop
  --http      Streamable HTTP on /mcp (remote MCP / Smithery)

Env: STADDRESS_API_KEY, STADDRESS_BASE_URL, STADDRESS_MCP_TRANSPORT=http, PORT, HOST`);
    return;
  }

  if (wantsHttp(argv)) {
    await listenHttp({ host: parseHost(argv), port: parsePort(argv) });
    return;
  }

  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(`${SERVER_NAME} v${SERVER_VERSION}: started (stdio)`);
}

main().catch((err) => {
  console.error(`${SERVER_NAME}: fatal error`, err);
  process.exit(1);
});
