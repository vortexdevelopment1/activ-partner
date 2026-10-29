# ---- Build Stage ----
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Full release toolchain for a separate, explicitly invoked migration job.
# Never run migrations during image build or application startup.
FROM builder AS migrations
CMD ["node", "node_modules/prisma/build/index.js", "migrate", "deploy", "--config", "./prisma7.config.ts"]

# ---- Production Stage ----
FROM node:20-alpine AS production

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist

RUN mkdir -p uploads

EXPOSE 8080

CMD ["node", "dist/main"]
