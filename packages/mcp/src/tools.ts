import type { CallToolResult } from '@modelcontextprotocol/sdk/types.js';
import { StaddressClient, StaddressError } from '@staddress/client';

/** MCP ツールが返す結果（SDK の CallToolResult）。 */
export type ToolTextResult = CallToolResult;

/** StaddressClient を遅延生成するファクトリ（環境変数を呼び出し時に解決するため）。 */
export type ClientFactory = () => StaddressClient;

export interface ParseArgs {
  input: string;
  postalCode?: string;
}

export interface BatchArgs {
  items: Array<{ id: string; address: string; postalCode?: string }>;
}

function ok(data: unknown): ToolTextResult {
  return { content: [{ type: 'text', text: JSON.stringify(data, null, 2) }] };
}

function fail(message: string): ToolTextResult {
  return { content: [{ type: 'text', text: message }], isError: true };
}

/** 例外を利用者向けの分かりやすいメッセージに変換する。 */
export function describeError(err: unknown): string {
  if (err instanceof StaddressError) {
    const parts = [`code=${err.code}`, `http_status=${err.httpStatus}`];
    if (err.requestId) parts.push(`request_id=${err.requestId}`);
    if (err.retryAfter) parts.push(`retry_after=${err.retryAfter}`);
    return `Staddress API エラー: ${err.message} (${parts.join(', ')})`;
  }
  if (err instanceof Error) return `エラー: ${err.message}`;
  return `不明なエラー: ${String(err)}`;
}

async function run(
  getClient: ClientFactory,
  call: (client: StaddressClient) => Promise<unknown>,
): Promise<ToolTextResult> {
  let client: StaddressClient;
  try {
    client = getClient();
  } catch (err) {
    return fail(describeError(err));
  }
  try {
    return ok(await call(client));
  } catch (err) {
    return fail(describeError(err));
  }
}

/** 単件住所解析 (POST /api/v1/addresses/parse)。 */
export function parseAddress(getClient: ClientFactory, args: ParseArgs): Promise<ToolTextResult> {
  return run(getClient, (client) =>
    client.parseAddress({ input: args.input, postalCode: args.postalCode }),
  );
}

/** 一括住所解析 (POST /api/v1/addresses/parse/batch)。 */
export function parseBatch(getClient: ClientFactory, args: BatchArgs): Promise<ToolTextResult> {
  return run(getClient, (client) => client.parseBatch({ items: args.items }));
}

/** 利用状況取得 (GET /api/v1/usage)。 */
export function getUsage(getClient: ClientFactory): Promise<ToolTextResult> {
  return run(getClient, (client) => client.getUsage());
}
