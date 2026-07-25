# @staddress/client

Staddress AI API 公式 Node.js / TypeScript SDK。

## ステータス

**Phase 2 — v0.1 実装済み**（`parseAddress` / `parseBatch` / `getUsage`）

- 依存パッケージなし（Node.js 18+ のネイティブ `fetch` を使用）
- ESM / CommonJS デュアルパッケージ、型定義同梱

## インストール

```bash
npm install @staddress/client
# または
yarn add @staddress/client
pnpm add @staddress/client
```

## 使い方

```typescript
import { StaddressClient, StaddressError } from '@staddress/client';

const client = new StaddressClient({
  apiKey: process.env.STADDRESS_API_KEY, // 省略時は環境変数 STADDRESS_API_KEY
  baseUrl: process.env.STADDRESS_BASE_URL, // 省略時は https://api.staddress.com
  timeout: 30_000, // 任意（ミリ秒、既定 30000）
});

// 単件解析
const { result } = await client.parseAddress({
  input: '六本木ヒルズ 森タワー 52F',
  postalCode: '106-6100', // 任意
});
console.log(result.normalized);

// 一括解析（Standard プラン以上、最大100件）
const { results } = await client.parseBatch({
  items: [
    { id: '1', address: '東京都渋谷区道玄坂1-2-3' },
    { id: '2', address: '大阪府大阪市北区梅田1-1-1' },
  ],
});

// 利用状況
const usage = await client.getUsage();
```

## エラーハンドリング

API エラー・ネットワークエラーは `StaddressError` として throw されます。

```typescript
try {
  await client.parseAddress({ input: '...' });
} catch (err) {
  if (err instanceof StaddressError) {
    console.error(err.code);       // 例: 'unauthorized', 'quota_exceeded', 'unresolved'
    console.error(err.httpStatus); // HTTP ステータス（ネットワークエラー時は 0）
    console.error(err.requestId);  // サポート問い合わせ用（あれば）
    console.error(err.retryAfter); // 再試行可能日時（あれば）
  }
}
```

## API

| メソッド | HTTP | 説明 |
|----------|------|------|
| `parseAddress({ input, postalCode? })` | POST `/api/v1/addresses/parse` | 単件解析 |
| `parseBatch({ items })` | POST `/api/v1/addresses/parse/batch` | 一括解析（Standard+、最大100件） |
| `getUsage()` | GET `/api/v1/usage` | 利用状況 |

## 開発

```bash
cd packages/node
npm install
npm run typecheck   # 型チェック
npm test            # 単体テスト（vitest、fetch をモック）
npm run build       # dist/ に ESM + CJS + 型定義を出力
```

詳細: [docs/plan-tools.md §3.4](../../docs/plan-tools.md)
