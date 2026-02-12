FROM node:20-alpine AS base
RUN corepack enable && corepack prepare pnpm@10.26.1 --activate
WORKDIR /app

FROM base AS deps
ENV HUSKY=0
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY apps/api/package.json ./apps/api/
COPY packages/shared/package.json ./packages/shared/
RUN pnpm install --frozen-lockfile --filter @intonavio/api...

FROM base AS builder
COPY --from=deps /app ./
COPY tsconfig.base.json ./tsconfig.base.json
COPY packages/shared ./packages/shared
COPY apps/api ./apps/api
RUN cd packages/shared && pnpm build
RUN cd apps/api && npx prisma generate && pnpm build
RUN pnpm --filter @intonavio/api deploy --prod --legacy /app/deploy

FROM base AS runner
ENV NODE_ENV=production
WORKDIR /app
COPY --from=builder /app/deploy/node_modules ./node_modules
COPY --from=builder /app/deploy/dist ./dist
COPY --from=builder /app/deploy/prisma ./prisma

EXPOSE 3000
CMD ["node", "dist/main.js"]
