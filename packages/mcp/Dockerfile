# Streamable HTTP 用。ビルド済み dist をコピーして起動する。
# 使い方（packages/mcp で）:
#   npm ci && npm run build
#   docker build -t staddress-mcp .
#   docker run --rm -p 8787:8787 staddress-mcp
FROM node:20-alpine
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY dist ./dist

ENV NODE_ENV=production
ENV STADDRESS_MCP_TRANSPORT=http
ENV HOST=0.0.0.0
ENV PORT=8787
EXPOSE 8787

USER node
CMD ["node", "dist/index.js", "--http"]
