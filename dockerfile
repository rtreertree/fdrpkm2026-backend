############################################
# 1) Install dependencies (cached layer)
############################################
FROM oven/bun:1-alpine AS deps
WORKDIR /app

# Copy only lockfiles first so this layer is cached unless deps change
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

############################################
# 2) Build (typecheck + bundle to dist/)
############################################
FROM oven/bun:1-alpine AS build
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Fail the build early on type errors (remove this line if you don't want it as a gate)
RUN bun run typecheck

# `bun build --target=bun` bundles all deps into dist/index.js,
# so the runtime image below doesn't need node_modules at all
RUN bun run build

############################################
# 3) Minimal production runtime
############################################
FROM oven/bun:1-alpine AS runtime
WORKDIR /app

ENV NODE_ENV=production
# Cloud Run injects PORT automatically; 8080 is the default it uses.
# Make sure src/config/env.ts reads process.env.PORT (falling back to 8080)
# and that the Elysia app calls .listen(Number(process.env.PORT) || 8080).
ENV PORT=8080

# Run as a non-root user
RUN addgroup -S app && adduser -S app -G app
USER app

COPY --from=build --chown=app:app /app/dist ./dist

EXPOSE 8080

CMD ["bun", "dist/index.js"]