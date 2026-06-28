# @staddress/client

Staddress AI API 公式 Node.js / TypeScript SDK。

## ステータス

**Phase 2 — 未実装**

## インストール（予定）

```bash
npm install @staddress/client
yarn add @staddress/client
pnpm add @staddress/client
```

## 使用例（予定）

```typescript
import { StaddressClient } from '@staddress/client';

const client = new StaddressClient({
  apiKey: process.env.STADDRESS_API_KEY!,
  baseUrl: process.env.STADDRESS_BASE_URL!,
});

const { result } = await client.parseAddress({
  input: '六本木ヒルズ 森タワー 52F',
});
```

## 開発

```bash
cd packages/node
npm install
npm test
npm run build
```

詳細: [docs/plan-tools.md §3.3](../../docs/plan-tools.md)
