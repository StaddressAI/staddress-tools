#!/usr/bin/env node
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

import { SERVER_NAME, SERVER_VERSION, createServer } from './server.js';

async function main(): Promise<void> {
  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // stdout は MCP プロトコル専用。ログは必ず stderr へ。
  console.error(`${SERVER_NAME} v${SERVER_VERSION}: started (stdio)`);
}

main().catch((err) => {
  console.error(`${SERVER_NAME}: fatal error`, err);
  process.exit(1);
});
