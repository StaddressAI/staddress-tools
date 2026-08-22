import { defineConfig } from 'tsup';

/** Desktop Extension 用。依存を server/index.js に同梱する。 */
export default defineConfig({
  entry: ['src/index.ts'],
  format: ['esm'],
  platform: 'node',
  target: 'node18',
  outDir: '.mcpb-stage/server',
  dts: false,
  sourcemap: false,
  clean: false,
  noExternal: [/.*/],
});
